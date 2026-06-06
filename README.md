# NavPlanner iOS

NavPlanner 是一个 iPhone / iPad Universal App 项目，目标是做成本地优先、可完全离线运行的航空航路规划 App。当前阶段采用混合架构：SwiftUI 原生外壳 + WKWebView 地图内核 + Swift 本地服务层。

`NavPlanner-web/` 是只读参考项目，用于理解现有 Web 航路规划器的功能、数据结构、API 形态、地图交互和算法行为。除非用户明确要求，不修改该目录。

## 新线程接手摘要

- 先读本文件、`TODO.md`、`codex_report.md`、`Docs/CodexGoal.md`，再按任务读取对应子文档。
- `NavPlanner-web/` 仅作为只读参考：可读 `README.md`、`src/`、`static/`、现有算法和交互行为，不要改其中任何文件。
- 当前 App 不是 WKWebView 套壳：SwiftUI 提供原生外壳、主题/状态栏同步、数据库导入和本地服务；WKWebView 承载地图工作台；Swift 本地 API 通过 `navplanner://api/...` 提供离线核心能力。
- 核心能力必须离线可用：数据库查询、航路规划、Procedure 查看、nav-overlay、离线地图读取不能依赖 Python server、远程服务或局域网服务。
- 下一阶段主线已经从“基础工程搭建”转为“Web parity、性能、真实数据验证、离线地图和真机体验打磨”。新的 `/goal` 草案见 `Docs/CodexGoal.md`。
- Web/CSS/JS 变更后要刷新 `NavPlanner/Resources/Web/map.html` 的资源版本；代码变更后同步更新相关 `Docs/*.md`、`TODO.md` 和 `codex_report.md`。

## 当前阶段

