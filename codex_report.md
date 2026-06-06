# Codex 执行报告

## 2026-06-06 FR24 历史页与 iPhone 上拉工作区

已完成：

- 将 FR24 航班历史从“继续扫描同航线 schedule 窗口”改为按航班号读取 `www.flightradar24.com/data/flights/{flight}` 数据页；例如 `TV9943` 会访问 `/data/flights/tv9943`。
- 扩展隐藏 WKWebView FR24 会话读取层：JSON API 仍顶层导航到 FR24 API 并读取 JSON 文本，历史页则顶层导航到 FR24 数据页，抽取可见 DOM 行和 `Play` / `flightId` 链接。
- `/api/fr24/history` 现在返回页面上可见的全部历史 / 计划记录，不再默认限制 10 条；没有 `flightId` 的计划记录仍显示，下载时沿用“FR24 flightId missing”错误提示。
- Query 航班卡片增加历史页解析到的状态字段，保留航班号、起降机场、航司、机型、计划 / 实际时间和飞行时长显示。
- iPhone 竖屏下部工作区新增上拉手柄：默认保持约 66% 地图 / 34% 工作区，最大上拉时地图保留 30%；切换 `计划 / 机场 / 查询 / 设置` 不重置位置，软键盘出现时隐藏手柄并继续走原有 `visualViewport` 自动上拉布局。
- `map.html` 资源版本刷新为 `20260606-fr24-history-sheet`。

初步验证：

- `swift -frontend -parse NavPlanner/Core/WebBridge/NavPlannerSchemeHandler.swift NavPlanner/Core/PlannerCore/PlannerService.swift` 成功。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功；RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- `git diff --check` 成功；`git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error；启动截图确认地图、Plan 表单、底部四标签和新的上拉手柄可见，截图为 `/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_cc80a54a-677d-4ed2-8547-6cd43904d5c1.jpg`。
- 扫描本轮 XcodeBuildMCP runtime / oslog，未发现 `TypeError`、`ReferenceError`、`SyntaxError`、`Exception` 或 FR24 WebBridge 错误。

待手动复验：

- macOS 当前未授予 `osascript` 辅助功能权限，无法自动坐标点击 WKWebView 内输入框；模拟器已启动到新包，需手动在 Query 页用 `ZULS` / `ZUAL` 查询并打开 `TV9943` 航班历史，确认 FR24 会话有效时可从 `/data/flights/tv9943` 展示全部可见记录。

## 2026-05-30 第一阶段工程骨架

已完成：

- 阅读根目录 `readme-app.md`。
- 阅读 `NavPlanner-web/README.md`。
- 检查 `NavPlanner-web/src/` 与 `NavPlanner-web/static/`。
- 提取 Web 参考项目 API：`header`、`search`、`airport`、`procedure`、`nav-overlay`、`route/resolve`、`offline-maps`。
- 创建 `NavPlanner.xcodeproj`。
- 创建 SwiftUI Universal App target：`NavPlanner`。
- 创建 iPad / iPhone 自适应 App Shell。
- 复制参考导航数据库为新 App 资源：`NavPlanner/Resources/Database/navdata.sqlite`。
- 实现 SQLite 本地数据层。
- 实现 PlannerService 第一阶段本地 API。
- 实现 WKURLSchemeHandler 与 WKScriptMessageHandler。
- 创建本地 WKWebView 地图内核资源。
- 创建离线地图资源扫描模型。
- 创建根 README、TODO 和子功能文档。

验证记录：

- `xcodebuild -list -project NavPlanner.xcodeproj` 成功识别 `NavPlanner` target 和 scheme。
- 首次 `xcodebuild ... build` 已通过 Swift 编译和链接，最后在模拟器本地签名阶段因 `PrivacyInfo.xcprivacy` 子组件签名检查失败。
- 已改用 `CODE_SIGNING_ALLOWED=NO` 作为当前沙箱内 CI 式构建校验方式。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build` 已成功。
- 早期构建产物曾包含 `Resources/Web/map.html`、`map.css`、`map.js` 和 `Resources/Database/navdata.sqlite`，后续已改为 App Bundle 顶层 `Web/` 和 `Database/`。
- 普通 shell 环境的 CoreSimulatorService 不可用；XcodeBuildMCP 可正常访问模拟器。
- 2026-05-30 继续推进可运行 App：移除 `PrivacyInfo.xcprivacy` 的资源阶段引用后，普通签名 `xcodebuild ... build` 已成功。
- XcodeBuildMCP 构建后安装阶段曾报 bundle id 读取失败，已将 bundle identifier 从 `com.midaxia.NavPlanner` 调整为小写 `com.midaxia.navplanner` 后继续验证。
- 查明安装失败根因：iOS app bundle 顶层包含名为 `Resources` 的目录会导致安装器误报 Missing bundle ID。已改为把 `Web/` 和 `Database/` 目录分别复制到 bundle 顶层，并同步 Swift 资源查找路径。
- `build_run_sim` 已在 iPhone 17 Pro 模拟器成功：bundle id `com.midaxia.navplanner`，进程 pid `36822`。
- iPhone 运行时截图已确认地图内核显示航路叠加层，底部入口可用。
- iPhone 运行时已验证搜索 `ZBAA` 返回 `ZBAA、机场、CAPITAL`。
- iPhone 运行时已验证机场详情面板可读取 `ZBAA`，显示坐标、6 条跑道、40 条通信频率、SID 85 / STAR 48 / APPROACH 69。
- `build_run_sim` 已在 iPad Pro 13-inch (M5) 模拟器成功：bundle id `com.midaxia.navplanner`，进程 pid `38741`。
- iPad 运行时截图已确认三栏工作台布局：左侧计划、中间地图、右侧机场详情 / Selection / 离线地图。
- 构建产物中已确认没有顶层 `Resources/` 目录，资源位于 `Web/` 和 `Database/`。
- 运行日志未发现 App 崩溃或本地资源缺失；仅出现 iOS 26.5 模拟器 WebKit 辅助功能类重复提示。

待验证：

- 继续迁移自动航路规划、完整 Procedure 几何、真实离线瓦片读取。

注意：

- 未修改 `NavPlanner-web/`。
- 未启动 Python server。
- 当前自动航路规划、完整 Procedure 几何和真实离线瓦片读取仍为后续阶段。

## 2026-05-30 Web 复刻内核接入

已完成：

- 对比当前 iOS 轻量地图内核与 `NavPlanner-web/static/`：iOS 原 `map.html/map.css/map.js` 约 692 行，Web 参考 `index.html/styles.css/app.js` 约 9160 行，功能差距明显。
- 将 `NavPlanner-web/static/index.html` 复制为 iOS 自有 `NavPlanner/Resources/Web/map.html`。
- 将 `NavPlanner-web/static/app.js`、`styles.css`、`nav-icons/` 复制到 iOS 自有 `NavPlanner/Resources/Web/`。
- 下载并打包本地前端运行时：Leaflet 1.9.4、MapLibre GL 5.10.0、maplibre-contour 0.0.5、pmtiles 3，存放于 `NavPlanner/Resources/Web/vendor/`。
- 修改 `map.html`，移除 `unpkg.com` CDN 引用，改为本地 vendor 资源。
- 修改 `app.js`，为 iOS custom scheme 增加 `apiResourceUrl(...)`，避免 `window.location.origin` 在 `navplanner://` 下影响瓦片和 PMTiles URL。
- 扩展 `NavPlannerSchemeHandler`：
  - 支持嵌套静态资源读取。
  - 支持 Web 代码中的 `/api/...` 绝对路径。
  - 支持 nav-icons、vendor 文件 MIME。
  - 支持 `map-cache`、`terrain`、`offline-maps` 占位瓦片。
  - 支持离线地图管理 POST API 的 Swift 占位响应。
- 扩展 `PlannerService`：
  - 增加 `/api/airway/{airway}`。
  - 增加 `/api/route/flightaware-match` 和 `/api/route/track-match` 离线不可用响应。
  - 将 `/api/route/resolve` 从纯 placeholder 提升为可返回本地 DCT、航点串和基础航路展开 payload。
- 扩展 `MapStore`：
  - 资源 payload 对齐 Web 离线地图 UI 需要的字段。
  - 增加选择、删除、压缩、下载、取消的占位通路。
- 调整 SwiftUI 外壳：当前运行路径使用全屏 Web 工作台，避免旧原生面板和 Web 面板重复。
- 新增 `Docs/WebParity.md`，记录 Web 复刻已对齐、部分对齐和未对齐内容。
- 更新 README、TODO、WebBridge、MapKernel、AppShell、OfflineMaps 文档。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，Web 参考版移动布局加载，Leaflet 地图和控件可见。
- iPhone 17 Pro 运行时输入 `ZBAA`，Web 搜索结果卡片显示 `ZBAA / CAPITAL / airport`。
- iPhone 17 Pro 运行时以 `ZBAA` / `ZSPD` 点击 Build Route，Web 面板成功加载跑道选项并把 route 写为 `DIRECT`，说明 `/api/route/resolve` payload 可被 Web `applyRoutePayload` 接受。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功，Web 工作台加载；当前竖屏按 Web 窄屏布局显示。

待验证 / 待迁移：

- 完整 `planner_routes.py` 自动规划、复杂航路择优和 `***` 行为。
- 完整 Procedure RF / AF / holding / missed 几何。
- PMTiles Range 读取；MBTiles / SQLite tile store 已在后续记录中接入。
- Web 弹窗、点击命中层和跨日期变更线行为的逐项回归。
- Web UI 中英文文案的中文化。

## 2026-05-30 iPhone / iPad 设置与触控回归

已完成：

- iPhone 界面调整为上部约 60% 地图、下部约 40% 输入工作区。
- iPhone 下部工作区加入 `Plan`、`Airport`、`Settings` 三个标签，切换标签时保持顶部 Leaflet 地图实例、当前视角和叠加层。
- iPhone 小屏样式压缩字体、输入框、按钮、搜索结果、Procedure chip 和地图控件尺寸。
- iPad 保持当前 Web 工作台布局，详情区域新增 `Airport / Settings` 切换。
- Settings 页面显示当前数据库名称和状态，支持从系统 Files 选择 `.s3db`、`.sqlite`、`.sqlite3`、`.db`。
- Swift bridge 新增 `selectDatabase` 消息，使用 `UIDocumentPickerViewController` 选择文件，并通过 `window.navplannerNativeDatabaseSelected(...)` 回写状态。
- `LocalDataStore.importDatabase(from:)` 会把导入文件复制到 Application Support 的 `NavPlanner/Database/`，重新打开 SQLite 连接并切换后续本地查询。
- Settings 页面支持系统自动、日间、夜间外观模式，偏好写入 `localStorage.navplannerThemeMode`。
- Settings 页面加入本地数据库、离线地图和数据版权说明。
- 移除地图右下角 Leaflet attribution / 水印显示。
- 关闭 Leaflet `doubleClickZoom`，并在地图容器层拦截 `dblclick` 默认行为，避免双击空白处误放大。
- 增加 document 级 `dblclick` / 双触防放大保护，覆盖地图外的下方面板空白区域，同时避开输入框、按钮、链接、Leaflet 控件和离线地图弹窗。
- 修复日间主题下 Settings “选择 s3db”按钮文字对比度过低的问题。
- 修复启动时 `PlannerService.headerPayload()` 在 `LocalDataStore.read` 串行队列内再次调用 `statusPayload()` 导致的同步队列重入死锁。
- 新增 `Docs/Settings.md`，并同步更新 README、TODO、AppShell、MapKernel、WebBridge、LocalDataStore、WebParity 文档。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，进程可稳定启动，不再回到 Home screen。
- iPhone 17 Pro 截图确认上方地图约 60%、下方 Plan 输入区约 40%，底部 `Plan / Airport / Settings` 标签可见。
- iPhone 17 Pro 输入 `ZBAA` 可聚焦文本框并显示本地搜索结果。
- iPhone 17 Pro 切换 Airport / Settings 时顶部地图保持不变。
- iPhone 17 Pro Settings 可弹出系统文件选择器，取消后设置页显示取消状态。
- iPhone 17 Pro 夜间模式可即时切换。
- iPhone 17 Pro 地图拖动平移、缩放按钮、航路点击弹窗可用；双击测试未触发地图级放大。后续补充页面空白处双触防放大的模拟器复测。
- iPad Pro 13-inch (M5) `build_run_sim` 成功，既有工作台布局保持，Settings 可从详情区域切换。

待验证 / 待迁移：

- 真机双指缩放和键盘弹出时的滚动细节。
- 导入数据库 schema 兼容性检查和恢复内置数据库入口。
- 继续完成 Web UI 中文化、完整航路规划、真实离线瓦片读取和复杂 Procedure 几何。

## 2026-05-30 Route Resolve 自动 Procedure 接入

已完成：

- 对比 `NavPlanner-web/static/app.js` 和 `NavPlanner-web/src/planner_routes.py`，确认 Web 前端在 Build Route 时会传 `departure_runway` / `arrival_runway`，并依赖 `selected_procedures` 自动绘制 SID / STAR / APPROACH。
- 扩展 `NavPlannerSchemeHandler`，把 `/api/route/resolve` 的起飞/到达跑道参数传入 Swift 本地 `PlannerService`。
- 扩展 `PlannerService.routeResolvePayload(...)`，在 Route 留空时尝试按 Web 参考逻辑选择匹配跑道的 SID / STAR / APPROACH。
- 新增 Swift 本地 Procedure 候选选择逻辑：
  - 按 procedure / transition 分组。
  - 从 transition 或 procedure identifier 推断 runway。
  - 支持 `RW16B` 等 B 跑道与左右跑道匹配。
  - 按 SID 终点和 STAR 入口距离筛选候选。
  - 返回 `selected_procedures`、`selected_runways`、`segments` 和自动接入 message。
- 将 route payload 的 `segments` 调整为更接近 Web 的 `departure / enroute / arrival` 字典结构。
- 同步更新 README、TODO、Procedures、WebBridge、WebParity 文档。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 运行时验证 `ZBAA` -> `ZSPD`，Route 留空点击 Build Route 后，状态显示“已按 SID / STAR 自动接入本地离线航路。646nm selected.”，地图出现主航线与 Procedure 叠加层。

待验证 / 待迁移：

- Web `planner_routes.py` 的完整 airway graph Dijkstra 搜索、single-airway preference、partial route fallback 和 `***` 自动补航路仍未完整迁移。
- 需要补充典型航线与跨日期变更线航线的 payload 对照测试。

## 2026-05-30 页面级双触防放大补强

已完成：

- 在 `NavPlanner/Resources/Web/app.js` 增加 document 级 `dblclick` 与双触 `touchend` 捕获保护，覆盖地图外的下方面板空白区域，避免 WKWebView 页面级放大。
- 防护逻辑避开 `button`、`input`、`textarea`、`select`、链接、Leaflet 控件、地图类型菜单和离线地图弹窗，避免影响输入、按钮和地图控件。
- 保留 Leaflet `doubleClickZoom: false` 与地图容器 `dblclick` 拦截，形成地图级与页面级双层保护。
- 更新 `map.html` 本地资源版本号，避免 WKWebView 缓存旧版 `app.js`。
- 同步更新 README、TODO、MapKernel、Settings、AppShell、WebParity 文档。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；截图确认上部地图约 60%、下部 Plan / Airport / Settings 三标签约 40%。
- iPhone 17 Pro 触控回归：输入 `ZBAA` 可聚焦并显示本地搜索结果；切换 Settings / Airport 时顶部地图不重建；缩放按钮和平移可用；连续点击下方面板空白区域未触发页面放大。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功；截图确认既有工作台布局保持，详情区域可切到 Settings。

## 2026-05-30 Route Resolve airway graph 对齐推进

已完成：

- 重新对照 `NavPlanner-web/src/planner_routes.py` 的 `_ifrr_route_between_with_exclusions`、`_prefer_single_airway_route`、`_build_partial_airway_route` 和 `_resolve_route_boundary_point`。
- 扩展 Swift `AirwayGraph`，新增 `nodeAirways`，用于判断两个候选节点是否共享同一条 airway。
- 在 Swift 本地自动规划中加入 Web 参考版的同航路优先逻辑：若起点/终点附近候选能由同一条 airway 合法连接，会优先返回单条 airway leg。
- 在 Swift 本地 Dijkstra 搜索中加入 partial airway + DCT fallback：找不到完整 end candidate 时，若已沿 airway 网络推进足够距离且总距离可接受，会返回 airway 段加最后 DCT。
- 手动航路和 `***` 目标点改为带 airway 上下文解析边界点：普通 airway 使用当前 airway，`***` 使用下一条 airway 作为目标解析提示，并按邻近点排序，减少同名航点选错。
- `***` 自动补航段成功返回 airway leg 时，message 改为“已按本地 IFR 航路网络补全 *** 航段。”
- 为 `LocalDataStore` 增加内部 `init(databaseURL:)`，方便命令行探针和后续单元测试直接打开 fixture 数据库，不改变 App 正常启动路径。
- 同步更新 README、TODO、WebBridge、Procedures、LocalDataStore、WebParity 文档。

验证记录：

- 临时 Swift 探针直连 `PlannerService.routeResolvePayload` 与 `NavPlanner/Resources/Database/navdata.sqlite` 成功。
- `DODGR -> GARNE` 留空 Route 返回 `DODGR V370 GARNE`，包含 1 条 airway leg，message 为“已按本地 IFR 航路网络自动规划。”
- `DODGR *** GARNE` 返回 1 条 airway leg，message 为“已按本地 IFR 航路网络补全 *** 航段。”
- `ZBAA -> ZSPD` 留空 Route 仍可自动选择 SID / STAR；当前数据库下 SID / STAR 之间仍回退 direct，后续需继续对照 Web 的完整择优与典型航线结果。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 与 iPad Pro 13-inch (M5) 成功；iPad 手工坐标输入受 Web 搜索联想层干扰，最终改用 Swift 探针验证 route payload。

待验证 / 待迁移：

- 与 Web Python 版逐条对照更多典型航线、跨日期变更线航线和含多个 airway 的 mixed-route。
- 迁移 route cache、excluded airway、错误提示、FlightAware AeroAPI / track match 及完整单元测试。

## 2026-05-30 Route Resolve 缓存对齐

已完成：

