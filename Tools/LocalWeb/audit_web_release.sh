#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "${script_dir}/../.." && pwd)"
package_dir="${1:-}"
docker_smoke=0
expected_database=""

if [[ -z "${package_dir}" || ! -d "${package_dir}" ]]; then
  echo "usage: $0 /path/to/web-package [--docker-smoke] [--expected-database <file>]" >&2
  exit 2
fi
package_dir="$(cd -- "${package_dir}" && pwd)"
shift
while (($#)); do
  case "$1" in
    --docker-smoke)
      docker_smoke=1
      shift
      ;;
    --expected-database)
      (($# >= 2)) || { echo "Missing value after --expected-database." >&2; exit 2; }
      expected_database="$2"
      shift 2
      ;;
    *)
      echo "Unknown Web release audit option: $1" >&2
      exit 2
      ;;
  esac
done
if [[ -n "${expected_database}" ]]; then
  if [[ ! -f "${expected_database}" ]]; then
    echo "Expected Web release database is missing: ${expected_database}" >&2
    exit 2
  fi
  expected_database="$(cd -- "$(dirname -- "${expected_database}")" && pwd)/$(basename -- "${expected_database}")"
fi

required_files=(
  Dockerfile
  docker-compose.yml
  README.md
  SHA256SUMS.txt
  web-manifest.json
  run-macos.command
  run-windows.ps1
  run-linux.sh
  stop-macos.command
  stop-windows.ps1
  stop-linux.sh
  app/Package.swift
  app/Package.resolved
  app/NavPlanner/Resources/Database/navdata.sqlite
  app/NavPlanner/Resources/Web/map.html
  app/NavPlanner/Resources/Web/runtime.js
  app/NavPlanner/Core/Runtime/SimNavRuntimeRouter.swift
  app/LocalWeb/Sources/SimNavLocalWeb/LocalWebHTTPServer.swift
  app/LocalWeb/Sources/SimNavLocalWeb/LocalWebRequestProcessor.swift
  app/LocalWeb/Sources/SimNavLocalWeb/NIOHTTPServer.swift
  app/LocalWeb/Tests/SimNavCoreTests/PackageBoundaryTests.swift
  app/LocalWeb/Tests/SimNavLocalWebTests/LocalWebHTTPServerTests.swift
  app/LocalWeb/Tests/SimNavLocalWebTests/LocalWebRequestProcessorTests.swift
)
for required_file in "${required_files[@]}"; do
  if [[ ! -f "${package_dir}/${required_file}" ]]; then
    echo "Web package is missing ${required_file}." >&2
    exit 3
  fi
done

(
  cd -- "${package_dir}"
  shasum -a 256 -c SHA256SUMS.txt >/dev/null
)

web_source_count="$(find "${package_dir}" -type d -path '*/NavPlanner/Resources/Web' | wc -l | tr -d ' ')"
if [[ "${web_source_count}" != "1" ]]; then
  echo "Web package must contain exactly one NavPlanner/Resources/Web source; found ${web_source_count}." >&2
  exit 3
fi
diff -qr "${project_root}/NavPlanner/Resources/Web" \
  "${package_dir}/app/NavPlanner/Resources/Web" >/dev/null
diff -qr "${project_root}/NavPlanner/Core" \
  "${package_dir}/app/NavPlanner/Core" >/dev/null
diff -qr "${project_root}/LocalWeb" \
  "${package_dir}/app/LocalWeb" >/dev/null

if rg -n 'NavPlanner-web' "${package_dir}/app/Package.swift" \
    "${package_dir}/app/LocalWeb/Sources" "${package_dir}/app/LocalWeb/Support" >/dev/null; then
  echo "Web package has a runtime dependency on the deleted NavPlanner-web project." >&2
  exit 3
fi
python3 - "${package_dir}/app/Package.swift" <<'PY'
import re
import sys

source = open(sys.argv[1], "r", encoding="utf-8").read()
if 'exact: "2.101.3"' not in source:
    raise SystemExit("The direct SwiftNIO dependency is not pinned to the verified version.")
if not all(product in source for product in ('NIOCore', 'NIOHTTP1', 'NIOPosix')):
    raise SystemExit("The portable SwiftNIO HTTP adapter dependencies are incomplete.")
hummingbird = re.search(
    r'name:\s*"Hummingbird".*?condition:\s*\.when\(platforms:\s*\[(.*?)\]\)',
    source,
    re.S,
)
if not hummingbird or '.windows' in hummingbird.group(1):
    raise SystemExit("Hummingbird must remain excluded from the native Windows build.")
PY
bundled_database="${package_dir}/app/NavPlanner/Resources/Database/navdata.sqlite"
unexpected_database="$(
  find "${package_dir}" -type f \
    \( -iname '*.s3db' -o -iname '*.sqlite' -o -iname '*.sqlite3' -o -iname '*.db' \) \
    ! -path "${bundled_database}" -print -quit
)"
if [[ -n "${unexpected_database}" ]]; then
  echo "Web package contains an unexpected database: ${unexpected_database}" >&2
  exit 3
