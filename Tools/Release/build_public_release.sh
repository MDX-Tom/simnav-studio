#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/NavPlanner.xcodeproj"
PUBLIC_SIGNING_CONFIG="$PROJECT_ROOT/Config/CodeSigning.xcconfig"
RELEASE_DATABASE_SOURCE="$PROJECT_ROOT/database/e_dfd_PMDG_release.s3db"
BUNDLED_DATABASE_DIR="$PROJECT_ROOT/NavPlanner/Resources/Database"
BUNDLED_DATABASE_TARGET="$BUNDLED_DATABASE_DIR/navdata.sqlite"
SCHEME="NavPlanner"
CONFIGURATION="Release"
PRODUCT_NAME="SimNav Studio"
APP_DISPLAY_NAME="SimNav"
PRODUCT_SUBTITLE="Planning & Navigation for Flight Simulation"
ARTIFACT_BASENAME="SimNav-Studio"

VERSION="$(awk -F'= ' '/MARKETING_VERSION = / {gsub(/;/, "", $2); print $2; exit}' "$PROJECT_ROOT/NavPlanner.xcodeproj/project.pbxproj")"
BUILD_NUMBER="$(awk -F'= ' '/CURRENT_PROJECT_VERSION = / {gsub(/;/, "", $2); print $2; exit}' "$PROJECT_ROOT/NavPlanner.xcodeproj/project.pbxproj")"
BUNDLE_IDENTIFIER="$(awk -F' = ' '/^PRODUCT_BUNDLE_IDENTIFIER = / {print $2; exit}' "$PUBLIC_SIGNING_CONFIG")"
IPA_FILENAME="$ARTIFACT_BASENAME-$VERSION-unsigned.ipa"
MAC_APP_FILENAME="$ARTIFACT_BASENAME-$VERSION-catalyst-adhoc.app"
DMG_FILENAME="$ARTIFACT_BASENAME-$VERSION-catalyst-adhoc.dmg"

if [ -z "$BUNDLE_IDENTIFIER" ]; then
  echo "Public Bundle Identifier is missing from Config/CodeSigning.xcconfig." >&2
  exit 2
fi

if [ ! -f "$RELEASE_DATABASE_SOURCE" ]; then
  echo "Release database is missing: $RELEASE_DATABASE_SOURCE" >&2
  echo "Place the latest e_dfd_PMDG_release.s3db in the Git-ignored database/ directory." >&2
  exit 2
fi

DATABASE_QUICK_CHECK="$(sqlite3 -readonly "$RELEASE_DATABASE_SOURCE" 'PRAGMA quick_check;')"
if [ "$DATABASE_QUICK_CHECK" != "ok" ]; then
  echo "Release database failed SQLite PRAGMA quick_check: $DATABASE_QUICK_CHECK" >&2
  exit 2
fi

REQUIRED_DATABASE_TABLES=(
  tbl_header
  tbl_airports
  tbl_runways
  tbl_airport_communication
  tbl_enroute_waypoints
  tbl_terminal_waypoints
  tbl_vhfnavaids
  tbl_enroute_ndbnavaids
  tbl_terminal_ndbnavaids
  tbl_enroute_airways
  tbl_sids
  tbl_stars
  tbl_iaps
  tbl_localizers_glideslopes
)
for table_name in "${REQUIRED_DATABASE_TABLES[@]}"; do
  if [ "$(sqlite3 -readonly "$RELEASE_DATABASE_SOURCE" "select count(*) from sqlite_master where type = 'table' and name = '$table_name';")" != "1" ]; then
    echo "Release database is missing required table: $table_name" >&2
    exit 2
  fi
done

DATABASE_SHA="$(shasum -a 256 "$RELEASE_DATABASE_SOURCE" | awk '{print $1}')"
DATABASE_SIZE="$(stat -f '%z' "$RELEASE_DATABASE_SOURCE")"
DATABASE_AIRAC="$(sqlite3 -readonly "$RELEASE_DATABASE_SOURCE" 'select current_airac from tbl_header limit 1;')"
DATABASE_REVISION="$(sqlite3 -readonly "$RELEASE_DATABASE_SOURCE" 'select revision from tbl_header limit 1;')"
if [ -z "$DATABASE_AIRAC" ]; then
  echo "Release database tbl_header.current_airac is empty." >&2
  exit 2
fi
if [ -z "$DATABASE_REVISION" ]; then
  echo "Release database tbl_header.revision is empty." >&2
  exit 2
fi

if [ -e "$BUNDLED_DATABASE_TARGET" ] && [ ! -f "$BUNDLED_DATABASE_TARGET" ]; then
  echo "Bundled database target is not a regular file: $BUNDLED_DATABASE_TARGET" >&2
  exit 2