- 对照 Web `PlannerCoreMixin.__init__` 中的 `_airway_graph`、`_route_between_cache` 和 `PlannerRouteMixin._ifrr_route_between(...)` 缓存策略。
- 在 Swift `PlannerService` 中加入 airway graph cache 和 route-between cache。
- route-between cache key 使用起终点 ident 与 5 位小数坐标，贴近 Web 参考版 cache key。
- cache 以 `LocalDataStore.databaseURL.path` 为边界；Settings 导入数据库成功后 `AppEnvironment.importDatabase(from:)` 会调用 `plannerService.invalidatePlanningCaches()`，避免切库后沿用旧 graph / route。
- `procedureGuidedRoutePayload` 中 SID / STAR 候选之间的 enroute 连接改为走 cached `ifrrRouteBetween(..., database:)`，重复 Build Route 时避免反复重建 airway graph。
- 同步更新 README、TODO、WebBridge、LocalDataStore、WebParity 文档。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 临时 Swift 探针重新编译成功，并直连 `PlannerService.routeResolvePayload` 验证：
  - `DODGR -> GARNE` 留空 Route 返回 `DODGR V370 GARNE`，包含 1 条 airway leg。
  - `DODGR *** GARNE` 返回 1 条 airway leg，message 为“已按本地 IFR 航路网络补全 *** 航段。”
  - `ZBAA -> ZSPD` 留空 Route 仍自动选择 SID / STAR，当前数据下 enroute 部分回退 direct。

待验证 / 待迁移：

- 增加正式 XCTest 或命令行 route fixture，记录 cache hit、跨数据库切换和典型航线 payload 对照。
- 继续迁移 excluded airway、FlightAware AeroAPI / track match、错误提示和多 airway mixed-route 权重。

## 2026-05-30 iPhone / iPad 界面与触控复验

验证记录：

- 未修改 `NavPlanner-web/`。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 截图确认上部地图约 60%、下部 Plan / Airport / Settings 输入工作区约 40%，地图右下角无 Leaflet / MapLibre attribution 水印。
- iPhone 17 Pro 输入框触控验证：点击 Departure 输入 `ZBAA` 可聚焦并显示本地搜索结果。
- iPhone 17 Pro Settings 验证：切换到 Settings 时顶部地图与弹窗保持不变；“选择 s3db”可弹出系统 Files 文件选择器，取消后状态回写。
- iPhone 17 Pro 地图触控验证：地图点击弹窗、缩放按钮和平移手势可用；双击地图区域未触发页面级放大。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功。
- iPad Pro 13-inch (M5) 截图确认仍保持工作台布局，Settings 可在详情区域切换显示，没有套用 iPhone 的 60/40 布局。

## 2026-05-30 导入轨迹匹配对齐推进

已完成：

- 对照 Web `NavPlanner-web/src/planner_routes.py` 的 `match_imported_track_route`、`_match_track_points_to_airways`、`_simplify_flightaware_legs` 与 Web 前端 `matchFlightAwareRoute()` 降级流程。
- `NavPlannerSchemeHandler` 接通 POST `/api/route/track-match`，读取 `{ departure, arrival, track_points }` 并返回 Swift 本地 route payload。
- `PlannerService.trackMatchPayload(...)` 新增导入轨迹点规范化、airway graph 最近节点吸附、图上最短路匹配、detour 过大时 direct fallback、连续 leg 合并和基础同航路窗口简化。
- `/api/route/flightaware-match` 当时保持离线增强边界，不访问远程 FlightAware；后续已迁移为 AeroAPI 在线增强入口。
- `MapWebView` 接入 `WKUIDelegate` 的 alert / confirm / prompt，让 Web 版 `window.prompt(...)` 在 iOS 上显示原生输入框。
- 同步更新 README、TODO、WebBridge、AppShell、WebParity 文档。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- 临时 Swift 探针重新编译成功，并直连 `PlannerService.trackMatchPayload` 验证：用 `DODGR V370 GARNE` 的 9 个轨迹点导入匹配，返回 `DODGR V370 GARNE`，包含 1 条 airway leg。
- `PlannerService.legacyFlightAwareUnavailablePayload()` 返回可导入轨迹的离线增强提示。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功启动。

待验证 / 待迁移：

- 继续迁移 Web 的 Procedure 自动挂接、轨迹误差平滑、zigzag 清理和在线 FlightAware AeroAPI 查询增强。
- 在模拟器中补测 `Match FlightAware AeroAPI` 按钮触发 prompt、粘贴 JSON/CSV 轨迹并绘图。

## 2026-05-30 route/resolve 错误语义对齐

已完成：

- 对照 Web `NavPlanner-web/src/planner_routes.py` 的 `resolve_route(...)` 与 `planner_api.py` 的 `ValueError -> HTTP 400` 行为。
- Swift `PlannerService.routeResolvePayload(...)` 对手动 route 的错误从“静默跳过 token”改为返回 `error` payload。
- `NavPlannerSchemeHandler` 对 `/api/route/resolve` 检测到 `error` 字段时返回 HTTP 400，让 Web `fetchJson` 走与参考版相同的错误提示路径。
- 增加 route 解析上下文标记，显式写出出发点再跟 airway 的输入会被视为已有前置 fix，贴近 Web 版 `points/expanded` 语义。
- 同步更新 README、TODO、WebBridge、WebParity 文档。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 临时 Swift 探针重新编译成功，正常 route 仍可返回：
  - `DODGR -> GARNE` 留空 Route 返回 `DODGR V370 GARNE`。
  - `DODGR *** GARNE` 返回 1 条 airway leg。
- 临时 Swift 探针验证错误语义：
  - `BOGUSFIX` 返回 `Waypoint BOGUSFIX not found.`
  - `DCT` 返回 `DCT must follow a known fix or airport.`
  - `DODGR V370` 返回 `Airway V370 is missing an exit fix.`
  - `DODGR ***` 返回 `*** is missing the target fix.`
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。

待验证 / 待迁移：

- 继续对齐 Web 中剩余 airway 扩展失败、excluded airway 和 mixed-route 权重相关错误路径。

## 2026-05-30 iPhone 端布局与触控要求复查

复查结论：

- 当前工程已经实现本轮 iPhone 需求：上部地图约 60%，下部输入区域约 40%，下部包含 `Plan`、`Airport`、`Settings` 三个标签。
- 切换 iPhone 下部标签时，顶部 WKWebView 地图实例保持不变；已验证 Settings 打开后地图弹窗和当前视图仍保留。
- iPad 没有套用 iPhone 的 60/40 布局，仍保持工作台布局；详情区域已加入 `Airport / Settings` 切换。
- Settings 已包含本地 `.s3db` / `.sqlite` / `.sqlite3` / `.db` 数据库选择、系统自动 / 日间 / 夜间主题切换，以及地图和导航数据版权说明。
- Leaflet / MapLibre attribution 水印已隐藏；地图右下仅保留图层按钮和缩放控件。
- 双击 / 双触页面空白处不会触发 WKWebView 页面级放大；Leaflet `doubleClickZoom` 也已关闭。

验证记录：

- 未修改 `NavPlanner-web/`。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；截图确认 iPhone 60/40 布局、三标签和无水印状态。
- iPhone 17 Pro 触控复查：输入框可聚焦并输入，地图点击弹窗、图层菜单、平移手势和缩放控件可用；连续点按空白未出现页面放大。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功；截图确认工作台布局保持，Settings 可在详情区域打开。

## 2026-05-31 Procedure 几何对齐推进

已完成：

- 对照 `NavPlanner-web/src/planner_core.py` 的 `procedure_geometry(...)` 和 `NavPlanner-web/src/planner_routes.py` 的 Procedure 几何辅助函数。
- 将 Swift `PlannerService.buildProcedureGeometry(...)` 从基础折线升级为 Web 对齐几何：
  - RF / AF leg 使用中心点、本段 magnetic course、前后相邻坐标进行方向评分并生成弧线采样点。
  - 跑道航点后切换 `missed_path`，保持 `path` / `primary_path` / `missed_path` 分段行为贴近 Web。
  - 复飞末端 HA / HF / HM 等待航线按 inbound course、holding distance/time 和转弯方向生成等待航线。
- 同步更新 README、TODO、Procedures、WebParity、MapKernel 文档。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 临时 Swift 探针直连 `PlannerService.procedurePayload(...)` 成功：
  - `BIAR ASKU1D RW19` 返回 `items=5 path=28 primary=28 missed=0 middle=65.604375,-18.066209`。
  - `MTCH NOSO1L RW05` 返回 `items=3 path=26 primary=26 missed=0 middle=20.008817,-72.417996`。
  - `07FA R05-P ALL` 返回 `items=7 path=48 primary=4 missed=45 middle=25.173469,-80.350817`。
- Python 参考探针调用 Web `procedure_geometry(...)`，上述三个样例的点数、中点坐标、primary / missed 分段与 Swift 输出一致。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；普通 shell 仍有 CoreSimulatorService 权限噪声，但最终 `BUILD SUCCEEDED`。

待验证 / 待迁移：

- 在模拟器中选择上述 Procedure，补截图确认前端渲染效果和交互高亮。
- 继续迁移 nav-overlay 日期变更线世界副本、Web 弹窗命中层和真实离线瓦片读取。

## 2026-05-31 nav-overlay 世界副本与日期变更线对齐

已完成：

- 对照 Web `NavPlanner-web/src/planner_overlay.py` 的 `nav_overlay(...)`、`_nav_overlay_data()`、`_world_copy_offsets_for_bounds(...)`、`_point_in_bounds(...)`、`_segment_intersects_bounds(...)` 和 `_spatially_distribute_segments(...)`。
- 将 Swift `PlannerService.navOverlayPayload(...)` 从 SQL bounds 直接查询改为 Web 对齐模型：
  - 构建并缓存全量本地 overlay 数据，缓存以当前 `databaseURL.path` 为边界，导入新数据库后随 `invalidatePlanningCaches()` 失效。
  - 使用 Web 同款世界副本偏移判断点和线段是否落入视野，支持跨日期变更线请求。
  - 对航路段使用空间分桶截断，避免大视野下叠加层密度集中。
  - 对航路标签使用 Web 同款预算和重复间隔。
  - 补齐 terminal waypoint、terminal NDB、跑道和 ILS 输出。
  - 为 waypoint / navaid 补齐 `connections` 和 `associated_routes`，让弹窗关联航路信息更接近 Web。
- 同步更新 README、TODO、WebParity、MapKernel、LocalDataStore 文档。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 临时 Swift 探针直连 `PlannerService.navOverlayPayload(...)` 成功：
  - `dateline-high`: `airports=50 airways=414 labels=414 waypoints=1181 navaids=30 runways=104 ils=8`
  - `dateline-mid`: `airports=52 airways=423 labels=143 waypoints=420 navaids=30 runways=0 ils=0`
  - `china`: `airports=93 airways=1823 labels=772 waypoints=923 navaids=302 runways=0 ils=0`
- Python 参考探针调用 Web `nav_overlay(...)`，上述三组视野的 airports / airways / labels / waypoints / navaids / runways / ils 计数与 Swift 输出逐项一致。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；普通 shell 仍有 CoreSimulatorService 权限噪声，但最终 `BUILD SUCCEEDED`。

待验证 / 待迁移：

- 在 iPhone / iPad 模拟器里拖到日期变更线附近，截图确认 nav-overlay 世界副本和前端点击命中层表现。
- 继续迁移 Web 弹窗命中层、空白关闭细节和真实 PMTiles / MBTiles / SQLite 瓦片读取。

## 2026-05-31 iPhone 日间主题与底部标签视觉优化

已完成：

- 根据用户截图复查 iPhone Settings：确认旧版底部 Tab 覆盖外观按钮，且 `Settings` 标题和大控件占用了过多下部空间。
- 优化日间主题基础变量：改为浅蓝灰背景、白色半透明面板、更清晰的深色文字、蓝绿/琥珀辅助色和更轻的阴影。
- 为日间主题补充面板、搜索结果、按钮、机场详情、选择表格和 active chip 的专用对比度样式。
- 将 iPhone 下部标签从英文文字改为中文图标 `计划 / 机场 / 设置`。
- 将 iPhone 底部标签改为独立网格行，使用 CSS 玻璃质感近似 Liquid Glass；下部内容区域截止到标签栏上方，不再被覆盖。
- 进一步压缩 iPhone 字体、输入框、按钮、设置卡片、搜索结果和地图控件尺寸。
- iPhone 下部工作区隐藏顶层 `Plan / Settings / Airports` 区块标题，节省垂直空间。
- 补充隐藏 MapLibre attribution / logo，继续保持地图右下角无水印。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；普通 shell 仍有 CoreSimulatorService 权限噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 截图确认：Settings 不再显示顶层标题，底部中文图标玻璃 Tab 不覆盖内容；日间主题切换后文字、按钮和卡片可读性明显改善。
- iPhone 17 Pro 触控回归：缩放按钮可用，Plan / Settings 切换保持地图，输入框可聚焦并显示 `ZBAA` 本地搜索结果，连续点按地图区域没有触发页面级放大，地图点击弹窗仍可用。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功；截图确认 iPad 仍保持工作台式布局，没有套用 iPhone 底部标签。

待验证 / 待迁移：

- 后续继续把 Plan / Airport 常用英文文案中文化，同时保持与 Web 参考行为一致。
- 如果后续将底部标签迁出 WebView，可在 SwiftUI 层改用原生 iOS 26 `glassEffect`；当前阶段因标签属于 WebView 工作台，使用 CSS `backdrop-filter` 近似玻璃效果。

## 2026-05-31 离线地图本地瓦片读取

已完成：

- 对照 Web `NavPlanner-web/src/planner_maps.py` 的 `OfflineMapManager.resource_tile(...)`、`active_tile(...)`、`offline_tile_path(...)`、`legacy_offline_tile_path(...)` 和 MBTiles / SQLite 读取行为。
- 将 iOS `MapStore.activeTile(...)` / `resourceTile(...)` 从占位 `nil` 改为真实读取：
  - Web `tiles.sqlite`：读取 `tiles(z, x, y, data)`。
  - MBTiles：读取 `tiles(zoom_level, tile_column, tile_row, tile_data)`，按 TMS y 翻转匹配 Leaflet 请求。
  - Web 文件布局：兼容新版 `tiles/zXX/shard/xxxxxxxx_yyyyyyyy.ext` 和旧版 `tiles/z/x/y.ext`。
- `MapStore` 现在能扫描 Web `map_offline` 目录资源，也能扫描 `.mbtiles`、`.sqlite`、`.sqlite3`、`.pmtiles` 单文件资源。
- 离线地图 status payload 补充 `content_type`、`tile_count`、缩放范围、bounds 和更准确的资源说明。
- `NavPlannerSchemeHandler` 会把矢量 gzip PBF 的 `Content-Encoding: gzip` 头传回 WebView。
- PMTiles 此时仍只扫描资源，Range 读取随后已在本日后续记录中接入。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 临时 Swift 探针生成 Web `tiles.sqlite` 与 MBTiles 样例资源，直连 `MapStore(rootDirectory:)` 成功：
  - 扫描资源数 `resources=2`。
  - `activeTile(0,0,0)` 从 Web `tiles.sqlite` 读回 68 字节 PNG。
  - `resourceTile("sample", 1, 0, 0)` 从 MBTiles 读回 4 字节 JPEG，验证 TMS y 翻转有效。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；普通 shell 仍有 CoreSimulatorService 权限噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；截图确认地图内核和 iPhone UI 启动正常。

待验证 / 待迁移：

- 使用真实 PMTiles 包验证 MapLibre `pmtiles://` 离线矢量底图完整显示。
- 在模拟器/真机导入真实 MBTiles 或 Web `map_offline` 资源包，截图确认底图瓦片显示和 nav-overlay 独立刷新。
- 后续实现 iOS 原生离线地图导入入口和下载器，继续收敛 Web 离线地图管理弹窗行为。

## 2026-05-31 iPhone 日间主题与底部标签二次打磨

已完成：

- 继续调整 iOS 自有 `NavPlanner/Resources/Web/styles.css`，未修改只读参考项目 `NavPlanner-web/`。
- 日间主题改为更柔和的浅蓝灰工作台：降低背景网格与阴影强度，增强正文、输入框、搜索结果、按钮和设置卡片对比度。
- iPhone 底部 `计划 / 机场 / 设置` 标签继续压低高度，减小图标、文字、间距和玻璃容器阴影，保持独占底部行，不覆盖下部内容。
- iPhone 输入框、按钮、搜索结果、设置卡片、主题切换按钮和地图控件继续缩小，节省下部 40% 工作区。
- 保持移动端隐藏顶层 `Plan / Settings / Airports` 区块标题，Settings 页直接从“导航数据库”卡片开始。
- 更新 `map.html` 的 CSS 版本号，避免 WKWebView 复用旧样式缓存。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 截图确认：日间主题更清淡，底部中文图标玻璃 Tab 更薄且贴近底部，Settings 无顶层标题，底部 Tab 不覆盖内容。
- iPhone 17 Pro 触控回归：输入框可聚焦并显示 `ZBAA` 本地搜索结果；地图平移、缩放按钮、连续点按防页面放大和点击弹窗均可用。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功；截图确认 iPad 仍保持工作台式布局，未套用 iPhone 底部三标签。

待验证 / 待迁移：

- 真机回归双指缩放、键盘遮挡和 Home Indicator 边距。
- 使用真实 PMTiles 包验证 `pmtiles://` 离线矢量底图完整显示。

## 2026-05-31 PMTiles Range 本地读取

已完成：

- 对照 Web `NavPlanner-web/src/planner_api.py` 的 `_send_offline_pmtiles(...)` 和 `_send_file_range(...)`，在 Swift 本地服务层补齐 PMTiles 文件 Range 响应。
- `MapStore` 新增 `OfflineFileRangeResult` 和 `pmtilesFileResponse(name:rangeHeader:)`。
- `.pmtiles` 单文件资源的 `storage_layout` 从占位 `pmtiles_file` 改为前端识别的 `pmtiles_v1`；Web `resource.pmtiles` 目录资源继续识别为 `pmtiles_v1`。
- Range 支持完整响应、`bytes=start-end`、`bytes=start-`、`bytes=-suffix`，无效或越界范围返回 416 与 `Content-Range: bytes */size`。
- `NavPlannerSchemeHandler` 接通 `/api/offline-maps/pmtiles/{name}.pmtiles`，返回 `Accept-Ranges`、`Content-Length`、`Content-Range` 和 `Cache-Control: public, max-age=31536000, immutable`。
- 未修改 `NavPlanner-web/`。

