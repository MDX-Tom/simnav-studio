# Map Kernel

第一阶段地图内核运行在 WKWebView 中。当前为了优先复刻 `NavPlanner-web/` 的地图行为，iOS 版已把 Web 参考版工作台复制到 App 自己的 `Web/` 目录，并通过 Swift 本地服务承接 API。

## 当前能力

- Leaflet 地图、Web 参考版 Plan / Airport / Selection / Offline Maps 面板已在 iOS WebView 中加载。
- Leaflet、MapLibre GL、maplibre-contour、pmtiles 已打包到 `Web/vendor/`，启动不依赖 CDN。
- 触控拖动、缩放控件、地图类型控件沿用 Web 参考版实现。
- 矢量底图拖动和缩放期间不再高频 `jumpTo`：拖动/缩放中用 Leaflet 同帧 CSS transform 镜像 MapLibre 容器，结束后再同步真实 MapLibre 相机，降低 vector 底图与航路层动画不同步。
- 地图左上角新增垂直叠加层控制，按钮尺寸、圆角和间距与缩放 / 地图类型控件保持一致；可分别显示 / 隐藏地图层、蓝色自动 / 匹配航路与 nav-overlay 蓝色 airway、黄色人工航路、SID / STAR / APPROACH、FR24 黑色轨迹、terminal waypoints 和其他航点 / 导航台。隐藏态仅移除或淡出前端图层并把图标置灰，按钮本体背景、阴影和底纹保持不变；显隐切换不重新请求 nav-overlay、不重算航路，也不影响本地离线服务。
- iPhone 缩放控件尺寸保持紧凑，`+` / `-` 按钮之间增加少量间距，避免小屏连续点按时误触；每个缩放按钮都覆盖 Leaflet touch 默认首尾圆角，保持四角独立圆角。
- 已禁用 Leaflet `doubleClickZoom`，并拦截地图容器与页面空白处的 `dblclick` / 双触默认行为，避免双击空白处放大。
- 保留单指平移、双指缩放、缩放按钮、点击航路/航点弹窗和输入框触控。
- 节流请求 `/api/nav-overlay`，由 `WKURLSchemeHandler` 路由到 Swift 本地 `PlannerService`。前端绘制采用双缓冲图层：新 nav-overlay 在离屏 layer group 完成后再替换旧 layer group；iPhone 使用 SVG renderer 与两帧延迟旧层移除，避免缩放或移动后旧航路先消失再显示；地图仍处于拖动/缩放动画时会延后刷新，避免重绘和动画争用同一帧。
- nav-overlay 前端图层已拆分为主导航叠加层、蓝色 airway 子图层、terminal waypoint 子图层和其他航点 / 导航台子图层；跑道、ILS 和机场保持在主叠加层，airway 跟随左上角第二个“航路”开关独立显示或隐藏，terminal / 其他点位也可由对应开关独立控制。
- 底图绘制、离线地图状态、nav-overlay 请求相互独立。
- nav-overlay Swift 服务已使用 Web 参考版同款本地缓存、世界副本偏移、跨日期变更线边界判断、空间分桶和航路标签预算。
- 点击机场 / 航点 / 导航台可弹窗。
- 机场弹窗可读取本地机场详情。
- iPhone 地图弹窗使用更小宽度、字号、行距和按钮，保留与按钮一致的柔和圆角，并将顶部标题深色块改为带缝隙的内嵌圆角样式；弹窗背景为半透明毛玻璃。iPad 弹窗同步为同一视觉体系，使用半透明毛玻璃、内嵌圆角标题和更紧凑宽度。机场/航点/导航台/航路标签与符号在 iPhone 下按紧凑比例缩小。
- Procedure 按钮可读取并绘制路径；Swift 本地服务已生成 RF / AF 弧线、复飞路径和末端等待航线几何。
- APPROACH 使用紫色绘制。
- 离线底图已可读取本地 PMTiles Range、MBTiles、Web `tiles.sqlite` 和 Web `tiles/` 文件布局；缺失底图瓦片继续返回透明 PNG，占位底图不阻塞叠加层刷新。
- 在线 terrain 与 terrarium 瓦片通过 Swift `OnlineTileCache` 异步缓存到 Caches 目录；`google_terrain` 通路优先尝试 Esri World Topographic 和 OpenTopoMap，随后再尝试 Google 子域，提升无法访问 Google 时的底图可用性。首次请求返回带 `X-Map-Cache: QUEUED/PENDING/MISS` 的透明瓦片，前端异步瓦片层轮询命中后再显示真实底图。缓存识别 JPEG / PNG，避免远端返回不同图片格式时加载失败。
- 在线地图缓存通过 Settings 的“在线地图缓存”卡片调用 `/api/map-cache/status` 和 `/api/map-cache/clear` 管理；“清理缓存 / 刷新缓存”统一位于卡片下排，清理后只刷新在线 terrain URL 版本，不清空离线地图包、航路层或本地数据库。
- 地图右下角 Leaflet attribution / 水印已隐藏，版权信息集中显示在 Settings 页面。

## 当前限制

- PMTiles Range 端点已接入，但仍需用真实 PMTiles 地图包在模拟器 / 真机上完成 MapLibre 离线矢量底图视觉验证。
- Procedure 速度 / 高度限制当前主要在 Selection 明细中展示；Selection 表格列顺序为 `SEQ / WAYPOINT / ALTITUDE / SPEED / LEG / TURN`，`LEG / TURN` 列在固定布局中压缩到旧视觉宽度约 60%，避免长 leg 描述挤出高度 / 速度列。iPhone 下 Selection 标题、表头和正文会进一步压缩，日间主题会为高度 / 速度 / leg 内容使用不透明深色文字和轻量行底色。地图上的限制标牌与更多 leg 类型专用符号仍需继续对齐 Web UI。
- `/api/route/resolve` 已能返回基础手动解析路线，尚未完整迁移 Web 自动规划、`***` 和复杂航路择优算法。
- Plan / Airport / Settings 常用路径已完成中文化第一轮；离线地图管理标题、标签、资源类型、供应商类型 / 格式、下载进度、范围选择和离线地形状态提示已中文化，少量网络错误和底层服务错误仍需在保持交互结构的前提下继续中文化。
- 双指缩放和软键盘高度仍需在真机上继续回归；当前 iPhone 17 Pro 模拟器已验证点击输入框可唤起键盘并输入、无系统附件栏、页面不整体上移、平移、缩放按钮、点击弹窗和连续点按防页面放大。
- 地图内核是第一阶段过渡方案，后续可评估 MapLibre Native 或更深原生化。
