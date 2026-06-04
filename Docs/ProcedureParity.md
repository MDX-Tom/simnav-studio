# ProcedureParity

`Tools/ProcedureParity/procedure_parity.py` 用于回归 Swift 本地 Procedure 几何与只读 Web 参考实现的一致性。

## 覆盖范围

- SID RF 弧线：`BIAR ASKU1D RW19`。
- STAR RF 弧线：`MTCH NOSO1L RW05`。
- Approach 复飞和末端等待航线：`07FA R05-P ALL`。
- Approach transition + runway 段合并：`07FA R05-P ADONE`。
- Approach 复飞异常圆弧回归：`ZULS R10L LS995`。
- 空结果语义：不存在的 `XXXX NOPE ALL`。

## 对比内容

- Procedure 明细 `items` 签名。
- 完整 `path` 点数和坐标签名。
- `primary_path` 点数和坐标签名。
- `missed_path` 点数和坐标签名。

## 运行方式

```bash
python3 Tools/ProcedureParity/procedure_parity.py
```

也可以通过统一入口或 Xcode scheme 运行：

```bash
python3 Tools/Parity/run_all_parity.py
xcodebuild -project NavPlanner.xcodeproj -scheme ParityChecks -configuration Debug -derivedDataPath /private/tmp/NavPlannerParityDerived build
```

该工具只读取 `NavPlanner-web/`，Swift 探针编译产物写入 `/private/tmp`，不会修改参考项目。
