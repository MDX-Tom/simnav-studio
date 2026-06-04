# LocalDataStore

LocalDataStore 负责把内置导航数据库复制到 Application Support，并提供串行 SQLite 读取。

## 当前实现

- 源码内置资源路径：`NavPlanner/Resources/Database/navdata.sqlite`。
- App Bundle 运行时路径：`Database/navdata.sqlite`。
- 首次启动复制到：`Application Support/NavPlanner/Database/navdata.sqlite`。
- 使用 `SQLite3` C API，不依赖 Python 或本地 HTTP server。
- 查询通过串行队列执行，避免同一 SQLite 连接被并发访问。
- 提供内部 `init(databaseURL:)` 入口，供命令行探针和后续单元测试直接打开 fixture 数据库，不影响 App 正常复制到 Application Support 的启动路径。
- 支持通过 Settings 页面导入 `.s3db` / `.sqlite` / `.sqlite3` / `.db`，文件会复制到 Application Support 的 `NavPlanner/Database/` 下，并统一保存为 `.sqlite`。
- 导入成功后会重新打开 SQLite 连接，后续 `header`、`search`、`airport`、`procedure`、`nav-overlay` 均读取新的本地数据库。
- `header` payload 包含 `database_name` 和 `database_path`，供 Settings 页面显示当前数据库状态。
- `PlannerService.headerPayload()` 避免在 `LocalDataStore.read` 的串行队列内再次调用 `statusPayload()`，防止同步队列重入死锁。
- `PlannerService` 的 airway graph / route-between / nav-overlay 缓存以 `databaseURL.path` 为边界；`AppEnvironment.importDatabase(from:)` 在切库成功后会调用 `invalidatePlanningCaches()`。

## 已接入查询

- `tbl_header`
- 机场 / 航点 / VOR / NDB 搜索
- 机场详情、跑道、通信频率
- SID / STAR / APPROACH 摘要
- Procedure RF / AF 弧线、复飞和等待航线几何
- nav-overlay 的机场、航路、航点、terminal waypoint、导航台、terminal navaid、跑道和 ILS 输出

## 后续

- 增加常用查询索引检查。
- 增加单元测试 fixture。
- 校验导入数据库 schema，给出更友好的不兼容提示。
