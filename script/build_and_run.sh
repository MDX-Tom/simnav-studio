#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="NavPlanner"
BUNDLE_ID="com.midaxia.navplanner"
SCHEME="NavPlanner"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/NavPlanner.xcodeproj"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
XCODEBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"

if [[ ! -x "$XCODEBUILD" ]]; then
  echo "Xcode toolchain not found at $DEVELOPER_DIR" >&2
  exit 1
fi

export DEVELOPER_DIR

OLD_PID="$(pgrep -x "$APP_NAME" | tail -n 1 || true)"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

DESTINATION_ID="$($XCODEBUILD \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -showdestinations 2>/dev/null \
  | sed -nE 's/.*platform:macOS.*variant:Designed for.*id:([^,}]+).*/\1/p' \
  | head -n 1)"

if [[ -z "$DESTINATION_ID" ]]; then
  echo "Could not find the My Mac (Designed for iPad) destination." >&2
  exit 1
fi

$XCODEBUILD \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$DESTINATION_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug-iphoneos/$APP_NAME.app"
APP_EXECUTABLE="$APP_BUNDLE/$APP_NAME"

if [[ ! -x "$APP_EXECUTABLE" ]]; then
  echo "Built app executable not found at $APP_EXECUTABLE" >&2
  exit 1
fi

launch_app() {
  /usr/bin/open -b com.apple.dt.Xcode "$PROJECT_PATH"
  sleep 1
  /usr/bin/osascript <<'APPLESCRIPT'
tell application id "com.apple.dt.Xcode" to activate
tell application "System Events"
  tell process "Xcode"
    set frontmost to true
    keystroke "r" using command down
    repeat 50 times
      if exists sheet 1 then
        if exists button "Replace" of sheet 1 then
          click button "Replace" of sheet 1
          exit repeat
        end if
      end if
      delay 0.1
    end repeat
  end tell
end tell
APPLESCRIPT
}

wait_for_pid() {
  local pid=""
  for _ in {1..120}; do
    pid="$(pgrep -x "$APP_NAME" | tail -n 1 || true)"
    if [[ -n "$pid" && "$pid" != "$OLD_PID" ]]; then
      printf '%s\n' "$pid"
      return 0
    fi
    sleep 0.25
  done
  return 1
}

case "$MODE" in
  run)
    launch_app
    APP_PID="$(wait_for_pid)" || {
      echo "$APP_NAME did not start through Xcode." >&2
      exit 1
    }
    echo "$APP_NAME is running under Xcode with pid $APP_PID"
    ;;
  --debug|debug)
    launch_app
    APP_PID="$(wait_for_pid)" || {
      echo "$APP_NAME did not start through Xcode." >&2
      exit 1
    }
    echo "$APP_NAME is running with Xcode's debugger attached (pid $APP_PID)"
    ;;
  --logs|logs)
    launch_app
    wait_for_pid >/dev/null || {
      echo "$APP_NAME did not start through Xcode." >&2
      exit 1
    }
    exec /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    launch_app
    wait_for_pid >/dev/null || {
      echo "$APP_NAME did not start through Xcode." >&2
      exit 1
    }
    exec /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    launch_app
    APP_PID="$(wait_for_pid)" || {
      echo "$APP_NAME did not start through Xcode." >&2
      exit 1
    }
    echo "$APP_NAME is running with pid $APP_PID"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
