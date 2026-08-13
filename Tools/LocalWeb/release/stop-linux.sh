#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
port="${SIMNAV_WEB_PORT:-8010}"
data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
state_root="${data_home}/simnav-studio-web/Runtime"
profile_root="${data_home}/simnav-studio-web/FR24Browser"
state_file="${state_root}/fr24-docker-${port}.state"
relay_name="simnav-studio-web-fr24-relay"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if docker container inspect "${relay_name}" >/dev/null 2>&1; then
    role="$(docker container inspect \
      --format '{{index .Config.Labels "com.simnav-studio.role"}}' \
      "${relay_name}")"
    if [[ "${role}" != "fr24-browser-relay" ]]; then
      echo "Refusing to stop an unexpected container named ${relay_name}." >&2
      exit 1
    fi
    docker container stop "${relay_name}" >/dev/null
    docker container rm "${relay_name}" >/dev/null
  fi
  "${script_dir}/stop-container.sh"
fi

if [[ -f "${state_file}" ]]; then
  browser_pid="$(sed -n 's/^browser_pid=//p' "${state_file}" | head -n 1)"
  if [[ "${browser_pid}" =~ ^[0-9]+$ && -r "/proc/${browser_pid}/cmdline" ]] \
      && tr '\0' '\n' < "/proc/${browser_pid}/cmdline" \
        | grep -Fx -- "--user-data-dir=${profile_root}" >/dev/null 2>&1; then
    kill "${browser_pid}" 2>/dev/null || true
    for _ in {1..50}; do
      kill -0 "${browser_pid}" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "${browser_pid}" 2>/dev/null; then
      kill -KILL "${browser_pid}" 2>/dev/null || true
    fi
  fi
  rm -f -- "${state_file}"
fi

echo "SimNav Studio Local Web and its dedicated FR24 browser stopped. User data and the isolated browser profile were preserved."
