# ParityChecks 工具

`run_all_parity.py` 是 Swift/Web 行为回归的统一入口，会顺序运行：

- `Tools/RouteParity/route_parity.py`
- `Tools/TrackParity/track_parity.py`
- `Tools/ProcedureParity/procedure_parity.py`

## 命令行运行

```bash
python3 Tools/Parity/run_all_parity.py
```

输出为 JSON，任一子检查失败时以非 0 状态退出。

## Xcode 运行

工程中已新增 `ParityChecks` Aggregate Target 和共享 scheme。可在 Xcode 里选择 `ParityChecks` 后 Build，也可以使用命令：

```bash
xcodebuild -project NavPlanner.xcodeproj \
  -scheme ParityChecks \
  -configuration Debug \
  -derivedDataPath /private/tmp/NavPlannerParityDerived \
  build
```

该 target 不产出 App，只执行脚本校验；当前会访问只读 `NavPlanner-web/` 作为参考实现，并把 Swift 探针编译产物写到 `/private/tmp`。
