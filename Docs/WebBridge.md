# WebBridge

WebBridge 用于让 WKWebView 地图内核调用 Swift 本地服务，不启动 Python server。

## 当前 scheme

```text
navplanner://app/map.html
navplanner://app/styles.css
navplanner://app/app.js
navplanner://app/nav-icons/{icon}
navplanner://app/vendor/{library}/{file}
navplanner://api/header
navplanner://api/search?q=...
navplanner://api/airport/{ident}
navplanner://api/procedure/{type}/{airport}/{procedure}/{transition}
navplanner://api/airway/{airway}
navplanner://api/nav-overlay?south=...&west=...&north=...&east=...&zoom=...
navplanner://api/route/resolve?departure=...&arrival=...&route=...&departure_runway=...&arrival_runway=...
navplanner://api/route/fr24-match?departure=...&arrival=...&flight_id=...
navplanner://api/route/track-match
navplanner://api/fr24/search?departure=...&arrival=...&limit=10
navplanner://api/fr24/history?departure=...&arrival=...&flight=...&callsign=...&limit=10
navplanner://api/fr24/download
navplanner://api/fr24/cache/status
navplanner://api/fr24/cache/clear
navplanner://api/fr24/access/status
navplanner://api/fr24/access/update
navplanner://api/fr24/access/clear
navplanner://api/map-cache/status
navplanner://api/map-cache/clear
navplanner://api/map-cache/{provider}/{z}/{x}/{y}.{ext}
navplanner://api/terrain/terrarium/{z}/{x}/{y}.png
navplanner://api/offline-maps
navplanner://api/offline-maps/select
navplanner://api/offline-maps/delete
navplanner://api/offline-maps/compact
navplanner://api/offline-maps/download
navplanner://api/offline-maps/cancel
navplanner://api/offline-maps/tile/{z}/{x}/{y}.png
navplanner://api/offline-maps/pmtiles/{name}.pmtiles
```

Web 参考版代码中大量使用 `/api/...` 和 `/nav-icons/...` 绝对路径。iOS 版 `NavPlannerSchemeHandler` 会把 `navplanner://app/api/...` 归一化到本地 API，同时支持嵌套静态资源读取。

## JS -> SwiftUI

地图内核通过 `window.webkit.messageHandlers.navplanner.postMessage(...)` 回传：

- `mapReady`
- `airportSelected`
- `pointSelected`
- `selectDatabase`
- `setAppIcon`

`selectDatabase` 会由 Swift 侧弹出 `UIDocumentPickerViewController`，允许选择 `.s3db`、`.sqlite`、`.sqlite3`、`.db`。导入结束后 Swift 调用 `window.navplannerNativeDatabaseSelected(payload)` 回传状态，Web 设置页会刷新数据库名称、状态、header 和 nav-overlay。

`setAppIcon` 接收 `{ iconChoice: "day-high" | "primary" | "day-soft" | "night-high" | "night-medium" | "night-soft" }`，由 Swift 侧映射到 `AppIconDayHigh`、主图标、`AppIconDaySoft`、`AppIconNightHigh`、`AppIconNightMedium` 或 `AppIconNightSoft`，调用 iOS 替代图标 API。切换结束后 Swift 调用 `window.navplannerNativeAppIconChanged(payload)` 回传当前选择或错误信息。

## 当前文件

- `NavPlanner/Core/WebBridge/NavPlannerSchemeHandler.swift`
- `NavPlanner/Core/WebBridge/MapBridgeScriptHandler.swift`
- `NavPlanner/Features/Map/MapWebView.swift`

## 资源路径

源码中的 `NavPlanner/Resources/Web` 会打包为 App Bundle 顶层 `Web/` 目录。不要把目录命名为顶层 `Resources/`，iOS 安装器会把这种 bundle 视为无效应用。

`/api/map-cache/google_terrain/...` 和 `/api/terrain/terrarium/...` 由 Swift `OnlineTileCache` 处理：先查 Caches 目录，未命中时异步下载并返回带 `X-Map-Cache: QUEUED/PENDING/MISS` 的透明 PNG，前端异步瓦片层会轮询直到真实瓦片命中。`google_terrain` 通路已加入 Esri World Topographic、OpenTopoMap 和 Google 子域的顺序兜底，下载失败或离线时不会让 Leaflet 卡住 nav-overlay 和本地查询。`/api/map-cache/status` 返回缓存根目录、大小、文件数、后台请求数和失败冷却数；`/api/map-cache/clear` 清理 Caches 中的在线瓦片并重置 pending / failed 记录。真实离线资源方面，MBTiles、Web `tiles.sqlite`、Web `tiles/` 文件布局已经通过 Swift `MapStore` 读取；PMTiles 通过 `/api/offline-maps/pmtiles/{name}.pmtiles` 返回 `Accept-Ranges` / `Content-Range`，供前端 `pmtiles://` protocol 随机读取。

