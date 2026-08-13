#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "${script_dir}"
docker compose down
echo "SimNav Studio Local Web stopped. Its Docker data volume was preserved."
