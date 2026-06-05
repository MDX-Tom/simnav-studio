# Settings

Settings 是第一阶段为 iPhone / iPad 共同提供的本地设置页。页面由 `NavPlanner/Resources/Web/map.html` 和 `app.js` 渲染，核心能力通过 Swift 本地服务完成，不依赖 Python server 或局域网服务。

## 当前能力

- iPhone：Settings 是下部工作区的第三个标签，切换时顶部地图保持原实例、视角和叠加层。
- iPhone：底部入口显示为 `设置` 中文图标标签，标签栏使用紧凑玻璃质感并独占底部行，Settings 内容区截止在标签栏上方。
- iPad：Settings 位于详情区域的 `Airport / Settings` 切换中，计划栏和地图区保持既有工作台状态。
- 数据库：通过 `window.webkit.messageHandlers.navplanner` 发送 `selectDatabase`，Swift 侧弹出系统文件选择器。
- 支持文件扩展名：`.s3db`、`.sqlite`、`.sqlite3`、`.db`。
- 导入路径：选中文件复制到 `Application Support/NavPlanner/Database/`，文件名清洗后统一使用 `.sqlite`。
- 导入成功后：Swift 重新打开 SQLite 连接，Web 侧刷新 header、数据库状态和 nav-overlay。
- 数据库状态：Settings 卡片和 Plan 状态栏使用中文描述 AIRAC 与修订号，避免启动后仍显示 `Database loaded` / `Rev` 等英文文案。
- 外观：支持系统自动、日间、夜间三种模式，偏好保存到 `localStorage.navplannerThemeMode`；日间主题采用柔和浅蓝灰背景、白色半透明面板、深色正文、蓝绿主色和琥珀辅助色，避免浅色模式发灰发糊。
- 外观同步：Web 主题切换会通过 `themeChanged` bridge 通知 SwiftUI 外壳，iPhone 顶部刘海安全区背景和状态栏明暗跟随实际日间 / 夜间主题变化；WebView 首屏会在 CSS 加载前预设 `data-theme`，并对 iPad 竖向折叠按钮增加显式日间样式兜底，让主题控件不再短暂或持续显示旧深蓝配色。
- 语言：支持系统语言、简体中文和 English 三种模式，偏好保存到 `localStorage.navplannerLanguageMode`；默认系统语言模式按 `navigator.languages[0]` / `navigator.language` 的首选语言判断，中文首选显示简体中文，其它语言显示 English。语言切换会即时刷新 Settings、Plan、Airport、Procedure Selection、地图弹窗、离线地图管理、在线缓存摘要和常见状态 / 错误提示，不需要重载 WebView；如果机场 / 航点 / 航路弹窗已经打开，Web 侧会记录原 point 和 `latlng`，切换语言后在原位置重渲染弹窗内容。
- 航空标识：不论界面语言如何，`SID` / `STAR` / `APPROACH`、`DCT`、`IFR`、`AIRAC`、`ILS/GLS`、`TCH`、`RNP`、`VPA`、`PMTiles`、`MBTiles`、`SQLite` 等必要航空和技术标识保持英文，避免破坏飞行程序和数据含义。
- 应用图标：Settings 提供日间三档和夜间三档 Liquid Glass 图标预览。默认主图标为日间均衡；日间高饱和备用图标保留源图饱和度但不额外提升，上一轮“默认”档位已下放为日间柔和。夜间图标不是简单调暗，而是类似反色的深蓝黑地形、紫色地形层次和暗橙航路，并同样提供高对比、均衡、柔和三档；上一轮夜间均衡档位已下放为夜间柔和。夜间版本弱化整图玻璃罩，把 Liquid Glass 反光主要落在航路和山体局部；当前六套图标外框均已加宽，夜间版本仍保留更强轮廓。用户选择后通过 JS bridge 调用 iOS `setAlternateIconName`，系统确认弹窗由 iOS 控制，App 负责回写当前选择状态，并将“已是当前选择 / 已切换 / 不支持 / 失败”等状态按当前语言显示。
- 离线地图：Settings 显示当前活动资源、资源数量和下载任务摘要，下排按钮为“管理离线地图 / 刷新状态”；下载入口整合在离线地图管理页内部。
- 在线地图缓存：Settings 显示在线增强底图缓存大小、文件数、后台请求数和失败冷却数；下排按钮为“清理缓存 / 刷新缓存”，“清理缓存”调用 Swift 本地 `/api/map-cache/clear`，只删除 Caches 中的在线瓦片，不影响离线地图包和导航数据库。
- FR24 会话和下载缓存不放在 Settings 中管理，而是在 `查询` Tab 内完成：访问卡片可打开 App 内 FR24 验证页并自动同步内置浏览器 Cookie / `_frPl`，手动 Cookie 输入仅作为高级可选兜底；底部单独显示 FR24 缓存文件数和大小，删除时只清理 Caches 中的 FR24 GPX / playback JSON / meta 文件，不影响在线地图缓存、离线地图包和导航数据库。
- 离线地图管理页：使用透明偏暗背景和居中弹窗；弹窗标题、标签和日间主题样式与主界面同步，日间使用浅蓝灰玻璃面板，夜间保持深色玻璃风格；iPhone 下进一步缩小字体、按钮、表单和范围选择控件。资源类型、供应商类型 / 格式、下载进度、范围选择和离线地形状态提示均使用中文显示。
- 错误提示：Web 工作台通过 `localizedErrorMessage(...)` 统一清理用户可见错误，覆盖常见网络失败、HTTP 请求失败、本地 API 缺失、航路解析、轨迹匹配、离线地图下载和 App 图标回调错误；FR24 会话缺失、Cloudflare 验证页、HTML 响应和轨迹不足会按当前语言说明。
- 版权：页面集中显示本地导航数据库、离线地图资源和数据来源版权说明；地图右下角不再显示 attribution 水印。

