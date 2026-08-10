<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Media/navplanner-hero-zh-Hans-dark.webp" />
  <source media="(prefers-color-scheme: light)" srcset="Media/navplanner-hero-zh-Hans.webp" />
  <img src="Media/navplanner-hero-zh-Hans.webp" alt="NavPlanner 在 iPhone 与 iPad 上展示 LGAV 至 EDDM 航路及 STAR 选择" width="84%" />
</picture><br />

<p>
  <a href="https://github.com/MDX-Tom/NavPlanner-App/stargazers"><img src="https://img.shields.io/github/stars/MDX-Tom/NavPlanner-App?logo=github&label=Stars" alt="GitHub Stars" /></a>
  <img src="https://img.shields.io/badge/设备-iPhone%20%7C%20iPad%20%7C%20mac-475569" alt="iPhone、iPad与mac" />
    <img src="https://img.shields.io/badge/Swift-5.0-F05138?logo=swift&logoColor=white" alt="Swift 5.0" />
  <img src="https://img.shields.io/badge/版本-0.1.0-0F766E" alt="版本 0.1.0" />
</p>

<p>
  <a href="README.md"><img src="https://img.shields.io/badge/lang-English-2563EB.svg" alt="English" /></a>
  <a href="README.zh-CN.md"><img src="https://img.shields.io/badge/语言-简体中文-DC2626.svg" alt="简体中文" /></a>
</p>

<h1>NavPlanner</h1>

<p><strong>从航路规划到地图复盘，一站式、本地计算的模拟飞行工作台。</strong></p>
<p>原生适配 iPhone & iPad · 航路规划 · Procedure 查看 · 轨迹对照 · 离线地图</p>

<p>
  <a href="#overview">项目概览</a> ·
  <a href="#highlights">功能亮点</a> ·
  <a href="#showcase">界面展示</a> ·
  <a href="#workflows">核心工作流</a> ·
  <a href="#architecture">系统架构</a> ·
  <a href="#build-from-source">源码构建</a>
</p>

</div>

<!-- README_SYNC: README.md 与 README.zh-CN.md 必须保持结构同步；视觉素材须同时适配亮色与暗色主题。 -->

<a id="overview"></a>

## 项目概览 ✈️

NavPlanner 是一款面向模拟飞行的 iOS 规划工作台。它把 **航路规划**、**机场与 Procedure 查看**、**FR24 轨迹下载、对照与拟合**、**离线地图**、**本地导航数据库**集中在一个 App 中，在核心功能离线可用的基础上，串联从航线构思到地图复盘的完整流程。

App 以 SwiftUI 构建原生外壳，以 WKWebView 承载地图工作区，并在 App 内封装 Swift 服务层。导入的数据库、地图包、缓存、偏好设置和轨迹历史均保存在 App 沙盒内。

<p align="center">
  <strong>航线构思</strong> → <strong>自动规划</strong> → <strong>Procedure 选择</strong> → <strong>飞行剖面计算</strong> → <strong>地图复盘</strong>
</p>

> [!CAUTION]
> **仅限模拟飞行。** NavPlanner 不是认证航空软件，不得用于真实飞行计划、真实导航、签派放行、运行决策或任何安全关键航空活动。

<a id="highlights"></a>

## 功能亮点 ✨