- 已创建 `NavPlanner.xcodeproj` 和 `NavPlanner` SwiftUI App target。
- 支持 iPhone / iPad：iPad 保持 Web 工作台式布局，iPhone 竖屏使用地图优先的上下布局，最新移动比例约为上部 66% 地图 + 下部 34% 输入工作区，并在最底部保留约 19px 的低高度四标签；iPhone 横屏切换为 iPad 横屏式左计划栏 / 中地图 / 右详情栏布局，但字体、输入框、按钮、地图标签和弹窗仍沿用 iPhone 竖屏的紧凑尺寸。横屏时 SwiftUI 让 WebView 横向铺满，由 Web 层识别刘海在左 / 右，只在刘海侧保留完整安全区，另一侧缩到 8px 以释放可用宽度；iPhone 17 Pro Max 等更宽 iPhone 横屏也会进入同一套 1024px 紧凑工作台规则，避免退回桌面布局。
- 已把参考导航数据库复制为 App 自己的 `NavPlanner/Resources/Database/navdata.sqlite`，启动后复制到 Application Support 使用。
- 已实现 Swift 本地 API 层：`header`、`search`、`airport`、`procedure`、`nav-overlay` 的第一阶段版本。
- 当前 bundle identifier：`com.midaxia.navplanner`。
- iOS App Bundle 顶层不会包含名为 `Resources` 的目录；资源目录分别打包为 `Web/` 和 `Database/`，避免安装器误报 bundle id 缺失。
- 已实现 `WKURLSchemeHandler`：Web 地图通过 `navplanner://api/...` 调 Swift 本地服务，不启动 Python server。
- 已实现 `WKScriptMessageHandler`：地图点击可回传 SwiftUI 原生外壳。
- 已将 Web 参考项目的静态工作台复制到 iOS 自有资源目录：`NavPlanner/Resources/Web/map.html`、`styles.css`、`app.js`、`nav-icons/`。
- 已将 Leaflet、MapLibre GL、maplibre-contour、pmtiles 前端运行时打包到 `NavPlanner/Resources/Web/vendor/`，地图内核启动不依赖 CDN。
- SwiftUI 当前提供全屏 WKWebView 容器和本地服务层，Plan、Airport、Settings、Selection、Offline Maps 等交互由本地 Web 工作台渲染，以优先满足 Web 行为复刻。
- iPhone 下部工作区已拆分为中文图标标签 `计划`、`机场`、`查询`、`设置`，标签采用更薄的紧凑玻璃质感并独占底部一行，同时为 iOS Home Indicator 保留安全区距离；底部标签栏当前整体向下 14px，并左右各内收 20px，标签预留行收窄到 9px 以同步增加中部工作区高度；工作区顶部新增类似系统输入栏的上拉手柄，可把地图区域从默认约 66% 压缩到最小 30%，标签切换时保持上拉位置，软键盘出现时仍走原有 `visualViewport` 自动上拉逻辑；手柄当前高度和面板顶部预留均为 20px，外层胶囊光晕改为上下居中的固定高度，保留按下/拖动动画和帧节流布局更新，减少小屏上划掉帧并进一步压缩 banner 上下占位；切换时顶部地图实例、视角和叠加层保持不变。
- iPhone 横屏不显示底部四标签，改用 iPad 工作台的左右折叠栏与右侧 `机场 / 查询 / 设置` 详情切换；左右面板使用横屏专用窄列宽，刘海侧安全避让，非刘海侧尽量贴近机身圆角边缘，避免左右同时留出大空白。当前紧凑布局断点已扩展到 1024px，覆盖 iPhone 17 Pro Max 等更宽机型。
- iPad 工作台新增 `Airport / Query / Settings` 详情切换，原有左侧计划栏、地图区和详情区布局保持不变；左右竖向折叠栏按钮已按日间 / 夜间主题分别使用浅蓝灰和深色玻璃配色，并在 WebView 首屏加载前预设主题，同时用显式日间样式兜底，避免日间模式短暂或持续显示深蓝长条。
- Settings 页面支持从 Files 选择 `.s3db` / `.sqlite` / `.sqlite3` / `.db` 本地导航数据库，导入后 Swift 本地 SQLite 服务即时切库。
- Settings 页面支持系统自动、日间、夜间外观模式，并新增系统语言 / 简体中文 / English 语言选择；语言默认跟随 `navigator.languages[0]` / 系统首选语言，偏好保存到 `localStorage.navplannerLanguageMode`，切换后会即时刷新 Settings、Plan、Airport、Procedure、已打开的地图弹窗、离线地图和常见状态/错误提示。无论选择哪种语言，`SID` / `STAR` / `APPROACH`、`DCT`、`IFR`、`AIRAC`、`PMTiles`、`MBTiles`、`SQLite` 等航空和技术标识保持英文。Settings 仍显示离线 MVP、地图/数据版权和本地优先说明；Web 主题会同步到 SwiftUI 外壳，顶部刘海 / 状态栏安全区也跟随日间或夜间切换；应用图标提供日间三档和夜间三档：默认主图标为日间均衡，日间高饱和备用图标保留源图饱和度但不额外提升，上一轮“默认”档位已下放为柔和；夜间版使用类似反色的深蓝黑地形、紫色地形层次和暗橙航路，弱化整图玻璃罩，把 Liquid Glass 反光主要放在航路和山体局部；当前六套图标均已加宽外框，夜间图标仍保留更强轮廓；iOS 替代图标回调状态也会按当前语言显示，不直接透出 Swift 中文原文。
- Settings 页面已集中管理离线地图和在线地图缓存：离线地图卡片下排提供“管理离线地图 / 刷新状态”，下载功能整合在离线地图管理页内部；在线地图缓存卡片下排提供“清理缓存 / 刷新缓存”，并通过 Swift 本地 `/api/map-cache/status` / `clear` 统计和清理在线增强底图缓存。
- 已隐藏 Leaflet / MapLibre 右下角版权水印；版权说明集中放到 Settings 页面。
- 已关闭地图和页面空白处的双击/双触放大，保留单指平移、双指缩放、缩放按钮、触控输入和地图点击弹窗。
- iPhone WebView 已撤销零高度 input accessory 覆盖，避免破坏 WKWebView 键盘 responder；Swift 侧保留 WKWebView 外层 scroll view 的输入触控能力并关闭 bounce / 自动 inset，同时由 `UIScrollViewDelegate` 将外层 `contentOffset` / inset 锁回 0，避免 UIKit 键盘自动滚动和 Web 布局互相拉扯；Web 侧用非 fixed 根页面和页面级 scroll reset 锁住页面级滚动，输入框改为原生单击聚焦加 click 阶段兜底聚焦，并完全移除输入框 `touchstart` 聚焦桥；软键盘出现时 Web 工作台会按 `visualViewport` 缩到键盘上方可见高度，临时隐藏底部 Tab，把当前输入面板留在键盘上方并滚动到当前输入框，键盘收起后恢复原布局；iPhone 的 Plan 输入框实际字号保持 16px 以规避 WebKit 聚焦自动缩放，视觉上再缩放回约 9.5px 的小屏紧凑字号。
- iPhone 地图弹窗、机场/航点/导航台/航路标签和符号已进一步缩小；iPad 地图弹窗也已同步为与 iPhone 一致的半透明毛玻璃、内嵌圆角标题和更紧凑宽度，机场弹窗操作按钮仍仅在机场类型中显示。
- Plan / Airport / Settings 常用路径已从单一中文化推进到中英双语本地化：表单标签、占位提示、按钮、机场详情、Procedure 空状态、弹窗动作、离线地图管理标题、航路状态和常见错误提示可随语言选择切换；语言切换时当前打开的机场 / 航点 / 航路弹窗会按原位置和原内容重新渲染。iPhone Airport 页的机场槽位、跑道筛选和机场标题框已进一步压缩高度与字号，起飞 / 到达 / 手动机场详情头部改为无背景纯文本信息块，跑道列表使用专用两列布局；Selection 的 Procedure 明细表已改为 `SEQ / WAYPOINT / ALTITUDE / SPEED / LEG / TURN` 顺序，`LEG / TURN` 列压缩到旧视觉宽度约 60%，iPhone 下标题和表头继续缩小，日间主题下高度 / 速度 / leg 正文使用不透明深色文字和轻量行底色保持可读；Procedure 类型显示固定为 `SID` / `STAR` / `APPROACH`，不随界面语言翻译；少量底层服务长错误、真实在线失败状态和控制台日志仍在后续收敛。
- 已实现离线地图资源扫描、本地瓦片读取和下载：扫描 Application Support 中的 PMTiles / MBTiles / SQLite 单文件资源，也兼容 Web `map_offline` 目录；MBTiles、Web `tiles.sqlite`、Web `tiles/` 文件布局可直接读取瓦片，PMTiles 通过 Range 响应供 MapLibre `pmtiles://` 协议读取；离线地图管理页使用暗色透明背景和居中紧凑弹窗，下载标签可在 iOS 本地下载 OpenTopoMap / Esri / OSM / OpenFreeMap 瓦片并写入 SQLite 瓦片库。按最新需求已取消离线地图下载代理服务器设置，Swift 下载器使用系统直连 URLSession，并保留启动前 provider 探测、12 worker / 24 inflight 有界并发、慢请求提示、连续失败中止和旧散瓦片迁移。
- 已补齐 Web UI 启动所需的 `/api/airway`、`/api/map-cache`、`/api/terrain`、`/api/offline-maps/*` 通路；在线地形图和 terrarium 高程瓦片可由 Swift 本地缓存异步下载，`google_terrain` 通路已加入 Esri / OpenTopoMap 兜底，底图缺失或下载失败不阻塞 nav-overlay；在线缓存支持状态统计和清理。
- `/api/route/resolve` 当前支持本地 DCT、航点串、基础“航路名 + 退出点”展开、同航路优先自动规划、partial airway + DCT fallback 和 `***` 自动补航段；Route 留空时会按跑道选择 SID / STAR / APPROACH 接入本地离线航路。airway graph 与 route-between 已按当前数据库缓存，导入新数据库后自动失效；airway graph、airway 展开、Dijkstra tie-break、Procedure 候选分组、Approach 排序和 `NSNull` 文本处理已进一步按 Web `planner_routes.py` 对齐，8 条典型自动航线的 `route_display`、legs、点列签名、距离和 SID / STAR / Approach 选择已与 Web 探针对齐；自动航路压缩已按 Web `_merge_continuing_airway_legs` / `_merge_repeated_airway_legs` 迁移连续 airway 与 A-B-A 重复 airway 合并，`route_display` 也区分普通显示和展开显示；起降点与普通 route token 已拆成 Web 同形态查找优先级，避免 IATA 与 waypoint 同名时手动航路选错；Swift 内部搜索已补齐 Web `_ifrr_route_between_with_exclusions` 的 excluded airway 通路，非空排除集不会污染默认 route-between 缓存；手动航路缺目标、未知 fix、非法 airway 边界等错误会按 Web 版返回 400 JSON。前端按航点绘制的主航路会把全部参与绘制的航点加上与 Procedure 表格点击一致的脉冲高亮。更多异常航线和前端 hit layer 仍在继续补充回归。
- 已新增 `Tools/RouteParity/route_parity.py` 可重复回归工具，会编译 Swift 探针并与只读 Web 参考实现对比 22 个 `/api/route/resolve` case，覆盖典型自动航线、跨日期变更线自动 / 手动航线、手动航路、IATA/waypoint 查找优先级、点列几何摘要和错误语义。
- 已新增 `Tools/TrackParity/track_parity.py` 可重复回归工具，会用 Web 参考 route resolve 生成离线合成轨迹点，再分别对比 Web `match_imported_track_route(...)` 与 Swift `trackMatchPayload(...)`，当前覆盖 7 个 `/api/route/track-match` case。
- 已新增 Xcode `ParityChecks` Aggregate Target 和共享 scheme，统一运行 RouteParity / TrackParity / ProcedureParity；也可通过 `python3 Tools/Parity/run_all_parity.py` 在命令行直接运行。
- `/api/route/track-match` 已支持导入轨迹点的本地 airway 匹配，并继续迁移 Web 版 FR24/导入轨迹的轨迹误差约束、单航路替换保护、zigzag 平滑清理和 Procedure 自动挂接；`查询` Tab 与 Swift 本地 `/api/fr24/search`、`history`、`download`、`cache`、`access` API 可按 FR24 Web schedule/playback 逻辑查询航线航班、按 `https://www.flightradar24.com/data/flights/{flight}` 航班数据页显示可见历史、下载并缓存 GPX / playback JSON、用黑色线绘制轨迹，并复用本地 `track-match` 匹配航路。历史页解析已补强表头/单元格字段、实际起降时间、机型提取、`Scheduled` 单条限制和两列历史卡片；FR24 轨迹相邻点超过 20nm 时以黑色虚线连接跳点段。FR24 仍是在线增强，失败、断网或会话缺失不会阻塞本地核心能力。
- FR24 查询使用 Web 会话方式：Query 页可在 App 内打开 FR24 验证页，用户正常完成 FR24 / Cloudflare 验证后由 App 自动同步内置浏览器中的 FR24 Cookie / `_frPl`；FR24 schedule/playback 请求会优先通过共享 WKWebView 浏览器上下文顶层导航到 FR24 API URL，再读取页面 JSON 文本，航班历史页会顶层导航到 FR24 数据页并抽取可见 DOM 行和链接，避免跨域 `fetch` 在 WKWebView 中触发 `Load failed`。Swift `URLSession` 仅在浏览器运行时失败时兜底；若浏览器上下文已明确返回 401 / 403、Cloudflare 或 HTML 响应，则直接向 Query 页暴露该原因。App 不实现 Cloudflare 绕过、挑战破解或 CAPTCHA 自动化，只复用用户已完成验证的浏览器会话。
- `/api/procedure/...` 已按 Web `procedure_geometry` 迁移 RF / AF 弧线、复飞段分割和末端等待航线几何；`Tools/ProcedureParity` 已可重复比较 6 个 Procedure case，覆盖 RF 弧线、复飞 / holding、transition 合并、ZULS 复飞异常圆弧回归和空结果语义。
- `/api/nav-overlay` 已按 Web `planner_overlay.py` 迁移本地缓存、世界副本边界过滤、空间分桶、航路标签预算、terminal waypoint / navaid、跑道和 ILS 输出；跨日期变更线视野的 payload 计数已与 Web 参考一致，前端刷新采用双缓冲图层替换，iPhone 使用 SVG renderer + 延迟移除旧层来降低缩放后灰色航路叠加层闪烁；矢量底图拖动/缩放期间改为 CSS 镜像并在结束后同步真实 MapLibre 相机，减少底图与航路层动画不同步。