fi
if [ -d "$BUNDLED_DATABASE_DIR" ]; then
  UNEXPECTED_BUNDLED_DATABASE_RESOURCE="$(
    find "$BUNDLED_DATABASE_DIR" -mindepth 1 -maxdepth 1 ! -name 'navdata.sqlite' -print -quit
  )"
  if [ -n "$UNEXPECTED_BUNDLED_DATABASE_RESOURCE" ]; then
    echo "Unexpected resource beside navdata.sqlite: $UNEXPECTED_BUNDLED_DATABASE_RESOURCE" >&2
    echo "Release builds may bundle only the prepared example navigation database." >&2
    exit 2
  fi
fi

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [/path/to/project/releases/release-$VERSION]" >&2
  exit 2
fi

RELEASES_ROOT="$PROJECT_ROOT/releases"
FINAL_OUTPUT_DIR="${1:-$RELEASES_ROOT/release-$VERSION}"

case "$FINAL_OUTPUT_DIR" in
  "$RELEASES_ROOT"/release-*) ;;
  *) echo "Refusing output path outside project releases/: $FINAL_OUTPUT_DIR" >&2; exit 2 ;;
esac
if [ "$(dirname "$FINAL_OUTPUT_DIR")" != "$RELEASES_ROOT" ]; then
  echo "Release output must be an immediate child of project releases/." >&2
  exit 2
fi
if [ "$(basename "$FINAL_OUTPUT_DIR")" != "release-$VERSION" ]; then
  echo "Release output must be named release-$VERSION." >&2
  exit 2
fi

mkdir -p "$RELEASES_ROOT"
if [ -e "$FINAL_OUTPUT_DIR" ]; then
  echo "Release output already exists; move it aside explicitly before rebuilding." >&2
  echo "OUTPUT_DIR=$FINAL_OUTPUT_DIR" >&2
  exit 2
fi
EXTRA_RELEASE_ENTRY="$(
  find "$RELEASES_ROOT" -mindepth 1 -maxdepth 1 \
    ! -name "$(basename "$FINAL_OUTPUT_DIR")" -print -quit
)"
if [ -n "$EXTRA_RELEASE_ENTRY" ]; then
  echo "releases/ may retain only the current release directory: $EXTRA_RELEASE_ENTRY" >&2
  exit 2
fi

WORK_DIR="$(mktemp -d "$RELEASES_ROOT/.navplanner-build-$VERSION.XXXXXX")"
OUTPUT_DIR="$WORK_DIR/release-$VERSION"
BUNDLED_DATABASE_BACKUP="$WORK_DIR/navdata.sqlite.before-release"
BUNDLED_DATABASE_WAS_PRESENT=0
BUNDLED_DATABASE_RESTORE_REQUIRED=0
cleanup() {
  local result=$?
  if [ "$BUNDLED_DATABASE_RESTORE_REQUIRED" -eq 1 ]; then
    if [ "$BUNDLED_DATABASE_WAS_PRESENT" -eq 1 ]; then
      /usr/bin/ditto "$BUNDLED_DATABASE_BACKUP" "$BUNDLED_DATABASE_TARGET" || result=3
    else
      rm -f -- "$BUNDLED_DATABASE_TARGET" || result=3
    fi
  fi
  rm -rf -- "$WORK_DIR"
  trap - EXIT
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

if [ -f "$BUNDLED_DATABASE_TARGET" ]; then
  /usr/bin/ditto "$BUNDLED_DATABASE_TARGET" "$BUNDLED_DATABASE_BACKUP"
  BUNDLED_DATABASE_WAS_PRESENT=1
fi
mkdir -p "$BUNDLED_DATABASE_DIR"
/usr/bin/ditto "$RELEASE_DATABASE_SOURCE" "$WORK_DIR/navdata.sqlite.release"
BUNDLED_DATABASE_RESTORE_REQUIRED=1
mv -f "$WORK_DIR/navdata.sqlite.release" "$BUNDLED_DATABASE_TARGET"

TASK_DEVELOPER_DIR="${DEVELOPER_DIR:-}"
if [ -z "$TASK_DEVELOPER_DIR" ]; then
  if [ -d /Applications/Xcode-beta.app/Contents/Developer ]; then
    TASK_DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
  elif [ -d /Applications/Xcode.app/Contents/Developer ]; then
    TASK_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  else
    echo "A complete Xcode installation is required." >&2
    exit 2
  fi
fi
export DEVELOPER_DIR="$TASK_DEVELOPER_DIR"

mkdir -p "$OUTPUT_DIR/ios" "$OUTPUT_DIR/macos" "$OUTPUT_DIR/metadata"
mkdir -p "$WORK_DIR/logs" "$WORK_DIR/ios-stage/Payload" "$WORK_DIR/dmg-stage"

IOS_DERIVED="$WORK_DIR/DerivedData-iOS"
MAC_DERIVED="$WORK_DIR/DerivedData-Catalyst"

xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination 'generic/platform=iOS' -derivedDataPath "$IOS_DERIVED" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= clean build >"$WORK_DIR/logs/ios-unsigned-release-build.txt" 2>&1
IOS_WARNING_COUNT="$(awk 'BEGIN { IGNORECASE=1 } /warning:/ { count++ } END { print count + 0 }' "$WORK_DIR/logs/ios-unsigned-release-build.txt")"
IOS_ERROR_COUNT="$(awk 'BEGIN { IGNORECASE=1 } /error:/ { count++ } END { print count + 0 }' "$WORK_DIR/logs/ios-unsigned-release-build.txt")"

IOS_APP="$IOS_DERIVED/Build/Products/Release-iphoneos/NavPlanner.app"
if [ ! -d "$IOS_APP" ]; then
  echo "Unsigned iOS app not found: $IOS_APP" >&2
  exit 3
fi
if [ -e "$IOS_APP/embedded.mobileprovision" ] || [ -e "$IOS_APP/_CodeSignature" ]; then
  echo "Unsigned iOS build unexpectedly contains provisioning/signature material." >&2
  exit 3
fi
IOS_EXECUTABLE="$IOS_APP/$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$IOS_APP/Info.plist"
)"
xcrun strip -S -x "$IOS_EXECUTABLE"