验证记录：

- 临时 Swift 探针直连 `MapStore(rootDirectory:)` 成功：目录 `resource.pmtiles` 和单文件 `single.pmtiles` 均扫描为 `pmtiles_v1`。
- 临时 Swift 探针验证完整读取返回 200 / 16 字节，`Range: bytes=2-5` 返回 206 / `2345`，`Range: bytes=-4` 返回 206 / `cdef`，`Range: bytes=99-100` 返回 416 / `Content-Range: bytes */16`。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；普通 shell 仍有 CoreSimulatorService 权限噪声，但最终 `BUILD SUCCEEDED`。

待验证 / 待迁移：

- 导入真实 PMTiles 资源包，在模拟器 / 真机确认 MapLibre `pmtiles://` 离线矢量底图画面、缩放和平移瓦片请求都正常。

## 2026-05-31 常用路径中文化与文档同步

已完成：

- 同步 README、TODO、WebParity、WebBridge、MapKernel 和 Settings 文档，记录 iPhone 日间主题、紧凑中文图标玻璃 Tab、无标题 Settings、无水印和双击防放大的当前状态。
- 修正文档中的离线地图旧描述：MBTiles、Web `tiles.sqlite`、Web `tiles/` 已可真实读取，PMTiles Range 已接入；剩余风险改为真实 PMTiles 包的 MapLibre 离线矢量底图视觉验证。
- 记录 Plan / Airport / Settings 常用路径中文化第一轮已完成：表单标签、占位提示、按钮、机场详情、Procedure 空状态、弹窗动作和航路状态提示已切换为中文。
- 保留后续中文化任务：离线地图管理弹窗、底图选择、错误提示和少量运行状态中的英文文案。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 权限噪声，但最终 `BUILD SUCCEEDED`。

待验证 / 待迁移：

- 真机继续回归双指缩放、键盘遮挡和 Home Indicator 边距。
- 继续清理离线地图管理和底图控制中的英文 UI 文案。
- 使用真实 PMTiles 包验证 MapLibre `pmtiles://` 离线矢量底图完整显示。

## 2026-05-31 iPhone 输入聚焦、弹窗和地图符号紧凑化

已完成：

- 确认截图中的底部上一项 / 下一项 / 完成栏来自 iOS WebKit 对 HTML 输入框自动添加的系统 input accessory view，不是 NavPlanner 页面或浏览器套壳控件；模拟器硬件键盘模式明显可见，真机外接键盘时也可能出现。
- 新增 `PhoneMapWebView`，仅 iPhone 使用，覆盖 `inputAccessoryView` 并清空 `inputAssistantItem`，去除 WebKit 输入附件栏。
- Swift 侧继续关闭 WKWebView 外层 `UIScrollView` 滚动、bounce 和自动 inset；Web 侧将 iPhone `html/body` 固定到视口，并安装 `installMobileViewportLock()`，输入聚焦或 visual viewport 变化时只复位 document 滚动，不影响下方面板内部滚动和地图手势。
- iPhone-only 缩小地图弹窗：`maxWidth` 从 432 降到 224，CSS 同步缩小弹窗字号、行距、标题区、关闭按钮、详情行、关联航路和机场操作按钮。
- iPhone-only 缩小地图符号和标签：普通航点、终端航点、VOR/DME/NDB 图标、机场/航点/导航台/航路标签、规划航路点和航路 badge 都按紧凑比例显示；点击命中层保持较大，避免牺牲触控可用性。
- 更新 `map.html` 样式版本号，避免 WKWebView 使用旧缓存。
- 同步更新 README、TODO、AppShell、MapKernel 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 权限噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 聚焦起飞机场输入框后，未再出现 WebKit 上一项 / 下一项 / 完成附件栏；页面未被顶起，输入 `ZBAA` 后本地搜索结果正常显示。
- iPhone 17 Pro 地图点击回归：航路弹窗缩小为约半宽，字体和操作按钮更紧凑；地图符号和标签缩小后仍可点击弹窗。

待验证 / 待迁移：

- 真机回归软键盘弹出时的下方面板可见性、双指缩放和 Home Indicator 边距。
- 如果用户需要在外接键盘下保留上一项/下一项输入导航，可后续改为自定义极简输入工具条；当前按“不显示浏览器式操作栏”的需求彻底移除。

## 2026-05-31 iPhone 弹窗圆角微调

已完成：

- 继续仅调整 iPhone 地图弹窗样式，iPad 保持原 Web 工作台弹窗尺寸与圆角。
- 将 iPhone `.nav-point-popup` 外框圆角从 9px 收到 6px，减少过圆的胶囊感。
- 将弹窗 tip 缩小到 10px，并把 tip 圆角收为 1px。
- 将关闭按钮从圆形改为 5px 小方圆角，与工具型浮层视觉一致。
- 更新 `map.html` 样式版本号，避免 WKWebView 使用旧缓存。
- 同步更新 README、MapKernel 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 地图点击截图确认：弹窗外框圆角更小，关闭按钮改为小方圆角，整体不再像大圆角卡片；弹窗点击仍可用。

## 2026-05-31 iPhone 弹窗内嵌标题圆角

已完成：

- 按用户反馈保留 iPhone 弹窗柔和圆角，并让外框圆角与按钮视觉更一致。
- 将顶部深色标题块改为内嵌样式：标题块与弹窗外边缘保留 5px 缝隙，标题块自身使用 7px 圆角。
- 关闭按钮跟随标题块内缩，并使用 7px 圆角，避免圆形按钮和弹窗外框风格割裂。
- 更新 `map.html` 样式版本号，避免 WKWebView 使用旧缓存。
- 同步更新 README、MapKernel 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 地图点击截图确认：顶部深色标题块已内嵌并保留外边距，标题块和关闭按钮圆角与弹窗按钮风格一致。

## 2026-05-31 iPhone 航路弹窗按钮与毛玻璃

已完成：

- 修正机场操作按钮判定：`isAirportActionCandidate(...)` 只接受 `point.kind === "airport"`，航路、航点、导航台和普通直飞航段不再因为 ident 类似 4 位机场代码而显示“设为起飞 / 到达 / 手动”。
- iPhone 弹窗宽度从 224px 缩小到 180px，约再缩小 20%；iPad 保持 432px 原宽度。
- iPhone 弹窗外层和 tip 改为半透明毛玻璃背景，叠加 `backdrop-filter: blur(...) saturate(...)`。
- iPhone 顶部内嵌标题块也改为半透明深色毛玻璃，继续保留 5px 外缝隙和圆角。
- 更新 `map.html` 样式版本号，避免 WKWebView 使用旧缓存。
- 同步更新 README、MapKernel 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 航路弹窗截图确认：`J138` 航路弹窗不再显示“设为起飞 / 到达 / 手动”按钮，宽度进一步缩小，背景呈半透明毛玻璃效果。

## 2026-05-31 iPhone 刘海安全区主题同步

已完成：

- 确认问题根因：Settings 切换日间 / 夜间只改变 WebView 内部 CSS，顶部刘海安全区由 SwiftUI 外壳绘制，之前没有收到 Web 主题状态，所以在日间主题下仍显示夜间深色。
- `AppEnvironment` 新增 `webThemeMode` 和 `webEffectiveTheme`，并处理 Web 发来的 `themeChanged` 事件。
- `AppRootView` 和 `MapContainerView` 使用 `webEffectiveTheme` 绘制 SwiftUI 外壳背景；显式 `day/night` 模式下通过 `.preferredColorScheme(.light/.dark)` 让状态栏文字和图标跟随主题。
- `app.js` 新增 `postNativeEvent(...)`，`applyThemeMode(...)` 每次应用主题后同步 `{ mode, effectiveTheme }` 给 SwiftUI。
- 更新 `map.html` 的 `app.js` 版本号，避免 WKWebView 使用旧脚本缓存。
- iPhone 底部 `计划 / 机场 / 设置` 标签切换时主动 `blur()` 当前输入框，避免编辑焦点干扰标签切换。
- 同步更新 README、TODO、AppShell、Settings 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 权限噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 截图确认：日间主题下顶部刘海安全区变为浅色，状态栏文字和图标变为深色，和 WebView 日间背景一致。
- iPhone 17 Pro Settings 主题切换回归：切到夜间后刘海安全区变深、状态栏变浅；切回日间后刘海安全区变浅、状态栏变深。

待验证 / 待迁移：

- 继续在真机上回归系统自动模式随系统外观变化时的刘海区域和 WebView 同步效果。

## 2026-05-31 iPhone 输入、地形图和叠加层回归

已完成：

- 修复 iPhone 输入框焦点回归：`PhoneMapWebView` 继续保留键盘 responder 链路，改为返回零高度 input accessory view，仅隐藏 WebKit 上一项 / 下一项 / 完成栏；表单控件恢复原生文本选择和触控行为。
- iPhone WebView 外层保留输入聚焦所需的 scroll view 能力，同时关闭 bounce、自动 inset 和滚动指示；Web 侧继续固定页面级视口，避免整页滚动。
- 对齐 iPhone `生成航路 / 重新计算 / 匹配轨迹` 三个按钮高度。
- 将 iPhone 移动布局微调为约 64% 地图 + 36% 输入区，并把底部 `计划 / 机场 / 设置` 标签进一步压低、减小字号和图标，给地图释放更多高度。
- iPhone 地图 `+ / -` 缩放按钮间距从 4px 增到 5px，保持小屏紧凑但减少误触。
- `/api/map-cache/google_terrain/...` 和 `/api/terrain/terrarium/...` 改为 Swift `OnlineTileCache` 异步缓存：未命中先返回 `X-Map-Cache: QUEUED/PENDING` 透明瓦片，前端异步轮询后显示真实地形图；请求头模拟浏览器图片请求，并兼容 JPEG / PNG 返回。
- nav-overlay 前端刷新改为双缓冲 layer group：先绘制新叠加层，再移除旧叠加层，避免缩放后航路先消失再出现。
- 更新 `map.html` 样式缓存版本，避免 WKWebView 继续使用旧 CSS。
- 同步更新 README、TODO、AppShell、MapKernel、WebBridge、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 截图确认：Google terrain 底图可见，底部三标签贴近底部，地图高度增加，`+ / -` 缩放按钮之间有更明显间距。
- iPhone 17 Pro 触控回归：输入框可获得焦点并输入 `ZBAA`，本地搜索结果显示；未出现 WebKit 上一项 / 下一项 / 完成附件栏。
- iPhone 17 Pro 地图回归：缩放按钮可用，拖动平移可用，缩放后地形底图和 nav-overlay 仍显示，没有观察到旧叠加层先清空的明显闪烁。

待验证 / 待迁移：

- 真机继续回归软键盘实际弹出高度、Home Indicator 边距和系统自动主题。
- 后续补缓存清理、配额控制和在线瓦片失败状态 UI。

## 2026-05-31 离线地图下载器本地化

已完成：

- 对照 `NavPlanner-web/src/planner_maps.py` 的 `OfflineMapManager.start_download/cancel_download/status_payload`，将 iOS 端 `/api/offline-maps/download` 从占位响应改为 Swift 本地下载任务。
- `MapStore` 新增离线下载 provider：`OpenTopoMap Terrain`、`Esri World Topographic`、`OpenStreetMap Standard`、`OpenFreeMap Vector`，状态 payload 现在返回 provider 列表、`max_download_tiles`、超时、重试和下载任务状态。
- Swift 本地下载器支持 Web 表单同形态 payload：`provider/name/min_zoom/max_zoom/source_max_zoom/base_max_zoom/tiered/bounds`。
- 下载任务按 Web Mercator 计算瓦片范围，支持低缩放全球 + 高缩放局部的分级策略，校验 5,000,000 瓦片上限。
- 下载结果写入 `Application Support/NavPlanner/MapOffline/{name}/tiles.sqlite`，完成后写入 `metadata.json` 并设为 active resource；离线底图读取链路可立即读取该资源。
- 下载任务支持轮询状态、取消请求、单瓦片重试、连续失败自动中止、下载速度估算和失败文案。
- `/api/offline-maps/cancel` 改为请求中止当前 Swift 下载任务，不再返回“没有 Python 下载器”的占位文案。
- 清理离线地图管理弹窗中的部分英文 UI 文案：地图类型、管理按钮、弹窗标题、关闭按钮、下载启动/结束状态、删除确认、瓦片计数和未知供应商文案。
- 更新 `map.html` 的 `app.js` 缓存版本，避免 WKWebView 使用旧离线地图脚本。
- 同步更新 README、TODO、OfflineMaps、WebBridge、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- 临时 Swift 探针直连 `MapStore(rootDirectory:)` 成功：使用 `osm_standard`、z0、全球范围启动下载，返回 `running=true total=1`；任务完成后 `downloaded=1 failed=0 aborted=false`；`resourceTile(name:z:x:y:)` 读回 6924 字节 PNG；状态返回 `resources=1 providers=4 max=5000000`。

待验证 / 待迁移：

- 继续用模拟器 UI 和真机验证 Offline Terrain 下载标签、取消按钮、资源选择和底图切换。
- 继续对齐 Web 版多线程并发下载、代理配置细节、provider 探测和大任务性能。

## 2026-05-31 iPhone 输入与地图细节二次回归

已完成：

- 按用户反馈继续压缩 iPhone 下部区域：地图行提升到约 66%，输入区约 34%，底部 `计划 / 机场 / 设置` 标签压到约 19px 并更贴近底部。
- 固定 `生成航路 / 重新计算 / 匹配轨迹` 在 iPhone 下的高度，避免主按钮和旁边两个按钮视觉不齐。
- 将 iPhone 地图 `+ / -` 缩放按钮间距增至 7px。
- 重新处理 iPhone 输入框焦点：撤销零高度 `inputAccessoryView` 覆盖，避免干扰 WKWebView 键盘 responder；Swift 侧禁用外层 WebView 滚动，Web 侧改为非 fixed 根页面 + 触控 focus bridge。
- 在线地形底图通路增加 Esri World Topographic、OpenTopoMap、Google 子域顺序兜底；前端异步瓦片层把 `MISS` 也视为待重试状态，避免透明失败瓦片覆盖已有底图。
- iPhone nav-overlay 改用 SVG renderer，并在新叠加层绘制后延迟两帧移除旧层，降低缩放后灰色航路叠加层闪烁。
- 更新 `map.html` 的 CSS / JS 缓存版本。
- 同步更新 README、TODO、AppShell、MapKernel、Settings、WebBridge、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP iPhone 17 Pro 安装运行成功。
- 触控诊断确认：点击起飞机场输入框后事件目标为 `departureInput`，且 `document.activeElement` 切换为 `departureInput`。当前模拟器硬件键盘模式未强制显示软件键盘，真机仍需回归软键盘高度和 Home Indicator。
- iPhone 17 Pro 截图确认：在线地形底图可见，地图高度增加，底部标签更贴底，`+ / -` 缩放按钮间距更明显。

待验证 / 待迁移：

- 用真机确认软键盘实际弹出、输入区是否被键盘遮挡以及外接键盘场景。
- 继续观察高频缩放 / 快速拖动时 nav-overlay 是否还存在瞬时闪烁。

## 2026-05-31 iPhone 输入键盘复测修正

已完成：

- 复查 iPhone 输入框无法唤起键盘的问题：撤销前一版在 `touchend/click` 捕获阶段主动 `focus()` 的方案，避免 WebKit 在默认输入路径之前抢占焦点。
- Swift 侧仅在 iPhone 将 `WKWebView.scrollView.isScrollEnabled` 恢复为 `true`，保留 WebKit 表单触控和键盘 responder 所需的 scroll view 能力；iPad 仍保持原外层不可滚动行为，继续关闭 bounce、自动 inset 和滚动指示。
- Web 侧保留页面级视口锁定，并改为只在 iPhone `touchstart` 的真实触控开始阶段对输入控件执行轻量聚焦；不影响按钮、地图拖动、双指缩放和底部标签点击。
- 保留 iPhone 小屏输入框字号和控件尺寸，不因键盘修复回退成大号表单。
- 更新 `map.html` 的 CSS / JS 缓存版本。
- 同步更新 README、TODO、AppShell、MapKernel、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 触控回归：点击起飞机场输入框后可唤起键盘，输入 `ZBAA` 后本地搜索结果显示；页面没有整体上移，也没有露出浏览器式底部操作栏。
- iPhone 17 Pro 地图回归：Google terrain / Esri 兜底地形底图可见，`+ / -` 按钮间距正常，点击 `+` 后 nav-overlay 仍保持显示；单指拖动平移可用。

待验证 / 待迁移：

- 真机继续回归软键盘高度、Home Indicator 边距和外接键盘场景。
- 高频快速缩放下继续观察 nav-overlay 是否仍有极短闪烁。

## 2026-05-31 iPhone 底部安全区与缩放按钮圆角

已完成：

- 按截图反馈调整 iPhone 底部三标签：移除向下偏移，并在 Web 工作台 shell 底部加入 `env(safe-area-inset-bottom)` 安全区留白，避免标签贴到 iOS Home Indicator。
- 修复 iPhone 地图 `+` / `-` 缩放按钮圆角：对 Leaflet touch 的 `first-child` / `last-child` 圆角规则增加 iPhone 覆盖，保证每个按钮四角都是独立圆角。
- 更新 `map.html` 的 CSS / JS 缓存版本，避免 WKWebView 使用旧样式。
- 同步更新 README、TODO、AppShell、MapKernel 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 截图确认：底部 `计划 / 机场 / 设置` 标签栏上移并留出 Home Indicator 安全区距离；地图 `+` / `-` 缩放按钮独立显示，四角均为圆角。

## 2026-05-31 导入轨迹 track-match 平滑对齐

已完成：

- 对照 `NavPlanner-web/src/planner_routes.py` 的 `_simplify_flightaware_legs`、`_smooth_flightaware_zigzag_legs` 和轨迹误差辅助函数。
- `PlannerService.matchTrackPointsToAirways(...)` 在基础 airway graph 匹配后继续执行 Web 同形态的轨迹误差约束：单航路替换只有在候选路径仍贴合导入轨迹时才允许发生。
- 新增导入轨迹 zigzag 平滑清理：在短窗口内移除偏离轨迹的 direct 折返段，同时要求新 direct 路径距离更短且轨迹误差增量不超过 Web 默认阈值。
- 增加本地投影距离、polyline 距离、轨迹采样范围和经度包裹辅助函数，用于跨日期变更线附近的轨迹误差计算。
- 同步更新 README、TODO、WebBridge、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- 临时 Swift 探针直连 `PlannerService.trackMatchPayload` 成功：`DODGR` -> `GARNE` 使用 9 个 `V370` 轨迹点返回 `DODGR V370 GARNE`，包含 1 条 `V370` airway leg。

