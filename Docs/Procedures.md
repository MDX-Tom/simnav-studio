# Procedures

Procedure 模块负责 SID、STAR、APPROACH 的列表、明细和地图绘制。

## 当前实现

- 机场详情返回 `procedures.sid`、`procedures.star`、`procedures.approach` 摘要。
- `navplanner://api/procedure/{type}/{airport}/{procedure}/{transition}` 返回：
  - `items`
  - `path`
  - `primary_path`
  - `missed_path`
- 地图弹窗可选择 Procedure 并绘制路径。
- APPROACH 使用紫色，SID 使用青色，STAR 使用橙色。
- `/api/route/resolve` 在 Route 留空时会读取 `departure_runway` / `arrival_runway`，选择匹配跑道的 SID / STAR，并附带优先 APPROACH。
- 自动选择的 Procedure 会通过 `selected_procedures` 回给 Web 工作台，前端会调用现有 `previewProcedure(..., source: "auto")` 绘制并高亮对应 chip。
- Procedure Selection 明细表使用 `SEQ / WAYPOINT / ALTITUDE / SPEED / LEG / TURN` 顺序，`LEG / TURN` 列放在高度 / 速度后方，并通过固定表格布局压缩到旧视觉宽度约 60%；iPhone 下标题、表头和表格正文更小，日间主题下各内容列使用不透明深色文字和轻量行底色保持可读。表格摘要、阶段标签和 leg 特征说明已中文化，例如主段 / 最后进近 / 跑道 / 复飞、左转 / 右转、弧线和等待。
- `PlannerService.buildProcedureGeometry` 已按 Web `procedure_geometry` 迁移：
  - RF / AF：使用中心点、本段 magnetic course、前后相邻点进行方向评分并插值生成弧线点。
  - 复飞：遇到跑道航点后切换到 `missed_path`，保持 `primary_path` / `missed_path` 与 Web 输出一致。
  - 等待航线：复飞末端 HA / HF / HM 会按 inbound course、holding distance/time 和转弯方向生成一圈等待航线。
- Procedure 行归一化已按 Web `_normalize_procedure_rows` 对齐：按 `route_type + seqno` 分组，过滤无半径且中心点为 `LSC*` 的 RF / AF 行，并用已使用航点参与打分，避免 ZULS 这类复飞段误画额外大圆。
- `Tools/ProcedureParity/procedure_parity.py` 会自动编译 Swift 探针，并与 Web 参考 `procedure_geometry(...)` 对比 items、path、primary_path、missed_path 的点数和坐标签名。

## 当前限制

- 当前自动接入会尝试用本地 airway graph 连接 SID 终点与 STAR 入口；若没有连续图路径，会回退到 direct leg。完整 Web 图搜索择优、缓存和更多典型航线仍在迁移。
- 速度 / 高度限制已随 `items` 返回，但地图上的限制标牌、更多 leg 类型的专门符号和复杂说明仍需继续对照 Web UI。

## 验证样例

- `BIAR ASKU1D RW19`：Swift 与 Web 参考均返回 `items=5 path=28 primary=28 missed=0`。
- `MTCH NOSO1L RW05`：Swift 与 Web 参考均返回 `items=3 path=26 primary=26 missed=0`。
- `07FA R05-P ALL`：Swift 与 Web 参考均返回 `items=7 path=48 primary=4 missed=45`。
- `07FA R05-P ADONE`：Swift 与 Web 参考均返回 `items=9 path=50 primary=6 missed=45`。
- `ZULS R10L LS995`：Swift 与 Web 参考均返回 `items=36 path=588 primary=223 missed=366`，不再出现额外 `LSC*` RF 大圆。
- `XXXX NOPE ALL`：Swift 与 Web 参考均返回空 payload，不抛出错误。

```bash
python3 Tools/ProcedureParity/procedure_parity.py
```

## 参考来源

- `NavPlanner-web/src/planner_core.py`
- `NavPlanner-web/src/planner_routes.py`
- `NavPlanner-web/static/app.js`