|  | 能力 | 功能说明 |
|:--:|---|---|
| 🧭 | **本地航路规划** | 输入起飞机场、到达机场和航路文本并绘制航路；航路留空时自动规划整条航路，也可在航点间插入 `***` 自动规划片段。 |
| 🛬 | **机场与 Procedure 查看** | 查看跑道、通信频率、`SID`、`STAR`、`APPROACH`，并支持 RF / AF 弧线、复飞段和等待航线几何。 |
| 🗺️ | **多图层地图工作区** | 独立控制底图、各类航路、Procedure、FR24 轨迹、航点、导航台、跑道、ILS 和 airway 标签；支持撤销、重做与清除绘制。 |
| 📐 | **飞行计算工作台** | 配置机型、重量、燃油、巡航、下降、天气和 QNH，查看风速 / 地形、地速 / 垂直速度剖面及 SimBrief 风格燃油估算。 |
| 📡 | **FR24 轨迹对照** | 在同步 App 内浏览器会话后查询近期航班或 flightId，导入 GPX、查看剖面，并把实际轨迹拟合回本地航路数据。 |
| 💾 | **离线地图库** | 导入或下载 PMTiles、MBTiles、SQLite 瓦片库和 Web 旧版 `tiles/` 布局，并与在线地图缓存分开管理。 |
| 🗄️ | **本地导航数据库** | 导入 `.s3db`、`.sqlite`、`.sqlite3` 或 `.db`，切换数据库、删除未使用副本，并恢复内置数据库。 |

<a id="showcase"></a>

## 界面展示 🖥️

<table align="center" width="80%">
  <tr>
    <td align="center"><strong>亮色 · iPhone 17 Pro 竖屏</strong><br /><img alt="iPhone 亮色主题下预览按跑道筛选的 EDDM STAR 总览" src="Media/workflows/zh-Hans/day/02-procedure-iphone.webp" height="272" /></td>
    <td align="center"><strong>亮色 · iPad Pro 13 英寸横屏</strong><br /><img alt="iPad 亮色主题下预览按跑道筛选的 EDDM STAR 总览" src="Media/workflows/zh-Hans/day/02-procedure-ipad.webp" height="272" /></td>
  </tr>
  <tr>
    <td align="center"><strong>暗色 · iPhone 17 Pro 竖屏</strong><br /><img alt="iPhone 暗色主题下预览按跑道筛选的 EDDM STAR 总览" src="Media/workflows/zh-Hans/night/02-procedure-iphone.webp" height="272" /></td>
    <td align="center"><strong>暗色 · iPad Pro 13 英寸横屏</strong><br /><img alt="iPad 暗色主题下预览按跑道筛选的 EDDM STAR 总览" src="Media/workflows/zh-Hans/night/02-procedure-ipad.webp" height="272" /></td>
  </tr>
</table>

<p align="center"><sub>界面展示：EDDM RW08R STAR 程序预览页面</sub></p>

<a id="workflows"></a>

## 核心工作流 🧭

<details open>
<summary><strong>1 · 规划并绘制航路</strong></summary>

1. 打开 **计划** 页。
2. 输入起飞机场和到达机场，例如 `KLAX` 与 `KJFK`。
3. 选择起飞 / 到达跑道，或保持自动选择。
4. 输入航路文本，留空自动规划整条航路，或在两个航点间输入 `***` 自动规划片段。
5. 点击 **生成并绘制航路**。

<table align="center" width="92%">
  <tr>
    <th align="center">iPhone</th>
    <th align="center">iPad/macOS</th>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/zh-Hans/night/01-plan-iphone.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/zh-Hans/day/01-plan-iphone.webp" /><img alt="在 iPhone 上规划并绘制 LGAV 至 EDDM" src="Media/workflows/zh-Hans/day/01-plan-iphone.webp" height="313" /></picture></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/zh-Hans/night/01-plan-ipad.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/zh-Hans/day/01-plan-ipad.webp" /><img alt="在 iPad 上规划并绘制 LGAV 至 EDDM" src="Media/workflows/zh-Hans/day/01-plan-ipad.webp" height="313" /></picture></td>
  </tr>
</table>

</details>

#

<details open>
<summary><strong>2 · 查看机场和 Procedure</strong></summary>

1. 生成航路后打开 **机场** 页，并切换到 EDDM 到达机场槽位。
2. 选择 `RW08R` 等跑道，再查看筛选后的 Procedure 列表。
3. 点击 **STAR** 标题，在地图中预览全部匹配 STAR；也可点击单个 Procedure 聚焦其路径。
4. 同时检查跑道资料、通信频率和完整程序几何。

