# Route Parity

Route Parity 是 `/api/route/resolve` 的回归验证工具，目标是在继续迁移 Web 行为时，及时发现 Swift 本地服务与 `NavPlanner-web/` 参考实现之间的 payload 差异。当前工具已覆盖 22 个 case，最近一次运行无差异。

## 范围

- 对照 Web 参考：`NavPlanner-web/src/planner_routes.py`。
- 对照 Swift 实现：`NavPlanner/Core/PlannerCore/PlannerService.swift`。
- 数据库使用 App 内置 `NavPlanner/Resources/Database/navdata.sqlite`。
- 对照字段包括 `route_display`、legs 摘要、点数、点列签名、跨日期变更线几何摘要、距离、`selected_procedures`、`selected_runways` 和错误语义。

## 工具

- `Tools/RouteParity/route_parity.py`：编排 Web 参考、Swift 探针编译和字段对比。
- `Tools/RouteParity/RouteParityProbe.swift`：只调用 Swift 本地 `PlannerService`，不访问 Web 代码。

运行：

```bash
python3 Tools/RouteParity/route_parity.py
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

- 自动航线：`ZBAA->ZSPD`、`KLAX->KPSP`、`RJTT->PHNL`、`EGLL->KJFK`、`YSSY->NZAA`、`VHHH->WSSS`、`OMDB->EDDF`、`AGGF->AYKM`。
- 跨日期变更线：自动 `NFFN->NSTU`、`NSTU->NFFN`、`PHNL->PGUM`、`NFFN->NSFA`，手动 `NN G224 TUT`、`TUT G224 NN`。
- 手动航路：`DODGR V370 GARNE`、`DODGR DCT GARNE`、`DODGR *** GARNE`。
- 查找优先级：`DODGR DCT FRE`。
- 错误边界：起始 `DCT`、缺少 `DCT` 目标、airway 缺 exit、`***` 缺目标。

当前已发现并修复的差异：

- Swift 手动 route payload 曾额外返回 `selected_runways`，Web 参考没有该字段；当前已按 Web 原始 payload 形态移除，前端仍会在 `buildRoute` 中按当前跑道状态补齐运行时默认值。

## 后续扩展

- 加入更多混合 airway、长航线和 procedure runway 指定样例。
- 为跨日期变更线航线补充前端绘制、规划航路 hit layer 和多世界副本点击回归。
- 继续扩展 `ParityChecks` 覆盖范围，避免 route 迁移回归。