## 目录结构

```text
NavPlanner.xcodeproj/          Xcode 工程
NavPlanner/
  App/                         SwiftUI App 入口、根布局、全局环境
  Features/
    Map/                       WKWebView 地图容器
    Plan/                      航路计划与本地搜索面板
    Airports/                  机场详情面板
    OfflineMaps/               离线地图资源状态
    Selection/                 地图选择状态
    Search/                    搜索结果行
  Core/
    LocalDataStore/            SQLite 数据库安装与薄封装
    PlannerCore/               本地 API 与基础规划服务
    MapStore/                  离线地图资源模型
    WebBridge/                 navplanner:// scheme 与 JS 消息桥
    Models/                    通用数据模型
  Resources/
    Web/                       Web 参考版地图工作台副本与本地 vendor 资源，打包到 App Bundle 的 Web/
    Database/                  内置导航数据库，打包到 App Bundle 的 Database/
    SampleMaps/                后续内置样例地图资源
  Support/                     隐私清单与资源目录
Docs/                          子功能设计文档
  RouteResolve.md              航路解析、自动规划和 Web parity 差距
  RouteParity.md               Swift/Web route resolve 回归工具
  TrackParity.md               Swift/Web track-match 回归工具
  FR24Query.md                        FR24 查询、GPX 缓存和轨迹匹配增强
  ProcedureParity.md           Swift/Web Procedure 几何回归工具
  CodexGoal.md                 新线程继续开发时推荐使用的 /goal 草案
  Settings.md                  设置页、数据库导入、主题和版权说明
  AppIcon.md                   App 图标资源、替代图标和设置页切换
Tools/
  Icon/                        日间三档 / 夜间三档 AppIcon 生成脚本
  Parity/                      RouteParity / TrackParity / ProcedureParity 统一校验入口和 Xcode target 说明
  RouteParity/                 route resolve Swift/Web parity 探针工具
  TrackParity/                 track-match Swift/Web parity 探针工具
  ProcedureParity/             procedure geometry Swift/Web parity 探针工具
TODO.md                        阶段任务列表
codex_report.md                Codex 执行记录
NavPlanner-web/                只读 Web 参考项目
```

