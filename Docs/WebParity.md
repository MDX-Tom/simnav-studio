# Web 复刻差距记录

本文记录 iOS App 与 `NavPlanner-web/` 的功能、交互和 API 对齐状态。`NavPlanner-web/` 仍是只读参考项目，所有迁移副本和适配代码只放在 iOS 工程中。

## 已对齐

- iOS `NavPlanner/Resources/Web/` 已包含 Web 参考版 `index.html` 的副本，入口文件为 `map.html`。
- iOS `NavPlanner/Resources/Web/` 已包含 Web 参考版 `app.js`、`styles.css` 和 `nav-icons/`。
- Leaflet、MapLibre GL、maplibre-contour、pmtiles 已打包到 `vendor/`，启动地图工作台不依赖 `unpkg.com`。
- `WKURLSchemeHandler` 支持 `navplanner://app/...` 嵌套资源，并兼容 Web 代码中的 `/api/...` 绝对路径。
- Web 工作台可通过 Swift 本地服务读取 `/api/header`、`/api/search`、`/api/airport/{ident}`、`/api/procedure/...`、`/api/nav-overlay`。
- `/api/route/resolve` 已接收 `departure_runway` / `arrival_runway`；Route 留空时可自动选择 SID / STAR / APPROACH，并通过 `selected_procedures` 驱动 Web 工作台绘制 Procedure。
- `/api/route/resolve` 已迁移 airway graph 基础 Dijkstra、同航路优先、partial airway + DCT fallback、`***` 自动补航段、带 airway 上下文的边界点解析、起降点 / 普通 route token 双查找优先级、自动航路连续 airway 合并、重复 airway / A-B-A 合并、内部 excluded airway 搜索通路，以及按数据库路径缓存的 airway graph / route-between；airway graph/expand 分组、heap tie-break、Procedure 候选顺序、Approach 前缀排序和 SQLite NULL 处理已按 Web 行为修正；`Tools/RouteParity` 已可重复比较 22 个 route resolve case，并包含点列签名和跨日期变更线几何摘要。
- `/api/route/resolve` 已按 Web API 行为返回手动 route 错误：未知 waypoint、起始 `DCT`、DCT 缺目标、airway 缺 exit、`***` 缺目标等会返回 400 JSON。
- `/api/route/resolve` 手动 route payload 已对齐 Web：终点机场仅进入 `points`，不额外生成 final direct leg；`***` 补航段后的 `route_display` 使用展开后的 legs。
- `/api/route/track-match` 已迁移导入轨迹点的本地 airway graph 匹配、同航路简化、轨迹误差约束、单航路替换保护、zigzag 平滑清理，以及匹配后 SID / STAR / APPROACH 自动挂接；`Tools/TrackParity` 已可重复比较 7 个 track-match case，覆盖合成导入轨迹、Procedure 自动挂接、日期变更线和基础错误语义；`/api/route/fr24-match` 的离线响应可触发 Web 粘贴轨迹降级流程。
- WKWebView 已接入 JavaScript alert / confirm / prompt，Web 版粘贴轨迹提示可以在 iOS 上弹出原生输入框。
- Procedure API 已按 Web `procedure_geometry` 迁移 RF / AF 弧线、复飞路径分段和末端等待航线几何；`Tools/ProcedureParity` 已可重复比较 6 个 Procedure geometry case，覆盖 RF 弧线、复飞 / holding、transition 合并、ZULS 复飞异常圆弧回归和空结果语义。
- nav-overlay 已按 Web `planner_overlay.py` 迁移本地缓存、世界副本偏移、跨日期变更线边界判断、航路空间分桶、航路标签预算、terminal waypoint / navaid、跑道和 ILS 输出；典型跨日期变更线视野与 Web 参考 payload 计数一致。
- `/api/map-cache/google_terrain/...`、`/api/terrain/terrarium/...` 已由 Swift 本地异步缓存承接；`google_terrain` 增加 Esri / OpenTopoMap / Google 顺序兜底，没有真实底图、下载失败或离线时不阻塞 nav-overlay。
- nav-overlay 前端绘制采用双缓冲 layer group 替换，缩放后旧航路叠加层会保留到新叠加层绘制完成；iPhone 额外使用 SVG renderer 和延迟旧层移除减少闪烁。
- iPhone 已按本地 App 需求调整为上部地图、下部 Plan / Airport / Settings 三标签；标签切换不重建地图。
- iPad 保持既有 Web 工作台布局，并新增 Settings 切换页。
- Settings 支持本地数据库选择、日间/夜间/系统自动外观模式、日间三档 / 夜间三档 App 图标选择、离线地图管理、在线地图缓存管理和版权说明。
- 地图右下角 attribution / 水印已移除。
- Leaflet 双击缩放已禁用，并增加页面级双击/双触防放大保护，避免地图或下方面板空白处误放大。
- MBTiles、Web `tiles.sqlite`、Web `tiles/` 文件布局已可由 Swift `MapStore` 读取本地瓦片；PMTiles 已通过本地 Range 响应接入 MapLibre `pmtiles://` 基础通路。
- `/api/offline-maps/download` 已从占位改为 Swift 本地下载任务，支持 Web 版下载表单的供应商、范围、缩放、分级策略、状态轮询、取消和完成后 SQLite 瓦片库读取；下载器已保留启动前 provider 探测、12 worker / 24 inflight 有界并发、慢请求提示、连续失败中止、250 瓦片批量提交和旧散瓦片迁移。按最新产品要求，iOS 版不再暴露离线地图下载代理设置。
- Plan / Airport / Settings 常用路径已从单一中文化推进到中英双语本地化，包含表单、按钮、空状态、机场详情、Procedure、地图弹窗动作、航路状态、常见错误提示、离线地图管理和在线缓存摘要；Settings 新增系统语言 / 简体中文 / English 选择，默认按系统首选语言显示。Procedure 类型和必要航空标识固定为 `SID` / `STAR` / `APPROACH`、`DCT`、`IFR`、`AIRAC` 等英文，避免翻译破坏数据语义。
- iPhone 17 Pro 模拟器已验证 Web 移动布局加载，`ZBAA` 搜索结果可显示。
- iPad Pro 13-inch (M5) 模拟器已验证 Web 工作台加载，竖屏按 Web 窄屏布局显示。

