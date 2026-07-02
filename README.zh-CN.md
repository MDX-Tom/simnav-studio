# NavPlanner

<p align="center">
  <img src="NavPlanner/Resources/Web/app-icons/day-medium.png" alt="NavPlanner 图标" width="104" height="104" />
</p>

<p align="center">
  面向 iPhone 与 iPad 的模拟飞行一站式航路规划与地图工作台。
  <br />
  <a href="README.md">English</a>
</p>

<p align="center">
  <img alt="NavPlanner iPhone 航路规划界面" src="Media/iphone-us.png" width="260" />
  &nbsp;&nbsp;
  <img alt="NavPlanner iPad 地图工作台" src="Media/ipad-us.png" width="520" />
</p>

NavPlanner 是一款面向模拟飞行的原生 iOS 规划工作台。它把 **航路规划**、**机场与 Procedure 查看**、**离线地图**、**本地导航数据库** 和可选 **FR24 在线轨迹下载、对照和拟合** 集中在一个 App 中，强调 **从航线构思到地图复盘的一体化工作流** 且 **离线可用**。

App 采用 SwiftUI 原生外壳、WKWebView 地图工作台和随 App 打包的 Swift 服务层，定位于模拟飞行、学习研究和个人规划练习。

**重要免责声明：** NavPlanner 不是认证航空软件，严禁用于真实飞行计划、真实导航、签派放行、运行决策或任何安全关键航空活动。

## 功能亮点

- **本地航路规划**：输入起飞机场、到达机场和航路文本，生成并绘制航路；航路留空时自动规划整条航路，也可在航点间输入 `***` 自动规划片段。
- **Procedure 预览**：按跑道查看并绘制 `SID`、`STAR`、`APPROACH`，支持 RF / AF 弧线、复飞段和等待航线几何。
- **地图叠加层与绘制控制**：独立显示或隐藏底图、计划航路、人工航路、Procedure、FR24 轨迹、terminal waypoints、其他航点、导航台、跑道、ILS 和 airway 标签；可在地图上撤销、重做或清除已绘制轨迹。
- **机场工作台**：查看跑道、通信频率、Procedure 列表和地图弹窗；可从地图快速设置起飞、到达或手动机场。
- **计算工作台**：选择飞机公司、具体机型、ZFW、携带燃油、巡航高度、巡航 Mach、下降率、气象数据源和重量单位，查看航路风速 / 地形剖面、地速 / 垂直速度剖面，并以 SimBrief 风格估算燃油。
- **FR24 轨迹对照**：通过 App 内浏览器同步会话后，可查询航线近期航班或指定 flightId、查看历史、下载或手动导入 GPX 轨迹、查看高度 / 速度剖面，并把轨迹匹配回本地航路。
- **离线地图**：支持导入或下载 PMTiles、MBTiles、SQLite 瓦片库和 Web 旧版 `tiles/` 布局；离线地图包、在线缓存、下载进度和空间占用分开管理。
- **本地导航数据库**：从 Files 导入 `.s3db`、`.sqlite`、`.sqlite3` 或 `.db` 文件，切换本地数据库、删除未使用副本、恢复内置数据库。

## 使用方式

### 规划并绘制航路

1. 打开 **计划** 页。
2. 输入起飞机场和到达机场，例如 `KLAX` 与 `KJFK`。
3. 选择起飞 / 到达跑道，或保持自动选择。
4. 输入航路文本，留空自动规划整条航路，或在两个航点间输入 `***` 自动规划片段。
5. 点击 **生成并绘制航路**。

无论界面语言如何，`DCT`、`SID`、`STAR`、`APPROACH`、airway 名称、航点标识、`AIRAC`、`PMTiles`、`MBTiles`、`SQLite` 等航空和技术标识始终保持英文。

### 查看机场和 Procedure

1. 在计划页输入手动机场，或点击地图上的机场。
2. 打开 **机场** 页。
3. 在起飞、到达、手动机场槽位之间切换。
4. 查看跑道、通信频率和 Procedure 列表。
5. 点击 Procedure 条目即可在地图上预览路径。

### 计算飞行剖面与燃油

1. 先在 **计划** 页生成航路，并按需选择 `SID`、`STAR` 或 `APPROACH`。
2. 打开 **计算** 页。
3. 选择飞机公司和具体机型，调整 ZFW、携带燃油、巡航高度、巡航 Mach、下降率、气象数据源和重量单位。
4. 查看航路风速 / 地面海拔剖面，通过缩放和平移 slider 调整剖面窗口，并检查地速 / 垂直速度剖面。
5. 查看 SimBrief 风格燃油估算。

当前计算模型本地优先、可离线运行。Terrarium DEM 瓦片可用时会用于地形采样，不可用时会降级为保守本地地形估算。真实 NOAA / ECMWF / GFS 气象格点、离线 DEM 数据包和更完整机型性能库是后续增强。

### 查询并绘制 FR24 轨迹

1. 先在计划页填写起飞机场和到达机场。
2. 打开 **查询** 页。
3. 首次查询时，点击打开验证页，在 App 内浏览器完成 FR24 / Cloudflare 验证后同步浏览器会话。
4. 点击 **查询**，列出该航线最近最多 10 个航班，或手动搜索航班号 / flightId。
5. 对航班或历史记录选择下载并绘制轨迹，也可以手动导入 GPX 文件、查看高度 / 速度剖面，或匹配轨迹到本地航路。

下载的 FR24 轨迹会以 GPX、playback JSON 和 metadata 缓存在本机。查询页可检索缓存、绘制缓存轨迹、分享 GPX、收藏重要轨迹、打开缓存目录，并清理未收藏的下载缓存。