fi
if find "${package_dir}" -type f \
    \( -iname '*.mbtiles' -o -iname '*.pmtiles' -o -iname '*.gpx' -o -iname '*.log' \
       -o -iname '.DS_Store' \) -print -quit | grep -q .; then
  echo "Web package contains a user map, track, log, or Finder metadata file." >&2
  exit 3
fi
database_quick_check="$(sqlite3 -readonly "${bundled_database}" 'PRAGMA quick_check;')"
if [[ "${database_quick_check}" != "ok" ]]; then
  echo "Bundled Web database failed SQLite PRAGMA quick_check: ${database_quick_check}" >&2
  exit 3
fi
for table_name in tbl_header tbl_airports tbl_runways tbl_enroute_waypoints tbl_enroute_airways; do
  if [[ "$(sqlite3 -readonly "${bundled_database}" \
      "select count(*) from sqlite_master where type = 'table' and name = '${table_name}';")" != "1" ]]; then
    echo "Bundled Web database is missing required table: ${table_name}" >&2
    exit 3
  fi
done
database_sha="$(shasum -a 256 "${bundled_database}" | awk '{print $1}')"
database_size="$(wc -c < "${bundled_database}" | tr -d '[:space:]')"
database_airac="$(sqlite3 -readonly "${bundled_database}" 'select current_airac from tbl_header limit 1;')"
database_revision="$(sqlite3 -readonly "${bundled_database}" 'select revision from tbl_header limit 1;')"
if [[ -n "${expected_database}" ]] && ! cmp -s "${bundled_database}" "${expected_database}"; then
  echo "Bundled Web database differs from the release-selected database." >&2
  exit 3
fi
if rg -n -i '/Users/[^/]+/|/home/[^/]+/|[A-Z]:\\Users\\[^\\]+\\|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' \
    "${package_dir}" --glob '*.json' --glob '*.md' --glob '*.txt' --glob '*.ps1' \
    --glob '*.sh' --glob '*.swift' >/dev/null; then
  echo "Web package contains a developer path or private-key marker." >&2
  exit 3
fi

python3 - "${package_dir}/web-manifest.json" \
  "${database_sha}" "${database_size}" "${database_airac}" "${database_revision}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)
if manifest.get("schema_version") != 2 or manifest.get("platform") != "web":
    raise SystemExit("Invalid Web manifest schema/platform.")
if manifest.get("database_included") is not True:
    raise SystemExit("Web manifest must state that the release database is included.")
database = manifest.get("bundled_database", {})
expected_database = {
    "path": "app/NavPlanner/Resources/Database/navdata.sqlite",
    "sha256": sys.argv[2],
    "size_bytes": int(sys.argv[3]),
    "current_airac": sys.argv[4],
    "revision": sys.argv[5],
    "sqlite_quick_check": "passed",
}
if database != expected_database:
    raise SystemExit("Web manifest bundled_database metadata does not match the packaged database.")
if manifest.get("ui_source") != "app/NavPlanner/Resources/Web":
    raise SystemExit("Web manifest does not identify the canonical UI source.")
if manifest.get("http_transports") != {
    "macos": "hummingbird-2.22.0",
    "linux": "hummingbird-2.22.0",
    "windows": "swift-nio-2.101.3",
}:
    raise SystemExit("Web manifest does not pin the platform HTTP transports.")
