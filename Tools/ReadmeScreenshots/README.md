# README 截图回归

`capture_readme_screenshots.sh` 会重放 README 的 5 个核心工作流，并为 iPhone 17 Pro 竖屏、iPad Pro 13 英寸横屏生成英语 / 简体中文、亮色 / 暗色共 40 张 WebP。

## 固定动作

所有场景先通过本地 API 自动规划 `LGAV → EDDM`，关闭密集的 nav-overlay，并等待 Debug 日志出现 `NavPlanner screenshot ready` 后再截图。除 STAR 外的场景会在标签、banner、图表稳定后重新 fit 完整航路，保留 52 px 边距、限制过度放大，并在日志同时确认 `clippedPoints: 0` 与 `clippedLabels: 0`，避免端点文字虽然坐标在视口内却仍贴边截断。STAR 场景改为验证程序总览自己的可见范围，避免把跨国主航路一起 fit 后导致机场程序过小。

| 编号 | 场景 | 脚本重放动作 |
|---:|---|---|
| 01 | Plan | 填写 LGAV、EDDM；航路留空；自动规划；展开 iPhone banner 至地图占 52%。 |
| 02 | Airport / STAR | 自动规划后打开 Airport；切换到 EDDM；**先选择 RW08R**；点击 STAR 标题进入多程序总览；显示全部匹配 STAR 与标签；按总览几何重新 fit，确认无截断。iPhone 将 banner 展开到地图占 58%，让地图与程序列表同时可见。 |
| 03 | Calculate | 选择 A320-200；设置 ZFW、燃油、FL370、M0.78、下降率；展开 banner；滚动至航路剖面。 |
| 04 | FR24 | 生成确定性的 A3 802 / 480 点本地航迹；绘制并标记“当前绘制”；展开 banner；显示高度 / 速度剖面。 |
| 05 | Settings | 打开 Settings；仅为截图切换到离线地图子菜单；滚动至离线地图管理卡片。 |

## 运行

1. 在 Xcode 与 Device Hub 中启动 iPhone 17 Pro 和 iPad Pro 13-inch 模拟器。
2. 保持 iPhone 竖屏；在 Device Hub 选择 iPad 并点击一次 **Rotate Left**，确认 App 是横屏三栏布局。
3. 执行：

```bash
Tools/ReadmeScreenshots/capture_readme_screenshots.sh
```

可用 `NAVPLANNER_CAPTURE_FILTER` 只更新一个子集，例如：

```bash
NAVPLANNER_CAPTURE_FILTER='en-day-04-fr24-iphone' \
  Tools/ReadmeScreenshots/capture_readme_screenshots.sh
```

脚本将原始 PNG、每次启动日志、完整 Debug JSON manifest，以及直接由当前 40 张 WebP 重建的 8 张联系表写入已被 `.gitignore` 忽略的 `codex/ux-tests/2026-08-09-lgav-eddm/`；公开产物写入 `Media/workflows/`。即使只定向重拍一张图，只要 40 张公开图仍齐全，脚本也会刷新全部联系表，避免本地视觉证据滞后。完整批次最后会分别用各语言亮色 / 暗色 STAR 场景组合 iPhone / iPad 首页 hero，README 通过 `<picture>` 跟随系统主题切换。Hero 合成器会把 iPhone 与 iPad 截图矩形分别垂直居中；1450×900pt 画布上的 iPad 连同外扩 7pt 设备框后，上下纯色留白均为 30.5pt（最终 2× WebP 各 61px），禁止顶部贴边、底部留出不对称大空白。每张 WebP 会自动缩放和逐级调质，超过 150 kB 时任务失败。STAR 截图还会断言程序总览已激活且 `clippedPoints: 0`，因此路线/程序缩放不能过大、过小或越出画面；Calculate 与 FR24 场景会比较 SVG `viewBox` 和实际 client 尺寸的横纵缩放比，非等比轴或文字压缩会直接让任务失败。
