# Codex Goal

本文记录新开 Codex 线程时建议使用的 `/goal` 草案。当前项目已经完成基础 iOS 工程骨架和离线 MVP 主通路，后续目标应从“搭建 App”切换为“对齐 Web 行为、稳定离线能力、优化性能和真机体验”。

## 建议 `/goal`

```text
你正在继续开发 NavPlanner iOS。请先阅读根目录 README.md、TODO.md、codex_report.md、Docs/CodexGoal.md，并按任务读取 Docs/AppIcon.md、Docs/Settings.md、Docs/WebParity.md、Docs/RouteResolve.md、Docs/RouteParity.md、Docs/TrackParity.md、Docs/ProcedureParity.md、Docs/OfflineMaps.md 等子文档。

NavPlanner-web/ 是只读参考项目，只用于理解现有 Web 航空航路规划器的功能、数据结构、API 形态、地图交互和算法行为。除非我明确要求，不要修改 NavPlanner-web/ 中任何文件。

当前 App 是 iPhone / iPad Universal App，采用 SwiftUI 原生外壳 + WKWebView 地图工作台 + Swift 本地服务层。核心能力必须本地优先、可离线运行，不能依赖 Python server、远程服务或局域网服务完成核心查询、规划、Procedure 查看、nav-overlay 和离线地图显示。在线能力只能作为增强功能，失败或断网时不得阻塞核心叠加层和本地服务。

下一阶段目标：
1. 继续对齐 NavPlanner-web 的端到端行为，不只对齐 API。重点检查航路规划、Procedure 绘制、nav-overlay、地图拖动缩放、跨日期变更线、弹窗点击/关闭、非规划航路点击、表格和错误提示。
2. 优化性能和触控体验，重点关注 iPhone 小屏、横屏刘海/灵动岛安全区、软键盘、iPad 横竖屏、地图拖动/缩放帧率、矢量底图与航路叠加层同步、Procedure 大几何绘制。
3. 强化离线地图能力，验证 PMTiles / MBTiles / SQLite 瓦片库、大范围下载、取消恢复、空间占用、在线地图缓存清理和断网可用性。
4. 保持中文 UI、中文文档和必要中文注释；不要引入其他飞行模拟器品牌痕迹。
5. 每次改动后同步维护 README.md、TODO.md、相关 Docs/*.md 和 codex_report.md。Web/CSS/JS 改动后刷新 map.html 的资源版本。
6. 优先使用现有 parity 工具和 XcodeBuildMCP 验证；关键校验包括 node --check、CSS 括号检查、plutil、Tools/Parity/run_all_parity.py、Xcode build/run 和必要截图。
7. 不要做简单 WKWebView 套壳式倒退；Swift 本地服务层和离线能力必须继续保留并演进。

在没有明确要求的情况下，不要创建或修改 Git 远端，不要自动提交。可以维护 .gitignore、文档、测试工具和本地校验流程。
```

## 接手优先级

1. 先跑 `python3 Tools/Parity/run_all_parity.py`，确认 route / track / procedure parity 基线。
2. 再跑 `node --check NavPlanner/Resources/Web/app.js`、CSS 括号检查和 `plutil -lint`。
3. 有 UI 改动时用 XcodeBuildMCP 在 iPhone 17 Pro / iPhone 17 Pro Max / iPad Pro 至少一个代表设备 build/run。
4. 涉及地图、键盘、安全区或 Settings 时尽量截图复核。
5. 涉及 App 图标时运行 `swift Tools/Icon/generate_app_icons.swift`，并检查 asset catalog、Settings 预览和 Xcode 备用图标配置。

## 不要忘记

- `NavPlanner-web/` 是只读参考项目。
- `NavPlanner/Resources/Web/` 是 iOS 自有 Web 工作台副本，可以按 iOS 需求修改。
- `NavPlanner/Resources/Database/navdata.sqlite` 是内置导航数据库资源，构建时会打包进 App。
- `Tools/Icon/navplanner-terrain-liquid-glass-source.png` 是当前 App 图标源图。
- `.gitignore` 已忽略 Xcode DerivedData、Swift `.build`、macOS `.DS_Store`、Python 缓存和 Web 参考项目运行时缓存。
