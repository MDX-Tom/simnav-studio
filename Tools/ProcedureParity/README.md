# Procedure Regression 工具

`procedure_parity.py` 直接编译 `ProcedureParityProbe.swift`，调用共享 Swift
`PlannerService.procedurePayload(...)`，再与 `Fixtures/expected.json` 的固化摘要比较。

```bash
python3 Tools/ProcedureParity/procedure_parity.py
```

完整摘要覆盖 Procedure 明细行、完整 path、primary path、missed path 的点数与六位坐标签名；
fixture 保存各路径可读计数和完整摘要 canonical SHA-256。`--dump` 只输出当前快照，不改写
fixture。

## 当前 6 个用例

- SID RF 弧线：`BIAR ASKU1D RW19`。
- STAR RF 弧线：`MTCH NOSO1L RW05`。
- Approach 复飞与末端 holding：`07FA R05-P ALL`。
- Approach transition + runway 段合并：`07FA R05-P ADONE`。
- Approach 异常大圆回归：`ZULS R10L LS995`。
- 空结果：不存在的 `XXXX NOPE ALL`。

case 与期望均位于 `Fixtures/`；Swift probe 显式接收只读数据库路径，临时编译文件自动放在
`/private/tmp`。该检查不依赖旧 Web 目录或网络。
