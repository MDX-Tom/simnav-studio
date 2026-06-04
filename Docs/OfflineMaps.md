# Offline Maps

离线地图模块负责管理本地离线地图资源，并为 WebView 地图内核提供本地瓦片读取。

## 当前实现

- 扫描目录：`Application Support/NavPlanner/MapOffline`。
- 支持识别扩展名：`.pmtiles`、`.mbtiles`、`.sqlite`、`.sqlite3`。
- 支持识别 Web 参考版 `map_offline` 资源目录：`metadata.json`、`tiles.sqlite`、`tiles/`、`resource.pmtiles`。
- 输出资源名称、类型、存储布局、文件大小、瓦片数量、缩放范围和 bounds。
- `navplanner://api/offline-maps` 已接入。
- Web 参考版离线地图弹窗所需的 `select`、`delete`、`compact`、`download`、`cancel` API 已有 Swift 响应；`select` / `delete` 已实际生效，`download` / `cancel` 不启动 Python 下载器，而是由 Swift 本地下载任务直接写入 SQLite 瓦片库。
- 离线地图管理入口已移动到 Settings：设置页显示活动资源和下载摘要，下排提供“管理离线地图 / 刷新状态”；下载功能整合在离线地图管理页内部，地图右下角不再常驻离线地图按钮。
- 离线地图管理 UI 使用透明偏暗背景和居中弹窗；iPhone 下限制窗口宽高，压缩标题、标签、按钮、表单和范围选择控件尺寸，内容在弹窗内部滚动。
- 缺失的离线瓦片返回透明 PNG，避免底图缺失阻塞地图叠加层。
- `MapStore.activeTile(...)` 和 `MapStore.resourceTile(...)` 已实现真实本地瓦片读取：
  - Web `tiles.sqlite`：读取 `tiles(z, x, y, data)`。
  - MBTiles：读取 `tiles(zoom_level, tile_column, tile_row, tile_data)`，按 TMS y 翻转匹配 Leaflet URL。
  - Web 文件布局：读取新版 `tiles/zXX/shard/xxxxxxxx_yyyyyyyy.ext` 和旧版 `tiles/z/x/y.ext`。
- `MapStore.pmtilesFileResponse(...)` 已支持 PMTiles Range 读取：
  - Web 目录资源读取 `resource.pmtiles`。
  - 单文件 `.pmtiles` 资源读取自身文件。
  - 支持完整响应、`bytes=start-end`、`bytes=start-`、`bytes=-suffix` 和 416 `Content-Range`。
  - 响应包含 `Accept-Ranges: bytes` 与长期缓存头，供前端 `pmtiles://` protocol 随机读取。
- 矢量瓦片若为 gzip PBF，会补 `Content-Encoding: gzip`。
- App 内不会启动 Python 下载器；下载按钮当前支持 `OpenTopoMap Terrain`、`Esri World Topographic`、`OpenStreetMap Standard`、`OpenFreeMap Vector` 四类供应商，按 Web 表单的范围、缩放和分级策略估算瓦片数量，后台下载并写入 `tiles.sqlite`。
- Swift 下载任务支持状态轮询、取消请求、单瓦片重试、连续失败自动中止、下载速度估算、完成后写入 `metadata.json`，新资源可立即被离线地形底图选择和读取。
- 离线地图管理页可见文案已进一步中文化：资源类型、供应商类型 / 格式、下载进度、范围选择按钮和离线地形状态提示均不再显示 `vector`、`raster`、`Offline Terrain` 等英文残留。
- 下载器已从串行任务升级为 Web 同形态的有界并发：启动前先探测第一个瓦片；运行时使用 12 个 worker、24 个在途任务上限；状态 payload 输出 `download_workers`、`inflight_limit`、`active_downloads`、`bytes_per_second` 和 `tiles_per_second`。
- 按最新产品要求已取消离线地图下载代理服务器设置：下载表单不再显示代理字段，`OfflineDownloadRequest` 不再接收 `proxyURL`，`URLSessionConfiguration` 使用系统直连默认配置。
- 下载过程中会跳过已存在的 SQLite 瓦片；若同名资源目录里存在 Web 旧散瓦片布局，会迁移写入 `tiles.sqlite`；SQLite 每 250 个写入提交一次以降低大任务磁盘同步压力。

## 设计约束

- 离线地图读取不能阻塞 nav-overlay。
- 底图失败或未安装地图包时，地图叠加层仍然显示。
- 优先单文件资源，兼容 Web 参考版旧散瓦片目录，避免破坏已有 `map_offline` 资源。

## 后续

- 使用真实 PMTiles 地图包在模拟器 / 真机上做 MapLibre 离线矢量底图视觉回归。
- 原生导入、删除、启用和空间占用统计。
- 使用真实大范围下载任务继续做真机 / 模拟器压力回归，观察取消响应、直连网络和 SQLite 写入性能。
- 将 Web 离线地图管理 UI 的行为与 Swift `MapStore` 的真实读写能力逐项对齐。