`/api/offline-maps/download` 和 `/api/offline-maps/cancel` 已由 Swift 本地 `MapStore` 承接。前端提交 Web 版同形态 payload 后，iOS 会在 Application Support 的 `MapOffline/{name}/tiles.sqlite` 创建 SQLite 瓦片库，后台下载瓦片、轮询 `download_job`、支持取消，并在完成时写入 `metadata.json`。下载任务启动前会先探测 provider；运行时使用 12 worker / 24 inflight 有界并发，状态里返回 `active_downloads`、`bytes_per_second`、`tiles_per_second` 和慢请求提示；同名资源里的 Web 旧散瓦片会迁移进 SQLite。按最新需求，离线地图下载不再接收或暴露代理字段。该路径不启动 Python server。

## 当前限制

- `route/resolve` 已支持 DCT、航点串、基础航路展开、同航路优先自动规划、partial airway + DCT fallback 和 `***` 自动补航段；手动航路边界点会按当前/下一条 airway 与邻近点解析。
- `route/resolve` 的手动 route 输出已对齐 Web：不会为终点机场额外追加 final direct leg，`***` 补全航段会以展开后的航路文本作为 `route_display`。
- `route/resolve` 的 airway graph 和 route-between 结果已按当前数据库路径缓存；Settings 导入数据库成功后 Swift 会主动失效缓存。
- `route/resolve` 已接收起飞/到达跑道参数；Route 留空时会尝试返回 `selected_procedures` 和 `selected_runways`，让 Web 工作台自动加载 SID / STAR / APPROACH。
- `route/resolve` 对手动 route 的错误处理已按 Web API 行为返回 400 JSON：未知 waypoint、起始 `DCT`、DCT 缺目标、airway 缺 exit、`***` 缺目标等不会再静默回退。
- `route/track-match` 已接收 POST JSON `{ departure, arrival, track_points }`，在 Swift 本地 airway graph 上把导入轨迹点匹配为 route payload，并按 Web 参考逻辑执行同航路简化、轨迹误差约束、zigzag 平滑清理和匹配后 Procedure 自动挂接；`Tools/TrackParity` 已提供 7 个 Swift/Web 可重复对照 case。
- `fr24/search`、`fr24/history`、`fr24/download`、`fr24/cache/*` 和 `fr24/access/*` 已接入 Swift 本地服务。查询 / 下载使用 FR24 Web 作为在线增强：Query 页可通过 JS bridge 打开 App 内 FR24 验证浏览器，用户正常完成 FR24 / Cloudflare 验证后由 Swift 自动同步内置浏览器 CookieStore 中的 Cookie / `_frPl`；后续 `/common/v1/airport.json` schedule 插件和 `/common/v1/flight-playback.json` 请求会优先由共享 WKWebView 浏览器上下文顶层导航到 FR24 API URL 并读取 JSON 文本，避免 WKWebView 跨域 `fetch` 的 `Load failed`。Swift `URLSession` 只在浏览器运行时失败时兜底；若浏览器上下文已明确返回 401 / 403、Cloudflare 或 HTML 响应，则直接向 Query 页暴露该原因。下载成功后会在 Caches 的 `NavPlanner/FR24` 中写入 GPX、playback JSON 和 meta JSON。会话缺失、Cloudflare 验证页、网络失败或 FR24 权限限制时返回可本地化错误，不阻塞本地核心 API。
- `route/fr24-match` 保留 Web parity 入口：有 `flight_id` 时尝试下载该 FR24 playback 轨迹并匹配；无 `flight_id` 时先查最近航班再匹配。iOS UI 已将 FR24 操作集中到 `查询` Tab，不再在 Plan 中提供旧按钮。
- 完整图搜索的 single-airway / mixed-route 权重细节、跨航路自动拼接和剩余错误提示仍需继续逐项对齐 Web `planner_routes.py`。
- `offline-maps/pmtiles` Range 读取已实现，但仍需用真实 PMTiles 包做 MapLibre 离线矢量底图视觉回归。
- POST body 已支持普通 JSON 和 body stream；下载、取消和状态轮询当前均由 Swift `MapStore` 本地任务处理，不启动 Python 或局域网服务。
