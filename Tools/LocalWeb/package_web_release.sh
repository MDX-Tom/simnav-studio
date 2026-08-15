#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "${script_dir}/../.." && pwd)"
template_root="${script_dir}/release"
output_path=""
build_macos_native=0
windows_native=""
database_source="${project_root}/database/e_dfd_PMDG_release.s3db"

usage() {
  cat <<'USAGE'
usage: Tools/LocalWeb/package_web_release.sh --output <new-directory> [options]

Options:
  --build-macos-native       Build and include a universal arm64+x86_64 macOS server.
  --windows-native <dir>     Include a prebuilt Windows bundle containing simnav-local-web.exe.
  --database <file>          Bundle this release-selected SQLite/S3DB navigation database.
                             Defaults to database/e_dfd_PMDG_release.s3db.
  --help                     Show this help.
USAGE
}

while (($#)); do
  case "$1" in
    --output)
      (($# >= 2)) || { echo "Missing value after --output." >&2; exit 2; }
      output_path="$2"
      shift 2
      ;;
    --build-macos-native)
      build_macos_native=1
      shift
      ;;
    --windows-native)
      (($# >= 2)) || { echo "Missing value after --windows-native." >&2; exit 2; }
      windows_native="$2"
      shift 2
      ;;
    --database)
      (($# >= 2)) || { echo "Missing value after --database." >&2; exit 2; }
      database_source="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown Web release option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${output_path}" ]]; then
  usage >&2
  exit 2
fi
output_parent="$(dirname -- "${output_path}")"
output_name="$(basename -- "${output_path}")"
mkdir -p -- "${output_parent}"
output_parent="$(cd -- "${output_parent}" && pwd)"
output_path="${output_parent}/${output_name}"
if [[ "${output_name}" == "." || "${output_name}" == ".." || -e "${output_path}" ]]; then
  echo "Output already exists or is unsafe; move it aside explicitly: ${output_path}" >&2
  exit 2
fi
if [[ ! -f "${project_root}/Package.swift" || ! -f "${project_root}/Package.resolved" ]]; then
  echo "Swift package inputs are incomplete." >&2
  exit 2
fi
if [[ ! -f "${project_root}/NavPlanner/Resources/Web/map.html" ]]; then
  echo "The canonical Web source is missing." >&2
  exit 2
fi
if [[ ! -f "${database_source}" ]]; then
  echo "The Web release database is missing: ${database_source}" >&2
  exit 2
fi
database_source="$(cd -- "$(dirname -- "${database_source}")" && pwd)/$(basename -- "${database_source}")"
case "${database_source##*.}" in
  db|s3db|sqlite|sqlite3) ;;
  *) echo "Unsupported Web release database: ${database_source}" >&2; exit 2 ;;
esac
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is required to validate the Web release database." >&2
  exit 2
fi
database_quick_check="$(sqlite3 -readonly "${database_source}" 'PRAGMA quick_check;')"
if [[ "${database_quick_check}" != "ok" ]]; then
  echo "Web release database failed SQLite PRAGMA quick_check: ${database_quick_check}" >&2
  exit 2
fi
required_database_tables=(
  tbl_header
  tbl_airports
  tbl_runways
  tbl_enroute_waypoints
  tbl_enroute_airways
)
for table_name in "${required_database_tables[@]}"; do
  if [[ "$(sqlite3 -readonly "${database_source}" \
      "select count(*) from sqlite_master where type = 'table' and name = '${table_name}';")" != "1" ]]; then
    echo "Web release database is missing required table: ${table_name}" >&2
    exit 2
  fi
done
database_airac="$(sqlite3 -readonly "${database_source}" 'select current_airac from tbl_header limit 1;')"
database_revision="$(sqlite3 -readonly "${database_source}" 'select revision from tbl_header limit 1;')"
if [[ -z "${database_airac}" || -z "${database_revision}" ]]; then
  echo "Web release database header is incomplete." >&2
  exit 2
fi
database_sha="$(shasum -a 256 "${database_source}" | awk '{print $1}')"
database_size="$(wc -c < "${database_source}" | tr -d '[:space:]')"
if rg -n 'NavPlanner-web' "${project_root}/Package.swift" \
    "${project_root}/LocalWeb/Sources" "${project_root}/LocalWeb/Support" >/dev/null; then
  echo "Local Web packaging must not depend on the deleted NavPlanner-web project." >&2
  exit 3
fi

staging_root="$(mktemp -d "${output_parent}/.simnav-web-package.XXXXXX")"
package_root="${staging_root}/web"
cleanup() {
  rm -rf -- "${staging_root}"
}
trap cleanup EXIT HUP INT TERM

mkdir -p \
  "${package_root}/app/NavPlanner" \
  "${package_root}/app/LocalWeb" \
  "${package_root}/native"
cp "${project_root}/Package.swift" "${project_root}/Package.resolved" "${package_root}/app/"
cp -R "${project_root}/NavPlanner/Core" "${package_root}/app/NavPlanner/"
mkdir -p "${package_root}/app/NavPlanner/Resources"
cp -R "${project_root}/NavPlanner/Resources/Web" "${package_root}/app/NavPlanner/Resources/"
mkdir -p "${package_root}/app/NavPlanner/Resources/Database"
cp "${database_source}" \
  "${package_root}/app/NavPlanner/Resources/Database/navdata.sqlite"
cp -R "${project_root}/LocalWeb/Sources" "${project_root}/LocalWeb/Support" \
  "${project_root}/LocalWeb/Tests" \
  "${package_root}/app/LocalWeb/"