security = manifest.get("security", {})
if security.get("published_host") != "127.0.0.1":
    raise SystemExit("Web manifest does not enforce loopback publication.")
PY

docker compose -f "${package_dir}/docker-compose.yml" config > /dev/null
if ! docker compose -f "${package_dir}/docker-compose.yml" config \
    | rg -q 'host_ip: 127\.0\.0\.1'; then
  echo "Compose does not publish the Web port exclusively on IPv4 loopback." >&2
  exit 3
fi
if ! rg -q '^USER 10001:10001$' "${package_dir}/Dockerfile" \
    || ! rg -q 'read_only: true' "${package_dir}/docker-compose.yml" \
    || ! rg -q 'no-new-privileges:true' "${package_dir}/docker-compose.yml"; then
  echo "Container non-root/read-only/no-new-privileges gates are incomplete." >&2
  exit 3
fi
if ! rg -q 'SIMNAV_DATABASE=/opt/simnav/Database/navdata.sqlite' "${package_dir}/Dockerfile" \
    || ! rg -q 'SIMNAV_DATABASE: /opt/simnav/Database/navdata.sqlite' "${package_dir}/docker-compose.yml" \
    || ! rg -q 'SIMNAV_DATABASE="\$\{bundled_database\}"' "${package_dir}/run-macos.command" \
    || ! rg -q 'SIMNAV_DATABASE = \$BundledDatabase' "${package_dir}/run-windows.ps1"; then
  echo "A Web launcher does not select the bundled release database." >&2
  exit 3
fi
bash -n \
  "${package_dir}/run-container.sh" \
  "${package_dir}/run-linux.sh" \
  "${package_dir}/run-macos.command" \
  "${package_dir}/stop-container.sh" \
  "${package_dir}/stop-linux.sh" \
  "${package_dir}/stop-macos.command"

if ((docker_smoke == 1)); then
  if ! docker info >/dev/null 2>&1; then
    echo "Docker smoke was requested, but the Docker engine is unavailable." >&2
    exit 4
  fi
  image_name="simnav-local-web-audit:local"
  test_image_name="simnav-local-web-audit-tests:local"
  container_name="simnav-local-web-audit-$$"
  volume_name="simnav-local-web-audit-data-$$"
  smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/simnav-web-audit.XXXXXX")"
  container_id=""
  cleanup_container() {
    if [[ -n "${container_id:-}" ]]; then
      docker rm --force "${container_id}" >/dev/null 2>&1 || true
    fi
    docker volume rm --force "${volume_name}" >/dev/null 2>&1 || true
    rm -rf -- "${smoke_root}"
  }
  trap cleanup_container EXIT HUP INT TERM
  fixture_database="${smoke_root}/linux-fixture.s3db"
  nio_fixture_database="${smoke_root}/linux-nio-fixture.s3db"
  python3 - "${fixture_database}" "${nio_fixture_database}" <<'PY'
import sqlite3
import sys

for path, revision in (
    (sys.argv[1], "linux-container-smoke"),
    (sys.argv[2], "linux-nio-smoke"),
):
    database = sqlite3.connect(path)
    database.executescript(f"""
    CREATE TABLE tbl_header (current_airac TEXT, revision TEXT);
    INSERT INTO tbl_header VALUES ('9999', '{revision}');
    CREATE TABLE tbl_airports (airport_identifier TEXT);
    CREATE TABLE tbl_runways (airport_identifier TEXT);
    CREATE TABLE tbl_enroute_waypoints (waypoint_identifier TEXT);
    CREATE TABLE tbl_enroute_airways (route_identifier TEXT);
    """)
    database.close()
PY
  smoke_port="$(python3 - <<'PY'