待验证 / 待迁移：

- 继续迁移导入轨迹匹配后的 Procedure 自动挂接。
- 继续补齐 `/api/route/flightaware-match` 在线增强和剩余错误提示细节。

## 2026-05-31 导入轨迹 Procedure 自动挂接对齐

已完成：

- 对照 Web `_match_procedures_for_enroute`、`_select_sid_candidate_for_first_airway`、`_select_star_candidate_for_route_airway`、`_replace_terminal_direct_with_star_airway` 和 STAR trim 相关逻辑。
- `PlannerService.trackMatchPayload(...)` 在 airway 轨迹匹配后会继续选择 SID / STAR / APPROACH，并把 `selected_procedures` / `selected_runways` 返回给 Web 工作台。
- 迁移 SID 接入点延展、STAR 终端 direct 替换、按 STAR endpoint 修剪 enroute legs、相邻 airway leg 对齐和近路线 Procedure 兜底选择。
- 同步更新 README、TODO、WebBridge、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- 临时 Swift 探针验证 waypoint-only 样例：`DODGR -> GARNE` 仍返回 `DODGR V370 GARNE`，`selected_procedures` 为空，未被误挂接。
- 临时 Swift 探针与 Web 参考 `NavDatabase.match_imported_track_route` 对照：`KLAX -> KPSP` 使用同一 `DODGR V370 GARNE` 轨迹，Swift 与 Web 均返回 1 条 `V370` airway leg、SID `GARDY4/RW07B`、Approach `VORB/ALL`、arrival runway `ALL`、departure runway `RW07B`。

待验证 / 待迁移：

- 继续补齐 `/api/route/flightaware-match` 在线增强。
- 继续对齐 track-match 的剩余错误提示细节和更多典型 FlightAware AeroAPI 导入样例。

## 2026-05-31 手动 route payload 细节对齐

已完成：

- 用同一 `NavPlanner/Resources/Database/navdata.sqlite` 对照 Web `NavDatabase.resolve_route(...)` 和 Swift `PlannerService.routeResolvePayload(...)`。
- 修复 Swift 手动 route 解析多生成 final direct leg 的差异：到达机场现在只加入 `points`，不再额外加入 `GARNE -> KPSP` 这类 direct leg。
- 修复 `***` 补航段显示文本差异：`DODGR *** GARNE` 现在和 Web 一样显示为展开后的 `DODGR V370 GARNE`。
- 同步更新 README、TODO、WebBridge、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- 临时 Swift 探针与 Web 参考对照成功：
  - `KLAX -> KPSP / DODGR V370 GARNE`：两端均返回 fix `DODGR` + airway `DODGR V370 GARNE`，`point_count=11`。
  - `KLAX -> KPSP / DODGR DCT GARNE`：两端均返回 fix `DODGR` + direct `DODGR -> GARNE`，`point_count=4`。
  - `KLAX -> KPSP / DODGR *** GARNE`：两端均返回 fix `DODGR` + airway `DODGR V370 GARNE`，`route_display=DODGR V370 GARNE`。
  - `DODGR -> GARNE` 空 Route：两端均返回自动 `DODGR V370 GARNE`，`point_count=9`。

待验证 / 待迁移：

- 继续用更长 mixed-route、跨日期变更线和不同区域的典型航线对照 Web `resolve_route`。
- 继续收敛自动规划权重细节。

## 2026-05-31 设置页地图管理与性能优化

已完成：

- 将航路输入占位示例从 `RKZ *** P245` 改为 `KTM *** LXA`。
- 将离线地图管理入口从地图右下角控件迁移到 Settings：设置页显示活动离线资源、资源数量和下载状态，并提供“管理 / 下载地图 / 刷新状态”入口。
- 在 Settings 增加“地图缓存”卡片，显示在线增强底图缓存大小、文件数、后台请求数和失败冷却数。
- Swift `OnlineTileCache` 增加 `/api/map-cache/status` 和 `/api/map-cache/clear`，可统计并清理 Caches/NavPlanner/MapCache，不影响离线地图包、导航数据库和 nav-overlay。
- 清理在线缓存后前端刷新 terrain 瓦片 URL 版本，避免继续显示旧缓存。
- 优化矢量底图同步：拖动期间继续使用 CSS 平移镜像，缩放期间新增 CSS scale 镜像，结束后再同步 MapLibre 真实相机，减少 vector 底图与 Leaflet 航路层动画不同步。
- nav-overlay 在地图仍处于移动/缩放动画时延后刷新，避免缩放过程中重绘造成掉帧或短闪。
- 移动/缩放时给导航层和标签层增加合成提示，并临时简化标签 text-shadow，降低动画帧绘制压力。
- 同步更新 README、TODO、Settings、MapKernel、OfflineMaps、WebBridge 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- iPhone 17 Pro 截图确认：Plan 占位示例已变为 `KTM *** LXA`，Settings 显示“离线地图”和“地图缓存”卡片，地图缓存显示大小与文件数。
- iPhone 17 Pro 交互回归：从 Settings 点击“管理”可打开离线地图管理弹窗；单指拖动地图和点击 `+` 缩放后 nav-overlay 仍保持显示。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功。
- iPad 截图确认：既有工作台布局保持，详情区域可切到 Settings，新增设置内容进入右侧详情区而未套用 iPhone 底部三标签。

待验证：

- 真机继续观察快速连续缩放和高密度矢量底图下的帧率；必要时再用 Instruments / ETTrace 做采样。

## 2026-05-31 离线地图下载器并发对齐

已完成：

- 对照 `NavPlanner-web/src/planner_maps.py` 的 `OfflineMapManager.start_download`、`_download_worker` 和 `fetch_tile_job`，继续收敛 iOS Swift 本地 `MapStore` 下载器。
- 将 Swift 下载器从串行下载升级为 Web 同形态有界并发：`download_workers=12`，`inflight_limit=24`，后台 `OperationQueue` 负责网络请求，主下载线程串行写入 SQLite。
- 启动下载前增加 provider 探测；探测失败时返回中文失败任务，不创建持续失败的后台下载。
- 代理字段按 Web 逻辑规范化：`DIRECT` / `NONE` / `NO_PROXY` / `直连` 表示直连，`host:port` 自动补 `http://`，HTTP/HTTPS 代理写入 `URLSessionConfiguration.connectionProxyDictionary`。
- 下载状态补齐 `active_downloads`、在途任务、KB/s / MB/s 速度文案和慢请求等待提示。
- 连续失败阈值按 Web 版 worker 因子计算；失败过多时提示检查代理、换用 Esri 或缩小范围。
- 下载时跳过已存在 SQLite 瓦片；同名资源目录中的 Web 新版 / 旧版散瓦片会迁移写入 `tiles.sqlite`。
- SQLite 写入批次从小批量改为 250 瓦片提交，降低大范围下载的磁盘同步压力。
- 同步更新 README、TODO、OfflineMaps、WebBridge、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 首次构建发现 iOS SDK 不允许直接使用 macOS 风格 CFNetwork HTTPS 代理常量；已改为 `connectionProxyDictionary` 字符串 key。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。

待验证：

- 用真实大范围离线地图任务继续做真机 / 模拟器压力回归，重点观察取消响应、代理网络、慢请求提示和 SQLite 写入性能。

## 2026-05-31 iPad 竖向折叠栏按钮主题配色

已完成：

- 根据用户二次截图确认目标是 iPad 左右两侧竖向折叠栏按钮，而不是详情区域 `机场 / 设置` 分段按钮。
- 将误加的 iPad 详情分段按钮专用主题记录收回，保持详情切换原有工作台样式。
- 在 `NavPlanner/Resources/Web/styles.css` 中为 `.layout-rail-button` 增加日间主题专用样式：浅蓝灰玻璃背景、低强度蓝色高光、深蓝灰文字和轻量阴影，避免日间模式下出现深蓝长条。
- 保留夜间折叠栏的深色玻璃风格，并让 hover 状态继续使用夜间蓝色高光。
- 将左右折叠栏按钮的 `aria-label` / `title` 和点击后状态文案从英文改为中文：`展开左侧面板`、`恢复左侧面板`、`展开地图`、`恢复地图布局`。
- 更新 `map.html` 的 `styles.css` / `app.js` 缓存版本，避免 WKWebView 继续使用旧样式。
- 同步更新 README、TODO、AppShell 和本执行记录。
- 未修改 `NavPlanner-web/`。

待验证：

- 夜间主题下左右竖向折叠栏与工作台主题一致性继续在后续截图回归中确认。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功。
- iPad Pro 13-inch (M5) 截图确认：日间主题下左右竖向折叠栏已从深蓝长条变为浅蓝灰主题配色，和面板、地图边缘更一致。

## 2026-05-31 Route Resolve 连续 airway 合并

已完成：

- 继续以 `NavPlanner-web/src/planner_routes.py` 为只读参考，对照 Web `_compress_auto_legs`、`_merge_continuing_airway_legs` 和 `_airway_can_continue_through`。
- 在 Swift `AirwayGraph` 中增加 `nodesByIdent` 索引，供航路压缩和精确 graph node 查找复用，减少按 ident 扫描全图的开销。
- 将自动航路压缩从单纯 `mergeRepeatedAirwayLegs` 扩展为 `mergeContinuingAirwayLegs` 后再合并重复 airway：当前一 airway 可以按有向 graph 从原入口合法延伸到当前 leg 出口，并且距离不超过原两段总距离的 `1.02 + 1nm` 容差时，沿用前一 airway 合并显示。
- 更新 README、TODO、WebParity，并新增 `Docs/RouteResolve.md` 记录航路解析子功能的当前实现、限制和验证重点。
- 未修改 `NavPlanner-web/`。

待验证：

- 用更多典型自动航线继续对照 Web `resolve_route` payload，重点观察 mixed-route 权重、excluded airway 和跨日期变更线输出。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- 临时 Swift 探针直连 `PlannerService.routeResolvePayload` 成功：`DODGR -> GARNE` 留空 Route 和 `DODGR *** GARNE` 均返回 `DODGR V370 GARNE`，包含 1 条 `V370` airway leg、9 个点。

## 2026-05-31 Route Resolve 重复 airway 与显示文本对齐

已完成：

- 继续对照 `NavPlanner-web/src/planner_routes.py` 的 `_merge_repeated_airway_legs`、`_display_route_from_legs` 和 `_display_route_from_expanded_legs`。
- 将 Swift `mergeRepeatedAirwayLegs` 从“只合并相邻同 airway”改为 Web 同形态的 while/lookahead 逻辑：
  - 保留非 airway leg，不再在重复合并阶段误丢 fix / sid / star 等非 airway leg。
  - 合并相邻同 airway。
  - 处理 A-B-A 这种隔一条 airway 后回到同 airway 的显示压缩。
- 将 Swift `routeDisplayFromLegs` 调整为普通显示规则：忽略非 airway / direct leg，并在遇到第一条可显示 leg 时补入 entry。
- 将 Swift `routeDisplayFromExpandedLegs` 拆出为展开显示规则：继续保留手动 route 中的 fix，贴近 Web 手动航路展开行为。
- 更新 README、TODO、WebParity、RouteResolve 和本执行记录。
- 未修改 `NavPlanner-web/`。

待验证：

- 用长 mixed-route 与包含 Procedure leg 的自动 route 对照 Web 输出，确认普通 `route_display` 起点、重复 airway 压缩和选中航段列表一致。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- 临时 Swift 探针直连 `PlannerService.routeResolvePayload` 成功：`DODGR -> GARNE` 空 Route、`DODGR V370 GARNE`、`DODGR DCT GARNE`、`DODGR *** GARNE` 的显示文本均符合预期，其中 `***` 继续展开为 `DODGR V370 GARNE`。

## 2026-05-31 Route Resolve excluded airway 通路

已完成：

- 继续对照 `NavPlanner-web/src/planner_routes.py` 的 `_ifrr_route_between_with_exclusions` 和 `_prefer_single_airway_route(..., excluded_airways=...)`。
- Swift `ifrrRouteBetween(..., database:)` 新增 `excludedAirways` 默认参数，默认空集合保持现有调用和缓存行为。
- 非空 excluded airway 会被标准化为大写集合，只复用当前数据库的 airway graph，不读取或写入默认 route-between cache，避免污染普通自动航路结果。
- Swift Dijkstra edge 扩展已跳过 `excludedAirways` 中的 airway。
- Swift 同航路优先候选已跳过 `excludedAirways` 中的 airway。
- 更新 README、TODO、WebParity、RouteResolve 和本执行记录。
- 未修改 `NavPlanner-web/`。

待验证：

- 后续如果 Web 参考项目把 excluded airway 用到公共 API 或绕行策略，应补一组直接对照探针；当前公共 `/api/route/resolve` 仍以空排除集调用。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- 临时 Swift 探针直连 `PlannerService.routeResolvePayload` 成功：默认空排除集下 `DODGR -> GARNE` 空 Route 和 `DODGR *** GARNE` 仍返回 `DODGR V370 GARNE`，均为 1 条 leg、9 个点。

## 2026-05-31 Route Resolve 查找优先级对齐

已完成：

- 对照 Web `lookup_departure_arrival_point` 与 `lookup_point`，确认 Web 起降点和普通 route token 使用不同解析优先级。
- Swift `routeResolvePayload` 和 `trackMatchPayload` 的起飞 / 到达参数改为 `lookupDepartureArrivalPoint`：先按机场 ICAO / IATA 解析，失败后按普通点解析。
- Swift 手动 route 的普通 token、`DCT` 目标、`***` source fallback、airway boundary fallback 和 direct leg endpoint fallback 改为 `lookupPoint`：依次查机场 ICAO、enroute waypoint、terminal waypoint、VOR、NDB，最后才用机场 IATA 兜底。
- `lookupPoint` 中 terminal waypoint 的 `kind` 改为 Web 同形态的 `waypoint`。
- 更新 README、TODO、WebParity、RouteResolve 和本执行记录。
- 未修改 `NavPlanner-web/`。

待验证：

- 用真实 IATA / waypoint 冲突样例（如 `FRE`）对照 Web 与 Swift 的手动 route token 解析。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- Swift 与 Web 参考对照成功：真实冲突 token `FRE` 在手动 route `DODGR DCT FRE` 中解析为 enroute waypoint `FRE (-32.058333, 115.741667)`，而起飞输入 `FRE` 解析为 IATA 对应机场 `AGGF`，与 Web `lookup_point` / `lookup_departure_arrival_point` 一致。

## 2026-05-31 iPad 竖向折叠按钮主题同步复修

已完成：

- 根据用户截图再次确认目标是 iPad 地图左右两侧的竖向折叠手柄。
- 将 `.layout-rail-button` 的背景、描边、文字和 hover 阴影改为 CSS 主题变量驱动，日间主题使用浅蓝灰玻璃配色，夜间主题保留深色玻璃配色。
- 为 `html[data-theme-mode="day"]` 和系统浅色模式增加兜底变量，避免 `system` 或初始化阶段漏用日间 rail 配色。
- 在 `map.html` 头部、样式表加载前读取 `localStorage.navplannerThemeMode` 并写入 `data-theme-mode` / `data-theme`，减少 WKWebView 首屏深蓝闪烁和旧主题残留。
- 更新 `map.html` 的 CSS / JS 缓存版本。
- 同步更新 README、TODO、AppShell、Settings 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功。
- iPad Pro 13-inch (M5) 截图确认：日间主题下用户标出的竖向折叠按钮已随主题变为浅蓝灰玻璃色，不再显示深蓝长条。

## 2026-05-31 Route Resolve 自动航线典型样例对齐

已完成：

- 按完整复刻目标继续用 `NavPlanner-web/` 只读参考建立临时 Swift/Web 自动空 Route 对照探针。
- 发现 Swift 在 `ZBAA->ZSPD`、`OMDB->EDDF`、`VHHH->WSSS` 等航线中偏向 direct 或选到不同 airway / Procedure，根因包括：
  - Swift airway graph 和 airway expand 额外按 `area_code/icao_code/route_type` 分组，切断 Web 版可连续搜索的同名 airway。
  - Swift Dijkstra heap 只按 cost 排序，未模拟 Python `heapq` 对 `(cost, node_key)` 的 key tie-break。
  - Procedure 候选使用 `Dictionary(grouping:)` 后丢失 Web SQL 顺序，等分候选可能选到不同 STAR。
  - `navString(NSNull)` 会变成 `"<NULL>"`，导致空 transition 不再等价于 Web 的 `ALL`。
  - Approach 排序用 `|` 拼接字符串模拟 tuple，在 `I05R` / `I05RE` 这种前缀关系下会反转 Web 的字典序。
- Swift `buildAirwayGraphUncached` 改为按 Web 的 `route_identifier, seqno` 顺序和 `route_identifier` 分组，再交给 `partitionAirwayRows` 分块。
- Swift `expandAirway` 改为读取整条 airway 并按 Web 顺序选择第一个同时包含 entry / exit 的 chunk。
- Swift `RouteHeap`、nearest/exact graph candidate 排序增加 node key tie-break。
- Swift Procedure 候选改为保留 SQL 顺序的有序分组，SID / STAR shortlist 排序增加 procedure / transition tie-break。
- `navString` 对 `NSNull` 返回空字符串；Procedure transition 重新统一为 `ALL`。
- Approach 和 Procedure 距离排序键改用不会破坏前缀字典序的分隔符，修复 `I05R` 被 `I05RE` 压过的问题。
- 同步更新 README、TODO、RouteResolve、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- 临时 Web 探针和 Swift 探针对照成功：`ZBAA->ZSPD`、`KLAX->KPSP`、`RJTT->PHNL`、`EGLL->KJFK`、`YSSY->NZAA`、`VHHH->WSSS`、`OMDB->EDDF`、`AGGF->AYKM` 的 `route_display`、legs 摘要、点数、距离、SID / STAR / Approach 和 runway 选择均无差异。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。

