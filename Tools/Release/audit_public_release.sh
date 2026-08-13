#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RELEASE_DIR="${1:-}"
EXPECTED_VERSION="$(awk -F'= ' '/MARKETING_VERSION = / {gsub(/;/, "", $2); print $2; exit}' "$PROJECT_ROOT/NavPlanner.xcodeproj/project.pbxproj")"
EXPECTED_BUILD="$(awk -F'= ' '/CURRENT_PROJECT_VERSION = / {gsub(/;/, "", $2); print $2; exit}' "$PROJECT_ROOT/NavPlanner.xcodeproj/project.pbxproj")"
EXPECTED_BUNDLE_ID="$(awk -F' = ' '/^PRODUCT_BUNDLE_IDENTIFIER = / {print $2; exit}' "$PROJECT_ROOT/Config/CodeSigning.xcconfig")"
EXPECTED_PRODUCT_NAME="SimNav Studio"
EXPECTED_DISPLAY_NAME="SimNav"
EXPECTED_SUBTITLE="Planning & Navigation for Flight Simulation"
EXPECTED_INTERNAL_BUNDLE_NAME="NavPlanner"
ARTIFACT_BASENAME="SimNav-Studio"

if [ -z "$EXPECTED_BUNDLE_ID" ]; then
  echo "Public Bundle Identifier is missing from Config/CodeSigning.xcconfig." >&2
  exit 2
fi

if [ -z "$RELEASE_DIR" ] || [ ! -d "$RELEASE_DIR" ]; then
  echo "usage: $0 /path/to/public-release-directory" >&2
  exit 2
fi
RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd)"

