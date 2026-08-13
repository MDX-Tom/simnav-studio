#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "${script_dir}/../.." && pwd)"
port=8010
no_open=0
database_provided=0
server_args=()

usage() {
  sed -n '1,28p' "${script_dir}/README.md"
}

while (($#)); do
  case "$1" in
    --port)
      if (($# < 2)); then
        echo "Missing value after --port." >&2
        exit 2
      fi
      port="$2"
      server_args+=("$1" "$2")
      shift 2
      ;;
    --database)
      if (($# < 2)); then
        echo "Missing value after --database." >&2
        exit 2
      fi
      database_provided=1
      server_args+=("$1" "$2")
      shift 2
      ;;
    --data-dir|--web-root|--write-token)
      if (($# < 2)); then
        echo "Missing value after $1." >&2
        exit 2
      fi
      server_args+=("$1" "$2")
      shift 2
      ;;
    --no-open)
      no_open=1
      shift
      ;;
    --watch)
      echo "--watch is reserved for a later development-reload phase." >&2
      exit 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown Local Web argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "${port}" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
  echo "Invalid port: ${port}" >&2
  exit 2
fi

if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port ${port} is already in use; no existing process was changed." >&2
  exit 1
fi

if [[ -n "${SIMNAV_SWIFT_BIN:-}" ]]; then
  swift_bin="${SIMNAV_SWIFT_BIN}"
else
  swift_bin="$(command -v swift || true)"
fi
if [[ -z "${swift_bin}" || ! -x "${swift_bin}" ]]; then
  echo "Swift 6.1 or newer is required to run the native Local Web server." >&2
  exit 1
fi

if ! swift_version="$(${swift_bin} --version 2>&1 | head -n 1)"; then
  echo "Unable to execute Swift at ${swift_bin}. Set SIMNAV_SWIFT_BIN to a working Swift 6.1+ binary." >&2
  exit 1
fi
if [[ ! "${swift_version}" =~ Swift[[:space:]]version[[:space:]]([0-9]+)\.([0-9]+) ]]; then
  echo "Unable to determine Swift version from: ${swift_version}" >&2
  exit 1
fi
swift_major="${BASH_REMATCH[1]}"
swift_minor="${BASH_REMATCH[2]}"
if ((swift_major < 6 || (swift_major == 6 && swift_minor < 1))); then
  echo "Swift 6.1 or newer is required; found ${swift_major}.${swift_minor}." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for the Local Web readiness check." >&2
  exit 1
fi

if ((database_provided == 0)) && [[ -f "${project_root}/database/e_dfd_PMDG_release.s3db" ]]; then
  server_args+=("--database" "${project_root}/database/e_dfd_PMDG_release.s3db")
fi

export SIMNAV_WEB_ROOT="${SIMNAV_WEB_ROOT:-${project_root}/NavPlanner/Resources/Web}"
url="http://127.0.0.1:${port}"

(
  cd -- "${project_root}"
  exec "${swift_bin}" run simnav-local-web "${server_args[@]}"
) &
server_pid=$!

# Invoked by the signal/exit trap below.
# shellcheck disable=SC2329
cleanup() {
  trap - INT TERM EXIT
  if kill -0 "${server_pid}" >/dev/null 2>&1; then
    kill -TERM "${server_pid}" >/dev/null 2>&1 || true
    wait "${server_pid}" 2>/dev/null || true
  fi
}
trap cleanup INT TERM EXIT

ready=0
for _ in {1..240}; do
  if ! kill -0 "${server_pid}" >/dev/null 2>&1; then
    wait "${server_pid}"
    exit $?
  fi
  if curl --noproxy '*' --fail --silent --show-error "${url}/healthz" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 0.5
done

if ((ready == 0)); then
  echo "Local Web did not become ready at ${url}." >&2
  exit 1
fi

echo "SimNav Studio Local Web is ready: ${url}"
if ((no_open == 0)); then
  if command -v open >/dev/null 2>&1; then
    open "${url}"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${url}" >/dev/null 2>&1 || true
  else
    echo "Open ${url} in a browser."
  fi
fi

wait "${server_pid}"
exit_code=$?
trap - INT TERM EXIT
exit "${exit_code}"