for template in \
  Dockerfile docker-compose.yml .dockerignore README.md \
  fr24-browser-bridge.ps1 \
  run-container.sh run-linux.sh run-macos.command run-windows.ps1 \
  stop-container.sh stop-linux.sh stop-macos.command stop-windows.ps1; do
  cp "${template_root}/${template}" "${package_root}/${template}"
done
cp "${script_dir}/build_windows_native.ps1" "${package_root}/build-windows-native.ps1"
chmod +x \
  "${package_root}/run-container.sh" \
  "${package_root}/run-linux.sh" \
  "${package_root}/run-macos.command" \
  "${package_root}/stop-container.sh" \
  "${package_root}/stop-linux.sh" \
  "${package_root}/stop-macos.command"

macos_native_included=false
if ((build_macos_native == 1)); then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "--build-macos-native requires macOS." >&2
    exit 2
  fi
  if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    if [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
      export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
    elif [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
      export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    else
      echo "A complete Xcode installation is required for the universal macOS server." >&2
      exit 2
    fi
  fi
  swift build --package-path "${project_root}" --configuration release \
    --product simnav-local-web --arch arm64 --arch x86_64
  macos_bin_dir="$(swift build --package-path "${project_root}" --configuration release \
    --show-bin-path --arch arm64 --arch x86_64)"
  macos_binary="${macos_bin_dir}/simnav-local-web"
  if [[ ! -f "${macos_binary}" ]]; then
    echo "Universal macOS Local Web binary was not produced: ${macos_binary}" >&2
    exit 3
  fi
  macos_archs="$(lipo -archs "${macos_binary}")"
  if [[ " ${macos_archs} " != *" arm64 "* || " ${macos_archs} " != *" x86_64 "* ]]; then
    echo "macOS Local Web binary is not universal: ${macos_archs}" >&2
    exit 3
  fi
  mkdir -p "${package_root}/native/macos-universal"
  cp "${macos_binary}" "${package_root}/native/macos-universal/simnav-local-web"
  chmod +x "${package_root}/native/macos-universal/simnav-local-web"
  codesign --force --sign - --timestamp=none \
    "${package_root}/native/macos-universal/simnav-local-web"
  macos_native_included=true
fi

windows_native_included=false
if [[ -n "${windows_native}" ]]; then
  windows_native="$(cd -- "${windows_native}" && pwd)"
  if [[ ! -f "${windows_native}/simnav-local-web.exe" ]]; then
    echo "Windows native bundle is missing simnav-local-web.exe: ${windows_native}" >&2
    exit 2
  fi
  mkdir -p "${package_root}/native/windows-x86_64"
  cp -R "${windows_native}/." "${package_root}/native/windows-x86_64/"
  windows_native_included=true
fi

diff -qr "${project_root}/NavPlanner/Resources/Web" \
  "${package_root}/app/NavPlanner/Resources/Web" >/dev/null

version="$(awk -F'= ' '/MARKETING_VERSION = / {gsub(/;/, "", $2); print $2; exit}' \
  "${project_root}/NavPlanner.xcodeproj/project.pbxproj")"
source_head="$(git -C "${project_root}" rev-parse HEAD)"
python3 - "${package_root}/web-manifest.json" "${version}" "${source_head}" \
  "${macos_native_included}" "${windows_native_included}" \
  "${database_sha}" "${database_size}" "${database_airac}" "${database_revision}" <<'PY'
import json
import sys

manifest = {
    "schema_version": 2,
    "platform": "web",
    "version": sys.argv[2],
    "source_head": sys.argv[3],
    "ui_source": "app/NavPlanner/Resources/Web",
    "swift_core_source": "app/NavPlanner/Core",
    "database_included": True,
    "bundled_database": {
        "path": "app/NavPlanner/Resources/Database/navdata.sqlite",
        "sha256": sys.argv[6],
        "size_bytes": int(sys.argv[7]),
        "current_airac": sys.argv[8],
        "revision": sys.argv[9],
        "sqlite_quick_check": "passed",
    },
    "native_bundles": {
        "macos_universal": sys.argv[4] == "true",
        "windows_x86_64": sys.argv[5] == "true",
        "linux": "built reproducibly by Dockerfile",
    },
    "http_transports": {
        "macos": "hummingbird-2.22.0",
        "linux": "hummingbird-2.22.0",
        "windows": "swift-nio-2.101.3",
    },
    "fr24": {
        "backend": "shared-FR24Service",
        "adapter": "managed-Chromium-CDP",
        "official_api_credential_required": False,
        "browser_profile": "isolated-and-persistent",
        "background_requests": True,
        "visible_window_trigger": "explicit-open-verification-only",
        "linux_docker_bridge": "private-compose-gateway",
        "windows_docker_bridge": "ephemeral-authenticated-host-relay",
    },
    "security": {
        "published_host": "127.0.0.1",
        "container_internal_host": "0.0.0.0",
        "persistent_volume": "simnav-studio-web-data",
    },
}
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY

checksum_file="${staging_root}/SHA256SUMS.txt"
(
  cd -- "${package_root}"
  find . -type f ! -name SHA256SUMS.txt -print0 \
    | sort -z \
    | xargs -0 shasum -a 256 > "${checksum_file}"
)
mv -- "${checksum_file}" "${package_root}/SHA256SUMS.txt"

mv -- "${package_root}" "${output_path}"
trap - EXIT HUP INT TERM
rmdir -- "${staging_root}"
echo "SimNav Studio Web release package: ${output_path}"