<table align="center" width="92%">
  <tr>
    <th align="center">iPhone</th>
    <th align="center">iPad/macOS</th>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/zh-Hans/night/02-procedure-iphone.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/zh-Hans/day/02-procedure-iphone.webp" /><img alt="在 iPhone 上选择 EDDM RW08R 并预览 STAR 总览" src="Media/workflows/zh-Hans/day/02-procedure-iphone.webp" height="313" /></picture></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/zh-Hans/night/02-procedure-ipad.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/zh-Hans/day/02-procedure-ipad.webp" /><img alt="在 iPad 上选择 EDDM RW08R 并预览 STAR 总览" src="Media/workflows/zh-Hans/day/02-procedure-ipad.webp" height="313" /></picture></td>
  </tr>
</table>

</details>

#

<details open>
<summary><strong>3 · 计算飞行剖面与燃油</strong></summary>

1. 先在 **计划** 页生成航路，并按需选择 `SID`、`STAR` 或 `APPROACH`。
2. 打开 **计算** 页，选择飞机公司和具体机型，再调整 ZFW、携带燃油、巡航高度、巡航 Mach、下降率、气象数据源、重量单位和 QNH 单位。
3. 查看 SimBrief 风格航路剖面，其中包含相对航向风、云、雨、地形、Procedure 高度限制、QNH、缩放和平移控制。
4. 检查地速 / 垂直速度剖面和燃油估算。

当前计算模型本地优先、可离线运行。在线天气仅作为增强，不可用时会降级为本地估算；Terrarium DEM 瓦片可用时用于地形采样，不可用时降级为保守的本地地形估算。直接气象数据授权、离线 DEM 数据包和更完整的机型性能库仍是后续增强方向。

<table align="center" width="92%">
  <tr>
    <th align="center">iPhone</th>
    <th align="center">iPad/macOS</th>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/zh-Hans/night/03-calculate-iphone.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/zh-Hans/day/03-calculate-iphone.webp" /><img alt="在 iPhone 上计算 LGAV 至 EDDM 飞行剖面" src="Media/workflows/zh-Hans/day/03-calculate-iphone.webp" height="313" /></picture></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/zh-Hans/night/03-calculate-ipad.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/zh-Hans/day/03-calculate-ipad.webp" /><img alt="在 iPad 上计算 LGAV 至 EDDM 飞行剖面" src="Media/workflows/zh-Hans/day/03-calculate-ipad.webp" height="313" /></picture></td>
  </tr>
</table>

</details>

#

<details open>
<summary><strong>4 · FR24 轨迹：查询、下载、回放、拟合</strong></summary>

1. 在计划页填写起飞机场和到达机场，再打开 **查询** 页。
2. 首次查询时，在 App 内浏览器打开验证页，完成 FR24 / Cloudflare 验证并同步浏览器会话。
3. 查询该航线最近最多 10 个航班，或手动搜索航班号 / flightId。
4. 下载并绘制轨迹、导入 GPX、查看高度 / 速度剖面，或把轨迹拟合到本地航路引擎。

尚未起飞的航班会使用深灰色计划卡片显示。由于 FR24 此时还没有实际 playback，NavPlanner 会明确提示这一限制，并可使用本地自动规划器以虚线绘制计划预览；该虚线不会被表述为实际飞行轨迹或 FR24 filed route。

若已加载航班的实际起降机场与计划页不同，Query 会在拟合前把实际机场同步回 Plan。对于终端采样充分、跑道判断可靠的轨迹，系统会先匹配完整的 SID / STAR / Approach，再以 Procedure 边界为端点拟合中间航路。

下载轨迹会以 GPX、playback JSON 和 metadata 缓存在本机。Query 可检索缓存、绘制或拟合缓存轨迹、分享 GPX、收藏重要轨迹、打开缓存目录，并清理未收藏的下载记录。

> **在线增强功能。** FR24 为可选功能。断网、会话失效或 FR24 返回验证页时，本地航路规划、机场查询、Procedure、nav-overlay 和离线地图仍可使用。NavPlanner 只复用用户在 App 内完成验证后的会话，不绕过 Cloudflare，也不自动处理 CAPTCHA。