/usr/bin/ditto "$IOS_APP" "$WORK_DIR/ios-stage/Payload/$APP_DISPLAY_NAME.app"
xattr -cr "$WORK_DIR/ios-stage/Payload/$APP_DISPLAY_NAME.app"
(
  cd "$WORK_DIR/ios-stage"
  COPYFILE_DISABLE=1 /usr/bin/zip -qry -X "$OUTPUT_DIR/ios/$IPA_FILENAME" Payload
)

xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination 'generic/platform=macOS,variant=Mac Catalyst' -derivedDataPath "$MAC_DERIVED" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= clean build >"$WORK_DIR/logs/macos-unsigned-release-build.txt" 2>&1
MAC_WARNING_COUNT="$(awk 'BEGIN { IGNORECASE=1 } /warning:/ { count++ } END { print count + 0 }' "$WORK_DIR/logs/macos-unsigned-release-build.txt")"
MAC_ERROR_COUNT="$(awk 'BEGIN { IGNORECASE=1 } /error:/ { count++ } END { print count + 0 }' "$WORK_DIR/logs/macos-unsigned-release-build.txt")"

MAC_BUILD_APP="$MAC_DERIVED/Build/Products/Release-maccatalyst/NavPlanner.app"
MAC_PUBLIC_APP="$OUTPUT_DIR/macos/$MAC_APP_FILENAME"
if [ ! -d "$MAC_BUILD_APP" ]; then
  echo "Unsigned Catalyst app not found: $MAC_BUILD_APP" >&2
  exit 3
fi
MAC_BUILD_EXECUTABLE="$MAC_BUILD_APP/Contents/MacOS/$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$MAC_BUILD_APP/Contents/Info.plist"
)"
xcrun strip -S -x "$MAC_BUILD_EXECUTABLE"

/usr/bin/ditto "$MAC_BUILD_APP" "$MAC_PUBLIC_APP"
xattr -cr "$MAC_PUBLIC_APP"
codesign --force --deep --sign - --timestamp=none "$MAC_PUBLIC_APP"
codesign --verify --deep --strict "$MAC_PUBLIC_APP"

assert_resource_parity() {
  local source_path="$1"
  local ios_path="$2"
  local mac_path="$3"

  if [ -e "$source_path" ]; then
    if [ ! -e "$ios_path" ] || [ ! -e "$mac_path" ]; then
      echo "Expected bundled resource is missing: $source_path" >&2
      exit 3
    fi
    diff -qr "$source_path" "$ios_path" >/dev/null
    diff -qr "$source_path" "$mac_path" >/dev/null
  elif [ -e "$ios_path" ] || [ -e "$mac_path" ]; then
    echo "Built bundle contains a resource absent from the source tree: $source_path" >&2
    exit 3
  fi
}

assert_resource_parity \
  "$PROJECT_ROOT/NavPlanner/Resources/Web" \
  "$IOS_APP/Web" \
  "$MAC_PUBLIC_APP/Contents/Resources/Web"
