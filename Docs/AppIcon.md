# App Icon

App 图标模块负责生成主图标和 iOS 替代图标，并在 Settings 中提供可见选择入口。

## 当前实现

- 主图标源图：`Tools/Icon/navplanner-terrain-liquid-glass-source.png`，来自用户提供的立体地形图标方案。
- 图标风格：iOS Liquid Glass 圆角玻璃外壳、立体地形底图、从上方山谷到右下角跑道的 S 形下降航路、直接绘制在地形图上的示意跑道。图标内不显示 WPT / RW / AP / 机场名 / 跑道名等文字，避免让用户识别出真实程序或真实机场。
- 图标套装：
  - `AppIcon`：默认主图标，也是日间均衡版本；位于高饱和和柔和之间，保留航路和跑道可读性。
  - `AppIconDayHigh`：日间高饱和备用版本；直接使用源图，不增加饱和度。
  - `AppIconDaySoft`：日间柔和版本，使用上一轮“默认”档位的饱和度、对比度和亮度。
  - `AppIconNightHigh`：夜间高对比版本，使用深蓝黑地形、紫色地形层次和暗橙航路，并保留更强的夜间玻璃边框。
  - `AppIconNightMedium`：夜间均衡版本，位于夜间高对比和柔和之间。
  - `AppIconNightSoft`：夜间柔和版本，使用上一轮夜间均衡档位的饱和度、对比度和亮度。
- 生成脚本：`Tools/Icon/generate_app_icons.swift` 使用 AppKit 逐像素处理源图，派生全部 iPhone / iPad / marketing 尺寸 PNG，并写入 `Contents.json`。脚本不再绘制整图颜色叠加层；日间版本按像素调整饱和度、对比度和亮度；夜间版本先逐像素映射为类似反色的蓝黑地形、紫色层次和暗橙航路，再按档位调整饱和度 / 对比度。
- Liquid Glass 后处理：日间图标保留圆角玻璃外壳、加宽外缘边框、内圈描边、顶部高光、侧向反光和弧形 glint。夜间图标降低全图玻璃罩强度，把玻璃反光主要落在航路和山体局部线条上；外缘边框已随日间 / 夜间六套图标一起加宽，夜间边框仍更强，避免暗色图标贴在主屏背景上失去轮廓。
- Asset catalog：图标写入 `NavPlanner/Support/Assets.xcassets/AppIcon*.appiconset`。
- Settings 预览：脚本同时生成 `NavPlanner/Resources/Web/app-icons/day-high.png`、`day-medium.png`、`day-soft.png`、`night-high.png`、`night-medium.png`、`night-soft.png`，供 Web 设置页展示；预览图内容变化时同步刷新 `map.html` 中的查询串，避免 WKWebView 沿用旧缓存。
- Xcode 工程已配置：
  - `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`
  - `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "AppIconDayHigh AppIconDaySoft AppIconNightHigh AppIconNightMedium AppIconNightSoft"`
  - `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES`

## 切换流程

1. 用户在 Settings 的“应用图标”卡片中选择日间高饱和、默认、日间柔和、夜间高对比、夜间均衡或夜间柔和。
2. Web 侧通过 `window.webkit.messageHandlers.navplanner.postMessage(...)` 发送 `setAppIcon`。
3. Swift `AppEnvironment.setAppIconChoice(_:)` 将选择映射为 `AppIconDayHigh`、`nil`、`AppIconDaySoft`、`AppIconNightHigh`、`AppIconNightMedium` 或 `AppIconNightSoft`。
4. iOS 调用 `UIApplication.shared.setAlternateIconName(...)`。系统会显示确认弹窗，这是 iOS 替代图标 API 的系统行为。
5. Swift 回调 `window.navplannerNativeAppIconChanged(payload)`，Web 侧刷新当前选中状态和提示文案。

## 维护规则

- 修改图标时优先更新 `Tools/Icon/navplanner-terrain-liquid-glass-source.png` 和 `Tools/Icon/generate_app_icons.swift`，再重新运行脚本，避免手动遗漏某个尺寸。
- 图标必须保持简洁，不使用第三方品牌元素，不使用真实机场、跑道、程序或航点名称。
- 如果新增更多图标套装，需要同步更新 asset catalog、Xcode `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`、Settings 选择项、Swift `AppEnvironment.setAppIconChoice(_:)`、Web `APP_ICON_CHOICES` 和本文件。若只是调整色彩，优先改 `IconVariant` 中的饱和度、对比度、亮度、`toneAdjustedImage(...)` 和夜间逐像素映射，不再使用整图叠色层。

## 验证

- `swift Tools/Icon/generate_app_icons.swift`
- `node -e ...` 解析 6 个 `NavPlanner/Support/Assets.xcassets/AppIcon*.appiconset/Contents.json`
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy`
- XcodeBuildMCP `build_run_sim` 在 iPhone 模拟器成功。
- Settings 中选择备用图标后，iOS 系统确认弹窗可正常出现并回写当前选择。