<table align="center" width="92%">
  <tr>
    <th align="center">iPhone</th>
    <th align="center">iPad/macOS</th>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/zh-Hans/night/04-fr24-iphone.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/zh-Hans/day/04-fr24-iphone.webp" /><img alt="在 iPhone 上绘制并查看 LGAV 至 EDDM FR24 剖面" src="Media/workflows/zh-Hans/day/04-fr24-iphone.webp" height="313" /></picture></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/zh-Hans/night/04-fr24-ipad.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/zh-Hans/day/04-fr24-ipad.webp" /><img alt="在 iPad 上绘制并查看 LGAV 至 EDDM FR24 剖面" src="Media/workflows/zh-Hans/day/04-fr24-ipad.webp" height="313" /></picture></td>
  </tr>
</table>

</details>

#

<details open>
<summary><strong>5 · 管理离线地图和导航数据库</strong></summary>

**离线地图**

1. 打开 **设置** → **管理离线地图**。
2. 导入或下载 PMTiles、MBTiles 或 SQLite 瓦片资源。
3. 选择活动资源后，地图底图会优先使用本地瓦片。

在线地图缓存和离线地图包分开管理。清理在线缓存不会删除导入的地图包或导航数据库。

**导航数据库**

1. 在 **设置** → **导航数据库** 中点击 **选择 s3db**。
2. 从 Files 中选择 `.s3db`、`.sqlite`、`.sqlite3` 或 `.db` 文件。
3. NavPlanner 切换到导入的数据库，并刷新航路、Procedure 和 nav-overlay 缓存。

<table align="center" width="92%">
  <tr>
    <th align="center">iPhone</th>
    <th align="center">iPad/macOS</th>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/zh-Hans/night/05-settings-iphone.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/zh-Hans/day/05-settings-iphone.webp" /><img alt="在 iPhone 上管理离线地图和本地设置" src="Media/workflows/zh-Hans/day/05-settings-iphone.webp" height="313" /></picture></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/zh-Hans/night/05-settings-ipad.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/zh-Hans/day/05-settings-ipad.webp" /><img alt="在 iPad 上管理离线地图和导航数据库" src="Media/workflows/zh-Hans/day/05-settings-ipad.webp" height="313" /></picture></td>
  </tr>
</table>

</details>

<a id="architecture"></a>

## 系统架构 🏗️

架构图以用户可见的核心工作流为主线，而不是从框架分层开始。每个编号步骤按 **功能入口 → 本地 API → 实现原理 → 返回 payload** 展开，同时保留贯穿全流程的运行时与本地数据平面。

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Media/architecture/project-architecture-zh-dark.webp" />
  <source media="(prefers-color-scheme: light)" srcset="Media/architecture/project-architecture-zh-light.webp" />
  <img src="Media/architecture/project-architecture-zh-light.webp" alt="NavPlanner 系统架构图：以核心工作流为主线" />
</picture>

编号工作流把依赖方向明确展示出来：航路规划产出的 payload 会被机场、计算和查询复用；Procedure 选择同时约束剖面计算和轨迹拟合；设置页提供所有离线路径依赖的本地数据库与地图存储。箭头同时表达以下实现原理：

| 原理 | 实现边界 | 结果 |
|---|---|---|
| **核心本地优先** | `PlannerService` + `LocalDataStore` + `MapStore` | 航路解析、Procedure、nav-overlay、本地地图和数据库查看在断网时继续工作。 |
| **Procedure-first 拟合** | 实际机场同步 → 终端 Procedure 拟合 → airway A* → 平滑 | 真实轨迹先保留 SID / STAR / APPROACH 语义，再匹配中间航路。 |
| **在线仅作增强** | FR24 会话、Open-Meteo、Terrarium DEM 使用虚线可选路径 | 网络或会话失败时降级到本地估算，不替代核心工作流。 |
| **类型化 payload 边界** | `navplanner://` API 与 JS Bridge | 每一步返回可由地图或当前工作台面板直接渲染的 payload，不泄漏存储内部实现。 |
| **缓存域分离** | SQLite 导航库、离线地图包、在线瓦片缓存、FR24 缓存 | 导入、刷新、清理和回滚只作用于各自负责的资源。 |

