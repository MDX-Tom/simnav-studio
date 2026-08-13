#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
port="${SIMNAV_WEB_PORT:-8010}"
relay_port="${SIMNAV_FR24_RELAY_PORT:-19223}"
data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
state_root="${data_home}/simnav-studio-web/Runtime"
profile_root="${data_home}/simnav-studio-web/FR24Browser"
state_file="${state_root}/fr24-docker-${port}.state"
relay_name="simnav-studio-web-fr24-relay"
relay_image="simnav-studio-fr24-relay:${SIMNAV_WEB_VERSION:-local}"
browser_pid=""
startup_complete=0

fail() {
  echo "$1" >&2
  exit 1
}

if ! [[ "${port}" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
  fail "Invalid SIMNAV_WEB_PORT: ${port}"
fi
if ! [[ "${relay_port}" =~ ^[0-9]+$ ]] || ((relay_port < 1024 || relay_port > 65535)); then
  fail "Invalid SIMNAV_FR24_RELAY_PORT: ${relay_port}"
fi
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  fail "Docker Engine with Compose v2 is required."
fi
if ! docker info >/dev/null 2>&1; then
  fail "Docker is installed but its engine is not running."
fi

browser_executable="${SIMNAV_FR24_BROWSER:-}"
if [[ -n "${browser_executable}" ]]; then
  [[ -x "${browser_executable}" ]] || fail "SIMNAV_FR24_BROWSER is not executable: ${browser_executable}"
else
  for candidate in google-chrome google-chrome-stable chromium chromium-browser microsoft-edge; do
    if browser_executable="$(command -v "${candidate}" 2>/dev/null)" && [[ -n "${browser_executable}" ]]; then
      break
    fi
  done
fi
[[ -n "${browser_executable}" && -x "${browser_executable}" ]] \
  || fail "Google Chrome, Microsoft Edge, or Chromium is required for the App-equivalent FR24 workflow."

if [[ "${SIMNAV_FR24_BROWSER_HEADLESS:-0}" != "1" \
      && -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  fail "A Linux desktop display is required to show the dedicated FR24 verification window."
fi

mkdir -p -- "${state_root}" "${profile_root}"
chmod 700 "${state_root}" "${profile_root}"

browser_process_is_owned() {
  local pid="$1"
  [[ "${pid}" =~ ^[0-9]+$ && -r "/proc/${pid}/cmdline" ]] || return 1
  tr '\0' '\n' < "/proc/${pid}/cmdline" \
    | grep -Fx -- "--user-data-dir=${profile_root}" >/dev/null 2>&1
}

browser_endpoint_is_ready() {
  local candidate_port="$1"
  [[ "${candidate_port}" =~ ^[0-9]+$ ]] || return 1
  curl --fail --silent --max-time 2 \
    "http://127.0.0.1:${candidate_port}/json/version" \
    | grep -q 'Protocol-Version'
}

get_available_tcp_port() {
  local candidate
  for _ in {1..200}; do
    candidate=$((22000 + ((RANDOM << 15 | RANDOM) % 33000)))
    if ((candidate != port && candidate != relay_port)) \
        && ! (exec 3<>"/dev/tcp/127.0.0.1/${candidate}") 2>/dev/null; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

clear_restored_fr24_tabs() {
  # Preserve the isolated profile's site data, but never restore stale raw
  # JSON/challenge tabs after a previous Local Web process has stopped.
  rm -rf -- "${profile_root}/Default/Sessions"
  rm -f -- \
    "${profile_root}/Default/Current Session" \
    "${profile_root}/Default/Current Tabs" \
    "${profile_root}/Default/Last Session" \
    "${profile_root}/Default/Last Tabs"
}

stop_owned_browser() {
  local pid="${browser_pid}"
  if browser_process_is_owned "${pid}"; then
    kill "${pid}" 2>/dev/null || true
    for _ in {1..50}; do
      kill -0 "${pid}" 2>/dev/null || return 0
      sleep 0.1
    done
    kill -KILL "${pid}" 2>/dev/null || true
  fi
}

cleanup_failed_start() {
  if ((startup_complete == 0)); then
    docker container stop "${relay_name}" >/dev/null 2>&1 || true
    docker container rm "${relay_name}" >/dev/null 2>&1 || true
    (
      cd -- "${script_dir}"
      docker compose down >/dev/null 2>&1 || true
    )
    stop_owned_browser
  fi
}
trap cleanup_failed_start EXIT HUP INT TERM

browser_port=""
if [[ -f "${state_file}" ]]; then
  recorded_pid="$(sed -n 's/^browser_pid=//p' "${state_file}" | head -n 1)"
  recorded_port="$(sed -n 's/^browser_port=//p' "${state_file}" | head -n 1)"
  if browser_process_is_owned "${recorded_pid}" && browser_endpoint_is_ready "${recorded_port}"; then
    browser_pid="${recorded_pid}"
    browser_port="${recorded_port}"
  fi
fi

if [[ -z "${browser_port}" ]]; then
  clear_restored_fr24_tabs
  rm -f -- "${profile_root}/DevToolsActivePort"
  browser_port="$(get_available_tcp_port)" \
    || fail "Unable to reserve a private loopback port for the FR24 browser."
  browser_arguments=(
    "--remote-debugging-port=${browser_port}"
    "--remote-debugging-address=127.0.0.1"
    "--user-data-dir=${profile_root}"
    "--no-first-run"
    "--no-default-browser-check"
    "--disable-sync"
    "--disable-background-mode"
    "--no-startup-window"
  )
  if [[ "${SIMNAV_FR24_BROWSER_HEADLESS:-0}" == "1" ]]; then
    browser_arguments=("--headless=new" "${browser_arguments[@]}")
  fi
  nohup "${browser_executable}" "${browser_arguments[@]}" \
    </dev/null >/dev/null 2>&1 &
  browser_pid="$!"
  for _ in {1..150}; do
    if browser_endpoint_is_ready "${browser_port}"; then
      break
    fi
    if ! kill -0 "${browser_pid}" 2>/dev/null; then
      fail "The dedicated FR24 browser exited during startup."
    fi
    sleep 0.1
  done
  browser_endpoint_is_ready "${browser_port}" \
    || fail "The dedicated FR24 browser did not expose its loopback session."
fi

export SIMNAV_WEB_PORT="${port}"
export SIMNAV_WEB_VERSION="${SIMNAV_WEB_VERSION:-local}"
cd -- "${script_dir}"

# Create the private Compose bridge before starting the relay. The relay binds
# only to that gateway address; Chromium itself continues to listen solely on
# host loopback.
docker compose create simnav-web >/dev/null
app_container="$(docker compose ps --all --quiet simnav-web)"
[[ -n "${app_container}" ]] || fail "Unable to create the SimNav Local Web container."
network_id="$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' "${app_container}")"
gateway="$(docker network inspect --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' "${network_id}")"
[[ "${gateway}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || fail "Unable to resolve the private SimNav Docker gateway."

docker build --target fr24-relay --tag "${relay_image}" . >/dev/null
if docker container inspect "${relay_name}" >/dev/null 2>&1; then
  docker container stop "${relay_name}" >/dev/null 2>&1 || true
  docker container rm "${relay_name}" >/dev/null
fi
docker run --detach \
  --name "${relay_name}" \
  --label com.simnav-studio.role=fr24-browser-relay \
  --network host \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --restart unless-stopped \
  "${relay_image}" \
  "TCP4-LISTEN:${relay_port},bind=${gateway},reuseaddr,fork" \
  "TCP4:127.0.0.1:${browser_port}" >/dev/null

export SIMNAV_FR24_CDP_ENDPOINT="http://${gateway}:${relay_port}"
unset SIMNAV_FR24_CDP_TOKEN || true

state_tmp="${state_file}.tmp.$$"
printf '%s\n' \
  "browser_pid=${browser_pid}" \
  "browser_port=${browser_port}" \
  "relay_port=${relay_port}" \
  "relay_name=${relay_name}" \
  > "${state_tmp}"
chmod 600 "${state_tmp}"
mv -f -- "${state_tmp}" "${state_file}"

"${script_dir}/run-container.sh"

status_payload="$(curl --fail --silent --max-time 5 \
  "http://127.0.0.1:${port}/api/fr24/browser/status")"
echo "${status_payload}" \
  | grep -Eq '"browser_adapter_available"[[:space:]]*:[[:space:]]*true' \
  || fail "The Local Web container could not reach its dedicated FR24 browser."
echo "FR24 managed browser bridge is ready on the private Docker network."
startup_complete=1
trap - EXIT HUP INT TERM
