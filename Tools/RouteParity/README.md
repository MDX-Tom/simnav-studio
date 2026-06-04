# Route Parity 工具

`route_parity.py` 用于把 iOS Swift 本地 `PlannerService.routeResolvePayload` 与只读参考项目 `NavPlanner-web/src/planner_routes.py` 做字段级对照。

## 使用方式

```bash
python3 Tools/RouteParity/route_parity.py
```

工具会执行以下步骤：

- 使用 `NavPlanner-web/src.planner_database.NavDatabase.resolve_route(...)` 生成 Web 参考摘要。
- 编译 `RouteParityProbe.swift`，直接调用 Swift `PlannerService.routeResolvePayload(...)`。
- 对比 `route_display`、legs 摘要、点数、点列签名、跨日期变更线几何摘要、距离、SID / STAR / Approach、runway 选择和错误语义。
- 任一字段不一致时以非 0 状态退出，并输出具体差异。

## 当前覆盖

- 典型自动航线：`ZBAA->ZSPD`、`KLAX->KPSP`、`RJTT->PHNL`、`EGLL->KJFK`、`YSSY->NZAA`、`VHHH->WSSS`、`OMDB->EDDF`、`AGGF->AYKM`。
- 跨日期变更线：自动 `NFFN->NSTU`、`NSTU->NFFN`、`PHNL->PGUM`、`NFFN->NSFA`，手动 `NN G224 TUT`、`TUT G224 NN`。
- 手动航路：`DODGR V370 GARNE`、`DODGR DCT GARNE`、`DODGR *** GARNE`。
- 查找优先级：`FRE` 同时作为 IATA 和 waypoint 时，手动 route token 应优先解析为 waypoint。
- 错误语义：起始 `DCT`、缺少 `DCT` 目标、airway 缺 exit、`***` 缺目标。

## 约束

- 工具只读取 `NavPlanner-web/`，不会修改参考项目。
- Swift 探针编译产物和 case JSON 写入 `/private/tmp`。
- 该工具不是完整验收，只是 `/api/route/resolve` 的可重复回归护栏；跨日期变更线地图绘制视觉、弹窗命中层、离线地图视觉和 FR24 在线增强仍需单独验证。