<a id="build-from-source"></a>

## 从源码构建 🛠️

### 环境要求

- macOS 与 Xcode
- iOS 17.0 及以上部署目标
- 目标可选 iPhone / iPad Simulator / macOS 或真机
- 私有构建可选用本地导航数据库

### 快速开始

```bash
git clone https://github.com/MDX-Tom/NavPlanner-App.git
cd NavPlanner-App
Tools/Signing/setup_local_signing.sh
open NavPlanner.xcodeproj
```

签名脚本会从本机有效的 Apple Development 证书读取 Team ID，并且只写入
被 Git 忽略的 `Config/CodeSigning.local.xcconfig`。如果自己的账号无法注册
仓库公开 Bundle Identifier，可传入仅限本机的覆盖值，例如
`--bundle-id com.example.NavPlanner`。Simulator 构建不需要签名；真机运行前，
如果脚本提示没有有效 identity，请先在 Xcode 添加 Apple Account 并创建
Apple Development 证书。
如果 Xcode 后续提示没有可用 profile 或 profile 已过期，请打开
“Xcode → Settings → Accounts”刷新 Apple Account 与证书，再重新运行脚本。
账号凭据始终只留在 Xcode 与钥匙串中，不得复制进仓库。

在 Xcode 中选择 **NavPlanner** scheme，再选择 iPhone、iPad 或 Mac Catalyst
目标并运行。Xcode 会自动读取被忽略的本机配置，不会把 Team ID 写回受跟踪的
工程文件。

私有构建可把本地数据库放在 `NavPlanner/Resources/Database/navdata.sqlite`，也可在 App 启动后从 Settings 导入。公开分发时，不应包含尚未确认再分发权利的导航数据。

<details>
<summary><strong>命令行构建</strong></summary>

```bash
xcodebuild -project NavPlanner.xcodeproj \
  -scheme NavPlanner \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/NavPlannerDerived \
  build
```

如果 `xcode-select` 指向 Command Line Tools，可显式指定完整 Xcode 开发目录：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project NavPlanner.xcodeproj \
  -scheme NavPlanner \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/NavPlannerDerived \
  build
