#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/NavPlanner.xcodeproj"
PUBLIC_SIGNING_CONFIG="$PROJECT_ROOT/Config/CodeSigning.xcconfig"
SCHEME="NavPlanner"
CONFIGURATION="Release"

VERSION="$(awk -F'= ' '/MARKETING_VERSION = / {gsub(/;/, "", $2); print $2; exit}' "$PROJECT_ROOT/NavPlanner.xcodeproj/project.pbxproj")"
BUILD_NUMBER="$(awk -F'= ' '/CURRENT_PROJECT_VERSION = / {gsub(/;/, "", $2); print $2; exit}' "$PROJECT_ROOT/NavPlanner.xcodeproj/project.pbxproj")"
BUNDLE_IDENTIFIER="$(awk -F' = ' '/^PRODUCT_BUNDLE_IDENTIFIER = / {print $2; exit}' "$PUBLIC_SIGNING_CONFIG")"

if [ -z "$BUNDLE_IDENTIFIER" ]; then
  echo "Public Bundle Identifier is missing from Config/CodeSigning.xcconfig." >&2
  exit 2
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
cleanup() {
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

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

/usr/bin/ditto "$IOS_APP" "$WORK_DIR/ios-stage/Payload/NavPlanner.app"
xattr -cr "$WORK_DIR/ios-stage/Payload/NavPlanner.app"
(
  cd "$WORK_DIR/ios-stage"
  COPYFILE_DISABLE=1 /usr/bin/zip -qry -X "$OUTPUT_DIR/ios/NavPlanner-$VERSION-unsigned.ipa" Payload
)

xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination 'generic/platform=macOS,variant=Mac Catalyst' -derivedDataPath "$MAC_DERIVED" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= clean build >"$WORK_DIR/logs/macos-unsigned-release-build.txt" 2>&1
MAC_WARNING_COUNT="$(awk 'BEGIN { IGNORECASE=1 } /warning:/ { count++ } END { print count + 0 }' "$WORK_DIR/logs/macos-unsigned-release-build.txt")"
MAC_ERROR_COUNT="$(awk 'BEGIN { IGNORECASE=1 } /error:/ { count++ } END { print count + 0 }' "$WORK_DIR/logs/macos-unsigned-release-build.txt")"

MAC_BUILD_APP="$MAC_DERIVED/Build/Products/Release-maccatalyst/NavPlanner.app"
MAC_PUBLIC_APP="$OUTPUT_DIR/macos/NavPlanner-$VERSION-catalyst-adhoc.app"
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

/usr/bin/ditto "$MAC_PUBLIC_APP" "$WORK_DIR/dmg-stage/$(basename "$MAC_PUBLIC_APP")"
ln -s /Applications "$WORK_DIR/dmg-stage/Applications"

DMG_PATH="$OUTPUT_DIR/macos/NavPlanner-$VERSION-catalyst-adhoc-not-notarized.dmg"
hdiutil create -volname "NavPlanner $VERSION" -srcfolder "$WORK_DIR/dmg-stage" -ov -format UDZO "$DMG_PATH" >"$WORK_DIR/logs/dmg-create.txt" 2>&1

IPA_PATH="$OUTPUT_DIR/ios/NavPlanner-$VERSION-unsigned.ipa"
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

python3 - "$OUTPUT_DIR/metadata/build-manifest.json" "$OUTPUT_DIR/PUBLIC_RELEASE_NOTES.md" <<PY
import json
import sys

manifest = {
    "schema_version": 3,
    "release": {
        "name": "NavPlanner",
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
    "artifacts": [
        {
            "path": "ios/NavPlanner-$VERSION-unsigned.ipa",
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
            "path": "macos/NavPlanner-$VERSION-catalyst-adhoc.app",
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
            "path": "macos/NavPlanner-$VERSION-catalyst-adhoc-not-notarized.dmg",
            "type": "Mac disk image",
            "platform": "macOS",
            "architectures": ["arm64", "x86_64"],
            "size_bytes": int("$DMG_SIZE"),
            "sha256": "$DMG_SHA",
            "signing_identity_type": "none; contained app is ad-hoc",
            "signing": "contains only the ad-hoc Catalyst app",
            "export_method": "hdiutil UDZO disk image",
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
        "built_info_version_build_bundle_id_and_device_family": "passed",
        "binary_platform_and_architecture": "passed",
        "mac_codesign_deep_strict": "passed",
        "bundle_web_database_privacyinfo_parity": "passed",
        "dmg_verify_mount_and_same_app_parity": "passed by the mandatory post-package audit",
        "sha256sums": "passed by the mandatory post-package audit",
        "standalone_launch_and_runtime_workflow": "manual validation required; recorded outside this reproducible packaging script",
    },
    "publishable_github_assets": [
        "ios/NavPlanner-$VERSION-unsigned.ipa",
        "macos/NavPlanner-$VERSION-catalyst-adhoc-not-notarized.dmg",
        "SHA256SUMS.txt",
        "PUBLIC_RELEASE_NOTES.md",
    ],
    "publication_preconditions": [
        "Source changes must correspond to a reviewed commit or tag; this candidate was built from a dirty working tree.",
        "Redistribution rights for the bundled navigation database must be confirmed separately.",
        "Publishing or creating a GitHub Release requires explicit user authorization.",
    ],
}

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, ensure_ascii=False, indent=2)
    handle.write("\n")

notes = """# NavPlanner $VERSION public-safe release candidate

- The iOS/iPadOS IPA is **unsigned**. It contains no developer certificate,
  TeamIdentifier or provisioning profile. A sideloading tool must re-sign it
  with the installer's own account.
- The Mac Catalyst app is **ad-hoc signed** only. The DMG is not notarized and
  contains no Developer ID certificate.
- No xcarchive, raw build log, account email, certificate, private key,
  provisioning profile or App Store Connect key belongs in a GitHub Release.
- This directory is a local candidate only. Do not publish it until the source
  changes correspond to a reviewed commit/tag and redistribution rights for
  the bundled navigation database have been confirmed.

## 中文说明

- iOS/iPadOS IPA **未签名**，不含维护者证书、TeamIdentifier 或
  provisioning profile；安装者必须使用自己的账号和可信侧载工具重签。
- Mac Catalyst App 只有 **ad-hoc** 签名，DMG 未 notarize，也不含
  Developer ID 证书。
- GitHub Release 不得包含 xcarchive、原始日志、账号邮箱、证书、私钥、
  provisioning profile 或 App Store Connect 密钥。
- 这只是本地候选。源码对应 reviewed commit/tag 且确认内置导航数据库的
  再分发权利之前，不得公开发布。
"""
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    handle.write(notes)
PY

(
  cd "$OUTPUT_DIR"
  MANIFEST_SHA="$(shasum -a 256 metadata/build-manifest.json | awk '{print $1}')"
  NOTES_SHA="$(shasum -a 256 PUBLIC_RELEASE_NOTES.md | awk '{print $1}')"
  {
    printf '%s  %s\n' "$IPA_SHA" "ios/NavPlanner-$VERSION-unsigned.ipa"
    printf '%s  %s\n' "$DMG_SHA" "macos/NavPlanner-$VERSION-catalyst-adhoc-not-notarized.dmg"
    printf '%s  %s\n' "$MANIFEST_SHA" "metadata/build-manifest.json"
    printf '%s  %s\n' "$NOTES_SHA" "PUBLIC_RELEASE_NOTES.md"
  } >SHA256SUMS.txt
)

"$SCRIPT_DIR/audit_public_release.sh" "$OUTPUT_DIR"

mv "$OUTPUT_DIR" "$FINAL_OUTPUT_DIR"

echo "Public-safe release candidate created:"
echo "$FINAL_OUTPUT_DIR"
echo "Temporary build logs and intermediates were removed."