FR24 是在线增强功能。断网、会话失效或 FR24 返回验证页时，本地航路规划、机场查询、Procedure、nav-overlay 和离线地图仍可使用。NavPlanner 只复用用户在 App 内完成验证后的浏览器会话，不绕过 Cloudflare，不自动破解验证码。

### 管理离线地图

1. 打开 **设置** 页。
2. 选择 **管理离线地图**。
3. 导入或下载 PMTiles、MBTiles、SQLite 瓦片资源。
4. 选择活动资源后，地图底图会优先使用本地瓦片。

在线地图缓存和离线地图包分开管理。清理在线缓存不会删除离线地图包或导航数据库。

### 导入导航数据库

1. 打开 **设置** 页。
2. 在 **导航数据库** 中点击 **选择 s3db**。
3. 从 Files 中选择 `.s3db`、`.sqlite`、`.sqlite3` 或 `.db` 文件。
4. 导入后 App 会切换到新数据库，并刷新航路、Procedure 和 nav-overlay 缓存。

## 架构

```mermaid
flowchart LR
  SwiftUI["SwiftUI 原生外壳"] --> WK["WKWebView 地图工作台"]
  WK --> Scheme["navplanner:// 本地 API"]
  Scheme --> Planner["Swift PlannerService"]
  Scheme --> Maps["Swift MapStore / OnlineTileCache"]
  Planner --> DB["SQLite 导航数据库"]
  Maps --> Files["PMTiles / MBTiles / SQLite 瓦片"]
  WK --> FR24["FR24 在线增强"]
```

导入的导航数据库、离线地图包、FR24 轨迹缓存、在线底图缓存、外观设置和浏览器会话配置均存储在 App 沙盒内。

## 从源码构建

### 环境要求

- macOS 与 Xcode。
- iOS 17.0 及以上部署目标。
- iPhone / iPad Simulator 或真机。
- 可选：本地导航数据库文件。公开仓库通常不应提交受版权约束的导航数据库；私有构建可把数据库放到 `NavPlanner/Resources/Database/navdata.sqlite`，或启动后在 Settings 中导入。

### Xcode

1. 打开 `NavPlanner.xcodeproj`。
2. 选择 `NavPlanner` scheme。
3. 选择 iPhone 或 iPad 模拟器，例如 iPhone 17 Pro Max。
4. 配置签名团队和 Bundle Identifier。
5. 点击 Run。

### 命令行

```bash
xcodebuild -project NavPlanner.xcodeproj \
  -scheme NavPlanner \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/NavPlannerDerived \
  build
```

如果系统 `xcode-select` 指向 Command Line Tools，可显式指定完整 Xcode：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project NavPlanner.xcodeproj \
  -scheme NavPlanner \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/NavPlannerDerived \
  build
```

## 发布前检查

- 复核 `PrivacyInfo.xcprivacy` 是否覆盖实际网络、文件、缓存和可选 FR24 行为。
- 确认导航数据库、离线地图包和底图来源的授权与分发方式。
- 更新版本号、Build 号、显示名称、签名配置、App 图标和备用图标元数据。
- 在 iPhone 小屏、iPhone 横屏、iPad 竖屏、iPad 横屏至少各跑一次。
- 验证飞行模式下：启动、机场搜索、机场详情、航路规划、Procedure 绘制、nav-overlay 和离线地图均可用。
- 验证 FR24 会话缺失、Cloudflare 验证、flightId 查询、手动 GPX 导入、高度剖面滑动、下载失败、轨迹绘制、轨迹匹配、分享和缓存管理。
- 排查 Xcode 日志时优先过滤 `NavPlanner` 进程；iOS beta 模拟器可能输出无关系统服务红字。

常用本地检查：

```bash
node --check NavPlanner/Resources/Web/app.js
node --check NavPlanner/Resources/Web/vendor/maplibre-gl/maplibre-gl.js
plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy
python3 Tools/Parity/run_all_parity.py
```

`Tools/Parity` 会对照 Swift 本地服务层和只读 Web 参考实现，适合在修改航路规划、轨迹匹配或 Procedure 几何后回归。

## 目录结构

```text
NavPlanner.xcodeproj/          Xcode 工程
NavPlanner/
  App/                         SwiftUI App 入口和外壳
  Core/                        本地数据库、规划服务、地图存储和 WebBridge
  Features/                    SwiftUI 功能容器
  Resources/Web/               WKWebView 地图工作台资源
  Support/                     Asset Catalog 与隐私清单
Tools/                         图标生成和 parity 校验工具
Media/                         README 截图和公开说明图片
```

## 数据与免责声明

NavPlanner 仅用于模拟飞行规划、数据查看和个人学习，不得用于真实飞行计划、真实导航、签派放行、运行决策或任何安全关键航空活动。实际飞行必须始终以官方航行资料、管制指令、适航设备和当前运行程序为准。

NavPlanner 可能使用第三方或用户自行提供的数据与资源，包括地图底图、机场与 Procedure 数据、AIRAC / 导航数据库、PMTiles / MBTiles / SQLite 地图包，以及来自 FR24 的航班数据。这些内容可能受版权、数据库权利、商标、平台条款或再分发限制约束。
本程序并不提供受版权或数据库权利保护的数据包，也不对第三方数据的准确性、完整性、可用性或合法性作出任何保证。
你需要自行确认拥有相应的数据使用、导入、缓存和分发权限。请确认你有权在本地使用和分发相关数据。
