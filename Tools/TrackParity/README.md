# Track Regression 工具

`track_parity.py` 直接编译 `TrackParityProbe.swift`，调用共享 Swift
`PlannerService.trackMatchPayload(...)`，再与 `Fixtures/expected.json` 的固化摘要比较。

```bash
python3 Tools/TrackParity/track_parity.py
```

完整摘要覆盖 route display、legs、点列签名、跨日期变更线几何、距离、SID / STAR /
Approach、runway、source provider 与导入点数；fixture 保存关键可读字段和完整摘要
canonical SHA-256。`--dump` 只输出当前快照，不改写 fixture。

## 当前 10 个用例

- 5 条离线合成轨迹：`KLAX→KPSP` airway / `***`、`ZBAA→ZSPD`、`VHHH→WSSS`、
  `NFFN→NSTU`。输入航路由同一 Swift route core 生成后抽样，再交给 track-match core。
- 3 条 tracked 稠密真实轨迹：`ZPPP→ZBAA`、部分 SID 的 `ZBAA→ZSSS`、平行跑道 /
  MEBNA 的 `ZBAA→ZPPP`。除完整摘要 hash 外，继续显式断言所选 Procedure、runway、
  enroute 边界和 Procedure item 首末航点，防止终端程序被实际轨迹截断。
- 2 条错误语义：导入点不足、出发机场无法解析。

所有输入位于 `Fixtures/`，不依赖 FR24、旧 Web 目录或网络。Swift probe 显式接收只读数据库
路径，临时编译文件自动放在 `/private/tmp`。
