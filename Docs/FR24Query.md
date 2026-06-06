# FR24 Query

FR24 Query 是在线增强功能，用于在已填写起飞机场和到达机场后，通过 FR24 Web 公开接口查询航线航班、下载实际轨迹并复用本地 `track-match` 算法匹配航路。该功能不参与核心离线能力闭环：断网、FR24 会话失效、Cloudflare 验证、HTML 挑战页或 FR24 请求失败时，不影响本地航路规划、Procedure 查看、nav-overlay 和离线地图。

## 当前实现

- 主界面保留 `查询` Tab，与 `计划 / 机场 / 设置` 并列；iPhone 竖屏底部为四标签，iPad 和 iPhone 横屏右侧详情栏为 `机场 / 查询 / 设置`。
- `计划` 中旧的“匹配轨迹”按钮已移除；FR24 相关操作集中在 `查询` Tab。
- 查询流程：
  - 读取 `计划` 中的起飞 / 到达输入。
  - Swift 本地服务先用导航数据库解析 ICAO / IATA / 坐标，并生成 FR24 schedule 所需的机场代码。
  - `/api/fr24/search` 按 `NavPlanner-web/src/planner_routes.py` 的 FR24 Web 逻辑扫描 `/common/v1/airport.json` 的 schedule 插件：同时检查起飞机场 `departures` 与到达机场 `arrivals`，按 24 小时窗口向前回看，返回最多 10 个航班。
  - 每个航班展示航班号、起降机场、航司、机型 / 注册号、计划 / 实际时间和飞行时长。
- 航班历史：
  - 每个航班提供“航班历史”子菜单。
  - `/api/fr24/history` 按航班号访问 FR24 数据页，例如 `https://www.flightradar24.com/data/flights/tv9943`，通过已验证的 WKWebView 会话读取页面中能看到的全部历史记录；不再用同航线 schedule 窗口继续回扫来假装历史。
  - 历史页中带 `Play` / `flightId` 的记录可以继续下载 playback 轨迹；免费页面中只有计划信息、没有 `flightId` 的记录仍会显示，但点击下载会按现有错误提示说明缺少 FR24 flightId。
- 轨迹下载：
  - 每个航班和历史记录提供“下载并绘制轨迹”。
  - `/api/fr24/download` 调用 `/common/v1/flight-playback.json?flightId=...&timestamp=...`，提取 `flight.track` / playback JSON 中的轨迹点，写入 App Caches 下的 `NavPlanner/FR24/{flightId}.gpx`、playback JSON 和 meta JSON。
  - 地图使用独立 `fr24TrackLayerGroup` 绘制黑色 GPX 轨迹线，并复用 route world-copy / 经度展开逻辑，避免跨日期变更线出现大直线。
- 轨迹匹配：
  - 每个航班和历史记录提供“匹配轨迹”。
  - 前端先确保轨迹已下载，然后 POST `/api/route/track-match`，继续使用 Swift 本地 airway graph、轨迹误差平滑 / zigzag 清理和 Procedure 自动挂接逻辑。
  - 匹配前会保存当前 route payload，`还原轨迹匹配` 可恢复匹配前航路；`清除轨迹绘制` 只清除黑色 GPX 线，不清除规划航路。
- 缓存管理：
  - Query 页底部显示 FR24 缓存文件数和大小。
  - `删除下载缓存` 调用 `/api/fr24/cache/clear`，只删除 FR24 GPX / playback JSON / meta 缓存，不影响在线地图缓存、离线地图包和导航数据库。