assert_resource_parity \
  "$PROJECT_ROOT/NavPlanner/Resources/Database" \
  "$IOS_APP/Database" \
  "$MAC_PUBLIC_APP/Contents/Resources/Database"
assert_resource_parity \
  "$PROJECT_ROOT/NavPlanner/Support/PrivacyInfo.xcprivacy" \
  "$IOS_APP/PrivacyInfo.xcprivacy" \
  "$MAC_PUBLIC_APP/Contents/Resources/PrivacyInfo.xcprivacy"

for bundled_database in \
  "$IOS_APP/Database/navdata.sqlite" \
  "$MAC_PUBLIC_APP/Contents/Resources/Database/navdata.sqlite"; do
  if [ ! -f "$bundled_database" ]; then
    echo "Release build is missing the default navigation database: $bundled_database" >&2
    exit 3
  fi
  if [ "$(shasum -a 256 "$bundled_database" | awk '{print $1}')" != "$DATABASE_SHA" ]; then
    echo "Bundled navigation database does not match database/e_dfd_PMDG_release.s3db." >&2
    exit 3
  fi
done

/usr/bin/ditto "$MAC_PUBLIC_APP" "$WORK_DIR/dmg-stage/$(basename "$MAC_PUBLIC_APP")"
ln -s /Applications "$WORK_DIR/dmg-stage/Applications"

DMG_PATH="$OUTPUT_DIR/macos/$DMG_FILENAME"
diskutil image create from \
  --format UDZO \
  --volumeName "$PRODUCT_NAME $VERSION" \
  "$WORK_DIR/dmg-stage" \
  "$DMG_PATH" >"$WORK_DIR/logs/dmg-create.txt" 2>&1

WEB_PACKAGE_ARGS=(
  --output "$OUTPUT_DIR/web"
  --build-macos-native
)
if [ -n "${SIMNAV_WINDOWS_NATIVE_BUNDLE:-}" ]; then
  WEB_PACKAGE_ARGS+=(--windows-native "$SIMNAV_WINDOWS_NATIVE_BUNDLE")
fi
"$PROJECT_ROOT/Tools/LocalWeb/package_web_release.sh" "${WEB_PACKAGE_ARGS[@]}"
"$PROJECT_ROOT/Tools/LocalWeb/audit_web_release.sh" "$OUTPUT_DIR/web" --docker-smoke

IPA_PATH="$OUTPUT_DIR/ios/$IPA_FILENAME"
APP_TREE_SHA="$(
  cd "$MAC_PUBLIC_APP"
  find . -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}'
)"
IPA_SHA="$(shasum -a 256 "$IPA_PATH" | awk '{print $1}')"
DMG_SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
IPA_SIZE="$(stat -f '%z' "$IPA_PATH")"
APP_SIZE="$(find "$MAC_PUBLIC_APP" -type f -print0 | xargs -0 stat -f '%z' | awk '{sum += $1} END {print sum + 0}')"
DMG_SIZE="$(stat -f '%z' "$DMG_PATH")"
WEB_TREE_SHA="$(
  cd "$OUTPUT_DIR/web"
  find . -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}'
)"
WEB_SIZE="$(find "$OUTPUT_DIR/web" -type f -print0 | xargs -0 stat -f '%z' | awk '{sum += $1} END {print sum + 0}')"
WEB_WINDOWS_NATIVE="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1]))["native_bundles"]["windows_x86_64"]))' "$OUTPUT_DIR/web/web-manifest.json")"
SOURCE_HEAD="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
SOURCE_BRANCH="$(git -C "$PROJECT_ROOT" branch --show-current)"
SOURCE_DIRTY=False
if [ -n "$(git -C "$PROJECT_ROOT" status --short)" ]; then
  SOURCE_DIRTY=True
fi
XCODE_VERSION="$(xcodebuild -version | awk 'NR == 1 {print $2}')"
XCODE_BUILD="$(xcodebuild -version | awk 'NR == 2 {print $3}')"
IOS_SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
IOS_SDK_BUILD="$(xcrun --sdk iphoneos --show-sdk-build-version)"
MACOS_SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
MACOS_SDK_BUILD="$(xcrun --sdk macosx --show-sdk-build-version)"
SWIFT_VERSION="$(xcrun swiftc --version 2>&1 | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
HOST_MACOS_VERSION="$(sw_vers -productVersion)"
GENERATED_AT="$(date '+%Y-%m-%dT%H:%M:%S%z')"

python3 - \
  "$OUTPUT_DIR/metadata/build-manifest.json" \
  "$OUTPUT_DIR/PUBLIC_RELEASE_NOTES.md" \
  "$DATABASE_AIRAC" "$DATABASE_REVISION" "$DATABASE_SIZE" "$DATABASE_SHA" <<PY