## 2026-06-01 RouteParity 回归工具

已完成：

- 新增 `Tools/RouteParity/route_parity.py`，把 Web 参考 `NavDatabase.resolve_route(...)` 与 Swift `PlannerService.routeResolvePayload(...)` 做字段级对照。
- 新增 `Tools/RouteParity/RouteParityProbe.swift`，编译为临时 CLI 后直接调用 Swift 本地服务层，不依赖 Web 或 Python server。
- 新增 `Tools/RouteParity/README.md` 与 `Docs/RouteParity.md`，记录用法、覆盖范围和限制。
- 当前工具覆盖 16 个 case：
  - 8 条典型自动航线。
  - `DODGR V370 GARNE`、`DODGR DCT GARNE`、`DODGR *** GARNE`。
  - `DODGR DCT FRE` 查找优先级。
  - 起始 `DCT`、缺少 `DCT` 目标、airway 缺 exit、`***` 缺目标。
- 工具首跑发现 Swift 手动 route payload 比 Web 多返回 `selected_runways`；已按 Web 原始 payload 形态移除手动 route 的 `selected_runways` / `selected_procedures` / `message` 额外字段。前端仍会在 `buildRoute` 中按当前跑道状态补齐运行时默认值。
- 同步更新 README、TODO、RouteResolve、RouteParity、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `python3 Tools/RouteParity/route_parity.py` 成功，16 个 case 无差异。

## 2026-06-01 iPad 竖向折叠栏日间主题兜底

已完成：

- 根据用户截图确认目标仍是 iPad 地图左右两侧的竖向折叠手柄，而不是详情区域普通按钮。
- 将日间主题下 rail 变量进一步调浅：使用更接近日间面板的白蓝灰玻璃背景、低强度蓝色高光、深蓝灰图标和轻量阴影。
- 为 `html[data-theme="day"]`、`html[data-theme-mode="day"]` 和系统浅色模式增加 `.layout-rail-button` 显式覆盖规则，避免初始化或系统自动路径漏回夜间深蓝配色。
- 更新 `map.html` 的 CSS / JS 缓存版本为 `20260601-rail-sync3`，降低 WKWebView 继续复用旧样式的概率。
- 同步更新 README、TODO、AppShell、Settings 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `python3 Tools/RouteParity/route_parity.py` 成功，16 个 case 无差异。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。

待验证：

- 当前没有已启动的模拟器，未自动启动新模拟器做截图；下一次 iPad 运行时回归需在日间 / 夜间 / 系统自动三种模式下确认左右折叠手柄颜色。

## 2026-06-01 RouteParity 跨日期变更线扩展

已完成：

- 按完整复刻目标继续扩展 `/api/route/resolve` 的 Swift/Web 对照覆盖，不修改 `NavPlanner-web/`。
- 在 `Tools/RouteParity/route_parity.py` 增加 6 个跨日期变更线样例：
  - 自动航线 `NFFN->NSTU`、`NSTU->NFFN`，覆盖南太平洋 `G224` 横跨 180 经线。
  - 自动航线 `PHNL->PGUM`，覆盖长距离 Pacific mixed route。
  - 自动航线 `NFFN->NSFA`，覆盖跨日期线并带 SID / STAR 的规划。
  - 手动航路 `NN G224 TUT`、`TUT G224 NN`，覆盖正反向 airway 展开。
- RouteParity 摘要新增 `point_signature`，比较每个点的 ident、kind、lat、lon，避免只看 `route_display` 和点数时漏掉几何差异。
- RouteParity 摘要新增 `geometry`，记录 raw 经度跳变次数、最大 raw 经度差、unwrap 后最大经度差和 unwrap 后经度跨度，用于持续监控日期变更线点列。
- Swift `RouteParityProbe.swift` 增加与 Python 端一致的点列签名和几何摘要函数。
- 同步更新 README、TODO、RouteResolve、RouteParity、WebParity、Tools/RouteParity README 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `python3 Tools/RouteParity/route_parity.py` 成功，22 个 case 无差异。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。

待验证：

- 当前 RouteParity 已覆盖 payload 几何；前端地图 polyline、多世界副本 hit layer 和弹窗点击仍需在模拟器 / 真机运行时继续截图与手势回归。

## 2026-06-01 Settings 按钮布局与 iPhone 输入框单击聚焦

已完成：

- 将 Settings 的“地图缓存”统一改为“在线地图缓存”，按钮下排改为左侧“清理缓存”、右侧“刷新缓存”。
- 将 Settings 的离线地图卡片改为下排双按钮：左侧“管理离线地图”、右侧“刷新状态”；移除 Settings 页面单独的“下载地图”按钮，下载入口保留在离线地图管理页内部。
- 将离线地图管理页标题、标签和日间主题样式继续向主界面收敛，日间使用浅蓝灰玻璃面板，夜间保持深色玻璃风格。
- 清理已删除 DOM 对应的 `downloadOfflineMapsButton` JS 引用。
- 针对 iPhone 输入框单击后键盘闪现又关闭的问题，移除输入框 `touchstart` 聚焦桥，只保留原生单击聚焦路径和 click 用户手势阶段的 `focus({ preventScroll: true })` 兜底；底部当前标签重复点击也不会再 blur 当前输入框。
- 刷新 Web 资源版本为 `20260601-settings-keyboard2`，降低真机继续加载旧脚本的概率。
- 同步更新 README、TODO、AppShell、Settings、OfflineMaps、MapKernel、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `python3 Tools/RouteParity/route_parity.py` 成功，22 个 case 无差异。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。

待验证：

- 当前所有模拟器均为 Shutdown，本轮未擅自启动新模拟器；iPhone 单击起飞机场输入框唤起键盘、Settings 按钮布局和离线地图管理页主题仍需在已启动模拟器或真机上做运行时回归。

## 2026-06-01 离线地图弹窗与 iPhone 键盘可见性

已完成：

- 离线地图管理弹窗背景改为透明偏暗蒙层，日间主题也使用暗色透明 backdrop，窗口保持居中。
- iPhone 离线地图管理页限制为更小的居中窗口，压缩标题、说明、标签、按钮、资源卡片、下载表单和范围选择控件尺寸，内容在弹窗内部滚动。
- iPhone 输入框键盘唤起后，通过 `visualViewport` 计算键盘覆盖高度，设置 `--mobile-keyboard-lift` 平滑抬升当前下部工作区和底部标签。
- 键盘打开期间会把当前输入框滚动到可见区域；键盘收起或焦点离开后自动恢复原布局。
- 刷新 Web 资源版本为 `20260601-offline-keyboard-lift`，避免真机继续使用旧 CSS / JS。
- 同步更新 README、TODO、AppShell、Settings、OfflineMaps 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/RouteParity/route_parity.py` 成功，22 个 case 无差异。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；仍有 CoreSimulatorService 沙盒日志噪声，但最终 `BUILD SUCCEEDED`。

待验证：

- 仍需在真机或已启动的 iPhone 模拟器上确认软键盘动画与系统键盘完全同步、输入框不被遮挡、离线地图弹窗尺寸符合截图预期。

## 2026-06-01 iPhone 键盘可见高度布局修正

已完成：

- 根据用户真机截图确认上一版 `transform` 抬升策略会把输入面板推出可见区域，只留下地图和悬在键盘上方的底部 Tab。
- 改为键盘态专用布局：键盘打开时根据 `visualViewport.height` 设置 `--mobile-visual-height`，将 `.shell` 高度压到键盘上方可见区域。
- 键盘态临时隐藏底部 `计划 / 机场 / 设置` Tab，把可见高度留给地图和当前输入面板；输入面板保留在键盘上方。
- 保留当前输入框滚入面板可见区域的逻辑，并在 shell 高度变化后补 `map.invalidateSize`，减少地图控件错位。
- Web 资源版本刷新为 `20260601-keyboard-visible-layout`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/RouteParity/route_parity.py` 成功，22 个 case 无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功。
- 关闭模拟器硬件键盘偏好并重启 iPhone 17 Pro 模拟器后，点击起飞机场输入框可显示系统软键盘；截图确认底部 Tab 隐藏，Plan 输入面板保留在键盘上方，未复现用户截图中的“只剩地图和悬浮 Tab”问题。
- 在软键盘场景输入 `ZBAA` 后，本地搜索结果出现在输入框下方且没有被键盘遮挡；点击地图或键盘/附件栏对勾后键盘布局退出，底部 `计划 / 机场 / 设置` Tab 恢复。

待验证：

- 真机键盘高度、中文输入法候选栏和系统“对勾”收起行为仍需用户侧复测；如果真机仍有遮挡，将继续按真实截图迭代。

## 2026-06-01 iPhone 输入框软键盘二次修正

已完成：

- 复测发现单纯关闭 WKWebView 外层 `scrollView.isScrollEnabled` 会让模拟器输入框获得焦点但软件键盘不稳定，只剩输入辅助条，因此改为保留 iPhone WKWebView 外层 scroll view 的输入触控能力。
- 在 `MapWebView.Coordinator` 增加 `UIScrollViewDelegate`，将外层 `contentOffset`、`contentInset` 和滚动指示 inset 锁回 0，避免 UIKit 键盘自动滚动和 Web 工作台键盘布局互相拉扯。
- Web 键盘态继续使用 `visualViewport.height` 设置 `--mobile-visual-height`，并把键盘态输入面板比例提高到 66%，给底部航路 textarea 留出稳定可见空间。
- 输入框 `focusin` 后在键盘动画过程中多次重新计算布局，避免键盘高度、候选栏或输入法动画未稳定时只校正一次。
- 更新 `map.html` 的 CSS / JS 缓存版本为 `20260601-keyboard-native-scroll-lock`。
- 同步更新 README、TODO、AppShell 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/RouteParity/route_parity.py` 成功，22 个 case 无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，构建无 warning / error。
- iPhone 17 Pro 模拟器关闭硬件键盘后，用 Simulator Cmd-K 显示软件键盘：点击起飞机场输入框时，键盘打开，底部 Tab 隐藏，输入框和下方表单保持在键盘上方。
- 在同一软键盘场景点击底部航路 textarea，面板自动滚动到 textarea，textarea 完整位于键盘上方。
- 点击键盘 / 附件栏对勾后，页面恢复正常地图 + 输入区 + 底部 Tab 布局。
- 回归地图触控：单指拖动地图和点击 `+` 缩放按钮可用，未观察到页面整体滚动。

待验证：

- 真机中文输入法候选栏、第三方键盘高度和外接键盘模式仍需用户侧继续回归；如果真机仍有遮挡，以真机截图继续细调。

## 2026-06-01 离线地图管理中文化二次清理

已完成：

- 清理离线地图管理页可见英文残留：资源类型 `vector/raster/resource` 改为“矢量 / 栅格 / 资源”。
- 清理离线地图供应商说明：供应商类型和格式改为中文显示，例如“矢量 · PBF 矢量瓦片 · 最高 z14”。
- 清理离线地图下载表单：范围字段从 `West / South / East / North` 改为“西界 / 南界 / 东界 / 北界”，范围小地图辅助标签改为中文。
- 清理下载任务进度：进度条 aria label 改为“下载进度”，默认任务名改为“离线地图资源”。
- 清理离线地形状态提示：`Offline Terrain` 和 `Terrain` 改为“离线地形”和“地形图”。
- Swift `MapStore` 的离线下载状态说明将 `SQLite tile store` 改为“SQLite 瓦片库”，OpenFreeMap Vector 描述中的 `Offline Terrain` 改为“离线地形”。
- 刷新 Web 资源版本为 `20260601-offline-map-chinese`，避免 App 继续使用旧 `app.js`。
- 同步更新 README、TODO、Settings、OfflineMaps、MapKernel、WebParity、WebBridge 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。

待验证：

- 仍需在模拟器打开 Settings -> 管理离线地图，截图确认下载标签和资源卡片在日间 / 夜间主题下均无英文残留或截断。
- 继续清理在线网络错误、底层服务错误和控制台可见状态中的英文文案。

## 2026-06-01 TrackParity 回归工具

已完成：

- 新增 `Tools/TrackParity/track_parity.py`，把 Web 参考 `NavDatabase.match_imported_track_route(...)` 与 Swift `PlannerService.trackMatchPayload(...)` 做字段级对照。
- 新增 `Tools/TrackParity/TrackParityProbe.swift`，编译为临时 CLI 后直接调用 Swift 本地服务层，不依赖 Web 或 Python server。
- TrackParity 使用 Web 参考 `resolve_route(...)` 生成离线合成轨迹点，避免依赖 FlightAware AeroAPI 或外网，同时保证 Web / Swift 使用同一组导入轨迹。
- 当前 7 个 case 覆盖：
  - `KLAX->KPSP` 的 `DODGR V370 GARNE` 和 `DODGR *** GARNE` 合成轨迹；
  - `ZBAA->ZSPD`、`VHHH->WSSS` 自动航线合成轨迹；
  - 跨日期变更线 `NFFN->NSTU` 合成轨迹；
  - 导入轨迹点不足、出发机场无法解析两个错误语义。
- 摘要对比字段包括 route display、legs、点数、点列签名、日期变更线几何摘要、距离、SID / STAR / Approach、runway、source provider 和导入轨迹点数量。
- 新增 `Tools/TrackParity/README.md` 与 `Docs/TrackParity.md`，记录用法、覆盖范围和限制。
- 同步更新 README、TODO、WebParity、WebBridge 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `python3 Tools/TrackParity/track_parity.py` 成功，7 个 case 无差异。
- `python3 Tools/RouteParity/route_parity.py` 成功，22 个 case 无差异。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_sim` 在 iPhone 17 Pro 模拟器目标成功，构建无 warning / error。

待验证：

- TrackParity 仍需扩展真实 FlightAware AeroAPI 轨迹样例，覆盖噪声、稀疏点、折返和缺点。
- `/api/route/flightaware-match` 当时在线增强仍未迁移；当前已改为 FlightAware AeroAPI 在线增强入口。

## 2026-06-01 ParityChecks 工程校验目标

已完成：

- 新增 `Tools/Parity/run_all_parity.py`，统一顺序运行 RouteParity 和 TrackParity，并以 JSON 输出每个子检查的状态、耗时和 stdout / stderr。
- 新增 `Tools/Parity/README.md`，记录命令行和 Xcode 运行方式。
- 在 `NavPlanner.xcodeproj` 中新增 `ParityChecks` Aggregate Target，Run Script build phase 调用 `python3 "$SRCROOT/Tools/Parity/run_all_parity.py"`。
- 新增共享 scheme `NavPlanner.xcodeproj/xcshareddata/xcschemes/ParityChecks.xcscheme`，可在 Xcode 中直接选择 `ParityChecks` 后 Build，也可通过 `xcodebuild -scheme ParityChecks build` 执行。
- 同步更新 README、TODO、RouteParity、TrackParity、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `xcodebuild -project NavPlanner.xcodeproj -list` 成功，输出包含 targets `NavPlanner` / `ParityChecks` 和 schemes `NavPlanner` / `ParityChecks`。
- `python3 Tools/Parity/run_all_parity.py` 成功，RouteParity 22 个 case 无差异，TrackParity 7 个 case 无差异。
- `xcodebuild -project NavPlanner.xcodeproj -scheme ParityChecks -configuration Debug -derivedDataPath /private/tmp/NavPlannerParityDerived build` 成功；Run Script 中 RouteParity / TrackParity 均 passed。
- XcodeBuildMCP `build_sim` 在 iPhone 17 Pro 模拟器目标成功，主 App 构建无 warning / error。

待验证：

- 后续可把更多前端截图/手势回归、nav-overlay dateline 视觉回归和真实导入轨迹样例继续接入 `ParityChecks` 或拆分出更细的校验 target。

## 2026-06-01 ProcedureParity 回归工具

已完成：

- 新增 `Tools/ProcedureParity/procedure_parity.py`，把 Web 参考 `NavDatabase.procedure_geometry(...)` 与 Swift `PlannerService.procedurePayload(...)` 做字段级对照。
- 新增 `Tools/ProcedureParity/ProcedureParityProbe.swift`，编译为临时 CLI 后直接调用 Swift 本地服务层，不依赖 Web 或 Python server。
- 当前 ProcedureParity 后续已扩展为 6 个 case，覆盖 SID / STAR RF 弧线、Approach 复飞和末端 holding、transition + runway 段合并、ZULS 复飞异常圆弧回归，以及空结果语义。
- 摘要对比字段包括 Procedure 明细项签名、完整 path、primary path、missed path 的点数和坐标签名。
- `Tools/Parity/run_all_parity.py` 与 Xcode `ParityChecks` Aggregate Target 已纳入 ProcedureParity。
- 新增 `Tools/ProcedureParity/README.md` 与 `Docs/ProcedureParity.md`，并同步更新 README、TODO、WebParity、Procedures 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `python3 Tools/ProcedureParity/procedure_parity.py` 成功，当前 6 个 case 无差异。
- `python3 Tools/Parity/run_all_parity.py` 成功，RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- `xcodebuild -project NavPlanner.xcodeproj -scheme ParityChecks -configuration Debug -derivedDataPath /private/tmp/NavPlannerParityDerived build` 成功；Run Script 中三组 parity 均 passed。

待验证：

- ProcedureParity 仍需扩展更多真实机场、复杂 leg 类型和前端 Procedure chip / 地图点击视觉回归。

## 2026-06-01 iPhone 键盘紧凑输入修正

已完成：

- 修复 iPhone Plan 输入框使用 16px 防 WebKit 自动缩放后视觉字号过大的回归。
- 将 Plan 搜索输入框和航路 textarea 的实际 CSS 字号保持为 16px，同时用缩放把视觉尺寸压回约 10.5px，继续保持小屏紧凑密度。
- 航路 textarea 增加独立 wrapper，确保缩放后可点击区域、搜索结果定位和面板高度稳定。
- 键盘态焦点可见性校正同时参考输入面板边界和 `visualViewport` 真实可见边界，避免键盘候选栏或系统动画未稳定时遮挡输入框。
- 键盘开合时 `.shell` 高度、最大高度、行高和 padding 使用一致的平滑过渡。
- Web 资源版本刷新为 `20260601-keyboard-compact-inputs`。
- 同步更新 README、TODO、AppShell 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，构建无 warning / error。

## 2026-06-03 iPhone 横屏刘海侧反向留白修正

已完成：