- 网络访问配置：
  - Query 页可在 App 内打开 FR24 验证页，用户正常完成 FR24 / Cloudflare 验证后，点击“同步会话”即可由 Swift 自动读取内置浏览器 CookieStore 中的 FR24 Cookie / `_frPl` 并保存。
  - 手动粘贴 FR24 Web Cookie 与 `_frPl` 仅作为高级可选兜底，主流程不要求用户自己查 Cookie。
  - Swift 使用 UserDefaults 保存配置，只向前端回传是否已配置，不回显敏感值；清除配置不会删除 GPX / JSON 下载缓存。
  - 若 Cookie 中已包含 `_frPl`，Swift 会自动提取；也可通过内置浏览器同步或高级输入单独保存 `_frPl`。
  - schedule/playback 请求优先通过共享的 WKWebView 浏览器上下文执行，复用用户已验证的浏览器会话；Swift 会让隐藏 WKWebView 顶层导航到 FR24 API URL，再读取页面 JSON 文本，避免从 `www.flightradar24.com` 跨域 `fetch api.flightradar24.com` 在 WKWebView 中触发 `Load failed`。航班历史页则顶层导航到 `www.flightradar24.com/data/flights/{flight}`，抽取可见 DOM 行和链接。`URLSession` 只在浏览器运行时失败时兜底；若浏览器上下文已明确返回 401 / 403、Cloudflare 或 HTML 响应，则直接向 Query 页暴露该原因。调试中已确认仅把 Cookie 搬到 `URLSession` 仍可能被 FR24 返回 403。
  - FR24 对过早的 schedule timestamp 可能返回 HTTP 400 JSON；如果较新的窗口已经找到航班，Swift 会停止继续向前扫描并返回已找到的最新航班，避免 Query 页长时间等待。

## 本地 API

```text
GET  /api/fr24/search?departure=...&arrival=...&limit=10
GET  /api/fr24/history?departure=...&arrival=...&flight=...&callsign=...
POST /api/fr24/download
GET  /api/fr24/cache/status
POST /api/fr24/cache/clear
GET  /api/fr24/access/status
POST /api/fr24/access/update
POST /api/fr24/access/clear
GET  /api/route/fr24-match?departure=...&arrival=...&flight_id=...
```

`/api/route/fr24-match` 保留 Web parity 入口：有 `flight_id` 时直接尝试下载 playback 并匹配；无 `flight_id` 时先查最近航班再匹配。iOS UI 已不再从 Plan 直接调用该入口。

## 参考来源

- `NavPlanner-web/src/planner_routes.py`：FR24 schedule/playback 查询、track-match 业务形态、导入轨迹平滑、zigzag 清理和 Procedure 自动挂接参考。
- `chaoshaowei/flightradar-kml-gpx`：使用 FR24 `flightId` 请求 `flight-playback.json`，从 `flight.track` 写出 GPX / KML 的流程。

## Cloudflare 边界

- App 不实现 Cloudflare 绕过、挑战破解、CAPTCHA 自动化或反检测逻辑。
- 用户可在 App 内打开 `flightradar24.com` 并正常完成 FR24 / Cloudflare 验证，App 只同步该内置浏览器会话，避免手动查找 Cookie。
- App 不伪造或破解 Cloudflare 验证，不生成 `_frPl`，也不自动完成挑战；如果浏览器上下文请求仍返回 401 / 403，需要用户重新打开验证页完成验证并同步会话。
- 如果 FR24 返回 `cf-mitigated: challenge`、Cloudflare HTML 或非 JSON 响应，Swift 会快速返回可本地化错误，提示更新已验证会话；Plan、Airport、Procedure、nav-overlay 和离线地图继续可用。
- 调试日志只记录 Cookie / storage 键名、HTTP 状态、content type 和 body 类型，不输出 Cookie、`_frPl` 或响应正文。

## 验证重点

- 每次修改 FR24 相关功能时，固定使用 `ZULS` / `ZUAL` 作为 FR24 查询验证航线；没有已同步会话时，至少验证该航线会走到会话缺失 / Cloudflare 降级提示，不阻塞本地核心能力。
- 2026-06-05 模拟器验证：`ZULS -> ZUAL` 通过隐藏 WKWebView 顶层导航获取 FR24 JSON，`LXA departures offset=24` 命中 1-2 条航班，Query 页显示 `TV9723`、`TV9943` 等航班卡片；`offset=48` 返回 HTTP 400 后会停止扫描并返回已找到结果。
- 2026-06-06 更新：历史查询改为读取 FR24 航班数据页；例如 `TV9943` 会访问 `/data/flights/tv9943` 并展示页面上可见的全部历史 / 计划记录，只有带 `flightId` 的记录才能继续下载 playback GPX。
- 离线 / 会话缺失 / Cloudflare 挑战 / FR24 请求失败时：Query 页显示错误，本地核心能力继续可用。
- 下载成功时：黑色 GPX 轨迹显示在地图上，跨日期变更线不画大直线。
- 匹配成功时：规划航路替换为本地 track-match 结果，并可通过“还原轨迹匹配”恢复。
- 缓存清理只影响 `NavPlanner/FR24`，不影响 `MapCache`、`MapOffline` 和导航数据库。