import socket
with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    print(listener.getsockname()[1])
PY
)"
  docker build --quiet --target tester --tag "${test_image_name}" "${package_dir}" >/dev/null
  docker run --rm --init --entrypoint /bin/sh "${test_image_name}" -lc '
    set -eu
    test_binary="$(find /source/.build -type f -name "SimNavStudioPackageTests.xctest" -perm -111 -print -quit)"
    test -n "${test_binary}"
    test_list=/tmp/simnav-release-tests.txt
    "${test_binary}" -l \
      | sed -n "/^[A-Za-z0-9_][A-Za-z0-9_.]*\/[A-Za-z0-9_]/p" \
      > "${test_list}"
    test_count="$(wc -l < "${test_list}" | tr -d "[:space:]")"
    if [ "${test_count}" -lt 24 ]; then
      echo "Expected at least 24 packaged Swift tests, found ${test_count}." >&2
      exit 1
    fi
    while IFS= read -r test_name; do
      test_output=/tmp/simnav-packaged-swift-test.txt
      set +e
      timeout --kill-after=10 120 "${test_binary}" "${test_name}" \
        > "${test_output}" 2>&1
      test_status=$?
      set -e
      if [ "${test_status}" -eq 124 ] || [ "${test_status}" -eq 137 ]; then
        echo "Packaged Swift test timed out once; retrying in a fresh process: ${test_name}" >&2
        set +e
        timeout --kill-after=10 120 "${test_binary}" "${test_name}" \
          > "${test_output}" 2>&1
        test_status=$?
        set -e
      fi
      if [ "${test_status}" -ne 0 ]; then
        cat "${test_output}" >&2
        echo "Packaged Swift test failed with status ${test_status}: ${test_name}" >&2
        exit "${test_status}"
      fi
      echo "Packaged Swift test passed: ${test_name}"
    done < "${test_list}"
  '
  docker build --quiet --tag "${image_name}" "${package_dir}" >/dev/null
  docker volume create "${volume_name}" >/dev/null
  container_id="$(docker run --rm --detach \
    --name "${container_name}" \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --tmpfs /tmp:rw,size=256m,mode=1777 \
    --mount "type=volume,source=${volume_name},target=/var/lib/simnav/data" \
    --publish "127.0.0.1:${smoke_port}:${smoke_port}" \
    --env SIMNAV_WEB_PORT="${smoke_port}" \
    --env SIMNAV_WRITE_TOKEN=containerreleaseaudit0123456789abcdef \
    "${image_name}")"
  ready=0
  for _ in {1..120}; do
    if curl --noproxy '*' --fail --silent "http://127.0.0.1:${smoke_port}/healthz" >/dev/null 2>&1; then
      ready=1
      break
    fi
    if ! docker inspect "${container_id}" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  if ((ready == 0)); then
    docker logs "${container_id}" >&2 || true
    echo "Linux container health smoke failed." >&2
    exit 4
  fi
  bundled_header_payload="$(curl --noproxy '*' --fail --silent --show-error \
    "http://127.0.0.1:${smoke_port}/api/header")"
  python3 - "${bundled_header_payload}" "${database_airac}" "${database_revision}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
expected = {
    "current_airac": sys.argv[2],
    "revision": sys.argv[3],
    "database_name": "navdata.sqlite",
}
if any(payload.get(key) != value for key, value in expected.items()):
    raise SystemExit("Linux container did not activate the bundled release database on first launch")
PY
  curl --noproxy '*' --fail --silent "http://127.0.0.1:${smoke_port}/" \
    | rg -q 'SimNav Studio'
  forbidden_status="$(curl --noproxy '*' --silent --output /dev/null --write-out '%{http_code}' \
    --header 'Host: example.invalid' "http://127.0.0.1:${smoke_port}/api/header")"
  if [[ "${forbidden_status}" != "403" ]]; then
    echo "Container Host validation returned ${forbidden_status}, expected 403." >&2
    exit 4
  fi
  inspect_gate="$(docker inspect --format '{{.Config.User}} {{.HostConfig.ReadonlyRootfs}} {{json .HostConfig.CapDrop}}' \
    "${container_id}")"
  if [[ "${inspect_gate}" != '10001:10001 true ["ALL"]' ]]; then
    echo "Unexpected container security state: ${inspect_gate}" >&2
    exit 4
  fi

  import_payload="$(curl --noproxy '*' --fail --silent --show-error \
    --request POST \
    --header "Origin: http://127.0.0.1:${smoke_port}" \
    --header 'X-SimNav-Filename: linux-fixture.s3db' \
    --header 'X-SimNav-Token: containerreleaseaudit0123456789abcdef' \
    --header 'Content-Type: application/octet-stream' \
    --data-binary "@${fixture_database}" \
    "http://127.0.0.1:${smoke_port}/api/databases/import")"
  python3 - "${import_payload}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if payload.get("local_status") != "ready" or payload.get("database_name") != "linux_fixture.sqlite":
    raise SystemExit("Linux container database import did not activate the fixture")