- 根据横屏截图反馈，修正 `screen.orientation.angle` / `window.orientation` 中 90° 与 270° 对应的刘海侧映射，避免把大留白放到刘海对侧。
- CSS 横屏安全区改为取左右 `safe-area-inset` 的较大值，再按 `data-landscape-notch-side` 应用到刘海侧，避免 WebKit 横屏 inset 方向差异导致再次反向。
- 撤销上一版“非刘海侧内容 22px 内收”的处理，保持非刘海 / 灵动岛对侧横向边距不变。
- 按用户在 Web Inspector 中手动验证出的效果，直接修改非刘海侧白色边栏本体圆角：刘海在右侧时左侧计划栏使用 `border-top-left-radius: 50px !important` 和 `border-bottom-left-radius: 50px !important`；刘海在左侧时右侧详情栏使用对应的右上 / 右下 50px 圆角。
- 刘海在右侧时，仅将左侧计划栏首个 `计划` 标题向右偏移 20px，将第一段内的字段标签、说明文字和 `Database loaded...` 状态提示向右偏移 9px；刘海在左侧时，右侧顶部标签组和右侧卡片/占位提示做对应避让。
- iPhone 横屏 shell 上下 padding 改为精确 8px，面板内侧 padding 恢复为 6px，减少上下留白并保持对称。
- Web 资源版本刷新为 `20260603-phone-landscape-panel-corner-50px`。
- 同步更新 TODO、AppShell 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `node -e ... styles.css` 简单括号平衡检查成功，CSS 大括号配对正常。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，构建无 warning / error。
- XcodeBuildMCP 已获取 iPhone 17 Pro 横屏截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_ed0ff435-253b-40a0-b5bb-3a6fddd1c8da.jpg`；截图确认右侧刘海避让在正确侧，非刘海侧横向空间未被硬内收，字段标签、说明文字和状态提示已右移避让。
- `xcrun simctl io ... screenshot --mask black` 已获取圆角遮罩截图：`/private/tmp/navplanner-landscape-panel-50px-mask-rotated.png`；旋正后确认左侧黑色圆角、8px 浅蓝背景间隔和 50px 白色计划边栏圆角形成三层关系，顶部“计划”标题已向右避让并完整显示。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-01 iPad 弹窗与 iPhone 输入字号二次微调

已完成：

- 根据截图反馈继续压缩 iPhone Plan 搜索输入框和航路 textarea 的视觉字号：实际 CSS 字号仍保持 16px，避免 WebKit 聚焦自动放大；视觉缩放调整到约 9.5px。
- 同步压缩 iPhone 输入 wrapper 高度，让搜索框和航路框在小屏下更接近当前底部工作区密度。
- 将 iPad 地图弹窗同步为 iPhone 弹窗视觉体系：更紧凑宽度、半透明毛玻璃背景、内嵌圆角标题块、圆角关闭按钮和更小的标题 / 正文字号。
- 非机场航路弹窗仍不显示“设为起飞 / 到达 / 手动”等机场专用按钮；机场弹窗继续保留机场操作按钮。
- Web 资源版本刷新为 `20260601-ipad-popup-compact-inputs`。
- 同步更新 README、TODO、MapKernel、AppShell 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，构建无 warning / error；截图确认 Plan 输入框和航路 textarea 视觉字号已进一步缩小。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功，构建无 warning / error；点击航路弹窗后截图确认 iPad 已使用紧凑半透明毛玻璃弹窗、内嵌圆角标题和圆角关闭按钮，航路弹窗未显示机场专用操作按钮。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-01 App 图标、Airport 紧凑控件与离线地图代理移除

已完成：

- 设计并接入默认、日间、夜间三套蓝-青渐变 Liquid Glass App 图标；图标包含渐变背景、半透明玻璃面板、航路弧线和简化飞机符号，不包含其他飞行模拟器品牌元素。
- 新增 `Tools/Icon/generate_app_icons.swift`，可重复生成 `AppIcon`、`AppIconDay`、`AppIconNight` 的 iPhone / iPad / marketing 尺寸，以及 Settings 页三张预览图。
- 配置 Xcode asset catalog 替代图标名称，Settings 页面新增“应用图标”卡片，可选择默认 / 日间 / 夜间图标。
- 新增 JS bridge `setAppIcon`，由 Swift 调用 `UIApplication.shared.setAlternateIconName(...)`，切换结果回调给 `window.navplannerNativeAppIconChanged(payload)`。
- 压缩 iPhone Airport 页面机场槽位、跑道筛选、机场标题框的字体、padding 和高度，降低 `ZBAA`、`RW01` 等控件在下部工作区的垂直占用。
- 按最新需求取消离线地图下载代理服务器设置：Web 下载表单删除代理输入项，Swift `OfflineDownloadRequest` 删除 `proxyURL`，`MapStore` 下载会话使用系统直连默认配置。
- 同步更新 README、TODO、Settings、OfflineMaps、WebBridge、WebParity、AppShell，并新增 `Docs/AppIcon.md`。
- 未修改 `NavPlanner-web/`。

验证记录：

- `swift Tools/Icon/generate_app_icons.swift` 成功。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，构建无 warning / error。
- iPhone 17 Pro 模拟器中 Settings 的默认 / 日间 / 夜间图标选择可触发 iOS 系统替代图标确认弹窗。
- iPhone 17 Pro 模拟器中 Settings 可打开离线地图管理弹窗，下载标签页不再显示代理输入项。
- iPhone 17 Pro 模拟器中 Airport 页面紧凑控件样式已随 CSS 更新；代码层面限定在 `html:not([data-device="pad"])`，不影响 iPad。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

待验证：

- 真机安装后继续确认替代图标在主屏幕上的视觉效果；iOS 替代图标切换会显示系统确认弹窗，这是系统 API 行为。
- 离线地图下载仍需用真实中大范围任务验证直连网络、取消响应和 SQLite 写入性能。

## 2026-06-01 iPhone 横屏工作台布局

已完成：

- 为 iPhone 横屏增加专用 CSS 覆盖：在 `max-width: 920px` 且横屏时，不再使用竖屏的地图上 / 面板下 / 底部三标签布局。
- iPhone 横屏改为 iPad 横屏式工作台：左侧计划栏、中间地图、右侧详情/设置栏、左右折叠按钮同屏显示。
- 横屏下隐藏底部 `计划 / 机场 / 设置` 三标签，恢复右侧 `机场 / 设置` 详情标签。
- 横屏仍沿用 iPhone 竖屏的紧凑字号和控件尺寸，包括输入框、按钮、机场槽位、地图标签、地图符号和弹窗。
- 横屏左右列宽使用 `clamp(...)`，在较小 iPhone 横屏宽度下仍保留中间地图可视面积。
- CSS 资源版本刷新为 `20260601-phone-landscape-ipad-layout`。
- 同步更新 README、TODO、AppShell 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `node -e ... styles.css` 简单括号平衡检查成功，CSS 大括号配对正常。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，构建无 warning / error；竖屏截图确认既有地图上 / 输入区下 / 底部三标签布局未回退。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。
- 后续已通过 XcodeBuildMCP 获取 iPhone 17 Pro 横屏截图，确认左计划栏 / 中地图 / 右详情栏工作台布局可显示；最新安全区和圆角修正见 2026-06-03 横屏刘海侧记录。

后续关注：

- 真机横屏下仍需继续观察动态岛、安全区左右 inset、圆角遮挡和软键盘高度。

## 2026-06-03 iPhone 横屏刘海侧安全区优化

已完成：

- 根据横屏截图反馈，修复 iPhone 横屏左右同时留出大空白的问题。
- SwiftUI 外壳将 `MapContainerView` 改为忽略横向和底部安全区，让 WKWebView 在横屏下可以铺满左右边缘。
- Web 层新增 `installPhoneLandscapeSafeAreaTuning()`：横屏时根据 `screen.orientation.angle` / `window.orientation` 在 `html` 上写入 `data-landscape-notch-side="left/right"`。
- CSS 横屏布局改为默认只在刘海侧使用完整 `env(safe-area-inset-*)`，非刘海侧固定约 8px 留白，从而把另一侧空间让给左计划栏 / 地图 / 右详情栏。
- 横屏反向旋转时会自动切换避让侧，并触发 Leaflet `invalidateSize` 修正地图尺寸。
- Web 资源版本刷新为 `20260603-phone-landscape-safe-area`。
- 同步更新 README、TODO、AppShell 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `node -e ... styles.css` 简单括号平衡检查成功，CSS 大括号配对正常。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，构建无 warning / error。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

后续关注：

- 真机横屏下继续观察动态岛、安全区 inset 与圆角遮挡；如不同机型圆角仍压到文字，再按机型截图微调外侧面板圆角半径和横屏上下 padding。

## 2026-06-03 iPhone Pro Max 横屏同设计覆盖

已完成：

- 将 iPhone 紧凑 Web 工作台断点从 `920px` 扩展到 `1024px`，覆盖 iPhone 17 Pro Max 等横屏 CSS 宽度更大的机型。
- 将 JS 地图紧凑判定同步扩展为 `max-width: 1024px` 或任意 iPhone 横屏，确保地图符号、标签和弹窗继续沿用 iPhone 17 Pro 的小屏紧凑尺寸。
- 保留既有 iPhone 横屏 50px 非刘海侧白色边栏圆角、8px 浅蓝背景间隔、刘海侧安全区和文字避让逻辑。
- Web 资源版本刷新为 `20260603-phone-landscape-all-iphones`。
- 同步更新 README、TODO、AppShell 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `node -e ... styles.css` 简单括号平衡检查成功，CSS 大括号配对正常。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `rg` 断言确认 `styles.css` 的 iPhone 紧凑和横屏媒体查询均为 `1024px`，`app.js` 的 `isCompactPhoneMap()` 已使用 `max-width: 1024px` 或横屏判定，`map.html` 资源版本已刷新。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 构建 / 安装成功，无 warning / error；但该模拟器 SpringBoard 连续返回 `FBSOpenApplicationServiceErrorDomain` preflight busy，前台启动被系统拒绝，截图停留在主屏。检查 App 包 `Info.plist`、可执行文件和 iPhone 横竖屏 supported orientations 均正常，未发现 App 代码崩溃日志。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，构建无 warning / error；竖屏截图确认既有地图上方、输入区下方、底部中文标签布局正常。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-03 iPhone 17 Pro Max 重装与横屏回归

已完成：

- 用户卸载 iPhone 17 Pro Max 模拟器中的旧 App 后，重新设置 XcodeBuildMCP 目标为 iPhone 17 Pro Max。
- 重新运行 XcodeBuildMCP `build_run_sim`，完成构建、安装和启动，App 进程正常创建。
- 竖屏截图确认 Pro Max 使用地图上方、输入区下方、底部 `计划 / 机场 / 设置` 中文标签布局。
- 通过 Simulator `Device > Orientation > Landscape Right` 切入横屏，截图确认 Pro Max 已使用 iPhone 横屏工作台：左计划栏 / 中地图 / 右机场/设置详情栏，未退回桌面布局。
- 收起键盘后再次截图确认横屏工作台干净状态，右侧刘海避让、地图区和左右面板可见。
- 使用 `simctl io ... screenshot --mask black` 获取带黑色屏幕圆角遮罩的 Pro Max 横屏截图，用于核对屏幕圆角与面板关系。
- 通过 Simulator `Device > Orientation > Landscape Left` 切换另一侧横屏，确认仍进入同一套 iPhone 横屏工作台布局。

验证记录：

- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建无 warning / error。
- 竖屏截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_157cc527-2630-454c-af8e-22f9e347b0f9.jpg`。
- 横屏截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_fe1d1c7e-2f8d-4e14-8641-9c252165f4ec.jpg`。
- 带黑色屏幕圆角遮罩截图：`/private/tmp/navplanner-17promax-landscape-mask.png`。

## 2026-06-03 ZULS Procedure 与 iPhone Airport 视觉回归

已完成：

- 对照只读 Web 参考 `NavPlanner-web/src/planner_routes.py`，将 Swift `normalizeProcedureRows(...)` 改为按 `route_type + seqno` 分组，并过滤无 `arc_radius` 且 `center_waypoint` 为 `LSC*` 的 RF / AF 行。
- Swift Procedure 行打分补齐 Web 的已使用航点权重、真实航点、可绘制 leg、真实中心点和 waypoint 字符串 tie-break，避免 ZULS `R10L / LS995` 复飞段保留额外 `LSC13 / LSC14` 行并画出异常大圆。
- `Tools/ProcedureParity/procedure_parity.py` 新增 `approach ZULS R10L LS995` case，当前 ProcedureParity 覆盖 6 个 case。
- iPhone 计划航路地图标签改为更清晰的深色背板、暗色文字阴影和更高字重；航路名标签使用更高对比的黄色胶囊，避免白字被全局浅色描边冲淡。
- iPhone Airport 页面进一步压缩跑道列表行、通信频率胶囊、Procedure chip、已选 Procedure chip 和删除圆点的字号、padding、圆角和间距，重点降低 `RW28R`、频率和 `Approach` 控件占用。
- `map.html` Web 资源版本刷新为 `20260603-procedure-ui-parity`。
- 同步更新 README、TODO、ProcedureParity、Procedures、AppShell、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `python3 Tools/ProcedureParity/procedure_parity.py` 成功，6 个 case 无差异。
- `python3 Tools/ProcedureParity/procedure_parity.py --dump` 成功，`ZULS R10L LS995` Swift / Web 均为 `items=36 path=588 primary=223 missed=366`。
- `python3 Tools/Parity/run_all_parity.py` 成功，RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `node -e ... styles.css` 简单括号平衡检查成功，CSS 大括号配对正常。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 竖屏启动截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_6e88cff7-a616-44e0-8107-fa41b6123266.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

受限说明：

- 本轮尝试用 Simulator 窗口坐标点击进入 WebView 深层控件，但 macOS 返回 `osascript` 不允许辅助访问。
- 本轮尝试通过 LLDB 对 WKWebView 注入 JS，但当前 XcodeBuildMCP DAP 后端不支持 LLDB 表达式求值；因此没有完成自动点击 ZULS Airport / Approach chip 的深层视觉截图，已用 ProcedureParity 和启动截图覆盖可自动化验证部分。

## 2026-06-03 Selection Procedure 明细表列布局

已完成：

- 调整 `NavPlanner/Resources/Web/app.js` 中 Procedure Selection 明细表列顺序：从 `SEQ / WAYPOINT / LEG / TURN / ALTITUDE / SPEED` 改为 `SEQ / WAYPOINT / ALTITUDE / SPEED / LEG / TURN`。
- 为 Selection 表格增加 `colgroup` 和语义列 class，避免后续再依赖 `nth-child` 猜列位置。
- `NavPlanner/Resources/Web/styles.css` 将 Selection 表格改为固定布局，`LEG / TURN` 列宽设为 43%，约为旧视觉宽度的 60%，同时保留 `ALTITUDE` 和 `SPEED` 的独立列宽，长 leg 描述在本列内换行。
- iPhone 横屏 / 左侧展开状态下取消 `table-layout: auto` 覆盖，避免长 `LEG / TURN` 文本再次把高度 / 速度列挤出视野。
- `map.html` Web 资源版本刷新为 `20260603-selection-table-leg-column`。
- 同步更新 README、TODO、MapKernel、Procedures 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `node -e ... styles.css` 简单括号平衡检查成功，CSS 大括号配对正常。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/ProcedureParity/procedure_parity.py` 成功，6 个 case 无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 竖屏启动截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_4ada8edb-2a05-4a09-8a47-4d72bf11edf4.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-03 Selection 表格可读性与机场页紧凑修复

已完成：