case "$RELEASE_DIR" in
  "$PROJECT_ROOT"/releases/*) ;;
  *) echo "Refusing to audit a release path outside project releases/." >&2; exit 2 ;;
esac

SENSITIVE_PUBLIC_SOURCE="$(
  git -C "$PROJECT_ROOT" ls-files --cached --others --exclude-standard |
    grep -Ei '\.(p12|pfx|cer|crt|der|pem|key|p8|mobileprovision|provisionprofile)$|(^|/)ExportOptions\.local\.plist$' || true
)"
if [ -n "$SENSITIVE_PUBLIC_SOURCE" ]; then
  echo "Sensitive signing file type is present in the public source set:" >&2
  echo "$SENSITIVE_PUBLIC_SOURCE" >&2
  exit 3
fi

SENSITIVE_PUBLIC_CONTENT=0
while IFS= read -r -d '' source_path; do
  if [ -f "$PROJECT_ROOT/$source_path" ] && \
     rg -I -q 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|DEVELOPMENT_TEAM = [A-Z0-9]{10};?' "$PROJECT_ROOT/$source_path"; then
    SENSITIVE_PUBLIC_CONTENT=1
    break
  fi
done < <(git -C "$PROJECT_ROOT" ls-files -z --cached --others --exclude-standard)
if [ "$SENSITIVE_PUBLIC_CONTENT" -ne 0 ]; then
  echo "Public source contains a private-key marker or concrete Development Team." >&2
  exit 3
fi

IPA_PATH="$RELEASE_DIR/ios/$ARTIFACT_BASENAME-$EXPECTED_VERSION-unsigned.ipa"
MAC_APP="$RELEASE_DIR/macos/$ARTIFACT_BASENAME-$EXPECTED_VERSION-catalyst-adhoc.app"
DMG_PATH="$RELEASE_DIR/macos/$ARTIFACT_BASENAME-$EXPECTED_VERSION-catalyst-adhoc.dmg"
WEB_DIR="$RELEASE_DIR/web"

if [ ! -f "$IPA_PATH" ] || [ ! -d "$MAC_APP" ] || [ ! -f "$DMG_PATH" ] || [ ! -d "$WEB_DIR" ]; then
  echo "Expected unsigned IPA, ad-hoc app, ad-hoc DMG and Local Web package were not found." >&2
  exit 4
fi
"$PROJECT_ROOT/Tools/LocalWeb/audit_web_release.sh" "$WEB_DIR"

unzip -tq "$IPA_PATH" >/dev/null
if unzip -Z1 "$IPA_PATH" | grep -Eq '(^|/)embedded\.mobileprovision$|(^|/)_CodeSignature(/|$)'; then
  echo "Unsigned IPA contains a provisioning profile or bundle CodeResources signature." >&2
  exit 4
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/navplanner-public-audit.XXXXXX")"
MOUNT_DIR="$TEMP_DIR/dmg-mount"
MOUNT_ATTACHED=0
cleanup() {
  if [ "$MOUNT_ATTACHED" -eq 1 ]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT
unzip -q "$IPA_PATH" -d "$TEMP_DIR"
IOS_APP="$(find "$TEMP_DIR/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"

if [ -z "$IOS_APP" ] || [ ! -f "$IOS_APP/Info.plist" ]; then
  echo "IPA does not contain the expected device application bundle." >&2
  exit 4
fi

assert_plist_value() {
  local plist="$1"
  local key="$2"
  local expected="$3"
  local actual
  actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist")"
  if [ "$actual" != "$expected" ]; then
    echo "Unexpected $key in $(basename "$plist"): $actual" >&2
    exit 4
  fi
}

assert_plist_value "$IOS_APP/Info.plist" CFBundleIdentifier "$EXPECTED_BUNDLE_ID"
assert_plist_value "$IOS_APP/Info.plist" CFBundleShortVersionString "$EXPECTED_VERSION"
assert_plist_value "$IOS_APP/Info.plist" CFBundleVersion "$EXPECTED_BUILD"
assert_plist_value "$IOS_APP/Info.plist" CFBundleName "$EXPECTED_INTERNAL_BUNDLE_NAME"
assert_plist_value "$IOS_APP/Info.plist" CFBundleDisplayName "$EXPECTED_DISPLAY_NAME"
assert_plist_value "$IOS_APP/Info.plist" UIDeviceFamily:0 1
assert_plist_value "$IOS_APP/Info.plist" UIDeviceFamily:1 2

IOS_SIGNING="$(codesign -dvv "$IOS_APP" 2>&1 || true)"
if printf '%s' "$IOS_SIGNING" | grep -Eq '^Authority=|^TeamIdentifier=[A-Z0-9]'; then
  echo "Unsigned IPA contains a certificate authority or TeamIdentifier." >&2
  exit 4
fi
IOS_BINARY="$IOS_APP/$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$IOS_APP/Info.plist"
)"
if [ "$(lipo -archs "$IOS_BINARY")" != "arm64" ]; then
  echo "Unsigned IPA executable is not the expected arm64 device binary." >&2
  exit 4
fi
if ! xcrun vtool -show-build "$IOS_BINARY" | grep -q 'platform IOS'; then
  echo "Unsigned IPA executable is not built for iphoneos." >&2
  exit 4
fi

codesign --verify --deep --strict "$MAC_APP"
MAC_SIGNING="$(codesign -dvv "$MAC_APP" 2>&1)"
if ! printf '%s' "$MAC_SIGNING" | grep -q '^Signature=adhoc$'; then
  echo "Mac app is not ad-hoc signed." >&2
  exit 4
fi
if printf '%s' "$MAC_SIGNING" | grep -Eq '^Authority=|^TeamIdentifier=[A-Z0-9]'; then
  echo "Ad-hoc Mac app contains a certificate authority or TeamIdentifier." >&2
  exit 4
fi
if find "$MAC_APP" -name embedded.mobileprovision -print -quit | grep -q .; then
  echo "Mac app contains an embedded provisioning profile." >&2
  exit 4
fi
MAC_BINARY="$MAC_APP/Contents/MacOS/$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$MAC_APP/Contents/Info.plist"
)"
assert_plist_value "$MAC_APP/Contents/Info.plist" CFBundleIdentifier "$EXPECTED_BUNDLE_ID"
assert_plist_value "$MAC_APP/Contents/Info.plist" CFBundleShortVersionString "$EXPECTED_VERSION"
assert_plist_value "$MAC_APP/Contents/Info.plist" CFBundleVersion "$EXPECTED_BUILD"
assert_plist_value "$MAC_APP/Contents/Info.plist" CFBundleName "$EXPECTED_INTERNAL_BUNDLE_NAME"
assert_plist_value "$MAC_APP/Contents/Info.plist" CFBundleDisplayName "$EXPECTED_DISPLAY_NAME"
MAC_ARCHS="$(lipo -archs "$MAC_BINARY")"
if ! printf ' %s ' "$MAC_ARCHS" | grep -q ' arm64 ' || ! printf ' %s ' "$MAC_ARCHS" | grep -q ' x86_64 '; then
  echo "Mac app is not a universal arm64 + x86_64 Catalyst build." >&2
  exit 4
fi
if ! xcrun vtool -show-build "$MAC_BINARY" | grep -q 'platform MACCATALYST'; then
  echo "Mac app executable is not built for Mac Catalyst." >&2
  exit 4
fi

IOS_DATABASE="$IOS_APP/Database/navdata.sqlite"
MAC_DATABASE="$MAC_APP/Contents/Resources/Database/navdata.sqlite"
if [ ! -f "$IOS_DATABASE" ] || [ ! -f "$MAC_DATABASE" ]; then
  echo "IPA or Mac app is missing Database/navdata.sqlite." >&2
  exit 4
fi
IOS_DATABASE_SHA="$(shasum -a 256 "$IOS_DATABASE" | awk '{print $1}')"
MAC_DATABASE_SHA="$(shasum -a 256 "$MAC_DATABASE" | awk '{print $1}')"
IOS_DATABASE_SIZE="$(stat -f '%z' "$IOS_DATABASE")"
IOS_DATABASE_AIRAC="$(sqlite3 -readonly "$IOS_DATABASE" 'select current_airac from tbl_header limit 1;')"
if [ "$IOS_DATABASE_SHA" != "$MAC_DATABASE_SHA" ]; then
  echo "IPA and Mac app contain different default navigation databases." >&2
  exit 4
fi
if [ "$(sqlite3 -readonly "$IOS_DATABASE" 'PRAGMA quick_check;')" != "ok" ]; then
  echo "Bundled default navigation database failed SQLite PRAGMA quick_check." >&2
  exit 4
fi

if rg -a -q '/Users/[^/]+/|/home/[^/]+/' "$IOS_APP" "$MAC_APP"; then
  echo "Public application bundle contains a developer home-directory path." >&2
  exit 4
fi

verify_dmg() {
  for _ in 1 2 3 4 5; do
    if hdiutil verify "$DMG_PATH" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  hdiutil verify "$DMG_PATH" >/dev/null
}

verify_dmg

mkdir "$MOUNT_DIR"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$DMG_PATH" >/dev/null
MOUNT_ATTACHED=1
MOUNT_APP="$MOUNT_DIR/$(basename "$MAC_APP")"
if [ ! -d "$MOUNT_APP" ]; then
  echo "Mounted DMG does not contain the expected Catalyst app." >&2
  exit 5
fi
DMG_APP_COUNT="$(find "$MOUNT_DIR" -mindepth 1 -maxdepth 1 -type d -name '*.app' | wc -l | tr -d ' ')"
if [ "$DMG_APP_COUNT" != "1" ]; then
  echo "Mounted DMG contains an unexpected number of application bundles." >&2
  exit 5
fi
if ! diff -qr "$MAC_APP" "$MOUNT_APP" >/dev/null; then
  echo "Mounted DMG app differs from the audited source app." >&2
  exit 5
fi
if find "$MOUNT_DIR" -type f | grep -Ei '\.(p12|pfx|cer|crt|der|pem|key|p8|mobileprovision|provisionprofile|log)$' >/dev/null; then
  echo "Mounted DMG contains a credential, provisioning profile or raw log." >&2
  exit 5
fi
hdiutil detach "$MOUNT_DIR" >/dev/null
MOUNT_ATTACHED=0

UNWANTED_PUBLIC_CONTENT="$(
  find "$RELEASE_DIR" \
    \( \
      \( -type f \( \
        -iname '*.p12' -o -iname '*.pfx' -o -iname '*.cer' -o -iname '*.crt' -o \
        -iname '*.der' -o -iname '*.pem' -o -iname '*.key' -o -iname '*.p8' -o \
        -iname '*.mobileprovision' -o -iname '*.provisionprofile' -o -iname '*.log' \
        -o -iname '.DS_Store' \
      \) \) -o \
      \( -type d \( -iname '*.xcarchive' -o -iname 'DerivedData*' -o -iname 'logs' \) \) \
    \) \
    -print
)"
if [ -n "$UNWANTED_PUBLIC_CONTENT" ]; then
  echo "Public release directory contains a credential, archive or raw log file." >&2
  exit 5
fi

if find "$IOS_APP" "$MAC_APP" -type f | grep -Ei '(^|/)(Cookies?|[^/]*session[^/]*|[^/]*\.gpx|Screenshots?)(/|$)' >/dev/null; then
  echo "Public application bundle contains session, track or screenshot evidence." >&2
  exit 5
fi
if find "$IOS_APP" "$MAC_APP" -type f | grep -Ei '\.(p12|pfx|cer|crt|der|pem|key|p8|mobileprovision|provisionprofile)$' >/dev/null; then
  echo "Public application bundle contains a credential or provisioning file." >&2
  exit 5
fi
if rg -q 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' "$IOS_APP" "$MAC_APP"; then
  echo "Public application bundle contains a private-key marker." >&2
  exit 5
fi
if rg -i -q \
  '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}' \
  "$IOS_APP" "$MAC_APP" \
  --glob '*.html' --glob '*.js' --glob '*.css' --glob '*.json' \
  --glob '*.md' --glob '*.txt' --glob '*.xml'; then
  echo "Public application text resources contain an account email address." >&2
  exit 5
fi

if rg -n -i 'Authority=Apple Development|TeamIdentifier=[A-Z0-9]|ProvisionedDevice|ProfileName=|/Users/[^/]+/|/home/[^/]+/|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}' "$RELEASE_DIR" --glob '*.json' --glob '*.md' --glob '*.txt' >/dev/null; then
  echo "Public release metadata contains signing identity or account information." >&2
  exit 5
fi

IPA_SHA="$(shasum -a 256 "$IPA_PATH" | awk '{print $1}')"
DMG_SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
APP_TREE_SHA="$(
  cd "$MAC_APP"
  find . -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}'
)"
IPA_SIZE="$(stat -f '%z' "$IPA_PATH")"
DMG_SIZE="$(stat -f '%z' "$DMG_PATH")"
APP_SIZE="$(find "$MAC_APP" -type f -print0 | xargs -0 stat -f '%z' | awk '{sum += $1} END {print sum + 0}')"
WEB_TREE_SHA="$(
  cd "$WEB_DIR"
  find . -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}'
)"
WEB_SIZE="$(find "$WEB_DIR" -type f -print0 | xargs -0 stat -f '%z' | awk '{sum += $1} END {print sum + 0}')"
CURRENT_HEAD="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
CURRENT_BRANCH="$(git -C "$PROJECT_ROOT" branch --show-current)"

python3 - \
  "$RELEASE_DIR/metadata/build-manifest.json" \
  "$EXPECTED_VERSION" "$EXPECTED_BUILD" "$EXPECTED_BUNDLE_ID" \
  "$EXPECTED_PRODUCT_NAME" "$EXPECTED_DISPLAY_NAME" "$EXPECTED_SUBTITLE" "$ARTIFACT_BASENAME" \
  "$CURRENT_BRANCH" "$CURRENT_HEAD" \
  "$IPA_SHA" "$IPA_SIZE" "$APP_TREE_SHA" "$APP_SIZE" "$DMG_SHA" "$DMG_SIZE" \
  "$WEB_TREE_SHA" "$WEB_SIZE" \
  "$IOS_DATABASE_SHA" "$IOS_DATABASE_SIZE" "$IOS_DATABASE_AIRAC" <<'PY'
import json
import sys

(
    manifest_path,
    expected_version,
    expected_build,
    expected_bundle_id,
    expected_product_name,
    expected_display_name,
    expected_subtitle,
    artifact_basename,
    current_branch,
    current_head,
    ipa_sha,
    ipa_size,
    app_sha,
    app_size,
    dmg_sha,
    dmg_size,
    web_sha,
    web_size,
    database_sha,
    database_size,
    database_airac,
) = sys.argv[1:]

with open(manifest_path, "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

if manifest.get("schema_version") != 5:
    raise SystemExit("Public manifest schema is not version 5.")

release = manifest.get("release", {})
expected_release = {
    "name": expected_product_name,
    "display_name": expected_display_name,
    "subtitle": expected_subtitle,
    "marketing_version": expected_version,
    "build_number": expected_build,
    "bundle_identifier": expected_bundle_id,
}
for key, expected in expected_release.items():
    if release.get(key) != expected:
        raise SystemExit(f"Manifest release.{key} does not match the built product.")

source = manifest.get("source", {})
if source.get("branch") != current_branch or source.get("head") != current_head:
    raise SystemExit("Manifest source branch/HEAD does not match the current checkout; rebuild the candidate.")

artifacts = {item.get("path"): item for item in manifest.get("artifacts", [])}
expected_artifacts = {
    "ios/" + artifact_basename + "-" + expected_version + "-unsigned.ipa": (ipa_sha, int(ipa_size)),
    "macos/" + artifact_basename + "-" + expected_version + "-catalyst-adhoc.app": (app_sha, int(app_size)),
    "macos/" + artifact_basename + "-" + expected_version + "-catalyst-adhoc.dmg": (dmg_sha, int(dmg_size)),
    "web/": (web_sha, int(web_size)),
}
for path, (expected_sha, expected_size) in expected_artifacts.items():
    artifact = artifacts.get(path)
    if artifact is None:
        raise SystemExit(f"Manifest is missing artifact metadata for {path}.")
    if artifact.get("sha256") != expected_sha or artifact.get("size_bytes") != expected_size:
        raise SystemExit(f"Manifest hash/size does not match {path}.")

if artifacts["web/"].get("http_transports") != {
    "macos": "hummingbird-2.22.0",
    "linux": "hummingbird-2.22.0",
    "windows": "swift-nio-2.101.3",
}:
    raise SystemExit("Public manifest Web HTTP transport pins do not match the release package.")

database = manifest.get("bundled_database", {})
expected_database = {
    "source": "database/e_dfd_PMDG_release.s3db",
    "bundle_path": "Database/navdata.sqlite",
    "role": "example navigation database bundled with release artifacts",
    "current_airac": database_airac,
    "size_bytes": int(database_size),
    "sha256": database_sha,
    "sqlite_quick_check": "passed",
}
for key, expected in expected_database.items():
    if database.get(key) != expected:
        raise SystemExit(f"Manifest bundled_database.{key} does not match the packaged database.")
identity_audit = manifest.get("identity_and_secret_audit", {})
if not identity_audit or any(value is not False for value in identity_audit.values()):
    raise SystemExit("Manifest identity/secret audit is missing or does not report a clean result.")
PY

(
  cd "$RELEASE_DIR"
  shasum -a 256 -c SHA256SUMS.txt
)

echo "PUBLIC_RELEASE_AUDIT=PASS"
echo "IPA_SIGNING=unsigned/no authority/no provisioning"
echo "MAC_SIGNING=adhoc/no authority/no TeamIdentifier"
echo "DMG_VERIFY_AND_APP_PARITY=passed"
echo "MANIFEST_ARTIFACT_PARITY=passed"
echo "BUNDLED_EXAMPLE_DATABASE_PARITY=passed"
echo "LOCAL_WEB_PACKAGE_PARITY_AND_SECURITY=passed"
echo "TRACKED_AND_UNTRACKED_PUBLIC_SIGNING_MATERIAL=none"
