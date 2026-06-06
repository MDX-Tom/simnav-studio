# App Shell

第一阶段 App Shell 使用 SwiftUI 实现，目标是避免把核心功能放在 Python server 或远程服务上。当前用户要求界面、交互和地图行为优先完整复刻 Web 版本，因此 SwiftUI 外壳暂时切换为全屏 Web 工作台容器，由 Swift 本地服务层提供所有核心 API。

## iPad

- 当前加载 Web 参考版工作台，宽屏时沿用 Web 三栏/折叠栏交互。
- iPad 竖屏较窄时会触发 Web 窄屏布局，表现为地图与详情区域上下排列。
- 详情区域加入 `Airport / Query / Settings` 切换，不改变计划栏、地图区和原有 Airport 面板结构。
- 左右竖向折叠栏按钮使用主题化配色：日间主题为浅蓝灰玻璃质感，夜间主题为深色玻璃质感；`map.html` 会在加载 CSS 前根据本地主题偏好写入 `data-theme`，CSS 也对 `day` 和系统浅色模式提供显式 rail 样式兜底，避免日间模式下出现深蓝长条割裂工作台。
- 后续若继续原生化，需要在不破坏 Web 行为复刻的前提下重接 SwiftUI 多栏。

## iPhone

- 当前 iPhone 竖屏加载 Web 参考版移动布局：上部固定为地图，默认比例约占屏幕 66%；下部为输入工作区，默认约占屏幕 34%，底部四标签另占一条约 19px 的低高度控制行。
- 下部工作区提供 `计划`、`机场`、`查询`、`设置` 四个中文图标标签，切换标签只改变下部内容，不销毁或重建顶部地图实例。
- 下部工作区面板内部顶部新增上拉手柄，视觉参考系统输入面板的短灰色拖拽条；用户可把工作区上拉，地图区域最小保留 30%，下拉回默认 66% / 34%。手柄状态保存在当前 Web 工作台内，切换 `计划 / 机场 / 查询 / 设置` 不重置高度；软键盘出现时继续由 `visualViewport` 键盘态布局接管，手柄隐藏且不影响自动上拉。
- 底部标签栏在 iPhone 网格中独占第三行，使用更低高度的紧凑玻璃质感，并通过 `env(safe-area-inset-bottom)` 为 iOS Home Indicator 保留距离；内容面板高度截止到标签栏上方，不再通过覆盖式悬浮占用表单空间。
- iPhone 横屏使用 iPad 横屏式工作台：左侧计划栏、中间地图、右侧详情/查询/设置栏和左右折叠按钮同时显示；底部四标签隐藏，右侧继续使用 `机场 / 查询 / 设置` 标签切换。紧凑工作台媒体查询已从 920px 扩展到 1024px，iPhone 17 Pro Max 等更宽横屏机型也会使用和 iPhone 17 Pro 一致的 UI。
- iPhone 横屏仍沿用 iPhone 竖屏紧凑字号、输入框、按钮、地图符号、地图标签和弹窗尺寸；横屏专用列宽使用 `clamp(...)` 控制，让不同 iPhone 横屏宽度都保留可用地图宽度。
- iPhone 横屏由 SwiftUI 外壳让 `MapContainerView` 忽略横向安全区，WebView 铺满左右边缘；Web 层再通过 `screen.orientation.angle` / `window.orientation` 写入 `data-landscape-notch-side`，并用左右 `safe-area-inset` 的较大值只避让刘海侧，另一侧固定为约 8px 留白；非刘海侧保持横向边距不变，浅蓝背景由 8px shell padding 露出，白色边栏本体使用手动验证后的 50px 外圆角，并对外侧标题、字段标签和状态提示做小幅文字避让。
- iPhone 媒体查询使用 `html:not([data-device="pad"])` 限定，Swift 在 WKWebView 注入 `data-device="phone"`，避免影响 iPad 现有布局。
- 旧的 SwiftUI 底部 Dock 和 Sheet 暂停作为主入口，避免与 Web 工作台重复。
- 字体、按钮、输入框、搜索结果、设置卡片、地图控件和底部标签在 iPhone 下使用更小尺寸，适配小屏触控密度。
- Airport 页面在 iPhone 下进一步压缩机场槽位、跑道筛选、机场标题框的字体、padding 和高度，避免 `ZBAA`、`RW01` 等控件在下部工作区占用过多垂直空间。
- Airport 页面在 iPhone 下继续压缩跑道列表行、通信频率胶囊、Procedure chip、已选 Procedure chip 和删除圆点，避免 `RW28R`、频率和 `Approach` 一类控件占满下部工作区。
- 计划航路地图标签在 iPhone 下使用单独的深色背板、清晰暗色文字阴影和更高字重，避免全局浅色地图标签描边让白色航点文字发灰；航路名使用更高对比黄色胶囊。
- iPhone 下部工作区隐藏顶层区块标题，减少 `Plan` / `Settings` 等标题占用，把有限高度留给输入、机场详情和设置操作。
- 页面级双击/双触缩放已拦截，避免下部空白区域误触发 WKWebView 放大。
- iPhone 不再覆盖 `WKWebView.inputAccessoryView`，避免零高度附件视图干扰输入框唤起键盘；Swift 侧仅清空 `inputAssistantItem` 的上一项 / 下一项按钮组。
- iPhone Web 工作台保留 WKWebView 外层 scroll view 的输入触控能力，关闭 bounce、自动 inset 和滚动指示，并在 `MapWebView.Coordinator` 中用 `UIScrollViewDelegate` 将外层 `contentOffset` / inset 锁回 0，避免 UIKit 自动滚动把页面顶出视口；Web 侧根页面不再使用 `position: fixed`，通过页面级 scroll reset 锁住页面级滚动，输入框采用原生单击聚焦并在 click 阶段补一次 `focus({ preventScroll: true })`，不再安装输入框 `touchstart` 聚焦桥；键盘出现时根据 `visualViewport` 设置 `--mobile-visual-height`，将 shell 重新排入键盘上方可见高度，临时隐藏底部 Tab，输入面板占比提高，并用当前面板边界和真实 `visualViewport` 边界多次校正当前输入框位置，键盘收起后恢复原位。
- iPhone Plan 输入框和航路 textarea 实际 CSS 字号保持 16px，避免 WebKit 聚焦时触发页面级自动缩放；外观通过缩放回约 9.5px 的视觉尺寸，继续保持小屏紧凑密度。
- Web 工作台通过 `themeChanged` bridge 同步当前 `system/day/night` 和实际 `day/night` 到 SwiftUI 外壳；iPhone 顶部刘海安全区背景和状态栏明暗会跟随主题变化。
- iPhone 切换底部 `计划 / 机场 / 查询 / 设置` 到不同标签时会主动取消输入框焦点；重复点击当前标签不再 blur，避免正在编辑的输入框被误收起。
- `MapWebView` 已接入 `WKUIDelegate` 的 alert / confirm / prompt 面板；当前主流程不再依赖旧的轨迹粘贴降级入口，Query 页通过 FR24 Web playback 下载轨迹并复用本地 `track-match`。FR24 访问配置可从 Query 页打开 App 内 FR24 验证浏览器，完成验证后自动同步 CookieStore 中的 FR24 Cookie / `_frPl`，无需用户手动查 Cookie。
- 后续需要继续在真机处理软键盘高度、Home Indicator 遮挡和全量中文文案。

## 当前文件

- `NavPlanner/App/AppRootView.swift`
- `NavPlanner/App/AppEnvironment.swift`
- `NavPlanner/Features/Plan/PlanPanelView.swift`
- `NavPlanner/Features/Airports/AirportDetailView.swift`
- `NavPlanner/Features/Selection/SelectionPanelView.swift`
- `NavPlanner/Features/OfflineMaps/OfflineMapsView.swift`

原生 Plan / Airport / Selection / OfflineMaps 视图目前仍保留在工程中，作为后续原生化阶段的组件基础；当前运行路径主要经过 `MapContainerView` 和 `MapWebView`。