- 修复 iPhone 日间主题下 Selection 表格正文过淡的问题：`tbody td`、高度、速度、`LEG / TURN`、waypoint 副标题改为不透明深色文字，并增加轻量行底色，避免正文被浅蓝白背景吞掉。
- 继续缩小 iPhone Selection 的 Procedure 标题、表头、正文和副标题字号，降低横屏三栏下 `APPROACH` 标题和表格标题的占用。
- 将跑道列表渲染为带 `runway-list-table` 专用 class 的列表，并在 iPhone 上强制每行两条，避免其它列表样式或横屏三栏样式把跑道重新撑成单列。
- 继续压缩 iPhone Airport 机场头卡、定位按钮、机场名和跑道行尺寸，使“手动机场 ZULS KONGGAR”区域接近跑道卡片高度。
- `map.html` Web 资源版本刷新为 `20260603-selection-airport-compact-fix`。
- 同步更新 README、TODO、MapKernel、Procedures 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `node -e ... styles.css` 简单括号平衡检查成功，CSS 大括号配对正常。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/ProcedureParity/procedure_parity.py` 成功，6 个 case 无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 竖屏启动截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_7a3fe267-aef3-4253-8c0e-9b5fac94d066.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

受限说明：

- 当前 `xcrun simctl ui` 在 iOS 26.5 工具链中没有 orientation 子命令；继续通过 Simulator 菜单执行 `Rotate Right` / `Rotate Left` 均返回成功，但截图仍保持竖屏尺寸，未能自动切换到横屏深层页面。本轮已完成构建启动和静态 / parity 校验，Selection / Airport 横屏深层视觉仍建议结合真机或 Simulator 手动旋转复核。

## 2026-06-03 iPhone Airport 详情头部纯文本化

已完成：

- iPhone Airport 页的起飞、到达、手动机场详情头部统一移除背景、边框、圆角和阴影，`ZULS / KONGGAR` 等机场信息直接以纯文本显示。
- 保留右侧“定位”按钮作为独立操作控件，不再让机场名称区域呈现为卡片。
- `map.html` Web 资源版本刷新为 `20260603-airport-head-text-only`。
- 同步更新 README、TODO 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `node -e ... styles.css` 简单括号平衡检查成功，CSS 大括号配对正常。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 竖屏启动截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_a026296a-6ed9-47b0-8ff8-244ca175719c.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-04 深蓝 3D 地形航路 App 图标重设计

已完成：

- 使用内置图像生成创建新版 App 图标源图：深蓝低视角 3D 地形山谷、较低且简化的山体、无云、无指南针、无橘色地标。
- 航路改为悬在半山腰高度的空中航路，仅保留 3 个 waypoint 符号，并标注 `WPT1 / WPT2 / WPT3`。
- 飞机改为白 / 青色扁平化窄体机图标，不使用航空公司涂装或第三方品牌元素。
- 将生成图复制为项目源图 `Tools/Icon/navplanner-terrain-liquid-glass-source.png`；原始生成图保留在 `/Users/midaxia/.codex/generated_images/019e76a6-4912-7723-86f0-eea10e35e4cd/`。
- 重写 `Tools/Icon/generate_app_icons.swift` 为源图派生流程，默认 / 日间 / 夜间三套图标都保持深蓝体系，仅做细微明暗和玻璃高光区别。
- 重新生成 `AppIcon`、`AppIconDay`、`AppIconNight` 完整 iPhone / iPad / marketing 尺寸，以及 Settings 页面 `default.png` / `day.png` / `night.png` 预览图。
- 同步更新 README、TODO、AppIcon、Settings 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `swift Tools/Icon/generate_app_icons.swift` 成功。
- 视觉检查通过：默认 / 日间 / 夜间 1024 图标保持深蓝主调，Settings 180px 预览中仍可辨认航路、扁平飞机和 3 个 WPT 标签。
- `python3 -m json.tool` 成功验证 `AppIcon`、`AppIconDay`、`AppIconNight` 三个 `Contents.json`。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 图标 PNG 检查成功：3 张 marketing 图为 1024 x 1024，Settings 预览图为 180 x 180，asset catalog 共 48 张 AppIcon PNG。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，asset catalog 编译、安装、启动无 warning / error。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-04 用户源图 App 图标与五套配色选项

已完成：

- 按用户指定，直接使用 `/Users/midaxia/Downloads/96701708-e656-492f-9728-bac4f7341714.png` 作为项目 App 图标源图，并复制到 `Tools/Icon/navplanner-terrain-liquid-glass-source.png`。
- 更新 `Tools/Icon/generate_app_icons.swift`：从同一源图派生默认、青蓝、翠绿、紫蓝和夜间五套图标；三套配色增加色彩层区分，夜间版单独压暗并保持航路可读。
- 重新生成 `AppIcon`、`AppIconCyan`、`AppIconEmerald`、`AppIconViolet`、`AppIconNight` 的 iPhone / iPad / marketing 尺寸，以及 Settings 页面 `default.png`、`cyan.png`、`emerald.png`、`violet.png`、`night.png` 预览图。
- Settings “应用图标”卡片从三项扩展为五项：默认、青蓝、翠绿、紫蓝、夜间；iPhone 下使用更紧凑的五等分预览按钮。
- Swift `AppEnvironment.setAppIconChoice(_:)`、Web `APP_ICON_CHOICES` 和 Xcode `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` 已同步映射新增备用图标。
- `map.html` Web 资源版本刷新为 `20260604-app-icon-variants`。
- 同步更新 README、TODO、Settings、WebBridge、WebParity、AppIcon 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `swift Tools/Icon/generate_app_icons.swift` 成功。
- 视觉检查通过：默认图标保持用户提供的立体地形、S 形下降航路和地面示意跑道；翠绿与夜间 1024 图标均能明显区分且航路可读。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- `python3 -m json.tool` 成功验证 `AppIcon`、`AppIconCyan`、`AppIconEmerald`、`AppIconViolet`、`AppIconNight` 五个 `Contents.json`。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 图标 PNG 检查成功：5 张 marketing 图为 1024 x 1024，Settings 预览图为 180 x 180，五套当前可选图标共 80 张 AppIcon PNG。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，asset catalog 编译、安装、启动无 warning / error。
- 启动截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_88a08a70-7377-4ad9-8265-71ce164f5775.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

受限说明：

- XcodeBuildMCP 的 runtime snapshot 未暴露 WebView 内部 Settings 图标按钮为可点击辅助功能目标，本轮未自动点击系统替代图标确认弹窗；已完成资源、桥接映射、Xcode 配置和启动构建验证。

## 2026-06-04 日间 / 夜间三档图标、Git 准备与目标文档优化

已完成：

- 按最新要求重构 `Tools/Icon/generate_app_icons.swift`：移除整图颜色叠加层，日间图标只通过饱和度、对比度和亮度派生；默认主图标改为日间均衡版本，高饱和版本作为备用图标且不额外增加源图饱和度。
- 夜间图标改为逐像素映射：整体使用深蓝黑类似反色地形，源图绿色地形层次改为紫色层次，主航路改为暗橙色，并提供高对比、均衡、柔和三档饱和度 / 对比度。
- 当前有效图标套装为 `AppIcon`、`AppIconDayHigh`、`AppIconDaySoft`、`AppIconNightHigh`、`AppIconNightMedium`、`AppIconNightSoft`。
- Settings “应用图标”卡片改为“日间 / 夜间”两组，每组三个紧凑预览按钮；Web `APP_ICON_CHOICES`、Swift `AppEnvironment.setAppIconChoice(_:)` 和 Xcode `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` 已同步。
- `map.html` Web 资源版本刷新为 `20260604-app-icon-liquid-glass-tones`。
- 图标生成脚本现在会清理不再使用的 `AppIcon*.appiconset` 和旧 Settings 预览图，并在写入每个有效 appiconset 前清空旧 PNG，避免 Git 收录历史残留资源。
- 新增 `.gitignore`，覆盖 macOS `.DS_Store`、Xcode `DerivedData` / `xcuserdata`、Swift `.build`、Python 缓存、日志和 `NavPlanner-web` 的运行时缓存目录。
- 已删除根工程本地构建产物和用户态文件：`.build/`、`DerivedData/`、根目录 `.DS_Store`、`NavPlanner/.DS_Store`、`NavPlanner.xcodeproj/xcuserdata/`。
- 新增 `Docs/CodexGoal.md`，提供下一轮新线程可直接使用的 `/goal` 草案，把目标从基础工程搭建调整为 Web parity、性能、离线地图、真机触控和产品化。
- README 顶部新增“新线程接手摘要”；同步更新 README、TODO、AppIcon、Settings、WebBridge、WebParity 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `swift Tools/Icon/generate_app_icons.swift` 成功。
- 视觉检查通过：日间默认图标为均衡低饱和版本；夜间高对比图标呈现深蓝黑地形、紫色层次和暗橙航路，水域误染橙色杂点已收敛。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- `node -e ...` 成功解析 6 个 AppIcon `Contents.json`。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 图标 PNG 检查成功：6 张 marketing 图为 1024 x 1024，Settings 预览图为 180 x 180，六套当前可选图标共 96 张 AppIcon PNG。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，asset catalog 编译、安装、启动无 warning / error。
- 启动截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_08237d88-e7a0-40bd-9d9f-e24956f5e8ea.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

说明：

- 上一节“用户源图 App 图标与五套配色选项”是历史记录，当前实现已被本节的日间三档 / 夜间三档方案取代。

## 2026-06-04 Liquid Glass 图标边框与饱和度梯度二次优化

已完成：

- 修复图标生成脚本中日间 / 夜间三档输出 PNG 哈希相同的问题：不再依赖 `CIImage` 表示层，改用 `toneAdjustedImage(...)` 逐像素执行饱和度、对比度和亮度调整。
- 将默认主图标保持为日间均衡档；日间高饱和继续使用源图且不增加饱和度，日间均衡明显降到中低饱和，日间柔和接近低饱和灰阶。
- 夜间高对比 / 均衡 / 柔和三档同样通过逐像素 tone 调整拉开差异；夜间高对比保留蓝黑地形、紫色层次和暗橙航路，柔和档显著压低饱和度与对比度。
- 增强所有图标的 Liquid Glass 后处理：更清晰的外缘边框、内圈描边、顶部高光、侧向反光和弧形 glint；夜间图标现在与日间一样有可见边框。
- 同步更新 `README.md`、`TODO.md`、`Docs/AppIcon.md`、`Docs/Settings.md` 和本报告。

验证记录：

- `swift Tools/Icon/generate_app_icons.swift` 成功。
- `swift -frontend -parse Tools/Icon/generate_app_icons.swift` 成功。
- `shasum` 确认 6 张 marketing 图标和 6 张 Settings 预览图均为不同 PNG。
- 视觉检查通过：日间高饱和 / 默认均衡 / 柔和三档差异明确；夜间图标有清晰玻璃边框，夜间高对比 / 柔和差异明确。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- Node JSON 检查确认 6 个 AppIcon `Contents.json` 均可解析且每套包含 18 个 image entry。
- 图标 PNG 检查成功：六套当前可选图标共 96 张 AppIcon PNG。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 启动截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_08a932d0-92fa-461a-825f-ed064f7b50a2.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-04 图标档位与夜间局部玻璃质感调整

已完成：

- 重新分配日间三档：上一轮“默认”档位的饱和度 / 对比度 / 亮度下放为 `AppIconDaySoft`，新的默认主图标 `AppIcon` 调整到高饱和与柔和之间。
- 重新分配夜间三档：上一轮夜间均衡档位下放为 `AppIconNightSoft`，新的夜间均衡档位位于高对比与柔和之间。
- 弱化夜间整图 Liquid Glass 罩层：不再绘制明显的全图顶部玻璃高光和整片 glass veil，只保留极轻的整体明暗深度。
- 将夜间 Liquid Glass 质感转移到图标内容上：沿暗橙航路绘制更细的局部反光，并在山体 ridge 上绘制低透明玻璃线条。
- 加宽夜间图标外框，降低内圈和全图 glint 强度，使夜间边界更稳但不再像整张图被玻璃罩覆盖。
- 为 Settings 中 6 张 App 图标预览图片增加 `?v=20260604-icon-subject-glass`，避免 WebView 继续显示旧预览。
- 同步更新 `README.md`、`TODO.md`、`Docs/AppIcon.md`、`Docs/Settings.md` 和本报告。

验证记录：

- `swift -frontend -parse Tools/Icon/generate_app_icons.swift` 成功。
- `swift Tools/Icon/generate_app_icons.swift` 成功。
- 视觉检查通过：日间柔和使用上一轮默认观感；夜间整图玻璃感明显减弱，航路和山体局部保留玻璃反光，夜间外框更宽。
- Node JSON 检查确认 6 个 AppIcon `Contents.json` 均可解析且每套包含 18 个 image entry。
- 图标 PNG 检查成功：六套当前可选图标共 96 张 AppIcon PNG。
- `shasum` 确认 6 张 marketing 图标和 6 张 Settings 预览图均为不同 PNG。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 启动截图：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_a7c86866-aa77-47ed-9847-f61282f727e4.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-04 Web UI 中文化三次清理

已完成：

- 继续清理 iOS 自有 Web 工作台中文化，不修改只读参考项目 `NavPlanner-web/`。
- 将启动状态栏的 `Database loaded` 和 Settings 数据库摘要中的 `Rev` 改为中文。
- 将 Settings / 初始化路径中的离线地图和在线地图缓存 console 状态改为中文。
- 将机场弹窗详情中的标高、过渡高度 / 层、IFR 能力、最长跑道面、入口标高、道面、磁方位、真方位、移位入口和坡度等字段改为中文。
- 将机场详情跑道摘要中的 `BRG` / `Surface` 改为“磁方位 / 道面”。
- 将 Procedure 已选芯片的来源标签改为“自动 / 手动”，进近类型显示为“进近”。
- 将 Procedure Selection 摘要的 `legs`、阶段标签 `Main / Final / Runway / Missed` 和特征说明 `Left turn / Right turn / Arc / Hold` 改为中文；表头继续保留 `SEQ / WAYPOINT / ALTITUDE / SPEED / LEG / TURN` 的既有紧凑列名。
- 将静态机场 Procedure 列标题和手动机场提示里的 `Approach` 改为“进近”。
- `map.html` Web 资源版本刷新为 `20260604-ui-chinese-cleanup`。
- 同步更新 README、TODO、Settings、WebParity、Procedures 和本执行记录。

验证记录：

- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- `git diff --check` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 首屏截图确认地图、中文输入区和底部 `计划 / 机场 / 设置` 标签正常：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_bef54e04-d98b-4747-a833-e9eb25d227fa.jpg`。

## 2026-06-04 Web UI 错误提示本地化

已完成：

- 新增 `localizedErrorMessage(...)` 和 `setErrorStatus(...)`，统一清理 Web 工作台用户可见错误提示。
- `fetchJson(...)` 现在会把成功响应但 JSON 解析失败的情况显示为中文错误，非 2xx 响应仍保留后端原始 error 供本地化和 FlightAware AeroAPI 降级判断使用。
- 本地化常见浏览器 / API 错误：`Request failed`、`Failed to fetch`、离线网络、未知本地 host、Web 资源缺失、本地 API 缺失、机场未找到、离线地图 API 缺失、PMTiles 缺失和无效瓦片坐标。
- 本地化航路解析错误：起降点无法解析、DCT 缺目标、`***` 缺起终点、airway 缺退出点、退出点未找到、airway 不连接指定航点和 waypoint 未找到。
- 本地化导入轨迹错误：无法从轨迹构建合法航路、无法构建可绘制航路点，以及 FlightAware AeroAPI 在线访问失败 / 轨迹点不足的降级提示。
- 将离线地图、在线缓存、机场弹窗操作、搜索结果机场加载、数据库切换、路线生成、轨迹导入和 Settings 按钮等状态栏错误统一走 `setErrorStatus(...)`。
- `map.html` Web 资源版本刷新为 `20260604-error-localization`。
- 同步更新 README、TODO、Settings、WebParity 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- `git diff --check` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 首屏截图确认地图、中文输入区和底部 `计划 / 机场 / 设置` 标签正常：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_2c0d9ced-671a-4a3d-8202-9d451e2b2f30.jpg`。

## 2026-06-04 App 图标边框加宽

已完成：

- 按本轮要求加宽已有 App 图标边框，不更换源图、不改变日间 / 夜间六套档位和替代图标映射。
- 调整 `Tools/Icon/generate_app_icons.swift` 的 Liquid Glass 收尾层：加粗外缘暗描边、外缘亮描边、内圈描边和下缘阴影；夜间图标仍保留比日间更强的轮廓。
- 重新运行图标生成脚本，写入 `AppIcon`、`AppIconDayHigh`、`AppIconDaySoft`、`AppIconNightHigh`、`AppIconNightMedium`、`AppIconNightSoft` 的完整 iPhone / iPad / marketing PNG，以及 Settings 页面 6 张 180px 预览图。
- Settings 预览图片内容已更新，`map.html` 中 6 张 app icon preview 查询串刷新为 `20260604-icon-wider-border`，底部 `app.js` 资源版本同步刷新为 `20260604-icon-wider-border`。
- 同步更新 README、TODO、Docs/AppIcon.md、Docs/Settings.md 和本执行记录。
- 未修改 `NavPlanner-web/`。

验证记录：

- `swift -frontend -parse Tools/Icon/generate_app_icons.swift` 成功。
- `swift Tools/Icon/generate_app_icons.swift` 成功。
- 视觉检查通过：默认日间均衡图标与夜间高对比图标外框均明显加宽，航路、地形和跑道主体仍可读。
- `shasum` 确认 6 张 marketing 图标和 6 张 Settings 预览图均为不同 PNG。
- `sips` 检查 6 张 marketing 图为 1024 x 1024，Settings 预览图为 180 x 180；图标 PNG 数量检查为 96 张 AppIcon PNG 和 6 张预览图。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- Node JSON 检查确认 6 个 AppIcon `Contents.json` 均可解析且每套包含 18 个 image entry。
- `git diff --check` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 首屏截图确认地图、中文输入区和底部 `计划 / 机场 / 设置` 标签正常：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_1597bc26-b6d3-42ba-abbc-8c0ee98efe26.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-04 Web UI 多语言与 Settings 语言选择

已完成：

- 为 iOS 自有 Web 工作台增加中英双语本地化，不修改只读参考项目 `NavPlanner-web/`。
- 在 `map.html` 启动阶段按 `localStorage.navplannerLanguageMode` 初始化语言；默认 `system` 模式会读取 `navigator.languages[0]` / `navigator.language`，中文首选显示简体中文，其它语言显示 English，避免首帧闪烁到错误语言。
- 在 Settings 页面新增语言设置卡片，提供“系统语言 / 简体中文 / English”三种选择，偏好保存到 `localStorage.navplannerLanguageMode`，点击后即时刷新当前 WebView。
- 在 `app.js` 增加 `TRANSLATIONS` 字典、语言模式解析、静态 `data-i18n` 属性刷新、动态状态刷新和本地化错误提示；Plan、Airport、Settings、Procedure Selection、地图弹窗、离线地图管理、在线地图缓存和轨迹匹配常见路径均可随语言切换。
- 保持必要航空 / 技术标识英文：`SID` / `STAR` / `APPROACH`、`DCT`、`IFR`、`AIRAC`、`PMTiles`、`MBTiles`、`SQLite`、`ILS/GLS`、`TCH`、`RNP`、`VPA` 等不随 UI 语言翻译。
- 将 Procedure 标题和芯片中的进近类型固定为 `APPROACH`，手动机场提示也固定使用 `SID / STAR / APPROACH`。
- `map.html` Web 资源版本刷新为 `20260604-language-settings`。
- 同步更新 `README.md`、`TODO.md`、`Docs/Settings.md`、`Docs/WebParity.md` 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- HTML 静态本地化覆盖检查成功：100 个 `data-i18n*` 属性均有翻译键。
- 翻译字典检查成功：335 个 `TRANSLATIONS` 条目均包含 `zh-Hans` 和 `en`。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 启动截图确认系统默认中文 UI 正常，且手动机场提示保留 `SID / STAR / APPROACH` 英文标识：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_57df7939-fc3c-47c6-a05d-00cc43c6a3cb.jpg`。
- WKWebView 内部控件未通过 XcodeBuildMCP 暴露为可点击 AX 元素，且当前 `xcrun simctl io ... tap` 不支持坐标点击，因此 Settings 语言按钮的模拟器深层点击未自动化；本轮通过静态覆盖检查、构建运行和首屏截图完成可验证项。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-05 地图弹窗语言即时刷新与 App 图标回调本地化

已完成：

