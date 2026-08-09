#!/bin/bash

set -euo pipefail

# README 截图固定使用 LGAV → EDDM。每个 workflow 都通过 Debug-only JSON
# 重放真实本地 API 航路规划，再把需要展示的标签页、banner 高度、滚动目标和图层写清楚。
# FR24 场景使用 app.js 的确定性 480 点模拟航迹，避免 README 更新依赖在线会话。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEVELOPER_PATH="${NAVPLANNER_XCODE_DEVELOPER_PATH:-/Applications/Xcode-beta.app/Contents/Developer}"
XCODEBUILD_PATH="$DEVELOPER_PATH/usr/bin/xcodebuild"
IPHONE_UDID="${NAVPLANNER_IPHONE_UDID:-6329EAA7-B985-41A0-A73D-1E14A8A7EC82}"
IPAD_UDID="${NAVPLANNER_IPAD_UDID:-59376FA2-71A2-4608-B1AB-9E89C1D75D5E}"
DERIVED_DATA_DIR="${NAVPLANNER_SCREENSHOT_DERIVED_DATA:-/private/tmp/NavPlanner-ReadmeScreenshots}"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug-iphonesimulator/NavPlanner.app"
BUNDLE_ID="com.midaxia.navplanner"
MEDIA_DIR="$ROOT_DIR/Media/workflows"
RUN_DIR="$ROOT_DIR/codex/ux-tests/2026-08-09-lgav-eddm"
LOG_DIR="$RUN_DIR/screenshot-logs"
RAW_DIR="$RUN_DIR/screenshot-raw"
CONTACT_SHEET_DIR="$RUN_DIR/contact-sheets"
MANIFEST_PATH="${NAVPLANNER_SCREENSHOT_MANIFEST:-$RUN_DIR/screenshot-manifest.tsv}"
CAPTURE_FILTER_VALUE="${NAVPLANNER_CAPTURE_FILTER:-}"
# 用户要求按十进制 150 kB 控制单图体积；不要用 150 KiB 放宽上限。
MAX_WEBP_BYTES=150000
SETTLE_SECONDS="${NAVPLANNER_SCREENSHOT_SETTLE_SECONDS:-6}"
LAUNCHER_PID=""

cleanup_launcher() {
  if [[ -n "$LAUNCHER_PID" ]] && kill -0 "$LAUNCHER_PID" 2>/dev/null; then
    kill "$LAUNCHER_PID" 2>/dev/null || true
    wait "$LAUNCHER_PID" 2>/dev/null || true
  fi
  LAUNCHER_PID=""
}

trap cleanup_launcher EXIT INT TERM

run_simctl() {
  DEVELOPER_DIR="$DEVELOPER_PATH" xcrun simctl "$@"
}

boot_simulator() {
  local udid="$1"
  if ! run_simctl list devices | rg -q "${udid}.*\(Booted\)"; then
    run_simctl boot "$udid"
  fi
  run_simctl bootstatus "$udid" -b >/dev/null
}

