#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
port="${SIMNAV_WEB_PORT:-8010}"
native_binary="${script_dir}/native/macos-universal/simnav-local-web"
state_dir="${TMPDIR:-/tmp}/simnav-studio-local-web-${UID}"
pid_file="${state_dir}/server-${port}.pid"

if [[ -f "${pid_file}" ]]; then
  server_pid="$(<"${pid_file}")"
  if [[ "${server_pid}" =~ ^[0-9]+$ ]] && kill -0 "${server_pid}" >/dev/null 2>&1; then
    command_line="$(ps -p "${server_pid}" -o command= 2>/dev/null || true)"
    if [[ "${command_line}" != *"${native_binary}"* ]]; then
      echo "Refusing to stop PID ${server_pid}: it is not this SimNav native server." >&2
      exit 1
    fi
    kill -TERM "${server_pid}"
    for _ in {1..50}; do
      if ! kill -0 "${server_pid}" >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done
    if kill -0 "${server_pid}" >/dev/null 2>&1; then
      echo "Native SimNav server did not stop after SIGTERM." >&2
      exit 1
    fi
    rm -f -- "${pid_file}"
    echo "SimNav Studio native Local Web stopped. Its data was preserved."
    exit 0
  fi
  rm -f -- "${pid_file}"
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  exec "${script_dir}/stop-container.sh"
fi
echo "No recorded native server is running, and Docker Compose is unavailable."
