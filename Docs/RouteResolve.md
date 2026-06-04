# Route Resolve

`/api/route/resolve` 负责把 Web 工作台输入的起飞机场、到达机场、跑道和航路文本解析为本地离线航路 payload。iOS 版必须在 Swift 客户端内完成，不依赖 Python server。

## 当前实现

- Swift `PlannerService.routeResolvePayload` 承接 Web 工作台的 `/api/route/resolve` 请求，并返回与 Web 版同形态的 `departure`、`arrival`、`legs`、`points`、`segments`、`route_display`、`selected_procedures` 和 `selected_runways`。
- 手动航路支持普通航点串、`DCT`、`airway + exit fix`、`***` 自动补航段，以及带 airway 上下文的边界点解析。
- 起降点与普通 route token 使用 Web 同形态的两套查找优先级：
  - 起降点先按机场 ICAO / IATA 解析，失败后再按普通点解析。
  - 普通 route token 依次查机场 ICAO、enroute waypoint、terminal waypoint、VOR、NDB，最后才用机场 IATA 兜底。
- Route 留空时会优先尝试 SID / STAR / APPROACH 接入，并用本地 airway graph 连接 enroute 段。
- airway graph 和 route-between 结果按当前数据库路径缓存；用户在 Settings 导入新数据库后会失效重建。
- airway graph 构建和 airway 展开已按 Web 的 `route_identifier + seqno + _partition_airway_rows` 行为收敛，不再按 `area_code/icao_code/route_type` 额外切断同名 airway；Dijkstra heap 和候选列表加入与 Python `heapq` / tuple 排序一致的 key tie-break。
- Procedure 候选保留 SQL 顺序进行分组，空 transition / SQLite `NULL` 统一成 `ALL`，Approach 排序避免前缀字符串被分隔符反转，贴近 Web `_procedure_connection_candidates` 和 `_select_approach_candidate`。
- 自动航路压缩已迁移 Web `_merge_continuing_airway_legs` 行为：当 Dijkstra 路径临时切换到相邻 airway，但上一条 airway 可以合法贯通并且距离没有明显绕行时，会合并为上一条 airway 的连续段，减少 `legs` 和 `route_display` 与 Web 版的差异。
- 重复 airway 合并已按 Web `_merge_repeated_airway_legs` 对齐：除了相邻同 airway，还会处理 A-B-A 这种隔一段后回到同 airway 的显示压缩，并保留非 airway leg。
- `route_display` 已拆分为普通显示和展开显示两套规则：普通显示忽略非 airway / direct leg，展开显示保留手动输入中的 fix，贴近 Web `_display_route_from_legs` 和 `_display_route_from_expanded_legs`。
- Swift 内部 route-between 搜索已补齐 Web `_ifrr_route_between_with_exclusions` 的 excluded airway 参数通路：Dijkstra edge 扩展和同航路优先候选都会跳过排除航路，默认空排除集继续使用 route-between 缓存，非空排除集只复用 airway graph、不写入默认缓存。

## 当前限制

- 多 airway mixed-route 的权重细节仍需用典型航线继续对照 Web 参考输出。
- 22 个 route resolve case 已由 `Tools/RouteParity/route_parity.py` 做可重复 Swift/Web 对照，包含典型自动航线、手动航路、错误语义和跨日期变更线自动 / 手动航线；仍需逐步沉淀为 Xcode 测试目标。
- FR24 在线增强不属于本接口，但会复用部分 airway graph 匹配逻辑，仍需继续迁移。

## 验证重点

- 手动 route：`DODGR V370 GARNE`、`DODGR DCT GARNE`、`DODGR *** GARNE` 的 `legs`、点数和 `route_display` 应与 Web 一致。
- 自动 route：观察 `route_display` 是否避免把可连续贯通的同一 airway 视觉上拆成多段。
- 典型自动 route：`ZBAA->ZSPD`、`KLAX->KPSP`、`RJTT->PHNL`、`EGLL->KJFK`、`YSSY->NZAA`、`VHHH->WSSS`、`OMDB->EDDF`、`AGGF->AYKM` 的 route display、legs、点列签名、距离和选中 Procedure 应与 Web 参考一致。
- 手动 route 和错误边界：`DODGR V370 GARNE`、`DODGR DCT GARNE`、`DODGR *** GARNE`、`DODGR DCT FRE`、起始 `DCT`、缺少目标等应由 RouteParity 工具持续对照 Web。
- 日期变更线：`NFFN->NSTU`、`NSTU->NFFN`、`PHNL->PGUM`、`NFFN->NSFA`、`NN G224 TUT`、`TUT G224 NN` 的 payload 点列、raw 经度跳变和 unwrap 后经度跨度应与 Web 参考一致；前端 polyline 世界副本和点击命中层仍需继续运行时回归，避免地图大直线。

## 参考来源

- `NavPlanner-web/src/planner_routes.py`
- `NavPlanner/Core/PlannerCore/PlannerService.swift`
- `NavPlanner/Resources/Web/app.js`
- `Tools/RouteParity/route_parity.py`
