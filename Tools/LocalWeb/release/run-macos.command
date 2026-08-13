#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
native_binary="${script_dir}/native/macos-universal/simnav-local-web"
bundled_database="${script_dir}/app/NavPlanner/Resources/Database/navdata.sqlite"
port="${SIMNAV_WEB_PORT:-8010}"
state_dir="${TMPDIR:-/tmp}/simnav-studio-local-web-${UID}"
pid_file="${state_dir}/server-${port}.pid"

if ! [[ "${port}" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
  echo "Invalid SIMNAV_WEB_PORT: ${port}" >&2
  exit 2
fi

if [[ ! -x "${native_binary}" ]]; then
  echo "The native macOS server is unavailable; using the Docker package."
  exec "${script_dir}/run-container.sh"
fi
if [[ ! -f "${bundled_database}" ]]; then
  echo "The bundled navigation database is missing: ${bundled_database}" >&2
  exit 1
fi

if lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port ${port} is already in use; nothing was changed." >&2
  exit 1
fi

export SIMNAV_WEB_PORT="${port}"
export SIMNAV_WEB_ROOT="${script_dir}/app/NavPlanner/Resources/Web"
export SIMNAV_DATABASE="${bundled_database}"
url="http://127.0.0.1:${port}"
umask 077
mkdir -p -- "${state_dir}"
"${native_binary}" &
server_pid=$!
printf '%s\n' "${server_pid}" > "${pid_file}"

# Invoked by the signal/exit trap below.
# shellcheck disable=SC2329
cleanup() {
  trap - HUP INT TERM EXIT
  if kill -0 "${server_pid}" >/dev/null 2>&1; then
    kill -TERM "${server_pid}" >/dev/null 2>&1 || true
    wait "${server_pid}" 2>/dev/null || true
  fi
  if [[ -f "${pid_file}" ]] && [[ "$(<"${pid_file}")" == "${server_pid}" ]]; then
    rm -f -- "${pid_file}"
  fi
}
trap cleanup HUP INT TERM EXIT

ready=0
for _ in {1..120}; do
  if ! kill -0 "${server_pid}" >/dev/null 2>&1; then
    wait "${server_pid}"
    exit $?
  fi
  if curl --noproxy '*' --fail --silent "${url}/healthz" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 0.5
done
if ((ready == 0)); then
  echo "SimNav Studio Local Web did not become ready at ${url}." >&2
  exit 1
fi

echo "SimNav Studio Local Web is ready: ${url}"
open "${url}"
echo "Keep this window open; press Control-C to stop the native server."
wait "${server_pid}"
exit_code=$?
rm -f -- "${pid_file}"
trap - HUP INT TERM EXIT
exit "${exit_code}"