workflow_config() {
  local workflow="$1"
  case "$workflow" in
    plan)
      printf '%s' '{"mobileTab":"plan","mobilePanelMapRatio":52}'
      ;;
    procedure)
      # 到达机场加载完成后选择 RW08R，再点击 STAR 标题进入多程序总览；最后重新拟合全部 STAR 几何。
      printf '%s' '{"mobileTab":"airport","detailTab":"airport","mobilePanelMapRatio":58,"airportSlot":"arrival","procedureOverviewType":"star","procedureOverviewSlot":"arrival","procedureOverviewRunway":"RW08R","fitRouteAfterLayout":false,"fitProcedureOverviewAfterLayout":true,"detailScrollTarget":"[data-procedure-overview-slot=\"arrival\"][data-procedure-overview-type=\"star\"]","detailScrollOffset":24,"mapOverlayVisibility":{"baseMap":true,"route":false,"manualRoute":false,"procedures":true,"fr24":false,"terminalWaypoints":false,"otherWaypoints":false}}'
      ;;
    calculate)
      printf '%s' '{"mobileTab":"calculate","detailTab":"calculate","mobilePanelMapRatio":27,"calculateManufacturer":"Airbus","calculateAircraft":"A320-200","zfwKg":62500,"fuelKg":9100,"cruiseAltitudeFt":37000,"cruiseMach":0.78,"descentRateFpm":1700,"profileZoom":1.2,"profilePan":0.55,"detailScrollTarget":".calculate-profile-card","detailScrollOffset":18}'
      ;;
    fr24)
      printf '%s' '{"mobileTab":"query","detailTab":"query","mobilePanelMapRatio":27,"syntheticFR24Track":{"pointCount":480,"fitBounds":false},"detailScrollTarget":"#fr24ProfileCard","detailScrollOffset":18}'
      ;;
    settings)
      printf '%s' '{"mobileTab":"settings","detailTab":"settings","mobilePanelMapRatio":27,"settingsMapSource":"offline","detailScrollTarget":".map-selection-card","detailScrollOffset":18}'
      ;;
    *)
      printf '未知 workflow：%s\n' "$workflow" >&2
      return 1
      ;;
  esac
}

build_debug_config() {
  local name="$1"
  local language="$2"
  local theme="$3"
  local workflow="$4"
  local workflow_json
  workflow_json="$(workflow_config "$workflow")"
  jq -nc \
    --arg name "$name" \
    --arg language "$language" \
    --arg theme "$theme" \
    --argjson workflow "$workflow_json" \
    '{
      name: $name,
      languageMode: $language,
      themeMode: $theme,
      departure: "LGAV",
      arrival: "EDDM",
      buildRoute: true,
      forceAuto: true,
      fitRouteAfterLayout: true,
      fitRoutePadding: 52,
      fitRouteMaxZoom: 6.5,
      reportReady: true,
      hideNavOverlay: true,
      mapOverlayVisibility: {
        baseMap: true,
        route: true,
        manualRoute: true,
        procedures: true,
        fr24: true,
        terminalWaypoints: false,
        otherWaypoints: false
      }
    } + $workflow'
}

compress_webp() {
  local source_png="$1"
  local destination_webp="$2"
  local quality=72
  local temporary_webp="${destination_webp}.tmp.webp"
  local byte_count=0
  mkdir -p "$(dirname "$destination_webp")"
  while (( quality >= 22 )); do
    cwebp -quiet -mt -m 6 -q "$quality" "$source_png" -o "$temporary_webp"
    byte_count="$(stat -f%z "$temporary_webp")"
    if (( byte_count <= MAX_WEBP_BYTES )); then
      mv "$temporary_webp" "$destination_webp"
      printf '%s' "$byte_count"
      return 0
    fi
    quality=$((quality - 5))
  done
  printf 'WebP 超过 150 kB：%s（%s bytes）\n' "$destination_webp" "$byte_count" >&2
  return 1
}