```

</details>

### 安装 Releases 中的 IPA 与 DMG

<details>
<summary><strong>查看原因</strong></summary>

GitHub 公开发布的 IPA 必须是用于侧载的未签名包，不得包含维护者证书、
Team ID、provisioning profile、账号邮箱、私钥、App Store Connect 密钥、
xcarchive 或原始构建日志。

本机 Apple Development 配置只能写入已被 Git 忽略的
`Config/CodeSigning.local.xcconfig`。受跟踪的
`Config/CodeSigning.xcconfig` 会可选加载该文件，因此 Xcode GUI 可以在本机
正常签名，而新克隆和公开 unsigned 构建不包含个人身份。没有私有 CI 凭据时，
Mac 工件只做 ad-hoc 签名且不进行 notarization；如未来需要 Developer ID /
App Store 签名，只能在受保护 CI 中从 Secret 临时导入。详见
[公开发布封包说明](Tools/Release/README.md)。

</details>

**安装 iPhone App 需通过 AltStore、SideStore、Sideloadly
或其他可信签名流程，使用自己的账号重新签名。**

<details>
<summary><strong>在 iPhone、iPad 与 Mac 上安装</strong></summary>

#### iPhone 与 iPad

GitHub 提供的 IPA 未签名，不包含维护者证书或
provisioning profile，不能直接安装。

1. 下载带 `-unsigned.ipa` 后缀的 IPA 与 `SHA256SUMS.txt`，先复验校验和。
2. 将 IPA 导入 AltStore、SideStore、Sideloadly 或其他可信签名工具。
3. 由工具使用安装者自己的 Apple Account 重新签名并安装。
4. 按工具与设备提示信任本地签名；仅在 iOS/iPadOS 明确要求时启用
   Developer Mode。

此外，也可以直接通过本机 Xcode 安装，先运行
`Tools/Signing/setup_local_signing.sh`，连接设备，在 NavPlanner scheme 中选择
该设备并点击 Run。生成的签名配置只留在当前 Mac，且始终被 Git 忽略。

#### Mac

1. 下载带 `-catalyst-adhoc-not-notarized.dmg` 后缀的 DMG，并复验 SHA-256。
2. 打开 DMG，将 `NavPlanner.app` 拖入“应用程序”。
3. 首次启动时按住 Control 点击 App 并选择“打开”；如果 macOS 仍拦截，只有在
   已核实校验和与下载来源后，才使用“系统设置 → 隐私与安全性 → 仍要打开”。

当前 Mac 版本是 arm64/x86_64 universal Mac Catalyst App。它只有 ad-hoc
签名且未 notarize，因此不具备 Developer ID/Gatekeeper 公开分发信任；它也不是
原生 AppKit App 或 Designed-for-iPad Wrapper。

</details>

<a id="validation"></a>

## 校验与发布检查 ✅

<details>
<summary><strong>常用本地检查</strong></summary>

```bash
node --check NavPlanner/Resources/Web/app.js
node --check NavPlanner/Resources/Web/vendor/maplibre-gl/maplibre-gl.js
plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy
python3 Tools/Parity/run_all_parity.py
```

`Tools/Parity` 用于在修改航路规划、轨迹拟合或 Procedure 几何后，对照 Swift 本地服务层和只读 Web 参考实现。

</details>

<details>
<summary><strong>发布前检查清单</strong></summary>

- 复核 `PrivacyInfo.xcprivacy` 是否覆盖实际网络、文件、缓存和可选 FR24 行为。
- 确认导航数据库、离线地图包和底图来源的授权与分发方式。
- 更新版本号、Build 号、显示名称、签名配置、App 图标和备用图标元数据。
- 在 iPhone 小屏、iPhone 横屏、iPad 竖屏和 iPad 横屏分别测试。
- 验证飞行模式下的启动、机场搜索、机场详情、航路规划、Procedure 绘制、nav-overlay 和离线地图。
- 验证 FR24 会话缺失、Cloudflare 验证、flightId、GPX 导入、剖面滑动、下载失败、轨迹绘制、拟合、分享和缓存管理流程。
- 排查 Xcode 日志时优先过滤 `NavPlanner` 进程；beta 模拟器可能输出无关的系统服务错误。

</details>

<a id="project-layout"></a>

## 目录结构 🗂️

```text
NavPlanner.xcodeproj/          Xcode 工程
NavPlanner/
  App/                         SwiftUI App 入口和外壳
  Core/                        本地数据库、规划服务、地图存储和 WebBridge
  Features/                    SwiftUI 功能容器
  Resources/Web/               WKWebView 地图工作区资源
  Support/                     Asset Catalog 与隐私清单
Tools/                         图标生成和 parity 校验工具
Media/                         README 截图与视觉素材
```

<a id="data-notice"></a>

## 数据与安全说明 ⚠️

NavPlanner 仅用于模拟飞行规划、数据查看和个人学习。实际飞行必须始终以官方航行资料、管制指令、适航设备和当前运行程序为准。

NavPlanner 可能使用第三方或用户自行提供的内容，包括地图底图、机场与 Procedure 数据、AIRAC / 导航数据库、PMTiles / MBTiles / SQLite 地图包，以及 FR24 航班数据。这些内容可能受版权、数据库权利、商标、平台条款或再分发限制约束。

本 App 不保证第三方数据的准确性、完整性、可用性或法律状态。你需要自行确认拥有每项数据的使用、导入、缓存和分发权利。
