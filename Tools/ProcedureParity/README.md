# Procedure Parity 工具

`procedure_parity.py` 用于把 iOS Swift 本地 `PlannerService.procedurePayload` 与只读参考项目 `NavPlanner-web/src/planner_core.py` 的 `procedure_geometry(...)` 做字段级对照。

## 使用方式

```bash
python3 Tools/ProcedureParity/procedure_parity.py
```

工具会执行以下步骤：

- 使用 `NavPlanner-web/src.planner_database.NavDatabase.procedure_geometry(...)` 生成 Web 参考摘要。
- 编译 `ProcedureParityProbe.swift`，直接调用 Swift `PlannerService.procedurePayload(...)`。
- 对比 Procedure 明细行签名、完整 path、primary path、missed path 的点数和坐标签名。
- 任一字段不一致时以非 0 状态退出，并输出具体差异。

## 当前覆盖

- SID RF 弧线：`BIAR ASKU1D RW19`。
- STAR RF 弧线：`MTCH NOSO1L RW05`。
- Approach 复飞和末端等待航线：`07FA R05-P ALL`。
- Approach transition + runway 段合并：`07FA R05-P ADONE`。
- Approach 复飞异常圆弧回归：`ZULS R10L LS995`。
- 空结果：不存在的 `XXXX NOPE ALL`。

## 约束

- 工具只读取 `NavPlanner-web/`，不会修改参考项目。
- Swift 探针编译产物和 case JSON 写入 `/private/tmp`。
- 该工具不是完整验收，只覆盖 `/api/procedure/...` 的几何 payload；前端 Procedure chip 高亮、地图点击和视觉样式仍需单独验证。
