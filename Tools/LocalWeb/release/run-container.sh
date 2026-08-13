#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
port="${SIMNAV_WEB_PORT:-8010}"

if ! [[ "${port}" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
  echo "Invalid SIMNAV_WEB_PORT: ${port}" >&2
  exit 2
fi
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "Docker Desktop or Docker Engine with Compose v2 is required." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "Docker is installed but its engine is not running." >&2
  exit 1
fi

export SIMNAV_WEB_PORT="${port}"
export SIMNAV_WEB_VERSION="${SIMNAV_WEB_VERSION:-local}"
cd -- "${script_dir}"
existing_container="$(docker compose ps --quiet simnav-web 2>/dev/null || true)"
port_busy=0
if command -v lsof >/dev/null 2>&1; then
  if lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
    port_busy=1
  fi
elif command -v ss >/dev/null 2>&1; then
  if ss -H -ltn | awk -v suffix=":${port}" '$4 ~ (suffix "$") { found=1 } END { exit !found }'; then
    port_busy=1
  fi
fi
if ((port_busy == 1)) && [[ -z "${existing_container}" ]]; then
  echo "Port ${port} is already in use by another process; nothing was changed." >&2
  exit 1
fi
docker compose up --detach --build

ready=0
for _ in {1..180}; do
  if docker compose exec --no-TTY simnav-web \
      curl --fail --silent "http://127.0.0.1:${port}/healthz" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if ((ready == 0)); then
  echo "SimNav Studio Local Web did not become ready." >&2
  docker compose logs --tail=100 simnav-web >&2 || true
  exit 1
fi

url="http://127.0.0.1:${port}"
echo "SimNav Studio Local Web is ready: ${url}"
if command -v open >/dev/null 2>&1; then
  open "${url}"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "${url}" >/dev/null 2>&1 || true
else
  echo "Open ${url} in a browser."
fi
echo "The container stays active after this window closes. Run the matching stop script to stop it."