- 继续收敛 Web 工作台多语言即时刷新，不修改只读参考项目 `NavPlanner-web/`。
- 为地图弹窗增加 `activeNavPopup` 状态：打开机场 / 航点 / 航路弹窗时记录规范化 point 和原始 `latlng`，关闭弹窗或点击地图空白处会清除该状态。
- 语言切换时会在原位置重渲染当前打开的地图弹窗，并继续沿用既有机场详情异步加载与缓存逻辑，避免弹窗动作、详情字段和关联航路标题停留在旧语言。
- App 图标 Swift bridge 回调不再直接显示 Swift 中文原文；Web 侧按当前语言展示“已是当前选择 / 已切换 / 当前系统不支持 / 切换失败”等状态，并保留日间 / 夜间六套图标名称的中英双语标签。
- `map.html` 中 `app.js` 资源版本刷新为 `20260605-popup-language-refresh`。
- 同步更新 `README.md`、`TODO.md`、`Docs/Settings.md`、`Docs/WebParity.md` 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- HTML 静态本地化覆盖检查成功：100 个 `data-i18n*` 属性均有翻译键。
- 翻译字典检查成功：345 个 `TRANSLATIONS` 条目均包含 `zh-Hans` 和 `en`。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 启动截图确认中文首屏、地图、Plan 表单和 `SID / STAR / APPROACH` 标识正常：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_8d1d8127-2646-49b4-b43e-30cc33c043fc.jpg`。
- WKWebView 内部控件仍未通过 XcodeBuildMCP 暴露为可点击 AX 元素，本轮未自动化“打开弹窗后切换语言”的深层点击；已通过代码路径和启动验证覆盖可自动化部分。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-05 FlightAware AeroAPI 查询 Tab 与 GPX 轨迹增强

已完成：

- 按用户要求移除 Plan 中旧的“匹配轨迹”按钮，将 FlightAware AeroAPI 操作集中到独立 `查询` Tab；iPhone 竖屏底部改为 `计划 / 机场 / 查询 / 设置` 四标签，iPad 与 iPhone 横屏右侧详情栏改为 `机场 / 查询 / 设置`。
- 新增 Swift 本地 FlightAware AeroAPI 在线增强服务，不修改只读参考项目 `NavPlanner-web/`：
  - `/api/flightaware/search` 按起飞 / 到达机场查询 FlightAware AeroAPI 航线最新最多 10 个航班。
  - `/api/flightaware/history` 按同航线和同航班号 / callsign 查询航班历史。
  - `/api/flightaware/download` 下载 `AeroAPI track JSON`，提取轨迹点并写入 GPX、AeroAPI JSON 和 meta JSON 缓存。
  - `/api/flightaware/cache/status` / `clear` 统计和删除 FlightAware AeroAPI 下载缓存。
  - `/api/route/flightaware-match` 保留 Web parity 入口，改为在线尝试下载回放并复用本地 `track-match`。
- `PlannerService` 增加 FlightAware AeroAPI 查询所需的起降机场 ICAO / IATA / 坐标摘要，继续复用现有本地数据库解析，避免前端自行猜测机场代码。
- Query 页每个航班和历史记录显示航班号、起降机场、航司、机型 / 注册号、计划 / 实际时间和飞行时长，并提供“下载并绘制轨迹”和“匹配轨迹”。
- 地图新增独立 FlightAware AeroAPI 轨迹图层，使用黑色线绘制 GPX 轨迹，并复用现有经度展开 / world copy 逻辑以兼容跨日期变更线。
- 匹配轨迹时先下载 / 读取缓存轨迹，再 POST `/api/route/track-match`，继续使用 Swift 本地 airway graph、FlightAware AeroAPI 平滑 / zigzag 清理和 Procedure 自动挂接；匹配前保存当前 route payload，可通过“还原轨迹匹配”恢复。
- Query 页底部提供清除轨迹绘制、还原轨迹匹配、删除下载缓存和刷新缓存状态；FlightAware AeroAPI 缓存与在线地图缓存、离线地图包和导航数据库互不影响。
- FlightAware 在线增强失败时会快速返回错误，不阻塞本地航路、Procedure、nav-overlay 和离线地图；当前已改为 FlightAware AeroAPI Key 访问方式。
- 新增 `Docs/FlightAwareQuery.md`，并同步更新 README、TODO、Docs/WebBridge.md、Docs/WebParity.md、Docs/TrackParity.md、Docs/RouteResolve.md、Docs/Settings.md 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- HTML 静态本地化覆盖检查成功：103 个 `data-i18n*` 属性均有翻译键，386 个翻译键已被扫描。
- `swift -frontend -parse ...` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 启动截图确认地图、Plan 表单和底部四标签正常：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_932e5092-4263-407f-89de-b6825c50158f.jpg`。
- WKWebView 内部控件仍未通过 XcodeBuildMCP 暴露为可点击 AX 元素，本轮未自动化点入 Query Tab；已通过静态检查、构建运行和首屏截图完成可自动化部分。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-05 FlightAware AeroAPI Query 降级提示修正

已完成：

- 根据 Query 页截图修正 FlightAware AeroAPI 失败后的用户可见提示，不再指向已从 Plan 移除的旧入口。
- 将 FlightAware AeroAPI 轨迹点不足的提示改为选择其他历史航班或稍后重试。
- 压缩小屏 Query 查询按钮视觉重量：在移动布局中改为居中紧凑宽度，不再占满整行。
- `map.html` 中 `app.js` / `styles.css` 资源版本刷新为 `20260605-flightaware-query-copy`。
- 同步更新 README、TODO、Docs/FlightAwareQuery.md 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- HTML 静态本地化覆盖检查成功：103 个 `data-i18n*` 属性均有翻译键，386 个翻译键已被扫描。
- `git diff --check` 成功。

## 2026-06-05 FlightAware AeroAPI 网络访问配置

已完成：

- 将网络访问方案收敛为 FlightAware AeroAPI：不再使用旧的非 AeroAPI 访问方式。
- Swift `FlightAwareService` 新增 FlightAware AeroAPI Key 的本地保存、清除、状态查询与请求注入：
  - `/api/flightaware/access/status`
  - `/api/flightaware/access/update`
  - `/api/flightaware/access/clear`
- 配置 AeroAPI Key 时，`/api/flightaware/search` / `history` 走 `aeroapi.flightaware.com/aeroapi/airports/{origin}/flights/to/{destination}`，`download` 走 `aeroapi.flightaware.com/aeroapi/flights/{id}/track`。
- Query 页新增“FlightAware 网络访问”卡片，可保存 / 清除 / 刷新 FlightAware AeroAPI Key；前端只显示是否已配置，不回显敏感值。
- `map.html` 中 `app.js` / `styles.css` 资源版本刷新为 `20260605-flightaware-network-access`。
- 同步更新 README、TODO、Docs/FlightAwareQuery.md 和本执行记录。

验证记录：

- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- HTML 静态本地化覆盖检查成功：112 个 `data-i18n*` 属性均有翻译键，399 个翻译键已被扫描。
- `swift -frontend -parse NavPlanner/Core/WebBridge/NavPlannerSchemeHandler.swift NavPlanner/Core/PlannerCore/PlannerService.swift` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 首屏截图确认地图、Plan 表单和底部 `计划 / 机场 / 查询 / 设置` 四标签正常：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_dbe5336d-cebb-4d85-a580-36d3dd8ad58f.jpg`。

## 2026-06-05 FlightAware AeroAPI 替换收敛

已完成：

- 按用户新方案将查询功能收敛为 FlightAware AeroAPI，不再使用旧的非 AeroAPI 访问方式。
- Swift `FlightAwareService` 现在通过 `https://aeroapi.flightaware.com/aeroapi` 和 `x-apikey` 请求：
  - `/airports/{origin}/flights/to/{destination}` 查询航线最近航班。
  - `/flights/{id}/track` 下载轨迹点。
- Query 页访问配置简化为单一 FlightAware AeroAPI Key，前端只展示是否已配置，不回显敏感值。
- 删除 Web 侧旧的 Plan 轨迹粘贴降级函数和未使用的 FlightAware 旧匹配入口代码，查询页继续提供“下载并绘制轨迹”和“匹配轨迹”。
- AeroAPI 轨迹点解析支持 ISO 时间戳；缓存说明更新为 GPX / AeroAPI JSON / meta JSON。
- `map.html` 中 `app.js` / `styles.css` 资源版本刷新为 `20260605-flightaware-aeroapi-v2`。
- 同步更新 README、TODO、Docs/FlightAwareQuery.md、Docs/WebBridge.md、Docs/WebParity.md、Docs/AppShell.md、Docs/Settings.md、Docs/TrackParity.md 和本执行记录。

已完成的本地校验：

- `swift -frontend -parse NavPlanner/Core/WebBridge/NavPlannerSchemeHandler.swift NavPlanner/Core/PlannerCore/PlannerService.swift` 成功。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- HTML 静态本地化覆盖检查成功：123 个 `data-i18n*` 属性均有翻译键，395 个翻译键已被扫描。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 启动截图确认地图、Plan 表单和底部 `计划 / 机场 / 查询 / 设置` 四标签正常：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_756adbbc-6a01-4091-b3e5-ece7c2b58a82.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-05 FR24 Web 会话查询与 GPX 轨迹回切

已完成：

- 按用户最新要求将 Query 在线增强从 FlightAware AeroAPI 改回 FR24 Web 逻辑，保持 `NavPlanner-web/` 只读未修改。
- Swift 本地服务新增 `FR24Service`：
  - `/api/fr24/search` 按 Web 参考扫描 FR24 `/common/v1/airport.json` schedule 插件，检查起飞机场 `departures` 与到达机场 `arrivals`，最多返回 10 个航线航班。
  - `/api/fr24/history` 按航班号 / callsign 扫描更长历史窗口。
  - `/api/fr24/download` 使用 `/common/v1/flight-playback.json?flightId=...&timestamp=...` 下载 playback JSON，提取轨迹点并写入 GPX、playback JSON 和 meta JSON 缓存。
  - `/api/fr24/cache/status` / `clear` 统计和删除 `Caches/NavPlanner/FR24`。
  - `/api/fr24/access/status` / `update` / `clear` 保存 FR24 Web Cookie / `_frPl`，只向前端回传是否已配置，不回显敏感值。
  - `/api/route/fr24-match` 保留 Web parity 入口，下载 FR24 playback 后复用 Swift 本地 `/api/route/track-match`。
- Query 页文案、DOM id、JS 状态和请求路径从 FlightAware 切换为 FR24；访问配置卡片改为 Cookie 文本框和 `_frPl` 输入框。
- 明确 Cloudflare 边界：App 不实现绕过、挑战破解或 CAPTCHA 自动化；只复用用户在浏览器中正常完成 FR24 / Cloudflare 验证后的 Cookie / `_frPl`。遇到 `cf-mitigated: challenge`、Cloudflare HTML 或非 JSON 响应时快速返回可本地化错误，不阻塞本地核心能力。
- 地图黑色轨迹图层改为 `fr24TrackLayerGroup`，继续复用跨日期变更线 world-copy / 经度展开逻辑；匹配成功前仍保存当前 route payload，支持“还原轨迹匹配”。
- `map.html` 中 `app.js` / `styles.css` 资源版本刷新为 `20260605-fr24-web-session`。
- 新增 `Docs/FR24Query.md`，删除旧 `Docs/FlightAwareQuery.md`，并同步更新 README、TODO、Docs/WebBridge.md、Docs/WebParity.md、Docs/TrackParity.md、Docs/RouteResolve.md、Docs/Settings.md、Docs/AppShell.md 和本执行记录。

已完成的本地校验：

- `swift -frontend -parse NavPlanner/Core/WebBridge/NavPlannerSchemeHandler.swift NavPlanner/Core/PlannerCore/PlannerService.swift` 成功。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- HTML 静态本地化覆盖检查成功：123 个 `data-i18n*` 属性均有翻译键，395 个翻译键已被扫描。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `rg -n "FlightAware|flightaware|AeroAPI|FlightAwareQuery" README.md TODO.md Docs NavPlanner/Core NavPlanner/Resources/Web -g '!Docs/Obsolete/**'` 无输出，当前正式文档和运行路径已无 FlightAware / AeroAPI 残留。
- `git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 启动截图确认地图、Plan 表单和底部 `计划 / 机场 / 查询 / 设置` 四标签正常：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_620db475-c3f7-4d53-91ac-6e6f059aa85c.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-05 FR24 App 内验证与会话自动同步

已完成：

- 按用户要求不再要求用户手动查找 FR24 Cookie；Query 页新增“打开 FR24 验证页”和“同步内置浏览器会话”。
- Swift `MapWebView` 新增 App 内 FR24 验证浏览器：打开 `https://www.flightradar24.com/`，用户正常完成 FR24 / Cloudflare 验证后点击“同步会话”。
- Swift 会自动读取 `WKWebsiteDataStore.default().httpCookieStore` 中 `flightradar24.com` 域 Cookie，并额外从当前 FR24 页面读取 `document.cookie` 与 `_frPl` local/session storage，合并后写入同一套 `FR24SessionStore`。
- `FR24SessionStore` 统一管理 `navplanner.fr24.webCookie` 和 `navplanner.fr24.frPl`，`FR24Service`、Query 页高级手动兜底和 App 内浏览器同步共用同一套存取逻辑。
- 模拟器调试确认：已同步 Cookie 包含 `cf_clearance`、`PHPSESSID`、`XSRF-TOKEN` 等，但 `_frPl` 缺失；使用该 Cookie 通过 Swift/Python 非浏览器请求 FR24 ZULS/ZUAL schedule 仍返回 403。
- 基于上述调试，新增 `FR24BrowserFetch`：`FR24Service.webGet(...)` 会优先通过共享 WKWebView 浏览器上下文执行 FR24 schedule/playback `fetch(..., credentials: "include")`，Swift `URLSession` 只作为兜底；浏览器上下文失败会保留 FR24 降级提示。
- 明确安全边界：仍不实现 Cloudflare 绕过、挑战破解、CAPTCHA 自动化或反检测逻辑；只复用用户在 App 内正常完成验证后的会话。
- Query 页手动 Cookie / `_frPl` 输入折叠为“高级：手动会话配置（可选）”，主流程改为 App 内验证与自动同步。
- `map.html` 中 `app.js` / `styles.css` 资源版本刷新为 `20260605-fr24-inapp-session`。
- 同步更新 README、TODO、Docs/FR24Query.md、Docs/WebBridge.md、Docs/WebParity.md、Docs/Settings.md、Docs/AppShell.md 和本执行记录。

已完成的本地校验：

- `swift -frontend -parse NavPlanner/Features/Map/MapWebView.swift NavPlanner/Core/WebBridge/MapBridgeScriptHandler.swift NavPlanner/Core/WebBridge/NavPlannerSchemeHandler.swift NavPlanner/Core/PlannerCore/PlannerService.swift NavPlanner/App/AppEnvironment.swift` 成功。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- HTML 静态本地化覆盖检查成功：126 个 `data-i18n*` 属性均有翻译键，402 个翻译键已被扫描。
- ZULS/ZUAL FR24 验证：本地导航数据库解析 `ZULS -> LXA`、`ZUAL -> NGQ` 成功；无已同步 FR24 会话时，FR24 `airport.json` schedule 探测对 `LXA departures` 和 `NGQ arrivals` 均返回 HTTP 403，符合需要先在 App 内完成 FR24 / Cloudflare 验证并同步会话的降级路径。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- 启动截图确认地图、Plan 表单和底部 `计划 / 机场 / 查询 / 设置` 四标签正常：`/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_7e971695-e3a0-4ab5-afab-04d1f0ecc7fe.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

## 2026-06-05 FR24 浏览器 fetch 调试修复

已完成：

- 按用户反馈重新打开 iPhone 17 Pro Max 模拟器并开启 FR24 专用系统日志。
- 复现并定位“Cookie 已同步、`_frPl` 未同步，但查询仍显示 Cloudflare 验证页”的关键链路：App 内验证页同步成功，CookieStore 中包含 `cf_clearance`、`PHPSESSID`、`XSRF-TOKEN` 等 FR24 Cookie，但 `_frPl` 未由 FR24 页面下发。
- 日志确认旧实现的 FR24 schedule 请求先进入 `FR24BrowserFetch`，但隐藏 WKWebView 使用 `evaluateJavaScript(async () => fetch(...))` 时返回“JavaScript 返回结果的类型不受支持”，随后回落到 `URLSession`，最终被 Cloudflare / 403 拦截。
- 第一轮修复将 `FR24BrowserFetch.evaluateFetch(...)` 改为 `WKWebView.callAsyncJavaScript(...)`，由 WKWebView 等待浏览器上下文中的 `fetch(..., credentials: "include")` 完成；继续调试发现 WKWebView 跨域 `fetch api.flightradar24.com` 仍会返回 `Load failed`。
- 最终修复改为共享隐藏 WKWebView 顶层导航到 FR24 API URL，并在 `didFinish` 后读取页面 JSON 文本；该路径复用用户已验证的 WKWebsiteDataStore Cookie，同时避开跨域 `fetch` 限制。
- 收紧 `URLSession` 兜底策略：如果浏览器上下文已经明确返回 401 / 403、Cloudflare、HTML 或非 JSON 响应，直接向 Query 页暴露浏览器上下文的真实原因，不再用 URLSession 的 Cloudflare 结果覆盖。
- 增加不含敏感值的 FR24 请求诊断日志：仅记录 path、当前 FR24 page URL、HTTP status、content type 和 body 类型，不输出 Cookie、`_frPl` 或响应正文。
- 保持安全边界不变：App 不实现 Cloudflare 绕过、挑战破解、CAPTCHA 自动化或反检测逻辑，只复用用户在 App 内正常完成验证后的浏览器会话。
- 同步更新 README、TODO、Docs/FR24Query.md、Docs/WebBridge.md 和本执行记录。

已完成的本地校验：

- `swift -frontend -parse NavPlanner/Core/WebBridge/NavPlannerSchemeHandler.swift NavPlanner/Core/PlannerCore/PlannerService.swift` 成功。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- CSS 大括号配对检查成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功：RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。

待继续验证：

- ZULS/ZUAL 在线调试已复测：iPhone 17 Pro Max 模拟器中，FR24 `/common/v1/airport.json` 通过隐藏 WKWebView 顶层导航返回 `status=200 type=application/json body=json-object`；`LXA departures offset=24` 从 138 条 raw schedule 中命中 1-2 条 `ZULS -> ZUAL` 航班，Query 页显示 `TV9723`、`TV9943` 等航班卡片。
- FR24 对更早的 `offset=48` schedule timestamp 返回 HTTP 400 JSON；已增加停止条件，较新窗口已有航班后遇到该 400 会停止继续向前扫描并返回已找到结果，避免 Query 页长时间等待。
