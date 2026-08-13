# Core Regression 工具

`run_all_parity.py` 是共享 Swift 业务核心的统一行为回归入口，会顺序运行：

- `Tools/RouteParity/route_parity.py`
- `Tools/TrackParity/track_parity.py`
- `Tools/ProcedureParity/procedure_parity.py`

三组检查直接编译仓库中的 `PlannerService`、`LocalDataStore`、`SQLiteDatabase` 与对应
Swift probe，并把当前摘要与 tracked fixtures 比较。它们不读取已删除的旧 Web 项目，也不
启动 Python server。fixture 同时记录数据库 SHA-256 / AIRAC，并以关键可读字段加完整摘要
canonical SHA-256 锁住原 Route 22、Track 10、Procedure 6 的覆盖语义。

## 命令行运行

```bash
python3 Tools/Parity/run_all_parity.py
```

默认使用 ignored `NavPlanner/Resources/Database/navdata.sqlite`；也可显式传入同一版本的
数据库：

```bash
NAVPLANNER_PARITY_DATABASE=/absolute/path/navdata.sqlite \
  python3 Tools/Parity/run_all_parity.py
```

数据库 fingerprint 与 fixture 不一致会 fail closed，避免把数据周期变化误判为算法回归。
输出为 JSON，任一子检查失败时以非 0 状态退出。Swift 编译产物与 case JSON 只写入自动
回收的 `/private/tmp/SimNav*` 临时目录。

## Xcode 运行

工程中的 `ParityChecks` Aggregate Target / shared scheme 可直接 Build，也可使用：

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project NavPlanner.xcodeproj \
  -scheme ParityChecks \
  -configuration Debug \
  -derivedDataPath /private/tmp/NavPlannerParityDerived \
  build
```

该 target 不产出 App，只执行同一组 Swift fixture regression。