capture_one() {
  local language="$1"
  local theme="$2"
  local workflow_number="$3"
  local workflow="$4"
  local device="$5"
  local udid orientation target_width force_landscape
  if [[ "$device" == "iphone" ]]; then
    udid="$IPHONE_UDID"
    orientation="portrait"
    target_width=720
    force_landscape="0"
  else
    udid="$IPAD_UDID"
    orientation="landscape"
    target_width=1400
    force_landscape="1"
  fi

  local key="${language}-${theme}-${workflow_number}-${workflow}-${device}"
  if [[ -n "$CAPTURE_FILTER_VALUE" && "$key" != *"$CAPTURE_FILTER_VALUE"* ]]; then
    return 0
  fi

  local config log_path raw_png normalized_png output_path byte_count
  config="$(build_debug_config "$key" "$language" "$theme" "$workflow")"
  log_path="$LOG_DIR/${key}.log"
  raw_png="$RAW_DIR/${key}-raw.png"
  normalized_png="$RAW_DIR/${key}.png"
  output_path="$MEDIA_DIR/$language/$theme/${workflow_number}-${workflow}-${device}.webp"

  printf '截图 %-58s' "$key"
  cleanup_launcher
  : >"$log_path"
  SIMCTL_CHILD_NAVPLANNER_SIM_FORCE_LANDSCAPE="$force_landscape" \
  SIMCTL_CHILD_NAVPLANNER_SIM_DEBUG_JSON="$config" \
  DEVELOPER_DIR="$DEVELOPER_PATH" \
    xcrun simctl launch --terminate-running-process --console-pty "$udid" "$BUNDLE_ID" \
      >"$log_path" 2>&1 &
  LAUNCHER_PID="$!"

  local waited=0
  while ! rg -q 'NavPlanner screenshot ready' "$log_path"; do
    if ! kill -0 "$LAUNCHER_PID" 2>/dev/null; then
      printf '\nApp 在就绪前退出：%s\n' "$key" >&2
      sed -n '1,240p' "$log_path" >&2
      return 1
    fi
    if (( waited >= 55 )); then
      printf '\n等待截图就绪超时：%s\n' "$key" >&2
      sed -n '1,240p' "$log_path" >&2
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done

  if ! rg -q "\\\"orientation\\\":\\\"${orientation}\\\"" "$log_path"; then
    printf '\n方向不符合要求：%s 应为 %s。请在 Device Hub 旋转设备后重试。\n' "$key" "$orientation" >&2
    tail -80 "$log_path" >&2
    return 1
  fi
  if [[ "$workflow" == "procedure" ]]; then
    if ! rg -q '\"procedureOverviewViewport\":\{\"active\":true.*\"clippedPoints\":0' "$log_path"; then
      printf '\nSTAR 总览未完整落入地图可见区域：%s。\n' "$key" >&2
      tail -80 "$log_path" >&2
      return 1
    fi
  elif ! rg -q '\"routeViewport\":\{[^}]*\"clippedPoints\":0[^}]*\"clippedLabels\":0' "$log_path"; then
    printf '\n完整航路或可见标签未落入地图可见区域：%s。\n' "$key" >&2
    tail -80 "$log_path" >&2
    return 1
  fi

  # Ready 表示业务状态与布局已经稳定；再给在线增强底图少量时间完成当前视野瓦片。
  sleep "$SETTLE_SECONDS"
  run_simctl io "$udid" screenshot "$raw_png" >/dev/null
  cp "$raw_png" "$normalized_png"
  if [[ "$device" == "ipad" ]]; then
    local pixel_width pixel_height
    pixel_width="$(sips -g pixelWidth "$normalized_png" | awk '/pixelWidth/ { print $2 }')"
    pixel_height="$(sips -g pixelHeight "$normalized_png" | awk '/pixelHeight/ { print $2 }')"
    if (( pixel_width < pixel_height )); then
      sips -r 270 "$normalized_png" >/dev/null
    fi
  fi
  sips --resampleWidth "$target_width" "$normalized_png" >/dev/null
  byte_count="$(compress_webp "$normalized_png" "$output_path")"
  printf '  %6s bytes\n' "$byte_count"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$workflow_number" "$workflow" "$language" "$theme" "$device" \
    "${output_path#$ROOT_DIR/}" "$config" >>"$MANIFEST_PATH"

  cleanup_launcher
  run_simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

compose_hero() {
  local language="$1"
  local source_phone="$MEDIA_DIR/$language/day/02-procedure-iphone.webp"
  local source_ipad="$MEDIA_DIR/$language/day/02-procedure-ipad.webp"
  local hero_png="$RAW_DIR/navplanner-hero-${language}.png"
  local hero_webp="$ROOT_DIR/Media/navplanner-hero-${language}.webp"
  DEVELOPER_DIR="$DEVELOPER_PATH" xcrun swift \
    "$SCRIPT_DIR/compose_readme_hero.swift" \
    "$source_phone" "$source_ipad" "$hero_png"
  local byte_count
  byte_count="$(compress_webp "$hero_png" "$hero_webp")"
  printf 'Hero %-58s  %6s bytes\n' "$language" "$byte_count"
}

compose_contact_sheets() {
  local tool_path="$DERIVED_DATA_DIR/compose_readme_contact_sheet"
  DEVELOPER_DIR="$DEVELOPER_PATH" xcrun swiftc \
    "$SCRIPT_DIR/compose_readme_contact_sheet.swift" \
    -o "$tool_path"
  for language in en zh-Hans; do
    for theme in day night; do
      for device in iphone ipad; do
        "$tool_path" \
          "$CONTACT_SHEET_DIR/${language}-${theme}-${device}.jpg" \
          "$MEDIA_DIR/$language/$theme/01-plan-$device.webp" \
          "$MEDIA_DIR/$language/$theme/02-procedure-$device.webp" \
          "$MEDIA_DIR/$language/$theme/03-calculate-$device.webp" \
          "$MEDIA_DIR/$language/$theme/04-fr24-$device.webp" \
          "$MEDIA_DIR/$language/$theme/05-settings-$device.webp"
      done
    done
  done
}

mkdir -p "$MEDIA_DIR" "$LOG_DIR" "$RAW_DIR" "$CONTACT_SHEET_DIR"
printf 'workflow_number\tworkflow\tlanguage\ttheme\tdevice\tfile\tdebug_json\n' >"$MANIFEST_PATH"

if [[ "${NAVPLANNER_SKIP_SCREENSHOT_BUILD:-0}" != "1" ]]; then
  printf '构建 NavPlanner Debug...\n'
  DEVELOPER_DIR="$DEVELOPER_PATH" "$XCODEBUILD_PATH" \
    -project "$ROOT_DIR/NavPlanner.xcodeproj" \
    -scheme NavPlanner \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,id=$IPHONE_UDID" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    build >"$LOG_DIR/xcodebuild.log"
fi

boot_simulator "$IPHONE_UDID"
boot_simulator "$IPAD_UDID"
run_simctl install "$IPHONE_UDID" "$APP_PATH"
run_simctl install "$IPAD_UDID" "$APP_PATH"

# iPadOS 27 的 simctl 截图会保留面板像素方向，脚本会在保存前转正；
# 但 Simulator 本身必须先由 Device Hub 的 Rotate Left 按钮保持横屏。
for language in en zh-Hans; do
  for theme in day night; do
    capture_one "$language" "$theme" 01 plan iphone
    capture_one "$language" "$theme" 01 plan ipad
    capture_one "$language" "$theme" 02 procedure iphone
    capture_one "$language" "$theme" 02 procedure ipad
    capture_one "$language" "$theme" 03 calculate iphone
    capture_one "$language" "$theme" 03 calculate ipad
    capture_one "$language" "$theme" 04 fr24 iphone
    capture_one "$language" "$theme" 04 fr24 ipad
    capture_one "$language" "$theme" 05 settings iphone
    capture_one "$language" "$theme" 05 settings ipad
  done
done

available_capture_count="$(find "$MEDIA_DIR" -type f -name '*.webp' | wc -l | tr -d ' ')"
if [[ "$available_capture_count" == "40" ]]; then
  compose_contact_sheets
fi

if [[ -z "$CAPTURE_FILTER_VALUE" ]]; then
  if [[ "$available_capture_count" != "40" ]]; then
    printf '截图数量错误：期望 40，实际 %s。\n' "$available_capture_count" >&2
    exit 1
  fi
  compose_hero en
  compose_hero zh-Hans
elif [[ "${NAVPLANNER_REBUILD_HERO:-0}" == "1" ]]; then
  compose_hero en
  compose_hero zh-Hans
fi

printf 'README 截图完成。Manifest：%s\n' "$MANIFEST_PATH"
