# Track Parity 工具

`track_parity.py` 用于把 iOS Swift 本地 `PlannerService.trackMatchPayload` 与只读参考项目 `NavPlanner-web/src/planner_routes.py` 的 `match_imported_track_route(...)` 做字段级对照。

## 使用方式

```bash
python3 Tools/TrackParity/track_parity.py
```

工具会执行以下步骤：

- 使用 `NavPlanner-web/src.planner_database.NavDatabase.resolve_route(...)` 生成离线合成轨迹点，避免依赖 FR24 或任何远程服务。
- 使用 `NavPlanner-web/src.planner_database.NavDatabase.match_imported_track_route(...)` 生成 Web 参考摘要。
- 编译 `TrackParityProbe.swift`，直接调用 Swift `PlannerService.trackMatchPayload(...)`。
- 对比 `route_display`、legs 摘要、点数、点列签名、跨日期变更线几何摘要、距离、SID / STAR / Approach、runway 选择、source provider 和导入轨迹点数量。
- 任一字段不一致时以非 0 状态退出，并输出具体差异。

## 当前覆盖

- 导入轨迹匹配：`KLAX->KPSP` 的 `DODGR V370 GARNE` 和 `DODGR *** GARNE`。
- 自动航线合成轨迹：`ZBAA->ZSPD`、`VHHH->WSSS`。
- 跨日期变更线合成轨迹：`NFFN->NSTU`。
- 错误语义：导入轨迹点不足、出发机场无法解析。

## 约束

- 工具只读取 `NavPlanner-web/`，不会修改参考项目。
- Swift 探针编译产物和 case JSON 写入 `/private/tmp`。
- 该工具不是完整验收，只覆盖 `/api/route/track-match` 的离线导入轨迹通路；FR24 在线抓取、真实用户轨迹噪声、前端弹窗命中层和真机触控仍需单独验证。
