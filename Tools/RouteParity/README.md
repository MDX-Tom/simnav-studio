# Route Regression 工具

`route_parity.py` 直接编译 `RouteParityProbe.swift`，调用共享 Swift
`PlannerService.routeResolvePayload(...)`，再与 `Fixtures/expected.json` 的固化摘要比较。

```bash
python3 Tools/RouteParity/route_parity.py
```

完整摘要包含 route display、legs、点列签名、跨日期变更线几何、距离、SID / STAR /
Approach、runway 与错误语义；fixture 保存关键可读字段和完整摘要 canonical SHA-256。用
`--dump` 可审阅当前数据库 fingerprint 与当前摘要快照，但不会改写 fixture。

## 当前 22 个用例

- 自动航线：`ZBAA→ZSPD`、`KLAX→KPSP`、`RJTT→PHNL`、`EGLL→KJFK`、
  `YSSY→NZAA`、`VHHH→WSSS`、`OMDB→EDDF`、`AGGF→AYKM`。
- 跨日期变更线：自动 `NFFN→NSTU`、`NSTU→NFFN`、`PHNL→PGUM`、`NFFN→NSFA`，
  手动 `NN G224 TUT`、`TUT G224 NN`。
- 手动航路：`DODGR V370 GARNE`、`DODGR DCT GARNE`、`DODGR *** GARNE`。
- 查找优先级：`FRE` 同时作为 IATA 与 waypoint 时，route token 仍解析为 waypoint。
- 错误语义：起始 `DCT`、缺少 `DCT` 目标、airway 缺 exit、`***` 缺目标。

case 与期望均位于 `Fixtures/`；Swift probe 显式接收只读数据库路径，临时编译文件自动放在
`/private/tmp`。该检查不依赖旧 Web 目录或网络。
