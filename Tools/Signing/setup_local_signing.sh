#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_PATH="$PROJECT_ROOT/Config/CodeSigning.local.xcconfig"
TEAM_ID=""
BUNDLE_ID=""
FORCE=0

usage() {
  cat <<'EOF'
usage: Tools/Signing/setup_local_signing.sh [options]

Options:
  --team-id ID       Use this 10-character Apple Development Team ID.
  --bundle-id ID     Override the public Bundle Identifier only on this Mac.
  --force            Replace an existing local signing file.
  -h, --help         Show this help.

Without --team-id, the script reads the Team ID from the certificate subject OU
of the first valid Apple Development identity. The identity is never printed.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --team-id)
      [ "$#" -ge 2 ] || { echo "--team-id requires a value." >&2; exit 2; }
      TEAM_ID="$2"
      shift 2
      ;;
    --bundle-id)
      [ "$#" -ge 2 ] || { echo "--bundle-id requires a value." >&2; exit 2; }
      BUNDLE_ID="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$TEAM_ID" ]; then
  IDENTITY_NAME="$(
    security find-identity -v -p codesigning 2>/dev/null |
      sed -nE 's/^[[:space:]]*[0-9]+\) [0-9A-F]+ "(Apple Development:[^"]+)".*/\1/p' |
      head -1
  )"
  if [ -n "$IDENTITY_NAME" ]; then
    CERTIFICATE_PEM="$(security find-certificate -c "$IDENTITY_NAME" -p 2>/dev/null || true)"
    TEAM_ID="$(
      printf '%s' "$CERTIFICATE_PEM" |
        openssl x509 -noout -subject -nameopt RFC2253 2>/dev/null |
        sed -nE 's/.*(^|,)OU=([A-Z0-9]{10})(,|$).*/\2/p'
    )"
  fi
fi

if ! [[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "No valid Apple Development Team ID was detected." >&2
  echo "Add your Apple Account in Xcode, create an Apple Development certificate," >&2
  echo "then rerun this command or pass --team-id explicitly." >&2
  exit 3
fi

if [ -n "$BUNDLE_ID" ] && ! [[ "$BUNDLE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9.-]+$ ]]; then
  echo "The Bundle Identifier contains unsupported characters." >&2
  exit 2
fi

if [ -e "$OUTPUT_PATH" ] && [ "$FORCE" -ne 1 ]; then
  echo "Local signing configuration already exists; use --force to replace it." >&2
  exit 4
fi

if ! git -C "$PROJECT_ROOT" check-ignore -q "$OUTPUT_PATH"; then
  echo "Refusing to create a signing file that is not ignored by Git." >&2
  exit 5
fi

umask 077
TEMP_PATH="$PROJECT_ROOT/Config/.CodeSigning.local.xcconfig.tmp.$$"
cleanup() {
  if [ -e "$TEMP_PATH" ]; then
    rm -f "$TEMP_PATH"
  fi
}
trap cleanup EXIT

{
  echo "// Local-only Xcode signing settings. Never commit or publish this file."
  echo "// 本文件只供本机 Xcode 签名；不得提交或发布。"
  printf 'DEVELOPMENT_TEAM = %s\n' "$TEAM_ID"
  echo "CODE_SIGN_STYLE = Automatic"
  echo "CODE_SIGN_IDENTITY = Apple Development"
  if [ -n "$BUNDLE_ID" ]; then
    printf 'PRODUCT_BUNDLE_IDENTIFIER = %s\n' "$BUNDLE_ID"
  fi
} >"$TEMP_PATH"

mv "$TEMP_PATH" "$OUTPUT_PATH"
trap - EXIT

echo "Created ignored local signing configuration."
echo "The Team ID and certificate identity were intentionally not printed."