## 构建

推荐把 DerivedData 放到不含空格的路径，便于模拟器安装：

```bash
xcodebuild -project NavPlanner.xcodeproj \
  -scheme NavPlanner \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/NavPlannerDerived \
  build
```

已通过 XcodeBuildMCP 在 iPhone 17 Pro 和 iPad Pro 13-inch 模拟器上完成 build、install、launch 和截图检查。

最近一次验证：

- `node --check NavPlanner/Resources/Web/app.js` 成功；CSS 大括号配对检查成功；`git diff --check` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error；首屏截图确认 banner / 手柄顶部占位已压缩到 20px，短条仍可见，截图为 `/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_2ea3b5a8-3b9e-4287-8847-d2c2127a4f4a.jpg`。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 再次成功，首屏截图确认 banner 外层阴影上下观感已更接近对称，底部四标签栏总下移 14px、左右总内收 20px 后仍保持可点按，中部工作区同步增高；截图为 `/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_8e02f35e-e7e1-4d0c-bc0e-3106915eb9e6.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。
- `node --check NavPlanner/Resources/Web/app.js` 成功；CSS 大括号配对检查成功；`swift -frontend -parse NavPlanner/Core/WebBridge/NavPlannerSchemeHandler.swift NavPlanner/Core/PlannerCore/PlannerService.swift` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功；`git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功；RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error；最终首屏截图确认手柄仍位于下方面板内部顶部，地图、Plan 表单和底部 `计划 / 机场 / 查询 / 设置` 四标签正常，截图为 `/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_12a22635-1a20-415a-88b8-e84fd0fdd16d.jpg`。
- ZULS/ZUAL FR24 无会话验证：当前模拟器无已保存 `com.midaxia.navplanner` FR24 Cookie；直接探测 `LXA` schedule 返回 HTTP 403、`cf-mitigated: challenge` 和 Cloudflare HTML，符合 App 内“打开 FR24 验证页并同步会话”的降级路径；本轮未自动点击 WKWebView 内 Query 控件。
- 扫描本轮 XcodeBuildMCP runtime / oslog，未发现 `TypeError`、`ReferenceError`、`SyntaxError`、`Exception`、`fatal` 或 FR24 WebBridge 错误；`git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。
- `node --check NavPlanner/Resources/Web/app.js` 成功；CSS 大括号配对检查成功；`swift -frontend -parse NavPlanner/Core/WebBridge/NavPlannerSchemeHandler.swift NavPlanner/Core/PlannerCore/PlannerService.swift` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功；`git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功；RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error；首屏截图确认新上拉手柄、地图、Plan 表单和底部 `计划 / 机场 / 查询 / 设置` 四标签正常，截图为 `/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_cc80a54a-677d-4ed2-8547-6cd43904d5c1.jpg`。
- 本轮 macOS 辅助功能权限未允许 `osascript` 自动点击 WKWebView 内控件，因此 `ZULS` / `ZUAL` 的 FR24 页面内查询和 `TV9943` 历史展开需在已启动模拟器中手动复验；App runtime / oslog 未发现 JS 语法错误或 FR24 WebBridge 错误。
- `node --check NavPlanner/Resources/Web/app.js` 成功；CSS 大括号配对检查成功；HTML 本地化覆盖检查确认 126 个 `data-i18n*` 属性均有翻译键，402 个翻译键已被扫描。
- FR24 Query 页已切换为 App 内 FR24 验证页 + 自动同步会话，手动 Cookie / `_frPl` 仅作为高级可选兜底；FR24 返回 Cloudflare 验证页、HTML 或 401 / 403 时显示可本地化提示，本地规划、Procedure、nav-overlay 和离线地图继续可用；`map.html` 资源版本刷新为 `20260605-fr24-inapp-session`。后续每次修改 FR24 相关功能时，固定使用 `ZULS` / `ZUAL` 做 FR24 路径验证。
- ZULS/ZUAL FR24 验证：本地导航数据库解析 `ZULS -> LXA`、`ZUAL -> NGQ` 成功；无已同步 FR24 会话时，FR24 schedule 探测返回 403，Query 页应提示先打开 FR24 验证页并同步会话。
- 模拟器调试确认旧实现中已同步 Cookie 包含 `cf_clearance`、`PHPSESSID`、`XSRF-TOKEN` 等，但 `_frPl` 缺失且 `URLSession` 带 Cookie 请求 ZULS/ZUAL schedule 仍返回 403；因此当前实现已改为优先用 WKWebView 浏览器上下文执行 FR24 Web 请求。2026-06-05 进一步定位到 `evaluateJavaScript(async...)` 未等待 Promise 会报“JavaScript 返回结果类型不受支持”，而跨域 `fetch` 会在 WKWebView 中报 `Load failed`；当前已改为隐藏 WKWebView 顶层导航加载 FR24 API JSON，并加入不含 Cookie 值的 FR24 请求状态诊断日志。
- ZULS/ZUAL FR24 在线验证：在 iPhone 17 Pro Max 模拟器中，隐藏 WKWebView 对 `/common/v1/airport.json` 返回 `status=200 type=application/json body=json-object`；`LXA departures offset=24` 命中 1-2 条 `ZULS -> ZUAL` 航班，UI 已显示 `TV9723`、`TV9943` 等航班卡片。FR24 对更早 `offset=48` timestamp 返回 HTTP 400 时，查询会停止继续向前扫描并返回已找到的最新航班。
- FR24 playback 轨迹解析已支持 JSON 中的 ISO 时间戳，下载缓存继续写入 App Caches 下的 GPX、playback JSON 和 meta JSON。
- `swift -frontend -parse NavPlanner/Core/WebBridge/NavPlannerSchemeHandler.swift NavPlanner/Core/PlannerCore/PlannerService.swift` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功；`git diff --check` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功；RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error；首屏截图确认地图、Plan 表单和底部 `计划 / 机场 / 查询 / 设置` 四标签正常，截图为 `/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_dbe5336d-cebb-4d85-a580-36d3dd8ad58f.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。
- `swift -frontend -parse Tools/Icon/generate_app_icons.swift` 成功；`swift Tools/Icon/generate_app_icons.swift` 成功，已重新生成日间三档 / 夜间三档 6 套图标和 Settings 预览图。
- 视觉检查确认默认日间均衡图标与夜间高对比图标外框均已加宽，航路、地形和跑道主体仍清晰；`map.html` 图标预览查询串和 `app.js` 资源版本刷新为 `20260604-icon-wider-border`。
- `shasum` 确认 6 张 marketing 图标和 6 张 Settings 预览图均为不同 PNG；`sips` 检查 6 张 marketing 图为 1024 x 1024，Settings 预览图为 180 x 180；图标 PNG 数量检查为 96 张 AppIcon PNG 和 6 张预览图。
- `node --check NavPlanner/Resources/Web/app.js` 成功；CSS 大括号配对检查成功；6 个 AppIcon `Contents.json` 均可由 Node 解析且每套包含 18 个 image entry；`git diff --check` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功；RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error；首屏截图确认地图、中文输入区和底部 `计划 / 机场 / 设置` 标签正常，截图为 `/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_1597bc26-b6d3-42ba-abbc-8c0ee98efe26.jpg`。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。
- `node --check NavPlanner/Resources/Web/app.js` 成功；已覆盖机场弹窗详情、Procedure 明细阶段 / 特征、Settings 数据库状态、进近标题和常见错误提示中文化，资源版本刷新为 `20260604-error-localization`。
- CSS 大括号配对检查成功；`git diff --check` 成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/Parity/run_all_parity.py` 成功；RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error；首屏截图确认地图、中文输入区和底部 `计划 / 机场 / 设置` 标签正常，截图为 `/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_2c0d9ced-671a-4a3d-8202-9d451e2b2f30.jpg`。
- `swift Tools/Icon/generate_app_icons.swift` 成功；当前有效图标为日间三档和夜间三档，默认主图标为日间均衡，上一轮默认档位已成为日间柔和；日间高饱和 / 均衡 / 柔和与夜间高对比 / 均衡 / 柔和均生成不同 PNG，视觉检查确认夜间版整图玻璃罩减弱、航路和山体具备局部玻璃反光、外框更宽。
- `node --check NavPlanner/Resources/Web/app.js` 成功；6 个 AppIcon `Contents.json` 可由 Node 正常解析；`plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 图标资源检查成功：6 张 marketing 图为 1024 x 1024，Settings 预览图为 180 x 180，六套当前可选图标共 96 张 AppIcon PNG。
- `python3 Tools/Parity/run_all_parity.py` 成功；RouteParity 22、TrackParity 7、ProcedureParity 6 均无差异。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error；启动截图为 `/var/folders/7m/jzh_ftyn6_gfjz552yy612zr0000gn/T/screenshot_optimized_a7c86866-aa77-47ed-9847-f61282f727e4.jpg`。
- 已新增 `.gitignore`，并清理根工程 `.build/`、`DerivedData/`、`.DS_Store` 和 Xcode `xcuserdata/`；`NavPlanner-web/` 保持未修改。
- `python3 Tools/ProcedureParity/procedure_parity.py` 成功；ProcedureParity 已扩展到 6 个 case，新增 `ZULS R10L LS995`，确认 Swift 不再额外保留会导致复飞异常大圆的 `LSC*` RF 行。
- `python3 Tools/Parity/run_all_parity.py` 成功；统一入口顺序运行 RouteParity 22、TrackParity 7 和 ProcedureParity 6，均无差异。
- `node --check NavPlanner/Resources/Web/app.js` 成功；CSS 大括号配对检查成功；`plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro Max 成功，构建、安装、启动无 warning / error；竖屏截图确认新包正常启动，资源版本刷新为 `20260603-procedure-ui-parity`。
- 本轮 iPhone 样式更新覆盖计划航路标签清晰度、Airport 页跑道行 / 通信频率 / Procedure chip 的紧凑尺寸；自动点击 WebView 深层控件因 macOS 辅助功能权限和当前 LLDB DAP 表达式限制未能执行，已用 ProcedureParity 和启动截图完成可自动化部分验证。
- `node --check NavPlanner/Resources/Web/app.js` 成功；已覆盖 iPhone 横屏刘海侧动态避让、反向留白修正、非刘海侧白色边栏 50px 圆角、8px 浅蓝背景间隔、外侧文字避让，以及 iPhone 17 Pro Max 等更宽 iPhone 横屏同设计触发。
- CSS 大括号配对检查成功。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- 用户卸载旧包后，XcodeBuildMCP `build_run_sim` 已在 iPhone 17 Pro Max 重新构建、安装并启动成功，构建无 warning / error；竖屏截图确认地图上方、输入区下方和底部中文标签正常，横屏两侧旋转截图确认 Pro Max 使用 iPhone 横屏工作台布局。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，构建无 warning / error。
- XcodeBuildMCP 已获取 iPhone 17 Pro 横屏截图和 `simctl --mask black` 圆角遮罩截图，确认右侧刘海避让在正确侧，非刘海侧横向空间未被硬内收；最新版本直接调整左侧计划栏白色背景本体圆角，并将顶部“计划”标题单独向右避让。
- `node --check NavPlanner/Resources/Web/app.js` 成功；CSS 资源版本刷新为 `20260601-phone-landscape-ipad-layout`，已覆盖 iPhone 横屏 iPad 式布局。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；竖屏仍保持地图上 / 输入区下 / 底部三标签布局。
- `swift Tools/Icon/generate_app_icons.swift` 成功；已基于 `Tools/Icon/navplanner-terrain-liquid-glass-source.png` 生成日间三档和夜间三档 App 图标和 Settings 页预览图。
- `node --check NavPlanner/Resources/Web/app.js` 成功；已覆盖应用图标选择、离线地图下载代理设置移除和 iPhone Airport 紧凑控件样式。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；Settings 中日间三档 / 夜间三档图标选择可触发 iOS 替代图标切换，离线地图管理弹窗可从 Settings 打开，下载页不再显示代理输入项，iPhone Airport 槽位和跑道筛选框已压缩。
- `git -C NavPlanner-web status --short` 无输出，参考项目保持未修改。
- `node --check NavPlanner/Resources/Web/app.js` 成功；已覆盖 iPad 弹窗紧凑毛玻璃样式和 iPhone 输入框二次压缩。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；截图确认 Plan 输入框和航路 textarea 视觉字号已进一步缩小，底部工作区密度更适合小屏。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功；点击航路弹窗确认 iPad 已使用与 iPhone 一致的紧凑半透明毛玻璃弹窗、内嵌圆角标题块，航路弹窗没有机场专用操作按钮。
- `node --check NavPlanner/Resources/Web/app.js` 成功；已覆盖 iPhone 键盘 `visualViewport` 可见边界校正和紧凑输入框缩放。
- `plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；关闭硬件键盘并显示软件键盘后，点击起飞机场输入框可稳定唤起键盘，视觉字号保持小屏紧凑，输入框和搜索结果位于键盘上方；点击底部航路 textarea 时面板平滑滚动，textarea 位于键盘上方，点击键盘对勾后恢复正常地图 + 输入区 + 底部 Tab 布局。
- `python3 Tools/Parity/run_all_parity.py` 成功；统一入口顺序运行 RouteParity 22、TrackParity 7 和 ProcedureParity 6，均无差异。
- `xcodebuild -project NavPlanner.xcodeproj -scheme ParityChecks -configuration Debug -derivedDataPath /private/tmp/NavPlannerParityDerived build` 成功；Xcode aggregate target 可直接执行三组 Swift/Web parity 校验。
- `node --check NavPlanner/Resources/Web/app.js` 成功；已覆盖 iPhone 键盘可见高度布局二次修正和焦点控件重复校正。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `python3 Tools/RouteParity/route_parity.py` 成功；22 个 case 无差异。
- `python3 Tools/TrackParity/track_parity.py` 成功；7 个 track-match case 无差异，覆盖 `KLAX->KPSP` 手动 / `***` 补航路、`ZBAA->ZSPD`、`VHHH->WSSS`、跨日期变更线 `NFFN->NSTU` 和两个错误语义。
- `python3 Tools/Parity/run_all_parity.py` 成功；统一入口顺序运行 RouteParity 22 和 TrackParity 7，均无差异。
- `xcodebuild -project NavPlanner.xcodeproj -scheme ParityChecks -configuration Debug -derivedDataPath /private/tmp/NavPlannerParityDerived build` 成功；Xcode aggregate target 可直接执行 Swift/Web parity 校验。
- XcodeBuildMCP `build_sim` 在 iPhone 17 Pro 模拟器目标成功；本轮新增 TrackParity 工具和文档未引入 App 构建问题。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；关闭硬件键盘并用 Simulator Cmd-K 显示软件键盘后，点击起飞机场输入框和底部航路 textarea 均可保持输入框位于键盘上方，底部 `计划 / 机场 / 设置` Tab 在键盘态隐藏，收起后恢复。回归拖动地图和点击 `+` 缩放按钮可用，未观察到页面整体滚动。
- `node --check NavPlanner/Resources/Web/app.js` 成功；已覆盖离线地图管理页暗色居中紧凑弹窗和 iPhone 键盘可见高度布局。
- `python3 Tools/RouteParity/route_parity.py` 成功；22 个 case 无差异。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；已覆盖离线地图弹窗和键盘可见高度布局 Web 资源打包。关闭模拟器硬件键盘后截图确认软键盘出现时底部 Tab 隐藏，Plan 输入面板保留在键盘上方，输入 `ZBAA` 后搜索结果可见，点击地图或键盘/附件栏对勾后恢复正常底部 Tab 布局。
- `node --check NavPlanner/Resources/Web/app.js` 成功；已覆盖 Settings 按钮重排、离线地图管理主题同步和 iPhone 输入框 click 聚焦兜底。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；已覆盖本次 Web 资源版本刷新和打包。
- `python3 Tools/RouteParity/route_parity.py` 成功；22 个 case 无差异，新增覆盖跨日期变更线自动航线 `NFFN->NSTU`、`NSTU->NFFN`、`PHNL->PGUM`、`NFFN->NSFA` 和手动 `NN G224 TUT`、`TUT G224 NN`，并对比点列签名与经度 unwrap 几何摘要。
- `node --check NavPlanner/Resources/Web/app.js` 成功；已覆盖 iPad 竖向折叠栏日间显式样式兜底和资源缓存版本刷新。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；已覆盖 RouteParity 跨日期变更线扩展和点列几何摘要。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；已覆盖 iPad 竖向折叠栏日间显式样式兜底和资源缓存版本刷新。
- 原 16 个 RouteParity 基线 case 已扩展为上方 22 个 case；8 条典型自动航线、3 条手动航路、`FRE` 查找优先级和 4 个错误边界仍无差异。
- 8 条典型自动空 Route Swift/Web 探针对照成功：`ZBAA->ZSPD`、`KLAX->KPSP`、`RJTT->PHNL`、`EGLL->KJFK`、`YSSY->NZAA`、`VHHH->WSSS`、`OMDB->EDDF`、`AGGF->AYKM` 的 `route_display`、legs 摘要、点数、距离、SID / STAR / Approach 和 runway 选择均无差异。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；已覆盖 route resolve 自动航线 parity 改动。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；已覆盖 iPad 竖向折叠栏主题变量和首屏主题预设。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功；截图确认日间主题下用户标出的竖向折叠按钮已随主题变为浅蓝灰玻璃色。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；已覆盖起降点 / 普通 route token 查找优先级拆分。
- Swift 与 Web 参考对照成功：真实冲突 token `FRE` 在手动 route `DODGR DCT FRE` 中解析为 enroute waypoint `FRE (-32.058333, 115.741667)`，而起飞输入 `FRE` 解析为 IATA 对应机场 `AGGF`，与 Web `lookup_point` / `lookup_departure_arrival_point` 一致。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；已覆盖 excluded airway 内部搜索通路。
- 临时 Swift 探针直连 `PlannerService.routeResolvePayload` 成功：默认空排除集下 `DODGR -> GARNE` 空 Route 和 `DODGR *** GARNE` 仍返回 `DODGR V370 GARNE`，均为 1 条 leg、9 个点。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；已覆盖重复 airway 合并和 `route_display` 拆分改动。
- 临时 Swift 探针直连 `PlannerService.routeResolvePayload` 成功：`DODGR -> GARNE` 空 Route、`DODGR V370 GARNE`、`DODGR DCT GARNE`、`DODGR *** GARNE` 的显示文本均符合预期，其中 `***` 继续展开为 `DODGR V370 GARNE`。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；已覆盖 Route Resolve 连续 airway 合并改动。
- 临时 Swift 探针直连 `PlannerService.routeResolvePayload` 成功：`DODGR -> GARNE` 留空 Route 和 `DODGR *** GARNE` 均返回 `DODGR V370 GARNE`，包含 1 条 `V370` airway leg、9 个点。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功；已覆盖离线地图下载器并发改动和 iPad 折叠栏主题样式。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功；截图确认日间主题下左右竖向折叠栏按钮已切换为浅蓝灰主题配色，不再显示深蓝长条。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；截图确认航路输入示例已改为 `KTM *** LXA`，Settings 显示“离线地图”和“在线地图缓存”卡片，在线地图缓存可显示大小和文件数。
- iPhone 17 Pro 交互回归：Settings 中“管理”可打开离线地图管理弹窗；拖动地图和点击 `+` 缩放后 nav-overlay 仍保持显示。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功；截图确认既有工作台布局保持，详情区域可切到 Settings。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功。
- 临时 Swift 探针直连 `PlannerService.trackMatchPayload` 成功：用 `DODGR V370 GARNE` 的 9 个轨迹点导入匹配，返回 `DODGR V370 GARNE`，包含 1 条 `V370` airway leg；本次路径已经过 Web 同形态的轨迹误差约束和 zigzag 平滑流程。
- 临时 Swift 探针与 Web 参考 `NavDatabase.match_imported_track_route` 对照成功：`KLAX -> KPSP` 使用同一轨迹均返回 `DODGR V370 GARNE`，并自动选择 SID `GARDY4/RW07B` 与 Approach `VORB/ALL`。
- 临时 Swift 探针与 Web 参考 `NavDatabase.resolve_route` 对照成功：`KLAX -> KPSP` 的 `DODGR V370 GARNE`、`DODGR DCT GARNE`、`DODGR *** GARNE` 三组手动 route 的 legs、点数和显示文本一致；Swift 不再为手动 route 额外追加终点 direct leg，`***` 显示为补全后的航路。
- XcodeBuildMCP iPhone 17 Pro 回归：点击 `departureInput` 可唤起键盘并输入 `ZBAA`，页面没有整体上移或露出浏览器式底栏。
- XcodeBuildMCP iPhone 17 Pro 截图确认：地图高度继续增加，底部标签与 Home Indicator 保持安全间距，`+ / -` 缩放按钮间距更明显且每个按钮四角独立圆角，在线地形底图可见；缩放和平移后 nav-overlay 仍保持显示。
- 临时 Swift 探针直连 `MapStore(rootDirectory:)` 成功：`osm_standard` z0 单瓦片下载完成，生成 SQLite 离线资源后可通过 `resourceTile` 读回 PNG；状态返回 4 个下载 provider 和 5,000,000 瓦片上限。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；确认 Google terrain 底图可加载，iPhone 底部三标签更贴底，地图高度增加，`+ / -` 缩放按钮间距增大。
- XcodeBuildMCP iPhone 17 Pro 触控回归：输入框可获得焦点并输入 `ZBAA`，本地搜索结果显示；地图缩放按钮和平移可用，缩放后 nav-overlay 保持显示，没有先清空旧叠加层的明显闪烁。
- `node --check NavPlanner/Resources/Web/app.js` 成功。
- `plutil -lint NavPlanner/Support/PrivacyInfo.xcprivacy` 成功。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功；聚焦起飞机场输入框后未出现系统上一项/下一项/完成附件栏，页面未被顶起，输入 `ZBAA` 搜索结果正常显示。
- XcodeBuildMCP iPhone 17 Pro 地图点击回归：航路弹窗约半宽显示，文字和按钮更紧凑，地图符号与标签缩小后仍可点击。
- XcodeBuildMCP iPhone 17 Pro 主题回归：Settings 切换到夜间时刘海安全区变深且状态栏变浅，切回日间时刘海安全区变浅且状态栏变深。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，确认 Plan / Airport / Settings 常用路径中文化后的紧凑移动布局仍可正常启动。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，确认二次调整后的日间主题、低高度中文图标玻璃 Tab、Settings 无顶层标题和底部独占行。
- XcodeBuildMCP iPhone 17 Pro 触控回归：输入框可聚焦并显示 `ZBAA` 本地搜索结果，地图平移、缩放按钮、连续点按防页面放大和地图弹窗均可用。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功，确认 iPad 工作台布局未套用 iPhone 底部三标签。
- `xcodebuild -project NavPlanner.xcodeproj -scheme NavPlanner -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/NavPlannerDerived build` 成功。
- 临时 Swift 探针验证 `MapStore.pmtilesFileResponse(...)` 成功：目录 `resource.pmtiles` 和单文件 `.pmtiles` 均识别为 `pmtiles_v1`，完整读取、`bytes=2-5`、`bytes=-4` 与 416 `Content-Range` 均符合预期。
- 临时 Swift 探针验证 `MapStore(rootDirectory:)` 成功：生成 Web `tiles.sqlite` 和 MBTiles 样例资源后，`activeTile` / `resourceTile` 分别读回 68 字节 PNG 和 4 字节 JPEG，MBTiles TMS y 翻转有效。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，确认日间主题、紧凑输入控件、中文图标玻璃 Tab、Settings 无标题和底部 Tab 不覆盖内容。
- XcodeBuildMCP iPhone 17 Pro 触控回归：地图缩放按钮可用，输入框可聚焦并显示 `ZBAA` 本地搜索结果，连续点按地图区域未触发页面级放大，地图点击弹窗仍可用。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功，确认 iPad 工作台布局未套用 iPhone 底部 Tab。
- 临时 Swift 探针直连 `PlannerService.routeResolvePayload` 成功：`DODGR -> GARNE` 留空 Route 自动返回 `DODGR V370 GARNE`，`DODGR *** GARNE` 返回 1 条 airway leg；重复规划走 airway graph / route-between 缓存。
- 临时 Swift 探针直连 `PlannerService.trackMatchPayload` 成功：用 `DODGR V370 GARNE` 轨迹点导入匹配，返回 `DODGR V370 GARNE`，包含 1 条 airway leg。
- 临时 Swift 探针直连 `PlannerService.procedurePayload` 成功，并与 Web 参考 `procedure_geometry` 对照：`BIAR ASKU1D RW19` 均为 `items=5 path=28`，`MTCH NOSO1L RW05` 均为 `items=3 path=26`，`07FA R05-P ALL` 均为 `items=7 path=48 primary=4 missed=45`。
- 临时 Swift 探针直连 `PlannerService.navOverlayPayload` 成功，并与 Web 参考 `nav_overlay` 对照：`dateline-high`、`dateline-mid`、`china` 三组视野的 airports / airways / labels / waypoints / navaids / runways / ils 计数完全一致。
- 临时 Swift 探针验证手动 route 错误语义：未知 waypoint、起始 `DCT`、airway 缺 exit、`***` 缺目标均返回与 Web 版一致的 error 文案。
- XcodeBuildMCP `build_run_sim` 在 iPhone 17 Pro 成功，确认上部地图 / 下部三标签工作区、搜索输入、设置页、地图平移和缩放控件可用。
- XcodeBuildMCP `build_run_sim` 在 iPad Pro 13-inch (M5) 成功，确认既有工作台布局保持、Settings 页面可切换。
- iPhone 触控回归：输入 `ZBAA` 可显示本地结果，Plan / Airport / Settings 切换时地图不重建，双击地图或面板空白处不触发页面放大，缩放按钮和平移可用。
- iPhone 17 Pro 运行时验证：`ZBAA` -> `ZSPD` 留空 Route 点击 Build Route，可自动选择 SID / STAR 接入并绘制航线，状态显示“已按 SID / STAR 自动接入本地离线航路”。

## 参考约束

- 核心功能必须本地完成，不依赖 Python server、远程服务或局域网服务。
- 在线能力只能作为增强功能；断网时启动、搜索、机场详情、Procedure 查看、叠加层和离线地图仍应可用。
- 地图底图、离线地图读取和航路叠加层刷新必须相互独立，底图失败不能阻塞 nav-overlay。
- 用户界面、文档和重要注释优先使用中文。