## 触控约束

- Settings 内按钮、卡片、标题和说明文字使用更小尺寸，适配 iPhone 下部约 34% 工作区。
- iPhone 底部标签固定在独立底部行，Settings 内容通过内部滚动查看，不被标签栏遮挡。
- iPhone 底部标签二次压缩高度，贴近底部安全区，同时保持 `计划 / 机场 / 设置` 图标和文字可读。
- iPhone Settings 顶部隐藏 `Settings` 区块标题，优先保留数据库、外观和版权等实际操作内容。
- iPhone Settings 中离线地图和在线地图缓存卡片使用双行摘要 + 下排双按钮，尽量减少高度，同时保留可触控的目标尺寸。
- iPhone Settings 中语言选择复用外观模式的三段式紧凑按钮，避免新增设置项挤压离线地图和缓存管理入口。
- iPhone Settings 中应用图标选择使用“日间 / 夜间”两组紧凑三列预览按钮，避免图标选择挤占离线地图与缓存管理空间。
- 文件选择器取消后会回写“已取消选择数据库文件”，不会改变当前数据库。
- 页面空白处安装 document 级双击/双触防放大保护，避开输入框、按钮、链接、Leaflet 控件和离线地图弹窗。
- iPhone 输入框唤起软键盘时，Web 工作台缩到键盘上方可见高度并临时隐藏底部 Tab，当前输入面板停在键盘上方；点击系统对勾或键盘收起后恢复原布局。

## 后续

- 增加导入前 schema 版本检查。
- 增加最近使用数据库列表和恢复内置数据库入口。
- 增加离线地图导入入口和缓存清理前的空间占用明细。
- 后续如果增加更多图标风格，继续通过 `Tools/Icon/generate_app_icons.swift` 生成完整 asset catalog，并同步 Swift 图标映射、Xcode 备用图标名和 Settings 按钮。
- 继续清理底层服务长错误、真实在线失败状态和更多控制台状态中的未本地化文案，并按语言选择提供中文 / English 展示。
- 后续如恢复更多 SwiftUI 原生页面，需要继续复用同一套主题状态，避免原生页面与 WebView 主题不一致。
