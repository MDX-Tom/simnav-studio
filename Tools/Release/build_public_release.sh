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
if [ -z "$DATABASE_AIRAC" ]; then
  echo "Release database tbl_header.current_airac is empty." >&2
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
  "$DATABASE_AIRAC" "$DATABASE_SIZE" "$DATABASE_SHA" <<PY
import json
import sys

database_airac = sys.argv[3]
database_size = int(sys.argv[4])
database_sha = sys.argv[5]

manifest = {
    "schema_version": 4,
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
        "working_tree_dirty": $SOURCE_DIRTY,
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
        "standalone_launch_and_runtime_workflow": "manual validation required; recorded outside this reproducible packaging script",
    },
    "publishable_github_assets": [
        "ios/$IPA_FILENAME",
        "macos/$DMG_FILENAME",
        "SHA256SUMS.txt",
        "PUBLIC_RELEASE_NOTES.md",
    ],
    "publication_preconditions": [
        "Source changes must correspond to a reviewed commit or tag; this candidate was built from a dirty working tree.",
        "Written redistribution permission required by the bundled Navigraph/Jeppesen example database notice must be confirmed separately.",
        "Publishing or creating a GitHub Release requires explicit user authorization.",
    ],
}

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, ensure_ascii=False, indent=2)
    handle.write("\n")

notes = """# $PRODUCT_NAME $VERSION public-safe release candidate

> $PRODUCT_SUBTITLE

- The iOS/iPadOS IPA is **unsigned**. It contains no developer certificate,
  TeamIdentifier or provisioning profile. A sideloading tool must re-sign it
  with the installer's own account.
- The Mac Catalyst app is **ad-hoc signed** only. The DMG is not notarized and
  contains no Developer ID certificate.
- No xcarchive, raw build log, account email, certificate, private key,
  provisioning profile or App Store Connect key belongs in a GitHub Release.
- The IPA and DMG include the example database prepared locally as
  database/e_dfd_PMDG_release.s3db and bundled as Database/navdata.sqlite.
  The public source repository itself does not contain a navigation database.

## 中文说明

- iOS/iPadOS IPA **未签名**，不含维护者证书、TeamIdentifier 或
  provisioning profile；安装者必须使用自己的账号和可信侧载工具重签。
- Mac Catalyst App 只有 **ad-hoc** 签名，DMG 未 notarize，也不含
  Developer ID 证书。
- GitHub Release 不得包含 xcarchive、原始日志、账号邮箱、证书、私钥、
  provisioning profile 或 App Store Connect 密钥。
- IPA 与 DMG 包含本机 database/e_dfd_PMDG_release.s3db 准备的示例数据库，
  在 App 内封装为 Database/navdata.sqlite；公开源码仓库本身不含导航数据库。
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
  } >SHA256SUMS.txt
)

"$SCRIPT_DIR/audit_public_release.sh" "$OUTPUT_DIR"

mv "$OUTPUT_DIR" "$FINAL_OUTPUT_DIR"

echo "Public-safe release candidate created:"
echo "$FINAL_OUTPUT_DIR"
echo "Temporary build logs and intermediates were removed."