import json
import sys

database_airac = sys.argv[3]
database_revision = sys.argv[4]
database_size = int(sys.argv[5])
database_sha = sys.argv[6]
source_dirty = $SOURCE_DIRTY

manifest = {
    "schema_version": 5,
    "release": {
        "name": "$PRODUCT_NAME",
        "display_name": "$APP_DISPLAY_NAME",
        "subtitle": "$PRODUCT_SUBTITLE",
        "marketing_version": "$VERSION",
        "build_number": "$BUILD_NUMBER",
        "bundle_identifier": "$BUNDLE_IDENTIFIER",
        "generated_at": "$GENERATED_AT",
        "classification": "public-safe local release candidate",
    },
    "source": {
        "branch": "$SOURCE_BRANCH",
        "head": "$SOURCE_HEAD",
        "working_tree_dirty": source_dirty,
    },
    "toolchain": {
        "xcode_version": "$XCODE_VERSION",
        "xcode_build": "$XCODE_BUILD",
        "iphoneos_sdk_version": "$IOS_SDK_VERSION",
        "iphoneos_sdk_build": "$IOS_SDK_BUILD",
        "macosx_sdk_version": "$MACOS_SDK_VERSION",
        "macosx_sdk_build": "$MACOS_SDK_BUILD",
        "swift": "$SWIFT_VERSION",
        "host_macos_version": "$HOST_MACOS_VERSION",
    },
    "build": {
        "scheme": "$SCHEME",
        "configuration": "$CONFIGURATION",
        "ios_destination": "generic/platform=iOS",
        "mac_destination": "generic/platform=macOS,variant=Mac Catalyst",
        "code_signing_allowed_during_build": False,
        "ios_warning_count": int("$IOS_WARNING_COUNT"),
        "ios_error_count": int("$IOS_ERROR_COUNT"),
        "mac_warning_count": int("$MAC_WARNING_COUNT"),
        "mac_error_count": int("$MAC_ERROR_COUNT"),
    },
    "bundled_database": {
        "source": "database/e_dfd_PMDG_release.s3db",
        "bundle_path": "Database/navdata.sqlite",
        "role": "example navigation database bundled with release artifacts",
        "current_airac": database_airac,
        "revision": database_revision,
        "size_bytes": database_size,
        "sha256": database_sha,
        "sqlite_quick_check": "passed",
    },
    "artifacts": [
        {
            "path": "ios/$IPA_FILENAME",
            "type": "unsigned iOS/iPadOS sideload IPA",
            "platform": "iphoneos",
            "architectures": ["arm64"],
            "targeted_device_family": [1, 2],
            "size_bytes": int("$IPA_SIZE"),
            "sha256": "$IPA_SHA",
            "signing_identity_type": "none",
            "signing": "unsigned; no developer certificate and no provisioning profile",
            "export_method": "manual unsigned Payload packaging from a Release iphoneos device build; not xcodebuild -exportArchive",
            "installation": "Must be re-signed by AltStore, SideStore, Sideloadly or another trusted signing workflow using the installer's own account.",
        },
        {
            "path": "macos/$MAC_APP_FILENAME",
            "type": "Mac Catalyst application",
            "platform": "Mac Catalyst",
            "architectures": ["arm64", "x86_64"],
            "size_bytes": int("$APP_SIZE"),
            "sha256": "$APP_TREE_SHA",
            "sha256_scope": "sha256-of-sorted-relative-file-sha256-list",
            "signing_identity_type": "ad-hoc",
            "signing": "ad-hoc; no certificate authority and no TeamIdentifier",
            "export_method": "unsigned Release Catalyst build copied to the public release candidate and ad-hoc signed with codesign --sign -",
            "installation": "Local testing only; not Developer ID signed and not notarized.",
        },
        {
            "path": "macos/$DMG_FILENAME",
            "type": "Mac disk image",
            "platform": "macOS",
            "architectures": ["arm64", "x86_64"],
            "size_bytes": int("$DMG_SIZE"),
            "sha256": "$DMG_SHA",
            "signing_identity_type": "none; contained app is ad-hoc",
            "signing": "contains only the ad-hoc Catalyst app",
            "export_method": "diskutil image create from --format UDZO",
            "installation": "Gatekeeper public-distribution trust is not provided; Developer ID signing and notarization would require a separate private CI workflow.",
        },
        {
            "path": "web/",
            "type": "Local Web deployment package",
            "platform": "Web",
            "host_operating_systems": ["macOS", "Windows", "Linux"],
            "architectures": ["arm64", "x86_64"],
            "size_bytes": int("$WEB_SIZE"),
            "sha256": "$WEB_TREE_SHA",
            "sha256_scope": "sha256-of-sorted-relative-file-sha256-list",
            "ui_source": "NavPlanner/Resources/Web",
            "swift_core_source": "NavPlanner/Core",
            "database_included": False,
            "macos_native_server": True,
            "windows_native_server": "$WEB_WINDOWS_NATIVE" == "True",
            "linux_server": "native Swift executable built inside the pinned Docker image",
            "http_transports": {
                "macos": "hummingbird-2.22.0",
                "linux": "hummingbird-2.22.0",
                "windows": "swift-nio-2.101.3",
            },
            "installation": "Use the one-click launcher for the host OS; all published ports bind to 127.0.0.1.",
        },
    ],
    "identity_and_secret_audit": {
        "developer_certificate_embedded": False,
        "provisioning_profile_embedded": False,
        "team_identifier_embedded": False,
        "account_email_embedded": False,
        "private_key_or_api_key_embedded": False,
        "developer_home_path_embedded": False,
        "raw_build_logs_in_release": False,
        "xcarchive_in_release": False,
    },
    "validation": {
        "ipa_unzip_and_unsigned_structure": "passed",
        "built_info_version_build_bundle_id_device_family_and_branding": "passed",
        "binary_platform_and_architecture": "passed",
        "mac_codesign_deep_strict": "passed",
        "bundle_web_database_privacyinfo_parity": "passed",
        "release_database_source_hash_and_bundle_hash": "passed",
        "dmg_verify_mount_and_same_app_parity": "passed by the mandatory post-package audit",
        "sha256sums": "passed by the mandatory post-package audit",
        "web_single_source_transport_and_container_smoke": "passed",
        "standalone_launch_and_runtime_workflow": "manual validation required; recorded outside this reproducible packaging script",
    },
    "publishable_github_assets": [
        "ios/$IPA_FILENAME",
        "macos/$DMG_FILENAME",
        "web/",
        "SHA256SUMS.txt",
        "PUBLIC_RELEASE_NOTES.md",
    ],
    "publication_preconditions": [
        (
            "Source changes must correspond to a reviewed commit or tag; this candidate was built from a dirty working tree."
            if source_dirty
            else "Source changes correspond to the clean commit recorded in source.head."
        ),
        "Written redistribution permission required by the bundled Navigraph/Jeppesen example database notice must be confirmed separately.",
        "Publishing or creating a GitHub Release requires explicit user authorization.",
    ],
}

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, ensure_ascii=False, indent=2)
    handle.write("\n")