PY

  docker rm --force "${container_id}" >/dev/null
  container_id=""
  container_id="$(docker run --rm --detach \
    --name "${container_name}" \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --tmpfs /tmp:rw,size=256m,mode=1777 \
    --mount "type=volume,source=${volume_name},target=/var/lib/simnav/data" \
    --publish "127.0.0.1:${smoke_port}:${smoke_port}" \
    --env SIMNAV_WEB_PORT="${smoke_port}" \
    --env SIMNAV_WRITE_TOKEN=containerreleaseaudit0123456789abcdef \
    "${image_name}")"
  ready=0
  for _ in {1..120}; do
    if curl --noproxy '*' --fail --silent "http://127.0.0.1:${smoke_port}/healthz" >/dev/null 2>&1; then
      ready=1
      break
    fi
    if ! docker inspect "${container_id}" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  if ((ready == 0)); then
    docker logs "${container_id}" >&2 || true
    echo "Restarted Linux container health smoke failed." >&2
    exit 4
  fi
  header_payload="$(curl --noproxy '*' --fail --silent --show-error \
    "http://127.0.0.1:${smoke_port}/api/header")"
  python3 - "${header_payload}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
expected = {
    "current_airac": "9999",
    "revision": "linux-container-smoke",
    "database_name": "linux_fixture.sqlite",
}
if any(payload.get(key) != value for key, value in expected.items()):
    raise SystemExit("Linux container database selection did not survive restart")
PY

  docker rm --force "${container_id}" >/dev/null
  container_id=""
  container_id="$(docker run --rm --detach \
    --name "${container_name}" \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --tmpfs /tmp:rw,size=256m,mode=1777 \
    --mount "type=volume,source=${volume_name},target=/var/lib/simnav/data" \
    --publish "127.0.0.1:${smoke_port}:${smoke_port}" \
    --env SIMNAV_WEB_PORT="${smoke_port}" \
    --env SIMNAV_WRITE_TOKEN=containerreleaseaudit0123456789abcdef \
    --env SIMNAV_HTTP_TRANSPORT=nio \
    "${image_name}")"
  ready=0
  for _ in {1..120}; do
    if curl --noproxy '*' --fail --silent "http://127.0.0.1:${smoke_port}/healthz" >/dev/null 2>&1; then
      ready=1
      break
    fi
    if ! docker inspect "${container_id}" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  if ((ready == 0)); then
    docker logs "${container_id}" >&2 || true
    echo "Portable SwiftNIO transport health smoke failed." >&2
    exit 4
  fi
  curl --noproxy '*' --fail --silent "http://127.0.0.1:${smoke_port}/" \
    | rg -q 'SimNav Studio'
  nio_forbidden_status="$(curl --noproxy '*' --silent --output /dev/null --write-out '%{http_code}' \
    --header 'Host: example.invalid' "http://127.0.0.1:${smoke_port}/api/header")"
  if [[ "${nio_forbidden_status}" != "403" ]]; then
    echo "SwiftNIO Host validation returned ${nio_forbidden_status}, expected 403." >&2
    exit 4
  fi
  docker exec "${container_id}" /bin/sh -c \
    "mkdir -p /var/lib/simnav/data/MapOffline && printf '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_' > /var/lib/simnav/data/MapOffline/nio-range.pmtiles"
  nio_range_headers="${smoke_root}/nio-range.headers"
  nio_range_body="${smoke_root}/nio-range.body"
  curl --noproxy '*' --fail --silent --show-error \
    --header 'Range: bytes=4-11' \
    --dump-header "${nio_range_headers}" \
    --output "${nio_range_body}" \
    "http://127.0.0.1:${smoke_port}/api/offline-maps/pmtiles/nio-range.pmtiles"
  if ! rg -q '^HTTP/[0-9.]+ 206' "${nio_range_headers}" \
      || ! rg -qi '^Content-Range: bytes 4-11/64' "${nio_range_headers}" \
      || [[ "$(cat "${nio_range_body}")" != '456789ab' ]]; then
    echo "SwiftNIO PMTiles Range transport parity failed." >&2
    exit 4
  fi
  nio_invalid_range_status="$(curl --noproxy '*' --silent --output /dev/null --write-out '%{http_code}' \
    --header 'Range: bytes=64-80' \
    "http://127.0.0.1:${smoke_port}/api/offline-maps/pmtiles/nio-range.pmtiles")"
  if [[ "${nio_invalid_range_status}" != "416" ]]; then
    echo "SwiftNIO invalid PMTiles Range returned ${nio_invalid_range_status}, expected 416." >&2
    exit 4
  fi
  inherited_header="$(curl --noproxy '*' --fail --silent --show-error \
    "http://127.0.0.1:${smoke_port}/api/header")"
  python3 - "${inherited_header}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if payload.get("revision") != "linux-container-smoke":
    raise SystemExit("SwiftNIO transport did not read the shared persisted data root")
