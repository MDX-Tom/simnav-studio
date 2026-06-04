# Track Parity

Track Parity 是 `/api/route/track-match` 的回归验证工具，目标是在继续迁移 Web 导入轨迹行为时，及时发现 Swift 本地服务与 `NavPlanner-web/` 参考实现之间的 payload 差异。当前工具覆盖 7 个 case，最近一次运行无差异。

## 范围

- 对照 Web 参考：`NavPlanner-web/src/planner_routes.py` 的 `match_imported_track_route(...)`。
- 对照 Swift 实现：`NavPlanner/Core/PlannerCore/PlannerService.swift` 的 `trackMatchPayload(...)`。
- 数据库使用 App 内置 `NavPlanner/Resources/Database/navdata.sqlite`。
- 合成轨迹点由 Web 参考 `resolve_route(...)` 生成，避免依赖 FR24、远程服务或 Python server。
- 对照字段包括 `route_display`、legs 摘要、点数、点列签名、跨日期变更线几何摘要、距离、`selected_procedures`、`selected_runways`、source provider、导入轨迹点数量和基础错误语义。

## 工具

- `Tools/TrackParity/track_parity.py`：编排 Web 参考、Swift 探针编译和字段对比。
- `Tools/TrackParity/TrackParityProbe.swift`：只调用 Swift 本地 `PlannerService`，不访问 Web 代码。

运行：

```bash
python3 Tools/TrackParity/track_parity.py
```

也可以通过统一入口或 Xcode target 运行：

```bash
python3 Tools/Parity/run_all_parity.py

xcodebuild -project NavPlanner.xcodeproj \
  -scheme ParityChecks \
  -configuration Debug \
  -derivedDataPath /private/tmp/NavPlannerParityDerived \
  build
```

## 当前样例

- `KLAX->KPSP`：合成轨迹来自 `DODGR V370 GARNE`。
- `KLAX->KPSP`：合成轨迹来自 `DODGR *** GARNE`。
- 自动航线合成轨迹：`ZBAA->ZSPD`、`VHHH->WSSS`。
- 跨日期变更线合成轨迹：`NFFN->NSTU`。
- 错误边界：导入轨迹点不足、出发机场无法解析。

## 后续扩展

- 加入真实 FR24 / 手动粘贴轨迹样例，覆盖噪声、稀疏点、折返和缺点。
- 补充更多长航线、跨洋航线、无 SID / STAR 机场和多 airway 候选场景。
- 继续扩展 `ParityChecks` 覆盖范围，避免 track-match 迁移回归。