notes = """## 🚀 $PRODUCT_NAME v$VERSION

### 中文

✨ v$VERSION 是 SimNav Studio 的首个公开版本。它将航路规划、机场与程序查看、飞行剖面计算、FR24 轨迹复盘、离线地图和本地导航数据库整合进一个本地优先的模拟飞行工作台，覆盖从航线构思到地图复盘的完整流程。

主要能力：

  * 🌐 **Local Web 第三正式平台**：macOS、Windows、Linux 使用同一套网页资源、Swift 业务核心和 runtime router；平台脚本只在本机回环地址启动服务，Web 包不携带数据库或用户数据。
  * 🧭 **本地航路规划**：支持手动航路、整条航路自动规划，以及使用 \x60***\x60 自动规划航点之间的单段航路。
  * 🛬 **机场与程序查看**：查看跑道、通信频率、 \x60SID\x60、 \x60STAR\x60、 \x60APPROACH\x60，并绘制 RF / AF 弧线、复飞段和等待航线几何。
  * 🗺️ **多图层地图工作区**：统一查看底图、航路、程序、FR24 轨迹、航点、导航台、跑道、ILS 和 airway 标签，支持绘制撤销与重做。
  * 📐 **飞行剖面与燃油计算**：配置机型、重量、燃油、巡航、下降、天气和 QNH，查看风、地形、地速 / 垂直速度剖面及 SimBrief 风格燃油估算。
  * 📡 **FR24 轨迹对照**：同步 App 内浏览器会话后查询航班或 flightId，下载和导入 GPX，缓存轨迹，并将实际轨迹拟合回本地航路。
  * 💾 **离线地图与导航数据库**：管理 PMTiles、MBTiles、SQLite 瓦片资源，导入 PMDG 风格 SQLite 导航数据库，并在核心功能上保持离线可用。
  * 🎨 **可选 App 图标样式**：提供多组日间 / 夜间图标样式，并在 iPhone、iPad 与 Mac Catalyst 间保持选择状态。

🪪 产品正式名称为 **SimNav Studio**，桌面图标短名称为 **SimNav**；内部 Xcode 工程和 \x60NavPlanner\x60 scheme 继续保留原名称，以兼容现有源码与工具链。

🛠️ 本版本同时完成了本地优先 Swift 服务层、WKWebView 地图工作区、程序优先的轨迹拟合、按住手势下的地图覆盖层对齐，以及 public-safe 发布封包流程。公开源码与个人签名配置分离，发布候选包含独立审计、SHA-256 校验和与双语说明。

📊 v$VERSION 发布候选的自动门禁结果：

| 门禁 | 结果 |
| --- | --- |
| Release 数据库 | \x60PRAGMA quick_check\x60 通过 · AIRAC \x60$DATABASE_AIRAC\x60 · revision \x60$DATABASE_REVISION\x60 |
| iOS / iPadOS IPA | arm64 · 未签名 · 无证书、TeamIdentifier 或 provisioning profile |
| Mac Catalyst App | arm64 + x86_64 universal · ad-hoc 签名 · 无 Developer ID / notarization |
| Local Web | macOS / Windows / Linux · 单一 UI 与 Swift 核心 · localhost 容器 smoke 通过 |
| Web / Database / PrivacyInfo bundle parity | 通过 |
| DMG、IPA 结构与 SHA-256 审计 | 通过 |

📌 上述自动门禁只证明源码、封包结构和资源一致性；实际启动、设备安装、FR24 会话、地图交互与完整工作流仍应按发布前检查清单进行人工验证。

📦 公开工件：

  * \x60SimNav-Studio-$VERSION-unsigned.ipa\x60：iPhone / iPad 侧载包。必须由 AltStore、SideStore、Sideloadly 或其他可信工具使用安装者自己的 Apple Account 重新签名。
  * \x60SimNav-Studio-$VERSION-catalyst-adhoc.dmg\x60：Mac Catalyst 通用包，仅 ad-hoc 签名，未 notarize；不提供 Developer ID / Gatekeeper 公开分发信任。
  * \x60web/\x60：Local Web 正式平台包。macOS/Linux 使用 Hummingbird 与同一 Swift 核心；Windows 包含经宿主 smoke 的原生 SwiftNIO \x60.exe\x60 时直接运行且不启动 Linux/WSL/Docker，未包含时使用 Docker Desktop fallback。三者都只发布到 \x60127.0.0.1\x60。
  * \x60SHA256SUMS.txt\x60：公开工件与元数据校验和。

⚠️ 公开源码仓库不包含导航数据库。发布候选会把本机 \x60database/e_dfd_PMDG_release.s3db\x60 作为 \x60Database/navdata.sqlite\x60 放入 IPA 与 DMG；本次输入库 AIRAC 为 \x60$DATABASE_AIRAC\x60，SHA-256 为 \x60$DATABASE_SHA\x60。当前示例数据库的随附 notice 将其用途限制为地面娱乐飞行模拟软件，并要求取得 Navigraph 的书面许可后才能再分发；未取得许可前，不得发布包含该库的 IPA 或 DMG。详细安装与发布边界见 [README](https://github.com/MDX-Tom/simnav-studio/blob/main/README.md#install-the-ipa-and-dmg-from-releases) 和 [public release packaging](https://github.com/MDX-Tom/simnav-studio/blob/main/Tools/Release/README.md)。

* * *
### English

✨ v$VERSION is the first public release of SimNav Studio. It brings route planning, airport and procedure inspection, flight-profile calculation, FR24 track replay, offline maps, and local navigation databases into one local-first flight-simulation workspace, covering the workflow from route idea to map review.

Key capabilities:

  * 🌐 **Local Web as the third formal platform**: macOS, Windows, and Linux use the same Web resources, Swift business core, and runtime router; platform launchers bind only to loopback, and the Web package contains no database or user data.
  * 🧭 **Local route planning**: support manual routes, full-route auto-planning, and \x60***\x60 segment auto-planning between fixes.
  * 🛬 **Airport and procedure inspection**: inspect runways, frequencies, \x60SID\x60, \x60STAR\x60, and \x60APPROACH\x60 paths, including RF / AF arcs, missed approaches, and holding geometry.
  * 🗺️ **Layered map workspace**: view basemaps, routes, procedures, FR24 tracks, waypoints, navaids, runways, ILS, and airway labels with undo / redo for drawn tracks.
  * 📐 **Flight profiles and fuel**: configure aircraft, weight, fuel, cruise, descent, weather, and QNH, then review wind, terrain, ground-speed / vertical-speed profiles, and a SimBrief-style fuel estimate.
  * 📡 **FR24 track comparison**: sync the in-app browser session, query flights or a flightId, download or import GPX, cache tracks, and match actual tracks back to local route data.
  * 💾 **Offline maps and navigation databases**: manage PMTiles, MBTiles, and SQLite tile resources, import PMDG-style SQLite navigation databases, and keep core workflows available offline.
  * 🎨 **Selectable app-icon styles**: provide multiple day / night icon styles and preserve the selected style across iPhone, iPad, and Mac Catalyst.

🪪 The product is branded **SimNav Studio** and uses **SimNav** as its short display name. The internal Xcode project and \x60NavPlanner\x60 scheme retain their original names for source and tooling compatibility.

🛠️ This release also completes the local-first Swift service layer, WKWebView map workspace, procedure-first track matching, held-gesture map-overlay alignment, and public-safe packaging workflow. Public source and personal signing configuration are separated, while release candidates include an independent audit, SHA-256 checksums, and bilingual notes.

📊 Automated gates for the v$VERSION release candidate:

| Gate | Result |
| --- | --- |
| Release database | \x60PRAGMA quick_check\x60 passed · AIRAC \x60$DATABASE_AIRAC\x60 · revision \x60$DATABASE_REVISION\x60 |
| iOS / iPadOS IPA | arm64 · unsigned · no certificate, TeamIdentifier, or provisioning profile |
| Mac Catalyst app | universal arm64 + x86_64 · ad-hoc signed · no Developer ID / notarization |
| Local Web | macOS / Windows / Linux · single UI and Swift core · localhost container smoke passed |
| Web / database / PrivacyInfo bundle parity | passed |
| DMG, IPA structure, and SHA-256 audit | passed |

📌 These automated gates cover source, package structure, and resource parity. Manual validation is still required for launch, device installation, FR24 sessions, map interaction, and the complete end-to-end workflow.

📦 Public artifacts:

  * \x60SimNav-Studio-$VERSION-unsigned.ipa\x60: iPhone / iPad sideload package. It must be re-signed with the installer's own Apple Account through AltStore, SideStore, Sideloadly, or another trusted tool.
  * \x60SimNav-Studio-$VERSION-catalyst-adhoc.dmg\x60: universal Mac Catalyst package, ad-hoc signed and not notarized; it does not provide Developer ID / Gatekeeper public-distribution trust.
  * \x60web/\x60: the formal Local Web platform package. macOS/Linux use Hummingbird with the shared Swift core; Windows runs the host-smoked native SwiftNIO \x60.exe\x60 directly without Linux/WSL/Docker when that bundle is included, and otherwise uses the Docker Desktop fallback. Every launcher publishes only to \x60127.0.0.1\x60.
  * \x60SHA256SUMS.txt\x60: checksums for public artifacts and metadata.

⚠️ The public source repository does not contain a navigation database. The release candidate bundles the local \x60database/e_dfd_PMDG_release.s3db\x60 as \x60Database/navdata.sqlite\x60 in both the IPA and DMG; this input database is AIRAC \x60$DATABASE_AIRAC\x60 with SHA-256 \x60$DATABASE_SHA\x60. The accompanying notice limits the current example database to ground-based recreational flight-simulation software and requires written permission from Navigraph for redistribution; do not publish an IPA or DMG containing it without that permission. See the [README](https://github.com/MDX-Tom/simnav-studio/blob/main/README.md#install-the-ipa-and-dmg-from-releases) and [public release packaging guide](https://github.com/MDX-Tom/simnav-studio/blob/main/Tools/Release/README.md) for installation and publication boundaries.
"""
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    handle.write(notes)
PY

(
  cd "$OUTPUT_DIR"
  MANIFEST_SHA="$(shasum -a 256 metadata/build-manifest.json | awk '{print $1}')"
  NOTES_SHA="$(shasum -a 256 PUBLIC_RELEASE_NOTES.md | awk '{print $1}')"
  {
    printf '%s  %s\n' "$IPA_SHA" "ios/$IPA_FILENAME"
    printf '%s  %s\n' "$DMG_SHA" "macos/$DMG_FILENAME"
    printf '%s  %s\n' "$MANIFEST_SHA" "metadata/build-manifest.json"
    printf '%s  %s\n' "$NOTES_SHA" "PUBLIC_RELEASE_NOTES.md"
    find web -type f -print0 | sort -z | xargs -0 shasum -a 256
  } >SHA256SUMS.txt
)

"$SCRIPT_DIR/audit_public_release.sh" "$OUTPUT_DIR"

mv "$OUTPUT_DIR" "$FINAL_OUTPUT_DIR"

echo "Public-safe release candidate created:"
echo "$FINAL_OUTPUT_DIR"
echo "Temporary build logs and intermediates were removed."