PY
  nio_import_payload="$(curl --noproxy '*' --fail --silent --show-error \
    --request POST \
    --header "Origin: http://127.0.0.1:${smoke_port}" \
    --header 'X-SimNav-Filename: linux-nio-fixture.s3db' \
    --header 'X-SimNav-Token: containerreleaseaudit0123456789abcdef' \
    --header 'Content-Type: application/octet-stream' \
    --data-binary "@${nio_fixture_database}" \
    "http://127.0.0.1:${smoke_port}/api/databases/import")"
  python3 - "${nio_import_payload}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if payload.get("database_name") != "linux_nio_fixture.sqlite":
    raise SystemExit("SwiftNIO transport database upload did not activate the fixture")
PY

  docker rm --force "${container_id}" >/dev/null
  container_id=""
  container_id="$(docker run --rm --detach \
    --name "${container_name}" \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --tmpfs /tmp:rw,size=256m,mode=1777 \
    --mount "type=volume,source=${volume_name},target=/var/lib/simnav/data" \
    --publish "127.0.0.1:${smoke_port}:${smoke_port}" \
    --env SIMNAV_WEB_PORT="${smoke_port}" \
    --env SIMNAV_WRITE_TOKEN=containerreleaseaudit0123456789abcdef \
    --env SIMNAV_HTTP_TRANSPORT=nio \
    "${image_name}")"
  ready=0
  for _ in {1..120}; do
    if curl --noproxy '*' --fail --silent "http://127.0.0.1:${smoke_port}/healthz" >/dev/null 2>&1; then
      ready=1
      break
    fi
    if ! docker inspect "${container_id}" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  if ((ready == 0)); then
    docker logs "${container_id}" >&2 || true
    echo "Restarted SwiftNIO transport health smoke failed." >&2
    exit 4
  fi
  nio_header_payload="$(curl --noproxy '*' --fail --silent --show-error \
    "http://127.0.0.1:${smoke_port}/api/header")"
  python3 - "${nio_header_payload}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
expected = {
    "current_airac": "9999",
    "revision": "linux-nio-smoke",
    "database_name": "linux_nio_fixture.sqlite",
}
if any(payload.get(key) != value for key, value in expected.items()):
    raise SystemExit("SwiftNIO transport database selection did not survive restart")
PY

  cleanup_container
  container_id=""
  trap - EXIT HUP INT TERM
fi

echo "WEB_RELEASE_AUDIT=PASS"
echo "WEB_SINGLE_UI_AND_SWIFT_CORE_PARITY=passed"
echo "WEB_PACKAGE_CHECKSUMS=passed"
echo "WEB_BUNDLED_DATABASE_PARITY=passed"
echo "WEB_LOOPBACK_AND_CONTAINER_SECURITY=passed"
if ((docker_smoke == 1)); then
  echo "WEB_LINUX_SWIFT_TESTS=passed"
  echo "WEB_LINUX_CONTAINER_SMOKE=passed"
  echo "WEB_LINUX_RESTART_PERSISTENCE=passed"
  echo "WEB_PORTABLE_SWIFTNIO_TRANSPORT_SMOKE=passed"
fi