## 部分对齐

- `/api/route/resolve` 当前返回本地手动解析和自动规划 payload，支持 DCT、普通航点串、基础“航路名 + 退出点”展开、`***` 自动补航段、自动规划连续 / 重复 airway 合并，以及 Route 留空时的 SID / STAR / APPROACH 自动接入；22 个 RouteParity case 已无差异，仍需继续扩展更多数据库样例并把工具沉淀为常规测试目标。
- `/api/route/track-match` 已能离线匹配导入轨迹，并对齐 Web 版轨迹误差平滑、zigzag 清理和 Procedure 自动挂接；7 个 TrackParity case 已无差异，仍需继续扩展真实 FR24 噪声轨迹和更多异常样例；在线 FR24 查询和剩余错误提示仍需继续迁移。
- 离线地图管理 UI 已能打开并收到本地状态，入口从 Settings 的“管理离线地图”进入，弹窗日间/夜间主题已跟主界面同步；本地瓦片读取、PMTiles Range 和 Web 同形态并发下载任务已接入，真实 PMTiles 包视觉显示以及大范围下载性能仍需在模拟器 / 真机验证。
- iOS 当前优先全屏 Web 工作台以贴近 Web 行为；原生 SwiftUI Plan / Airport / Selection 面板保留在代码中，后续再按复刻结果决定是否原生化重接。

## 尚未对齐

- 完整航路解析和自动航路规划。
- FR24 在线查询增强。
- 在线瓦片缓存已能覆盖 terrain / terrarium 首轮需求并提供地形底图兜底；仍需补配额控制和更完整的失败状态 UI。
- 离线地图下载器仍需用真实大范围任务做真机 / 模拟器压力回归，重点观察取消响应、直连网络和 SQLite 写入性能。
- 真实 PMTiles 包的 MapLibre 离线矢量底图视觉回归。
- Web 版弹窗交互的完整验收：规划航路命中层、非规划航路点击、空白关闭、跨日期变更线多世界副本。
- 底层服务长错误、真实在线失败状态和更多控制台状态中仍可能有未本地化文案，需要逐步补齐中文 / English 双语展示，同时保持交互结构与参考版一致。
- iPad 横屏、iPad 竖屏、iPhone 真机键盘高度和 Home Indicator 细节仍需逐项截图回归；当前 iPhone 17 Pro 模拟器已确认键盘可唤起且页面不整体上移。
- 本地导入数据库当前只做文件复制与 SQLite 打开校验，尚未做完整 schema 兼容性检查。

## 下一步验收清单

- 继续扩展 Xcode `ParityChecks` target 下的 `Tools/RouteParity`、`Tools/TrackParity` 和 `Tools/ProcedureParity`，用更多典型航线、真实导入轨迹、Procedure 边界样例和错误边界验证本地 payload 与 Web 参考一致。
- 用跨日期变更线航线继续验证前端 polyline、多世界副本 hit layer 和弹窗不出现大直线或点击错位。
- 用 `ZBAA`、`RJTT`、`PHNL` 等机场逐项对比 SID / STAR / APPROACH 列表和绘制结果。
- 在飞行模式下验证：启动、搜索、机场详情、Procedure 预览、nav-overlay、离线地图状态均不依赖 Python server 或外网。
