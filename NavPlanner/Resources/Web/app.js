import { registerAirportPage } from "./pages/airport.js";
import { createCalculatePage } from "./pages/calculate.js";
import { registerPlanPage } from "./pages/plan.js";
import { registerQueryPage } from "./pages/query.js";
import { registerSettingsPage } from "./pages/settings.js";

const savedThemeMode = readLocalStorageValue("navplannerThemeMode");
const savedAppIconChoice = readLocalStorageValue("navplannerAppIconChoice");
const savedLanguageMode = readLocalStorageValue("navplannerLanguageMode");
const savedMapSourceMode = readLocalStorageValue("navplannerMapSourceMode");
const savedOnlineMapProvider = readLocalStorageValue("navplannerOnlineMapProvider");
const savedMapTileZoomOffset = readLocalStorageValue("navplannerMapTileZoomOffset");
const NAVPLANNER_API_ORIGIN = (window.location.protocol === "navplanner:"
  || window.location.protocol === "about:"
  || window.location.protocol === "file:"
  || window.location.origin === "null")
  ? "navplanner://app"
  : window.location.origin;
const apiResourceUrl = (path) => `${NAVPLANNER_API_ORIGIN}${path}`;
const THEME_MODES = new Set(["system", "day", "night"]);
const LANGUAGE_MODES = new Set(["system", "zh-Hans", "en"]);
const APP_ICON_CHOICES = new Set(["day-high", "primary", "day-soft", "night-high", "night-medium", "night-soft"]);
const MAP_SOURCE_MODES = new Set(["online", "offline"]);
const MAP_TILE_ZOOM_OFFSETS = new Set([-1, 0, 1, 2]);
const ONLINE_TILE_BASE_SIZE = 256;
const LOCAL_SETTING_KEYS = Object.freeze([
  "navplannerThemeMode",
  "navplannerAppIconChoice",
  "navplannerLanguageMode",
  "navplannerMapSourceMode",
  "navplannerOnlineMapProvider",
  "navplannerMapTileZoomOffset",
]);
const ONLINE_MAP_PROVIDERS = Object.freeze({
  arcgis: {
    labelKey: "map.provider.arcgis",
    titleKey: "map.provider.arcgisHint",
    format: "jpg",
    maxZoom: 20,
  },
  openstreetmap: {
    labelKey: "map.provider.openstreetmap",
    titleKey: "map.provider.openstreetmapHint",
    format: "png",
    maxZoom: 19,
  },
  opentopomap: {
    labelKey: "map.provider.opentopomap",
    titleKey: "map.provider.opentopomapHint",
    format: "png",
    maxZoom: 17,
  },
  google: {
    labelKey: "map.provider.google",
    titleKey: "map.provider.googleHint",
    format: "jpg",
    maxZoom: 20,
  },
});
const ONLINE_MAP_PROVIDER_KEYS = new Set(Object.keys(ONLINE_MAP_PROVIDERS));
const themeMediaQuery = typeof window.matchMedia === "function" ? window.matchMedia("(prefers-color-scheme: light)") : null;

const TRANSLATIONS = {
  "app.title": { "zh-Hans": "航空航路规划器", en: "Aviation Route Planner" },
  "nav.plan": { "zh-Hans": "计划", en: "Plan" },
  "nav.airport": { "zh-Hans": "机场", en: "Airport" },
  "nav.query": { "zh-Hans": "查询", en: "Query" },
  "nav.calculate": { "zh-Hans": "计算", en: "Calc" },
  "nav.settings": { "zh-Hans": "设置", en: "Settings" },
  "plan.departureAirport": { "zh-Hans": "起飞机场", en: "Departure" },
  "plan.arrivalAirport": { "zh-Hans": "到达机场", en: "Arrival" },
  "plan.manualAirport": { "zh-Hans": "手动机场", en: "Manual Airport" },
  "plan.airportPlaceholder": { "zh-Hans": "ICAO / IATA / 航点", en: "ICAO / IATA / waypoint" },
  "plan.manualPlaceholder": { "zh-Hans": "仅用于查看 SID / STAR / APPROACH", en: "For SID / STAR / APPROACH lookup only" },
  "plan.manualHint": { "zh-Hans": "手动机场仅用于查看 SID / STAR / APPROACH 数据。", en: "Manual airport is only used to inspect SID / STAR / APPROACH data." },
  "plan.departureRunway": { "zh-Hans": "起飞跑道", en: "Departure Runway" },
  "plan.arrivalRunway": { "zh-Hans": "到达跑道", en: "Arrival Runway" },
  "plan.route": { "zh-Hans": "航路", en: "Route" },
  "plan.routePlaceholder": { "zh-Hans": "", en: "" },
  "plan.buildRoute": { "zh-Hans": "生成并绘制航路", en: "Build & Draw" },
  "plan.recalculate": { "zh-Hans": "重新计算", en: "Recalculate" },
  "plan.matchTrack": { "zh-Hans": "匹配轨迹", en: "Match Track" },
  "plan.stopTask": { "zh-Hans": "停止当前任务", en: "Stop Current Task" },
  "plan.autoRouteHint": { "zh-Hans": "留空航路以自动规划整条航路，或在航点间输入'***'以自动规划航路片段", en: "Leave Route blank to auto-plan the whole route, or enter '***' between waypoints to auto-plan that segment." },
  "status.waitingRoute": { "zh-Hans": "等待输入航路。", en: "Waiting for route input." },
  "section.legs": { "zh-Hans": "航段", en: "Legs" },
  "section.selectedProcedures": { "zh-Hans": "已选程序", en: "Selected Procedures" },
  "section.selection": { "zh-Hans": "选中内容", en: "Selection" },
  "layout.expandSidebar": { "zh-Hans": "展开左侧面板", en: "Expand sidebar" },
  "layout.expandMap": { "zh-Hans": "展开地图", en: "Expand map" },
  "layout.restoreSidebar": { "zh-Hans": "恢复左侧面板", en: "Restore sidebar" },
  "layout.restoreMap": { "zh-Hans": "恢复地图布局", en: "Restore map layout" },
  "detail.tabsLabel": { "zh-Hans": "详情、查询、计算与设置", en: "Details, query, calculation, and settings" },
  "mobile.tabsLabel": { "zh-Hans": "iPhone 下部页面", en: "iPhone lower pages" },
  "mobile.dragHandle": { "zh-Hans": "调整下方面板高度", en: "Resize lower panel" },
  "airport.detailTabs": { "zh-Hans": "机场详情", en: "Airport details" },
  "airport.departureAirport": { "zh-Hans": "起飞机场", en: "Departure Airport" },
  "airport.arrivalAirport": { "zh-Hans": "到达机场", en: "Arrival Airport" },
  "airport.manualAirport": { "zh-Hans": "手动机场", en: "Manual Airport" },
  "airport.runways": { "zh-Hans": "跑道", en: "Runways" },
  "airport.communications": { "zh-Hans": "通信频率", en: "Communications" },
  "airport.procedures": { "zh-Hans": "程序", en: "Procedures" },
  "airport.runwayFilter": { "zh-Hans": "跑道筛选", en: "Runway Filter" },
  "airport.focus": { "zh-Hans": "定位", en: "Focus" },
  "airport.empty": { "zh-Hans": "选择上方机场槽位后搜索，或从机场弹窗设置。", en: "Select an airport slot above, then search or set it from an airport popup." },
  "airport.empty.manual": { "zh-Hans": "尚未选择手动机场。请在左侧搜索，或从机场弹窗中选择“设为手动”。", en: "No manual airport selected. Search on the left, or choose \"Set Manual\" from an airport popup." },
  "airport.empty.slot": { "zh-Hans": "尚未选择{slot}机场。请在左侧搜索，或从机场弹窗中设置。", en: "No {slot} airport selected. Search on the left, or set it from an airport popup." },
  "airport.slot.departure": { "zh-Hans": "起飞", en: "Departure" },
  "airport.slot.arrival": { "zh-Hans": "到达", en: "Arrival" },
  "airport.slot.manual": { "zh-Hans": "手动", en: "Manual" },
  "airport.unnamed": { "zh-Hans": "未命名机场", en: "Unnamed airport" },
  "airport.elevation": { "zh-Hans": "标高", en: "Elev" },
  "airport.magneticBearing": { "zh-Hans": "磁方位", en: "Mag bearing" },
  "airport.surface": { "zh-Hans": "道面", en: "Surface" },
  "airport.trueBearing": { "zh-Hans": "真方位", en: "True bearing" },
  "airport.thresholdElevation": { "zh-Hans": "入口标高", en: "Threshold elev" },
  "airport.displacedThreshold": { "zh-Hans": "移位入口", en: "Displaced threshold" },
  "airport.gradient": { "zh-Hans": "坡度", en: "Gradient" },
  "airport.details": { "zh-Hans": "机场详情", en: "Airport Details" },
  "airport.detailsLoading": { "zh-Hans": "正在加载机场详情...", en: "Loading airport details..." },
  "airport.detailsUnavailable": { "zh-Hans": "机场详情不可用。", en: "Airport details unavailable." },
  "airport.noRunwayDetails": { "zh-Hans": "无跑道详情", en: "No runway details" },
  "airport.runwayCount": { "zh-Hans": "跑道（{count}）", en: "Runways ({count})" },
  "airport.ifrCapability": { "zh-Hans": "IFR 能力", en: "IFR capability" },
  "airport.transitionAltLevel": { "zh-Hans": "过渡高度 / 层", en: "Transition altitude / level" },
  "airport.longestSurface": { "zh-Hans": "最长跑道面", en: "Longest runway surface" },
  "airport.surface.hard": { "zh-Hans": "硬质", en: "hard" },
  "airport.surface.soft": { "zh-Hans": "软质", en: "soft" },
  "airport.surface.water": { "zh-Hans": "水面", en: "water" },
  "airport.surface.unknown": { "zh-Hans": "未知", en: "unknown" },
  "settings.database": { "zh-Hans": "导航数据库", en: "Navigation Database" },
  "settings.chooseS3db": { "zh-Hans": "选择 s3db", en: "Choose s3db" },
  "settings.databaseHint": { "zh-Hans": "支持从“文件”中选择 .s3db / .sqlite / .db，导入后核心查询会切换到新的本地数据库。", en: "Choose .s3db / .sqlite / .db from Files. Core local queries switch to the imported database after import." },
  "settings.appearance": { "zh-Hans": "外观", en: "Appearance" },
  "settings.appearanceMode": { "zh-Hans": "外观模式", en: "Appearance mode" },
  "settings.language": { "zh-Hans": "语言", en: "Language" },
  "settings.languageHint": { "zh-Hans": "默认跟随系统语言；无论选择哪种语言，SID / STAR / APPROACH、DCT、IFR、AIRAC 等航空标识保持英文。", en: "Default follows the system language. SID / STAR / APPROACH, DCT, IFR, AIRAC, and other aviation identifiers remain in English." },
  "settings.appIcon": { "zh-Hans": "应用图标", en: "App Icon" },
  "settings.appIconHint": { "zh-Hans": "默认图标为日间均衡，夜间图标使用蓝黑反色地形、紫色层次和暗橙航路。", en: "The default icon is the balanced day variant. Night icons use blue-black terrain, purple relief, and dark amber routes." },
  "settings.mapSelection": { "zh-Hans": "地图选择", en: "Map Selection" },
  "settings.mapSelectionMode": { "zh-Hans": "地图模式", en: "Map mode" },
  "settings.mapSelectionHint": { "zh-Hans": "在线地图作为增强底图；离线地图读取本机资源，断网时本地航路、程序和 nav-overlay 仍可使用。", en: "Online maps are enhanced base maps. Offline maps read local resources; routes, procedures, and nav-overlay remain local-first when offline." },
  "settings.offlineMaps": { "zh-Hans": "离线地图", en: "Offline Maps" },
  "settings.mapCache": { "zh-Hans": "在线地图缓存", en: "Online Map Cache" },
  "settings.resetAll": { "zh-Hans": "重置与清理", en: "Reset & Cleanup" },
  "settings.resetAllHint": { "zh-Hans": "恢复外观、语言、图标和地图设置默认值，并清理在线地图缓存与 FR24 轨迹缓存；不会删除导航数据库或离线地图包。", en: "Restore appearance, language, icon, and map settings to defaults, and clear online map plus FR24 track caches. Navigation databases and offline map packages are kept." },
  "settings.resetAllButton": { "zh-Hans": "重置所有设置并删除全部缓存", en: "Reset All Settings & Delete All Caches" },
  "settings.resetAllConfirm": { "zh-Hans": "确认重置所有设置并删除全部缓存？\n\n将恢复默认外观、语言、图标和地图设置，并清理在线地图缓存与 FR24 轨迹缓存；不会删除导航数据库或离线地图包。", en: "Reset all settings and delete all caches?\n\nThis restores default appearance, language, icon, and map settings, and clears online map plus FR24 track caches. Navigation databases and offline map packages are kept." },
  "settings.resetAllWorking": { "zh-Hans": "正在重置...", en: "Resetting..." },
  "settings.resetAllDone": { "zh-Hans": "已重置所有设置，并清理在线地图与 FR24 缓存。", en: "All settings reset. Online map and FR24 caches cleared." },
  "settings.copyright": { "zh-Hans": "版权与说明", en: "Copyright & Notes" },
  "settings.copyrightP1": { "zh-Hans": "NavPlanner 是面向航路规划和航图查看的本地优先工具，可在本机数据库上完成机场、航点、航路、SID / STAR / APPROACH 与 nav-overlay 查询。", en: "NavPlanner is a local-first route planning and chart inspection tool for airports, waypoints, routes, SID / STAR / APPROACH data, and nav-overlay queries from the on-device database." },
  "settings.copyrightP2": { "zh-Hans": "在计划页填写起降机场并生成航路，在机场页查看程序和跑道信息，在查询页检索并绘制 FR24 轨迹，在计算页估算剖面与燃油，在设置页管理数据库、离线地图、缓存、外观、语言和图标。", en: "Use Plan to enter airports and build routes, Airport to inspect procedures and runways, Query to find and draw FR24 tracks, Calc to estimate profiles and fuel, and Settings to manage databases, offline maps, cache, appearance, language, and icons." },
  "settings.copyrightP3": { "zh-Hans": "地图底图、离线地图包和导航数据版权归各自数据来源所有；App 开发者为 MDX。", en: "Base maps, offline map packages, and navigation data remain copyrighted by their sources. The app developer is MDX." },
  "theme.system": { "zh-Hans": "系统自动", en: "System" },
  "theme.day": { "zh-Hans": "日间", en: "Day" },
  "theme.night": { "zh-Hans": "夜间", en: "Night" },
  "language.system": { "zh-Hans": "系统语言", en: "System" },
  "language.zhHans": { "zh-Hans": "简体中文", en: "简体中文" },
  "language.en": { "zh-Hans": "English", en: "English" },
  "appIcon.highSaturation": { "zh-Hans": "高饱和", en: "High sat." },
  "appIcon.default": { "zh-Hans": "默认", en: "Default" },
  "appIcon.soft": { "zh-Hans": "柔和", en: "Soft" },
  "appIcon.highContrast": { "zh-Hans": "高对比", en: "High contrast" },
  "appIcon.balanced": { "zh-Hans": "均衡", en: "Balanced" },
  "appIcon.choice.dayHigh": { "zh-Hans": "日间高饱和", en: "Day high saturation" },
  "appIcon.choice.primary": { "zh-Hans": "日间均衡", en: "Day balanced" },
  "appIcon.choice.daySoft": { "zh-Hans": "日间柔和", en: "Day soft" },
  "appIcon.choice.nightHigh": { "zh-Hans": "夜间高对比", en: "Night high contrast" },
  "appIcon.choice.nightMedium": { "zh-Hans": "夜间均衡", en: "Night balanced" },
  "appIcon.choice.nightSoft": { "zh-Hans": "夜间柔和", en: "Night soft" },
  "appIcon.alreadySelected": { "zh-Hans": "应用图标已是当前选择。", en: "App icon already uses the selected variant." },
  "appIcon.changed": { "zh-Hans": "已切换为{name}应用图标。", en: "Changed app icon to {name}." },
  "appIcon.unsupported": { "zh-Hans": "当前系统不支持切换 App 图标。", en: "This system does not support changing the app icon." },
  "appIcon.changeFailed": { "zh-Hans": "切换应用图标失败。", en: "Failed to change app icon." },
  "database.loading": { "zh-Hans": "正在读取本地导航数据库...", en: "Reading local navigation database..." },
  "database.ready": { "zh-Hans": "本地导航数据库已就绪", en: "Local navigation database is ready" },
  "database.unavailable": { "zh-Hans": "数据库不可用", en: "Database unavailable" },
  "database.revision": { "zh-Hans": "修订 {revision}", en: "Rev {revision}" },
  "database.loaded": { "zh-Hans": "本地导航数据库已就绪。", en: "Local navigation database is ready." },
  "database.iosOnly": { "zh-Hans": "本地数据库选择需要在 iOS App 内使用。", en: "Local database selection is available inside the iOS app." },
  "database.cancelled": { "zh-Hans": "已取消选择数据库文件。", en: "Database file selection cancelled." },
  "database.importFailed": { "zh-Hans": "导入数据库失败。", en: "Database import failed." },
  "database.switched": { "zh-Hans": "已切换本地导航数据库。", en: "Local navigation database switched." },
  "database.storageTitle": { "zh-Hans": "本地数据库存储", en: "Local Database Storage" },
  "database.storageInitial": { "zh-Hans": "本地数据库文件数量和空间占用会在这里显示。", en: "Local database file count and storage usage appear here." },
  "database.storageSummary": { "zh-Hans": "{count} 个数据库文件，占用 {size}。", en: "{count} database files, using {size}." },
  "database.searchPlaceholder": { "zh-Hans": "搜索数据库、AIRAC 或修订", en: "Search database, AIRAC, or revision" },
  "database.restoreBuiltIn": { "zh-Hans": "恢复内置库", en: "Restore Built-in" },
  "database.listInitial": { "zh-Hans": "进入设置页后读取本地数据库文件。", en: "Open Settings to read local database files." },
  "database.listLoading": { "zh-Hans": "正在读取本地数据库文件...", en: "Reading local database files..." },
  "database.listEmpty": { "zh-Hans": "没有找到本地数据库文件。", en: "No local database files found." },
  "database.listLoaded": { "zh-Hans": "已读取 {count} 个本地数据库文件。", en: "Loaded {count} local database files." },
  "database.active": { "zh-Hans": "当前使用", en: "Active" },
  "database.builtIn": { "zh-Hans": "内置", en: "Built-in" },
  "database.invalid": { "zh-Hans": "不可读", en: "Unreadable" },
  "database.airac": { "zh-Hans": "AIRAC {airac}", en: "AIRAC {airac}" },
  "database.modified": { "zh-Hans": "修改 {time}", en: "Modified {time}" },
  "database.use": { "zh-Hans": "使用此库", en: "Use Database" },
  "database.delete": { "zh-Hans": "删除文件", en: "Delete File" },
  "database.deleteConfirm": { "zh-Hans": "确认删除本地数据库 {name}？当前使用和内置数据库不会被删除。", en: "Delete local database {name}? Active and built-in databases are protected." },
  "database.deleted": { "zh-Hans": "已删除本地数据库文件。", en: "Local database file deleted." },
  "database.restored": { "zh-Hans": "已恢复并启用内置导航数据库。", en: "Built-in navigation database restored and enabled." },
  "offline.loading": { "zh-Hans": "正在读取离线地图...", en: "Reading offline maps..." },
  "offline.summaryInitial": { "zh-Hans": "本地资源、下载任务和启用状态会在这里显示。", en: "Local resources, download jobs, and active state appear here." },
  "offline.manage": { "zh-Hans": "管理离线地图", en: "Manage Offline Maps" },
  "offline.settingsHint": { "zh-Hans": "离线地图从本机 Application Support/NavPlanner/MapOffline 读取，可在这里启用、删除、下载和查看下载进度。", en: "Offline maps are read from Application Support/NavPlanner/MapOffline. Enable, delete, download, and track progress here." },
  "offline.unread": { "zh-Hans": "离线地图未读取", en: "Offline maps not read" },
  "offline.refreshPrompt": { "zh-Hans": "进入设置页后可刷新本机离线地图资源。", en: "Open Settings to refresh local offline map resources." },
  "offline.downloadingTitle": { "zh-Hans": "正在下载 {name}", en: "Downloading {name}" },
  "offline.defaultName": { "zh-Hans": "离线地图", en: "offline map" },
  "offline.downloadSummary": { "zh-Hans": "{downloaded} / {total} 瓦片，已写入 {size}。", en: "{downloaded} / {total} tiles, {size} written." },
  "offline.enabledTitle": { "zh-Hans": "已启用 {name}", en: "Enabled {name}" },
  "offline.enabledSummary": { "zh-Hans": "{provider} · {kind} · {size} · 共 {count} 瓦片", en: "{provider} · {kind} · {size} · {count} tiles" },
  "offline.notEnabled": { "zh-Hans": "未启用离线地图", en: "No offline map enabled" },
  "offline.noResources": { "zh-Hans": "暂无离线地图资源", en: "No offline map resources" },
  "offline.foundResources": { "zh-Hans": "已发现 {count} 个资源，请点“管理”选择一个作为离线底图。", en: "{count} resources found. Tap Manage to choose one as the offline base map." },
  "offline.noResourcesHint": { "zh-Hans": "可以下载选区瓦片，或把 PMTiles / MBTiles / SQLite 地图包放入本机离线目录。", en: "Download selected-area tiles, or place PMTiles / MBTiles / SQLite map packages in the local offline directory." },
  "offline.kind.vector": { "zh-Hans": "矢量", en: "Vector" },
  "offline.kind.raster": { "zh-Hans": "栅格", en: "Raster" },
  "offline.kind.resource": { "zh-Hans": "资源", en: "Resource" },
  "offline.kind.vectorDesc": { "zh-Hans": "矢量，可作为离线地形显示", en: "Vector, usable as offline terrain" },
  "offline.kind.rasterDesc": { "zh-Hans": "栅格，可作为离线地形显示", en: "Raster, usable as offline terrain" },
  "offline.localResource": { "zh-Hans": "本地资源", en: "Local resource" },
  "offline.unknownProvider": { "zh-Hans": "未知供应商", en: "Unknown provider" },
  "offline.unknownFormat": { "zh-Hans": "未知格式", en: "Unknown format" },
  "offline.modalAria": { "zh-Hans": "离线地图管理", en: "Offline map manager" },
  "offline.modalKicker": { "zh-Hans": "本地资源", en: "Local Resources" },
  "offline.modalTitle": { "zh-Hans": "离线地图管理", en: "Offline Map Manager" },
  "offline.modalDescription": { "zh-Hans": "管理本地离线地图资源，并在下载标签中创建指定区域瓦片。", en: "Manage local offline map resources and create selected-area tiles from the Download tab." },
  "offline.modalClose": { "zh-Hans": "关闭离线地图管理器", en: "Close offline map manager" },
  "offline.tabManage": { "zh-Hans": "管理资源", en: "Manage" },
  "offline.tabDownload": { "zh-Hans": "下载地图", en: "Download" },
  "offline.noJob": { "zh-Hans": "暂无正在运行的离线地图下载任务。", en: "No offline map download job is running." },
  "offline.progress": { "zh-Hans": "下载进度", en: "Download progress" },
  "offline.cancelDownload": { "zh-Hans": "取消下载", en: "Cancel Download" },
  "offline.state.canceling": { "zh-Hans": "正在取消", en: "Cancelling" },
  "offline.state.aborted": { "zh-Hans": "已中止", en: "Aborted" },
  "offline.state.running": { "zh-Hans": "下载中", en: "Downloading" },
  "offline.state.done": { "zh-Hans": "已结束", en: "Finished" },
  "offline.workers": { "zh-Hans": "并发 {count} 线程", en: "{count} workers" },
  "offline.singleWorker": { "zh-Hans": "单线程", en: "Single worker" },
  "offline.speed": { "zh-Hans": "速度 {speed}/s", en: "Speed {speed}/s" },
  "offline.inflight": { "zh-Hans": "在途 {active} / {limit}", en: "In flight {active} / {limit}" },
  "offline.displaySourceZoom": { "zh-Hans": "显示 z{min}-{max} / 源 z{min}-{source}", en: "Display z{min}-{max} / source z{min}-{source}" },
  "offline.zoomRange": { "zh-Hans": "z{min}-{max}", en: "z{min}-{max}" },
  "offline.writtenSize": { "zh-Hans": "已写入 {size}", en: "{size} written" },
  "offline.estimatedSize": { "zh-Hans": "预计 {size}", en: "Estimated {size}" },
  "offline.tileProgress": { "zh-Hans": "{downloaded} / {total} 瓦片", en: "{downloaded} / {total} tiles" },
  "offline.failedCount": { "zh-Hans": "失败 {count}", en: "{count} failed" },
  "offline.current": { "zh-Hans": "当前使用", en: "Active" },
  "offline.storageSQLite": { "zh-Hans": "SQLite 单文件", en: "SQLite single file" },
  "offline.storagePMTiles": { "zh-Hans": "PMTiles 单文件", en: "PMTiles single file" },
  "offline.storageLegacy": { "zh-Hans": "旧版多文件", en: "Legacy files" },
  "offline.field.type": { "zh-Hans": "类型", en: "Type" },
  "offline.field.zoom": { "zh-Hans": "缩放", en: "Zoom" },
  "offline.field.tiles": { "zh-Hans": "瓦片", en: "Tiles" },
  "offline.field.size": { "zh-Hans": "大小", en: "Size" },
  "offline.field.storage": { "zh-Hans": "存储", en: "Storage" },
  "offline.field.average": { "zh-Hans": "均值", en: "Average" },
  "offline.field.bounds": { "zh-Hans": "范围", en: "Bounds" },
  "offline.action.enabled": { "zh-Hans": "已启用", en: "Enabled" },
  "offline.action.setBase": { "zh-Hans": "设为底图", en: "Set Base Map" },
  "offline.action.unavailable": { "zh-Hans": "不可显示", en: "Not displayable" },
  "offline.action.compact": { "zh-Hans": "压缩存储", en: "Compact Storage" },
  "offline.action.delete": { "zh-Hans": "删除", en: "Delete" },
  "offline.action.refresh": { "zh-Hans": "刷新", en: "Refresh" },
  "offline.activeResource": { "zh-Hans": "当前活动资源：{name}", en: "Active resource: {name}" },
  "offline.unset": { "zh-Hans": "未设置", en: "Not set" },
  "offline.emptyManage": { "zh-Hans": "map_offline/ 下暂无可管理资源。可以切换到“下载”标签创建一个离线地形资源。", en: "No manageable resources in map_offline/. Switch to Download to create an offline terrain resource." },
  "offline.noProviders": { "zh-Hans": "无可用供应商", en: "No providers available" },
  "offline.maxZoom": { "zh-Hans": "最高 z{zoom}", en: "Max z{zoom}" },
  "offline.recommendedSource": { "zh-Hans": "建议源 z{zoom}", en: "recommended source z{zoom}" },
  "offline.form.provider": { "zh-Hans": "供应商", en: "Provider" },
  "offline.form.name": { "zh-Hans": "资源名称（自动生成）", en: "Resource name (auto generated)" },
  "offline.form.minZoom": { "zh-Hans": "最小缩放", en: "Min zoom" },
  "offline.form.maxZoom": { "zh-Hans": "显示到", en: "Display to" },
  "offline.form.sourceMaxZoom": { "zh-Hans": "实际下载到", en: "Download to" },
  "offline.form.baseMaxZoom": { "zh-Hans": "全局底图到", en: "Global base to" },
  "offline.form.strategy": { "zh-Hans": "下载策略", en: "Download strategy" },
  "offline.form.tiered": { "zh-Hans": "分级混合：低缩放全球，高缩放仅选区", en: "Tiered: global low zoom, selected area high zoom" },
  "offline.form.west": { "zh-Hans": "西界", en: "West" },
  "offline.form.south": { "zh-Hans": "南界", en: "South" },
  "offline.form.east": { "zh-Hans": "东界", en: "East" },
  "offline.form.north": { "zh-Hans": "北界", en: "North" },
  "offline.boundsMap": { "zh-Hans": "离线地图范围选择", en: "Offline map bounds selector" },
  "offline.boundsUnknown": { "zh-Hans": "范围未知", en: "Bounds unknown" },
  "offline.bounds.global": { "zh-Hans": "选择全球", en: "Select Global" },
  "offline.bounds.clear": { "zh-Hans": "取消选择", en: "Clear Selection" },
  "offline.bounds.select": { "zh-Hans": "框选范围", en: "Draw Bounds" },
  "offline.downloadNote": { "zh-Hans": "默认不选择下载范围，避免误下载全球高缩放瓦片；如确实需要全球底图，请点击“选择全球”。最大下载量限制：{limit} 个瓦片。\n瓦片上限由本地离线地图服务控制；请优先选择较小范围，避免长时间占用网络和存储。\n推荐优先下载 OpenFreeMap Vector：显示可到 z14，但实际源瓦片通常下载到 z10 左右，再由矢量引擎过缩放，体积会比截图式栅格瓦片小很多。若需要真正“城市几 MB”的包，请优先导入裁剪后的 PMTiles。\n新下载资源会写入单个 SQLite 瓦片库，避免大量小文件拖慢系统。", en: "No download bounds are selected by default to avoid accidental global high-zoom downloads. If you really need a global base map, tap Select Global. Maximum download limit: {limit} tiles.\nThe local offline map service controls the tile limit. Prefer a small area to avoid long network and storage use.\nOpenFreeMap Vector is recommended first: display can reach z14, while source tiles usually download around z10 and overzoom in the vector engine, much smaller than raster screenshot tiles. For true city-scale MB-sized packages, import clipped PMTiles.\nNew downloads are written to a single SQLite tile database to avoid many small files slowing the system." },
  "offline.estimate.overzoomDisplay": { "zh-Hans": "显示 z{min}-{max}，实际下载到 z{source} 后过缩放", en: "Display z{min}-{max}; download to z{source}, then overzoom" },
  "offline.estimate.displayDownload": { "zh-Hans": "显示/下载 z{min}-{max}", en: "Display/download z{min}-{max}" },
  "offline.estimate.strategyTiered": { "zh-Hans": "全球 z{min}-{base} + 选区 z{next}-{source}", en: "Global z{min}-{base} + selected area z{next}-{source}" },
  "offline.estimate.strategyGlobal": { "zh-Hans": "全球 z{min}-{source}", en: "Global z{min}-{source}" },
  "offline.estimate.strategyBounds": { "zh-Hans": "选区 z{min}-{source}", en: "Selected area z{min}-{source}" },
  "offline.estimate.rasterOverzoom": { "zh-Hans": " · 栅格会放大源瓦片，体积小但清晰度会下降", en: " · raster tiles overzoom from source tiles: smaller size, lower clarity" },
  "offline.estimate.rasterLarge": { "zh-Hans": " · 栅格 z13+ 会指数级变大，建议改用 OpenFreeMap Vector 或 PMTiles", en: " · raster z13+ grows quickly; consider OpenFreeMap Vector or PMTiles" },
  "offline.estimate.vectorOverzoom": { "zh-Hans": " · 矢量过缩放可保持轻量并继续平滑显示", en: " · vector overzoom stays lightweight and smooth" },
  "offline.estimate.summary": { "zh-Hans": "预计 {count} 个源瓦片，约 {size}（{tileSize}/瓦片） · {overzoom} · {strategy}{warning}{limit}", en: "Estimated {count} source tiles, about {size} ({tileSize}/tile) · {overzoom} · {strategy}{warning}{limit}" },
  "offline.estimate.limitExceeded": { "zh-Hans": "，超过上限 {limit} 个瓦片", en: ", exceeds the {limit}-tile limit" },
  "offline.estimate.needsBounds": { "zh-Hans": "请先选择下载范围。", en: "Select download bounds first." },
  "offline.startDownloadWithCount": { "zh-Hans": "开始下载（{count} 源瓦片 / 约 {size}）", en: "Start Download ({count} source tiles / about {size})" },
  "offline.startDownloadNeedsBounds": { "zh-Hans": "开始下载（请先选择范围）", en: "Start Download (select bounds first)" },
  "offline.startDownload": { "zh-Hans": "开始下载", en: "Start Download" },
  "offline.readingResources": { "zh-Hans": "正在读取 map_offline/ 资源...", en: "Reading map_offline/ resources..." },
  "offline.readingProviders": { "zh-Hans": "正在读取下载供应商...", en: "Reading download providers..." },
  "offline.cancelRequested": { "zh-Hans": "已请求取消离线地图下载。", en: "Offline map download cancellation requested." },
  "offline.selectedResource": { "zh-Hans": "已选择离线地形资源：{name}", en: "Selected offline terrain resource: {name}" },
  "offline.deleteConfirm": { "zh-Hans": "确认从 map_offline/ 删除离线地图资源“{name}”？", en: "Delete offline map resource \"{name}\" from map_offline/?" },
  "offline.deletedResource": { "zh-Hans": "已删除离线地形资源：{name}", en: "Deleted offline terrain resource: {name}" },
  "offline.compacting": { "zh-Hans": "压缩中...", en: "Compacting..." },
  "offline.compactedResource": { "zh-Hans": "离线地形资源已压缩为 SQLite：{name}", en: "Offline terrain resource compacted to SQLite: {name}" },
  "offline.startedDownload": { "zh-Hans": "已开始离线地图下载：{name}", en: "Started offline map download: {name}" },
  "offline.downloadNotStarted": { "zh-Hans": "下载未启动：{message}", en: "Download did not start: {message}" },
  "offline.downloadEnded": { "zh-Hans": "离线地图下载已结束。", en: "Offline map download finished." },
  "offline.statusRefreshed": { "zh-Hans": "离线地图状态已刷新。", en: "Offline map status refreshed." },
  "offline.unavailable": { "zh-Hans": "离线地形暂无可用的离线底图资源，已切回地形图。请在离线地图管理器中启用一个栅格/矢量资源。", en: "Offline terrain has no usable offline base map resource. Switched back to Terrain. Enable a raster/vector resource in Offline Map Manager." },
  "offline.notInstalledPrompt": { "zh-Hans": "当前未安装离线地图，已打开离线地图管理器。请先下载或导入 PMTiles / MBTiles / SQLite 地图包。", en: "No offline map is installed. Offline Map Manager is open; download or import a PMTiles / MBTiles / SQLite map package first." },
  "cache.loading": { "zh-Hans": "正在统计缓存大小...", en: "Calculating cache size..." },
  "cache.clear": { "zh-Hans": "清理缓存", en: "Clear Cache" },
  "cache.refresh": { "zh-Hans": "刷新缓存", en: "Refresh Cache" },
  "cache.settingsHint": { "zh-Hans": "仅清理在线增强底图缓存，不影响本地导航数据库、离线地图包和航路叠加层。", en: "Only clears online enhanced base-map cache. Local navigation databases, offline map packages, and route overlays are not affected." },
  "cache.unread": { "zh-Hans": "缓存状态尚未读取。", en: "Cache status has not been read." },
  "cache.summary": { "zh-Hans": "在线地图缓存位于 App Caches；后台请求 {pending} 个，失败冷却 {failed} 个。", en: "Online map cache is stored in App Caches; {pending} background requests, {failed} failure cooldowns." },
  "cache.status": { "zh-Hans": "地图缓存：{size}，{count} 个文件。", en: "Map cache: {size}, {count} files." },
  "cache.clearConfirm": { "zh-Hans": "确认清理在线地图缓存？离线地图包和航路数据不会被删除。", en: "Clear the online map cache? Offline map packages and route data will not be deleted." },
  "cache.cleared": { "zh-Hans": "已清理在线地图缓存。", en: "Online map cache cleared." },
  "common.refreshStatus": { "zh-Hans": "刷新状态", en: "Refresh Status" },
  "common.refresh": { "zh-Hans": "刷新", en: "Refresh" },
  "common.noData": { "zh-Hans": "无数据。", en: "No data." },
  "common.noOptions": { "zh-Hans": "无可选项。", en: "No options." },
  "common.none": { "zh-Hans": "无", en: "None" },
  "common.auto": { "zh-Hans": "自动", en: "Auto" },
  "common.manual": { "zh-Hans": "手动", en: "Manual" },
  "common.allRunways": { "zh-Hans": "全部跑道", en: "All runways" },
  "common.yes": { "zh-Hans": "是", en: "Yes" },
  "common.no": { "zh-Hans": "否", en: "No" },
  "common.unknown": { "zh-Hans": "未知", en: "Unknown" },
  "map.typeAria": { "zh-Hans": "选择地图类型", en: "Choose map type" },
  "map.typeTitle": { "zh-Hans": "地图类型", en: "Map Type" },
  "map.terrain.label": { "zh-Hans": "地形图", en: "Terrain" },
  "map.terrain.title": { "zh-Hans": "在线缓存地形底图", en: "Cached online terrain base map" },
  "map.source.online": { "zh-Hans": "在线地图", en: "Online Map" },
  "map.source.onlineHint": { "zh-Hans": "选择在线底图来源", en: "Choose an online base-map source" },
  "map.source.offline": { "zh-Hans": "离线地图", en: "Offline Map" },
  "map.source.offlineHint": { "zh-Hans": "使用本机离线地图资源", en: "Use local offline map resources" },
  "map.providerTitle": { "zh-Hans": "在线地图来源", en: "Online Map Source" },
  "map.provider.arcgis": { "zh-Hans": "ArcGIS", en: "ArcGIS" },
  "map.provider.arcgisHint": { "zh-Hans": "默认在线地形底图", en: "Default online topographic base map" },
  "map.provider.openstreetmap": { "zh-Hans": "OpenStreetMap", en: "OpenStreetMap" },
  "map.provider.openstreetmapHint": { "zh-Hans": "OSM 标准底图", en: "OSM standard base map" },
  "map.provider.opentopomap": { "zh-Hans": "OpenTopoMap", en: "OpenTopoMap" },
  "map.provider.opentopomapHint": { "zh-Hans": "开源地形底图", en: "Open topographic base map" },
  "map.provider.google": { "zh-Hans": "Google", en: "Google" },
  "map.provider.googleHint": { "zh-Hans": "Google 地形底图", en: "Google terrain base map" },
  "map.zoomOffsetTitle": { "zh-Hans": "地图清晰度 Offset", en: "Map Clarity Offset" },
  "map.zoomOffsetAria": { "zh-Hans": "在线地图瓦片缩放 Offset", en: "Online map tile zoom offset" },
  "map.zoomOffsetHint": { "zh-Hans": "提高 Offset 会请求更高缩放级别的在线瓦片，文字和地形通常更清晰，但加载量会增加。", en: "Higher offsets request higher-zoom online tiles, usually making labels and terrain sharper while increasing tile loading." },
  "map.zoomOffsetValue": { "zh-Hans": "当前 {value}", en: "Current {value}" },
  "map.zoomOffsetDefault": { "zh-Hans": "默认", en: "Default" },
  "map.sourceChanged": { "zh-Hans": "已切换为{mode}。", en: "Switched to {mode}." },
  "map.providerChanged": { "zh-Hans": "已切换在线地图来源：{provider}。", en: "Online map source changed to {provider}." },
  "map.zoomOffsetChanged": { "zh-Hans": "在线地图清晰度 Offset 已设为 {value}。", en: "Online map clarity offset set to {value}." },
  "map.vector.label": { "zh-Hans": "地形矢量", en: "Topo Vector" },
  "map.vector.title": { "zh-Hans": "山影与等高线", en: "Hillshade and contours" },
  "map.aero.label": { "zh-Hans": "航空图", en: "Aero" },
  "map.aero.title": { "zh-Hans": "简洁航空矢量底图", en: "Clean aviation vector base map" },
  "map.offline.label": { "zh-Hans": "离线地形", en: "Offline Terrain" },
  "map.offline.title": { "zh-Hans": "本地 map_offline 资源", en: "Local map_offline resources" },
  "map.offlineControl": { "zh-Hans": "管理离线地形地图", en: "Manage offline terrain maps" },
  "map.overlay.base": { "zh-Hans": "地图层", en: "Base map layer" },
  "map.overlay.route": { "zh-Hans": "航路绘制", en: "Route drawing" },
  "map.overlay.manualRoute": { "zh-Hans": "人工绘制航路", en: "Manual route drawing" },
  "map.overlay.procedure": { "zh-Hans": "SID / STAR / APPROACH 绘制", en: "SID / STAR / APPROACH drawing" },
  "map.overlay.fr24": { "zh-Hans": "FR24 航路", en: "FR24 track" },
  "map.overlay.terminal": { "zh-Hans": "terminal waypoints", en: "terminal waypoints" },
  "map.overlay.points": { "zh-Hans": "其他航点和导航台", en: "Other waypoints and navaids" },
  "map.vectorRuntimeError": { "zh-Hans": "矢量地图运行库加载失败。", en: "Vector map runtime failed to load." },
  "map.contourRuntimeError": { "zh-Hans": "矢量地形等高线运行库加载失败。", en: "Vector contour runtime failed to load." },
  "map.pmtilesRuntimeError": { "zh-Hans": "PMTiles 运行库加载失败。", en: "PMTiles runtime failed to load." },
  "map.vectorBaseError": { "zh-Hans": "矢量地形底图加载失败，普通地形底图仍可使用。", en: "Vector terrain base map failed to load; regular terrain remains available." },
  "selection.chooseProcedure": { "zh-Hans": "选择一个程序以预览路径。", en: "Choose a procedure to preview its path." },
  "selection.noSelectedProcedure": { "zh-Hans": "尚未选择 SID / STAR / APPROACH。", en: "No SID / STAR / APPROACH selected." },
  "selection.noLegs": { "zh-Hans": "数据库中没有该程序的航段。", en: "This procedure has no legs in the database." },
  "selection.legCount": { "zh-Hans": "{airport} · {count} 个航段", en: "{airport} · {count} legs" },
  "selection.phase.main": { "zh-Hans": "主段", en: "Main" },
  "selection.phase.final": { "zh-Hans": "最后进近", en: "Final" },
  "selection.phase.runway": { "zh-Hans": "跑道", en: "Runway" },
  "selection.phase.missed": { "zh-Hans": "复飞", en: "Missed" },
  "procedure.noDrawable": { "zh-Hans": "程序 {procedure}/{transition} 在数据库中没有可绘制坐标。", en: "Procedure {procedure}/{transition} has no drawable coordinates in the database." },
  "procedure.loadFailed": { "zh-Hans": "{type} {procedure}/{transition} 加载失败。", en: "{type} {procedure}/{transition} failed to load." },
  "procedure.autoLoaded": { "zh-Hans": "已加载自动选择的 SID / STAR / APPROACH，可手动替换任意项目。", en: "Auto-selected SID / STAR / APPROACH loaded. You can manually replace any item." },
  "procedure.noAvailable": { "zh-Hans": "无可用程序。", en: "No procedures available." },
  "procedure.feature.left": { "zh-Hans": "左转", en: "Left turn" },
  "procedure.feature.right": { "zh-Hans": "右转", en: "Right turn" },
  "procedure.feature.turn": { "zh-Hans": "转弯 {turn}", en: "Turn {turn}" },
  "procedure.feature.arc": { "zh-Hans": "弧线", en: "Arc" },
  "procedure.feature.arcVia": { "zh-Hans": "弧线 经 {waypoint}", en: "Arc via {waypoint}" },
  "procedure.feature.hold": { "zh-Hans": "等待", en: "Hold" },
  "popup.airport": { "zh-Hans": "机场", en: "Airport" },
  "popup.airway": { "zh-Hans": "航路", en: "Airway" },
  "popup.direct": { "zh-Hans": "直飞航段", en: "Direct Leg" },
  "popup.terminalWaypoint": { "zh-Hans": "终端航点", en: "Terminal Waypoint" },
  "popup.waypoint": { "zh-Hans": "航点", en: "Waypoint" },
  "popup.actionsAria": { "zh-Hans": "机场操作", en: "Airport actions" },
  "popup.setDeparture": { "zh-Hans": "设为起飞", en: "Set Departure" },
  "popup.setArrival": { "zh-Hans": "设为到达", en: "Set Arrival" },
  "popup.setManual": { "zh-Hans": "设为手动", en: "Set Manual" },
  "popup.region": { "zh-Hans": "区域", en: "Region" },
  "popup.frequency": { "zh-Hans": "频率", en: "Frequency" },
  "popup.coordinates": { "zh-Hans": "坐标", en: "Coordinates" },
  "popup.directionRestriction": { "zh-Hans": "方向限制", en: "Direction restriction" },
  "popup.associatedRoutes": { "zh-Hans": "关联航路（{count}）", en: "Associated airways ({count})" },
  "popup.direction.forward": { "zh-Hans": "仅正向", en: "Forward only" },
  "popup.direction.backward": { "zh-Hans": "仅反向", en: "Backward only" },
  "popup.direction.both": { "zh-Hans": "双向", en: "Both directions" },
  "route.noIntermediateLegs": { "zh-Hans": "无中间航段。", en: "No intermediate legs." },
  "route.needAirports": { "zh-Hans": "需要填写起飞和到达机场。", en: "Departure and arrival airports are required." },
  "route.currentTask": { "zh-Hans": "当前任务", en: "current task" },
  "route.operation.resolve": { "zh-Hans": "航路解析", en: "route resolve" },
  "route.parsing": { "zh-Hans": "正在解析航路...", en: "Resolving route..." },
  "route.generatedFallback": { "zh-Hans": "已自动生成航路。", en: "Route generated." },
  "route.generatedStatus": { "zh-Hans": "{message} 已选择 {distance}nm。", en: "{message} Selected {distance}nm." },
  "route.resolvedStatus": { "zh-Hans": "航路解析完成，共 {count} 个绘制点。", en: "Route resolved with {count} drawable points." },
  "route.resolveStopped": { "zh-Hans": "航路解析已停止。", en: "Route resolve stopped." },
  "route.operationStopped": { "zh-Hans": "{label}已停止。", en: "{label} stopped." },
  "track.operation": { "zh-Hans": "轨迹匹配", en: "track match" },
  "track.searching": { "zh-Hans": "正在查找可匹配的历史轨迹...", en: "Searching for a matchable historical track..." },
  "track.matchedFallback": { "zh-Hans": "轨迹航路已匹配。", en: "Track route matched." },
  "track.importMatchedFallback": { "zh-Hans": "导入轨迹已匹配。", en: "Imported track matched." },
  "track.matchedStatus": { "zh-Hans": "{message} 已匹配 {distance}nm。", en: "{message} Matched {distance}nm." },
  "track.stopped": { "zh-Hans": "轨迹匹配已停止。", en: "Track match stopped." },
  "query.title": { "zh-Hans": "FR24 航班查询", en: "FR24 Flight Query" },
  "query.search": { "zh-Hans": "查询", en: "Search" },
  "query.importGPX": { "zh-Hans": "手动导入", en: "Import GPX" },
  "query.importGPXOpening": { "zh-Hans": "请选择 GPX 轨迹文件。", en: "Choose a GPX track file." },
  "query.importGPXDrawn": { "zh-Hans": "已导入并绘制 {filename}，共 {count} 个点。", en: "Imported and drawn {filename} with {count} points." },
  "query.hint": { "zh-Hans": "", en: "" },
  "query.statusInitial": { "zh-Hans": "填好起飞和到达机场后，可查询该航线的最新 FR24 航班。", en: "Enter departure and arrival first, then search recent FR24 flights on this route." },
  "query.manualHistoryTitle": { "zh-Hans": "手动航班历史", en: "Manual Flight History" },
  "query.manualHistoryHint": { "zh-Hans": "可输入航班号查询 FR24 历史页，或输入 flightId 直接生成可下载 / 匹配的单条历史记录。", en: "Enter a flight number to query its FR24 history page, or a flightId to create a downloadable/matchable single history record." },
  "query.manualHistoryPlaceholder": { "zh-Hans": "航班号或 flightId，例如 TV9943", en: "Flight number or flightId, e.g. TV9943" },
  "query.manualHistorySearch": { "zh-Hans": "查历史", en: "Search History" },
  "query.manualHistoryMissing": { "zh-Hans": "请输入航班号或 flightId。", en: "Enter a flight number or flightId." },
  "query.manualHistoryLoading": { "zh-Hans": "正在查询手动航班历史...", en: "Searching manual flight history..." },
  "query.manualHistoryLoaded": { "zh-Hans": "已加载 {count} 条手动航班历史。", en: "Loaded {count} manual history records." },
  "query.empty": { "zh-Hans": "暂无查询结果。", en: "No query results yet." },
  "query.loading": { "zh-Hans": "正在查询 FR24 航班...", en: "Searching FR24 flights..." },
  "query.loaded": { "zh-Hans": "已找到 {count} 个 FR24 航班。", en: "Found {count} FR24 flights." },
  "query.noFlights": { "zh-Hans": "没有找到该航线的 FR24 航班。", en: "No FR24 flights found for this route." },
  "query.history": { "zh-Hans": "航班历史", en: "Flight History" },
  "query.loadHistory": { "zh-Hans": "加载历史", en: "Load History" },
  "query.historyLoading": { "zh-Hans": "正在读取航班历史...", en: "Loading flight history..." },
  "query.historyLoaded": { "zh-Hans": "已加载 {count} 条航班历史。", en: "Loaded {count} history records." },
  "query.noHistory": { "zh-Hans": "暂无可用航班历史。", en: "No flight history available." },
  "query.downloadDraw": { "zh-Hans": "下载并绘制轨迹", en: "Download & Draw Track" },
  "query.matchTrack": { "zh-Hans": "匹配轨迹", en: "Match Track" },
  "query.downloading": { "zh-Hans": "正在下载 FR24 GPX 轨迹...", en: "Downloading FR24 GPX track..." },
  "query.drawn": { "zh-Hans": "已绘制 FR24 GPX 轨迹，共 {count} 个点。", en: "FR24 GPX track drawn with {count} points." },
  "query.matching": { "zh-Hans": "正在使用本地 airway 图匹配 FR24 轨迹...", en: "Matching FR24 track with the local airway graph..." },
  "query.matched": { "zh-Hans": "{message} 已匹配 {distance}nm。", en: "{message} Matched {distance}nm." },
  "query.profileTitle": { "zh-Hans": "FR24 高度剖面", en: "FR24 Altitude Profile" },
  "query.profileAria": { "zh-Hans": "FR24 轨迹高度和速度剖面", en: "FR24 track altitude and speed profile" },
  "query.profileSlider": { "zh-Hans": "轨迹时间位置", en: "Track time position" },
  "query.profileReadout": { "zh-Hans": "{time} / 高度 {altitude} / 速度 {speed}", en: "{time} / Alt {altitude} / Speed {speed}" },
  "query.profileNoData": { "zh-Hans": "该轨迹暂无高度或速度数据。", en: "No altitude or speed data in this track." },
  "calculate.basicParams": { "zh-Hans": "基本参数", en: "Basic Parameters" },
  "calculate.manufacturer": { "zh-Hans": "飞机公司", en: "Manufacturer" },
  "calculate.aircraftType": { "zh-Hans": "具体机型", en: "Aircraft Type" },
  "calculate.cruiseAltitude": { "zh-Hans": "目标巡航高度", en: "Target Cruise Altitude" },
  "calculate.cruiseMach": { "zh-Hans": "目标巡航速度", en: "Target Cruise Speed" },
  "calculate.descentRate": { "zh-Hans": "下高目标下降率", en: "Target Descent Rate" },
  "calculate.weatherSource": { "zh-Hans": "气象数据", en: "Weather Data" },
  "calculate.statusInitial": { "zh-Hans": "生成航路后，计算页会读取计划页航路、Procedure 和本地剖面数据。", en: "Build a route first. Calc reads the Plan route, procedures, and local profile data." },
  "calculate.statusReady": { "zh-Hans": "已根据计划页航路生成 {count} 个剖面采样点；气象为 {source} 本地估算层。", en: "Generated {count} profile samples from the Plan route; weather uses the local {source} estimate layer." },
  "calculate.statusNoRoute": { "zh-Hans": "请先在计划页生成并绘制航路。", en: "Build and draw a route in Plan first." },
  "calculate.weatherProfileTitle": { "zh-Hans": "航路风速与地面海拔", en: "Route Wind & Terrain" },
  "calculate.weatherProfileAria": { "zh-Hans": "航路风速、云量、降雨量、地面海拔和计划高度剖面", en: "Route wind, cloud, precipitation, terrain, and planned altitude profile" },
  "calculate.weatherReadout": { "zh-Hans": "{distance}nm / FL{flightLevel} / 风 {wind}kt / {component} / 云量 {cloud}% / 雨 {rain}mm/h", en: "{distance}nm / FL{flightLevel} / wind {wind}kt / {component} / cloud {cloud}% / rain {rain}mm/h" },
  "calculate.weatherReadoutEmpty": { "zh-Hans": "等待航路剖面。", en: "Waiting for route profile." },
  "calculate.componentTail": { "zh-Hans": "顺风 {value}kt", en: "tailwind {value}kt" },
  "calculate.componentHead": { "zh-Hans": "逆风 {value}kt", en: "headwind {value}kt" },
  "calculate.layerToolbar": { "zh-Hans": "剖面图层", en: "Profile layers" },
  "calculate.layerWind": { "zh-Hans": "风向风速", en: "Wind" },
  "calculate.layerCloud": { "zh-Hans": "云量", en: "Cloud" },
  "calculate.layerRain": { "zh-Hans": "降雨量", en: "Rain" },
  "calculate.layerWindShort": { "zh-Hans": "风", en: "W" },
  "calculate.layerCloudShort": { "zh-Hans": "云", en: "C" },
  "calculate.layerRainShort": { "zh-Hans": "雨", en: "R" },
  "calculate.profileZoom": { "zh-Hans": "缩放", en: "Zoom" },
  "calculate.resetProfile": { "zh-Hans": "重置剖面", en: "Reset Profile" },
  "calculate.speedProfileTitle": { "zh-Hans": "飞行速度与 VS", en: "Ground Speed & VS" },
  "calculate.speedProfileAria": { "zh-Hans": "飞行地速和垂直速度剖面", en: "Ground speed and vertical speed profile" },
  "calculate.speedReadout": { "zh-Hans": "{distance}nm / GS {groundSpeed}kt / VS {verticalSpeed}fpm / {phase}", en: "{distance}nm / GS {groundSpeed}kt / VS {verticalSpeed}fpm / {phase}" },
  "calculate.phaseClimb": { "zh-Hans": "爬升", en: "Climb" },
  "calculate.phaseCruise": { "zh-Hans": "巡航", en: "Cruise" },
  "calculate.phaseDescent": { "zh-Hans": "下降", en: "Descent" },
  "calculate.fuelTitle": { "zh-Hans": "燃油消耗", en: "Fuel Burn" },
  "calculate.fuelSummaryInitial": { "zh-Hans": "等待航路与参数。", en: "Waiting for route and parameters." },
  "calculate.fuelSummary": { "zh-Hans": "预计航程 {distance}nm，总时间 {time}，T/OFF FUEL {fuel}kg。", en: "Estimated {distance}nm, total time {time}, T/OFF FUEL {fuel}kg." },
  "calculate.noFuel": { "zh-Hans": "等待计划页航路。", en: "Waiting for Plan route." },
  "calculate.tod": { "zh-Hans": "下高点", en: "TOD" },
  "calculate.procedureConstraint": { "zh-Hans": "程序高度限制", en: "Procedure altitude constraint" },
  "query.cache": { "zh-Hans": "FR24 轨迹缓存", en: "FR24 Track Cache" },
  "query.cacheStatus": { "zh-Hans": "正在读取缓存...", en: "Reading cache..." },
  "query.cacheInitial": { "zh-Hans": "GPX、playback JSON 和 meta JSON 缓存在 App Caches 中。", en: "GPX, playback JSON, and meta JSON are stored in App Caches." },
  "query.cacheSummary": { "zh-Hans": "FR24 缓存：{size}，{count} 个文件。", en: "FR24 cache: {size}, {count} files." },
  "query.cacheSearchTitle": { "zh-Hans": "检索已下载轨迹", en: "Search Downloaded Tracks" },
  "query.cacheSearchPlaceholder": { "zh-Hans": "航班号 / flightId / 机场 / 机型", en: "Flight / flightId / airport / aircraft" },
  "query.cacheSearch": { "zh-Hans": "检索缓存", en: "Search Cache" },
  "query.cacheSearchHint": { "zh-Hans": "只检索本机已下载的 FR24 GPX / playback 缓存；收藏文件不会被一键删除缓存清掉。", en: "Search only locally downloaded FR24 GPX / playback cache. Favorited files are protected from one-click cache clearing." },
  "query.cacheLoading": { "zh-Hans": "正在检索 FR24 下载缓存...", en: "Searching FR24 download cache..." },
  "query.cacheLoaded": { "zh-Hans": "已找到 {count} 条已下载轨迹。", en: "Found {count} downloaded tracks." },
  "query.cacheEmpty": { "zh-Hans": "没有匹配的已下载轨迹。", en: "No matching downloaded tracks." },
  "query.cacheDraw": { "zh-Hans": "绘制路径", en: "Draw Track" },
  "query.cacheShare": { "zh-Hans": "分享", en: "Share" },
  "query.cacheSharing": { "zh-Hans": "正在准备 FR24 GPX 分享文件...", en: "Preparing FR24 GPX share file..." },
  "query.cacheShareReady": { "zh-Hans": "已打开 FR24 GPX 分享面板。", en: "FR24 GPX share sheet opened." },
  "query.cacheDelete": { "zh-Hans": "删除文件", en: "Delete File" },
  "query.cacheFavorite": { "zh-Hans": "收藏", en: "Favorite" },
  "query.cacheUnfavorite": { "zh-Hans": "取消收藏", en: "Unfavorite" },
  "query.cacheFavoriteBadge": { "zh-Hans": "已收藏", en: "Favorited" },
  "query.cacheDownloaded": { "zh-Hans": "缓存 {time} / {count} 点", en: "Cached {time} / {count} pts" },
  "query.cacheDeleteConfirm": { "zh-Hans": "确认删除 {flight} 的 FR24 缓存文件？", en: "Delete FR24 cached files for {flight}?" },
  "query.cacheDeleted": { "zh-Hans": "已删除 FR24 缓存文件。", en: "FR24 cached files deleted." },
  "query.cacheFavorited": { "zh-Hans": "已收藏 FR24 缓存文件。", en: "FR24 cached files favorited." },
  "query.cacheUnfavorited": { "zh-Hans": "已取消收藏 FR24 缓存文件。", en: "FR24 cached files unfavorited." },
  "query.cacheClearedWithFavorites": { "zh-Hans": "已删除未收藏的 FR24 缓存，保留 {count} 个收藏。", en: "Deleted non-favorited FR24 cache and kept {count} favorites." },
  "query.openCacheDirectory": { "zh-Hans": "打开目录", en: "Open Folder" },
  "query.cacheDirectoryOpening": { "zh-Hans": "正在打开 FR24 缓存目录...", en: "Opening FR24 cache folder..." },
  "query.cacheDirectoryOpened": { "zh-Hans": "已打开 FR24 缓存目录。", en: "FR24 cache folder opened." },
  "query.cacheDirectoryFailed": { "zh-Hans": "无法打开 FR24 缓存目录。", en: "Could not open the FR24 cache folder." },
  "query.access": { "zh-Hans": "FR24 网络访问", en: "FR24 Network Access" },
  "query.accessInitial": { "zh-Hans": "浏览器会话未同步。", en: "Browser session not synced." },
  "query.accessSummary": { "zh-Hans": "浏览器会话{state}。", en: "Browser session {state}." },
  "query.accessSyncedState": { "zh-Hans": "已同步", en: "synced" },
  "query.accessUnsyncedState": { "zh-Hans": "未同步", en: "not synced" },
  "query.accessConfigured": { "zh-Hans": "已配置", en: "configured" },
  "query.accessMissing": { "zh-Hans": "未配置", en: "missing" },
  "query.accessOpenBrowser": { "zh-Hans": "打开 FR24 验证页", en: "Open FR24 Verification" },
  "query.accessSyncBrowser": { "zh-Hans": "同步内置浏览器会话", en: "Sync Browser Session" },
  "query.accessOpening": { "zh-Hans": "已打开 FR24 验证页；完成验证后点“同步会话”。", en: "FR24 verification opened. Complete verification, then tap Sync Session." },
  "query.accessSyncing": { "zh-Hans": "正在同步内置浏览器中的 FR24 会话...", en: "Syncing the FR24 session from the in-app browser..." },
  "query.accessSynced": { "zh-Hans": "已从内置浏览器同步 FR24 Web 会话。", en: "FR24 Web session synced from the in-app browser." },
  "query.accessSyncMissing": { "zh-Hans": "内置浏览器还没有可同步的 FR24 会话。请先完成 FR24 / Cloudflare 验证。", en: "No FR24 session is available in the in-app browser yet. Complete FR24 / Cloudflare verification first." },
  "query.accessManual": { "zh-Hans": "高级：手动会话配置（可选）", en: "Advanced: Manual Session (Optional)" },
  "query.accessCookie": { "zh-Hans": "FR24 Web Cookie", en: "FR24 Web Cookie" },
  "query.accessFrPl": { "zh-Hans": "_frPl", en: "_frPl" },
  "query.accessSave": { "zh-Hans": "保存手动配置", en: "Save Manual Session" },
  "query.accessClear": { "zh-Hans": "清除会话配置", en: "Clear Session" },
  "query.accessSaved": { "zh-Hans": "已保存 FR24 Web 会话配置。", en: "FR24 Web session saved." },
  "query.accessCleared": { "zh-Hans": "已清除 FR24 Web 会话配置。", en: "FR24 Web session cleared." },
  "query.accessHint": { "zh-Hans": "在 App 内打开 FR24 验证页并正常完成验证，然后同步会话，即可查询 FR24 航班。", en: "Open FR24 verification inside the app, complete verification normally, then sync the session to query FR24 flights." },
  "query.undoTrack": { "zh-Hans": "撤销上一步绘制", en: "Undo Last Drawing" },
  "query.redoTrack": { "zh-Hans": "重做上次撤销", en: "Redo Last Undo" },
  "query.clearTrack": { "zh-Hans": "清除绘制", en: "Clear Drawing" },
  "query.clearAllTrack": { "zh-Hans": "清除全部绘制", en: "Clear All Drawings" },
  "query.restoreMatch": { "zh-Hans": "还原轨迹匹配", en: "Restore Match" },
  "query.clearCache": { "zh-Hans": "删除下载缓存", en: "Delete Download Cache" },
  "query.clearCacheConfirm": { "zh-Hans": "确认删除未收藏的 FR24 下载缓存？已收藏的 GPX、playback JSON 和 meta JSON 会保留。", en: "Delete non-favorited FR24 download cache? Favorited GPX, playback JSON, and meta JSON files will be kept." },
  "query.cacheCleared": { "zh-Hans": "已删除未收藏的 FR24 下载缓存。", en: "Non-favorited FR24 download cache deleted." },
  "query.fr24TrackCleared": { "zh-Hans": "已清除 FR24 轨迹绘制。", en: "FR24 track drawing cleared." },
  "query.noFR24Track": { "zh-Hans": "当前没有已绘制的 FR24 轨迹。", en: "No FR24 track is currently drawn." },
  "query.trackCleared": { "zh-Hans": "已清除全部绘制。", en: "All drawings cleared." },
  "query.trackUndoRestored": { "zh-Hans": "已撤销上一步绘制。", en: "Undid the last drawing." },
  "query.trackUndoCleared": { "zh-Hans": "已撤销到无绘制状态。", en: "Undid to no drawing." },
  "query.trackRedoRestored": { "zh-Hans": "已重做绘制。", en: "Redid the drawing." },
  "query.noTrackUndo": { "zh-Hans": "没有可撤销的绘制。", en: "No drawing to undo." },
  "query.noTrackRedo": { "zh-Hans": "没有可重做的绘制。", en: "No drawing to redo." },
  "query.noTrack": { "zh-Hans": "当前没有可清除的绘制。", en: "No drawing is currently visible." },
  "query.noRestore": { "zh-Hans": "没有可还原的轨迹匹配航路。", en: "No matched route to restore." },
  "query.restored": { "zh-Hans": "已还原轨迹匹配前的航路。", en: "Restored the route from before track matching." },
  "query.flightUnknown": { "zh-Hans": "未知航班", en: "Unknown Flight" },
  "query.airlineUnknown": { "zh-Hans": "未知航司", en: "Unknown airline" },
  "query.aircraftUnknown": { "zh-Hans": "未知机型", en: "Unknown aircraft" },
  "query.scheduleActual": { "zh-Hans": "计划 {scheduled} / 实际 {actual}", en: "Scheduled {scheduled} / Actual {actual}" },
  "query.duration": { "zh-Hans": "时长 {duration}", en: "Duration {duration}" },
  "query.cacheHit": { "zh-Hans": "使用缓存", en: "Cache hit" },
  "query.cacheMiss": { "zh-Hans": "新下载", en: "Downloaded" },
  "query.actualRoute": { "zh-Hans": "实际起降 {route}", en: "Actual route {route}" },
  "error.requestFailed": { "zh-Hans": "请求失败。", en: "Request failed." },
  "error.invalidJson": { "zh-Hans": "响应不是有效的 JSON。", en: "Response is not valid JSON." },
  "error.http": { "zh-Hans": "请求失败：HTTP {code}。", en: "Request failed: HTTP {code}." },
  "error.fetch": { "zh-Hans": "网络请求失败，请检查网络连接或本地服务状态。", en: "Network request failed. Check the network connection or local service state." },
  "error.offline": { "zh-Hans": "当前网络不可用，在线增强内容暂时无法加载。", en: "The network is offline. Online enhancements are temporarily unavailable." },
  "error.unknownHost": { "zh-Hans": "无法识别的 NavPlanner 本地地址。", en: "Unknown NavPlanner local address." },
  "error.webNotFound": { "zh-Hans": "本地 Web 资源未找到。", en: "Local Web resource not found." },
  "error.apiNotFound": { "zh-Hans": "本地 API 不存在。", en: "Local API not found." },
  "error.airportNotFound": { "zh-Hans": "机场未找到。", en: "Airport not found." },
  "error.offlineApi": { "zh-Hans": "离线地图 API 不存在。", en: "Offline maps API not found." },
  "error.pmtilesNotFound": { "zh-Hans": "PMTiles 资源未找到。", en: "PMTiles resource not found." },
  "error.tilePath": { "zh-Hans": "地图瓦片路径无效。", en: "Invalid map tile path." },
  "error.tileCoord": { "zh-Hans": "地图瓦片坐标无效。", en: "Invalid map tile coordinate." },
  "error.trackPost": { "zh-Hans": "轨迹匹配需要使用 POST 请求。", en: "Track match requires POST." },
  "error.airportsUnresolved": { "zh-Hans": "无法解析起飞或到达机场。", en: "Departure or arrival could not be resolved." },
  "error.dctSource": { "zh-Hans": "DCT 前必须是已知航点或机场。", en: "DCT must follow a known fix or airport." },
  "error.dctMissing": { "zh-Hans": "DCT 缺少目标航点。", en: "DCT is missing the target fix." },
  "error.dctTarget": { "zh-Hans": "DCT 目标 {fix} 未找到。", en: "DCT target {fix} not found." },
  "error.starsBetween": { "zh-Hans": "*** 必须位于两个航点之间。", en: "*** must be between two fixes." },
  "error.starsMissing": { "zh-Hans": "*** 缺少目标航点。", en: "*** is missing the target fix." },
  "error.starsSource": { "zh-Hans": "*** 起点 {fix} 未找到。", en: "*** source {fix} not found." },
  "error.starsTarget": { "zh-Hans": "*** 目标 {fix} 未找到。", en: "*** target {fix} not found." },
  "error.airwaySource": { "zh-Hans": "航路 {airway} 前必须是航点。", en: "Airway {airway} must follow a fix." },
  "error.airwayExit": { "zh-Hans": "航路 {airway} 缺少退出点。", en: "Airway {airway} is missing an exit fix." },
  "error.exitFix": { "zh-Hans": "退出点 {fix} 未找到。", en: "Exit fix {fix} not found." },
  "error.airwayConnect": { "zh-Hans": "航路 {airway} 不连接 {from} 到 {to}。", en: "Airway {airway} does not connect {from} to {to}." },
  "error.waypoint": { "zh-Hans": "航点 {fix} 未找到。", en: "Waypoint {fix} not found." },
  "error.trackNoPath": { "zh-Hans": "无法从导入轨迹构建合法航路。", en: "No legal airway path could be built from the imported trajectory." },
  "error.trackNoPoints": { "zh-Hans": "无法从导入轨迹构建可绘制航路点。", en: "No drawable route points could be built from the imported trajectory." },
  "error.fr24Session": { "zh-Hans": "FR24 Web 会话不可用。请在查询页打开 FR24 验证页，完成验证后同步会话。", en: "FR24 Web session is unavailable. Open FR24 verification in Query, complete verification, then sync the session." },
  "error.fr24Cloudflare": { "zh-Hans": "FR24 返回 Cloudflare 验证页。请在查询页打开 FR24 验证页，完成验证后同步会话。", en: "FR24 returned a Cloudflare verification page. Open FR24 verification in Query, complete verification, then sync the session." },
  "error.fr24NotEnough": { "zh-Hans": "FR24 Web 未返回足够轨迹点，可选择其他历史航班或稍后重试。", en: "FR24 web did not return enough track points. Try another history entry or retry later." },
  "error.fr24MissingId": { "zh-Hans": "FR24 flightId 缺失。", en: "FR24 flightId missing." },
};

function readLocalStorageValue(key) {
  try {
    return window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

function writeLocalStorageValue(key, value) {
  try {
    window.localStorage.setItem(key, value);
  } catch (_) {
    // localStorage 在受限 WebView 中可能不可写；语言/主题仍可在当前会话生效。
  }
}

function removeLocalStorageValue(key) {
  try {
    window.localStorage.removeItem(key);
  } catch (_) {
    // localStorage 在受限 WebView 中可能不可写；重置仍会应用到当前会话。
  }
}

function systemLanguageCode() {
  const languages = Array.isArray(navigator.languages) && navigator.languages.length
    ? navigator.languages
    : [navigator.language || "en"];
  return String(languages[0] || "").toLowerCase().startsWith("zh")
    ? "zh-Hans"
    : "en";
}

function normalizeLanguageMode(mode) {
  return LANGUAGE_MODES.has(mode) ? mode : "system";
}

function resolveLanguageMode(mode) {
  const normalized = normalizeLanguageMode(mode);
  return normalized === "system" ? systemLanguageCode() : normalized;
}

function currentLanguage() {
  return document.documentElement.dataset.language === "zh-Hans" ? "zh-Hans" : "en";
}

function t(key, params = {}) {
  const entry = TRANSLATIONS[key];
  const value = (entry && (entry[currentLanguage()] ?? entry["zh-Hans"])) || key;
  return String(value).replace(/\{([a-zA-Z0-9_]+)\}/g, (_match, name) => (
    params[name] === null || params[name] === undefined ? "" : String(params[name])
  ));
}

function formatCount(value) {
  return Number(value || 0).toLocaleString(currentLanguage());
}

const state = {
  selectedAirport: null,
  airportMarkers: new Map(),
  airportSlotMarkerKeys: {
    departure: null,
    arrival: null,
    manual: null,
  },
  labelMarkers: [],
  departureAirport: null,
  arrivalAirport: null,
  manualAirport: null,
  activeAirportSlot: "departure",
  selectedProcedures: {
    sid: null,
    star: null,
    approach: null,
  },
  selectedRunways: {
    departure: "ALL",
    arrival: "ALL",
    manual: "ALL",
  },
  airportProcedureData: {
    departure: null,
    arrival: null,
    manual: null,
  },
  runwayButtonOptions: {
    departure: ["ALL"],
    arrival: ["ALL"],
    manual: ["ALL"],
  },
  procedureRequestVersion: {
    sid: 0,
    star: 0,
    approach: 0,
  },
  procedureVisualLayers: {
    sid: null,
    star: null,
    approach: null,
  },
  procedureChips: new Map(),
  airwaySegmentLayers: new Map(),
  airwayLegChips: new Map(),
  navAirwayLayers: new Map(),
  navAirwayLabels: new Map(),
  hoveredAirwayKey: null,
  selectedNavAirway: null,
  lastRouteWasGenerated: false,
  lastGeneratedRouteDisplay: "",
  navOverlayVersion: 0,
  navOverlayAbortController: null,
  navOverlayPayload: null,
  navOverlayFetchBounds: null,
  navOverlayDrawBounds: null,
  navOverlayZoom: null,
  navOverlayDrawZoom: null,
  navOverlayRetryTimer: 0,
  activeRouteAbortController: null,
  activeRouteOperation: "",
  procedureCache: new Map(),
  airportPopupCache: new Map(),
  activeNavPopup: null,
  pendingMapPopupTimer: 0,
  mapPopupSuppressUntil: 0,
  refreshingNavPopup: false,
  activeSelectionProcedure: null,
  selectionHighlightLayer: null,
  offlineMapStatus: null,
  offlineMapManagerTab: "manage",
  offlineMapPollTimer: 0,
  offlineMapTileVersion: Date.now(),
  mapCacheStatus: null,
  mapCacheTileVersion: Date.now(),
  fr24Flights: new Map(),
  fr24CacheFlights: new Map(),
  fr24SearchFlights: [],
  fr24SearchRenderOptions: {},
  fr24CacheItems: [],
  fr24HistoryByKey: new Map(),
  fr24CacheStatus: null,
  fr24AccessStatus: null,
  fr24QueryBusy: false,
  fr24TrackPayload: null,
  fr24ProfilePoints: [],
  fr24ProfileCursorIndex: 0,
  fr24ProfileDragging: false,
  fr24ProfileLayout: null,
  fr24ProfileResizeFrame: null,
  fr24ProfileResizeObserver: null,
  calculateManufacturer: "boeing",
  calculateAircraft: "B738",
  calculateCruiseAltitudeFt: 30000,
  calculateCruiseMach: null,
  calculateDescentRateFpm: 1500,
  calculateWeatherSource: "noaa",
  calculateLayerVisibility: {
    wind: true,
    cloud: true,
    rain: false,
  },
  calculateAltitudeOverrides: new Map(),
  calculateRouteSignature: "",
  calculateProfileZoom: 1,
  calculateProfileFocusNm: null,
  calculateProfileData: null,
  calculateWeatherLayout: null,
  calculateSpeedLayout: null,
  calculateWeatherDragging: false,
  calculateResizeFrame: null,
  calculateResizeObserver: null,
  drawingUndoStack: [],
  drawingRedoStack: [],
  restoringDrawingSnapshot: false,
  currentRoutePayload: null,
  currentRouteAirports: null,
  preTrackMatchRoutePayload: null,
  preTrackMatchAirports: null,
  preTrackMatchRouteLayerKind: null,
  offlineDownloadError: "",
  offlineSelectionRequested: false,
  offlineDownloadBounds: null,
  offlineBoundsSelecting: false,
  searchSuppressedUntil: 0,
  mapSourceMode: normalizeMapSourceMode(savedMapSourceMode),
  baseMap: normalizeMapSourceMode(savedMapSourceMode) === "offline" ? "offline" : "terrain",
  onlineMapProvider: normalizeOnlineMapProvider(savedOnlineMapProvider),
  mapTileZoomOffset: normalizeMapTileZoomOffset(savedMapTileZoomOffset),
  mapOverlayVisibility: {
    baseMap: true,
    route: true,
    manualRoute: true,
    procedures: true,
    fr24: true,
    terminalWaypoints: true,
    otherWaypoints: true,
  },
  currentRouteLayerKind: "route",
  activeDetailTab: "airport",
  activeMobileTab: "plan",
  themeMode: THEME_MODES.has(savedThemeMode) ? savedThemeMode : "system",
  languageMode: normalizeLanguageMode(savedLanguageMode),
  effectiveLanguage: resolveLanguageMode(savedLanguageMode),
  appIconChoice: APP_ICON_CHOICES.has(savedAppIconChoice) ? savedAppIconChoice : "primary",
  databaseStatus: null,
  databaseListStatus: null,
  databaseItems: [],
  airportPayloads: {
    departure: null,
    arrival: null,
    manual: null,
  },
  mobileFocusedControl: null,
  mobileKeyboardLift: 0,
  mobileVisualHeight: 0,
  mobileKeyboardFrame: 0,
  mobileKeyboardResetTimer: 0,
  mobilePanelMapRatio: 66,
  mobilePanelDrag: null,
  mobilePanelDragFrame: 0,
  mobilePanelDragPendingRatio: null,
  mobilePanelMapFlexValue: "",
  mobilePanelPanelFlexValue: "",
  mobilePanelTapGuard: null,
  mobilePanelDeferredVectorResize: false,
  mobilePanelMapRowValue: "",
  mobilePanelPanelRowValue: "",
  mobilePanelResizeFrame: 0,
};

const MAP_ZOOM = {
  controlStep: 0.5,
  doubleClickStep: 0.75,
  doubleClickPopupDelay: 280,
  doubleClickPopupGuard: 420,
  wheelSpeed: 0.0065,
  wheelMaxFrameDelta: 1.2,
  trackpadGestureSpeed: 1.15,
  wheelIdleDelay: 140,
};
const DOUBLE_TAP_ZOOM_GUARD_MS = 320;
const MOBILE_KEYBOARD_MIN_OVERLAP_PX = 80;
const MOBILE_KEYBOARD_MARGIN_PX = 14;
const MOBILE_PANEL_DEFAULT_MAP_RATIO = 66;
const MOBILE_PANEL_MIN_MAP_RATIO = 30;
const MOBILE_PANEL_RATIO_STEP = 0.2;
const NAV_OVERLAY_REFRESH_DELAY_MS = 110;
const NAV_OVERLAY_FETCH_PADDING_RATIO = 0.16;
const NAV_OVERLAY_DRAW_PADDING_RATIO = 0.12;
const NAV_AIRWAY_INTERACTIVE_MIN_ZOOM = 6;
const NAV_TERMINAL_DETAIL_MIN_ZOOM = 9;
const NAV_RUNWAY_LABEL_MIN_ZOOM = 11;
const PROCEDURE_CACHE_LIMIT = 180;
const DRAWING_HISTORY_LIMIT = 30;
const EMPTY_LIST = Object.freeze([]);
const versionPathSegment = (value) => `_v${encodeURIComponent(String(value || 0))}`;

function normalizeMapSourceMode(mode) {
  return MAP_SOURCE_MODES.has(mode) ? mode : "online";
}

function normalizeOnlineMapProvider(provider) {
  return ONLINE_MAP_PROVIDER_KEYS.has(provider) ? provider : "arcgis";
}

function normalizeMapTileZoomOffset(value) {
  const parsed = Number.parseInt(String(value), 10);
  return MAP_TILE_ZOOM_OFFSETS.has(parsed) ? parsed : 0;
}

function mapTileZoomOffsetLabel(value = state.mapTileZoomOffset) {
  const normalized = normalizeMapTileZoomOffset(value);
  return normalized > 0 ? `+${normalized}` : String(normalized);
}

function mapTileZoomOffsetProgress(value = state.mapTileZoomOffset) {
  const normalized = normalizeMapTileZoomOffset(value);
  return `${((normalized + 1) / 3) * 100}%`;
}

function currentMapSourceMode() {
  return normalizeMapSourceMode(state.mapSourceMode);
}

function mapSourceModeForBaseMap(type) {
  return type === "offline" ? "offline" : "online";
}

function setMapSourceMode(mode, { persist = true } = {}) {
  state.mapSourceMode = normalizeMapSourceMode(mode);
  if (persist) {
    writeLocalStorageValue("navplannerMapSourceMode", state.mapSourceMode);
  }
}

function currentOnlineMapProviderConfig(provider = state.onlineMapProvider) {
  return ONLINE_MAP_PROVIDERS[normalizeOnlineMapProvider(provider)] || ONLINE_MAP_PROVIDERS.arcgis;
}

function onlineMapTileUrl(provider = state.onlineMapProvider) {
  const key = normalizeOnlineMapProvider(provider);
  const config = currentOnlineMapProviderConfig(key);
  return apiResourceUrl(`/api/map-cache/${key}/${versionPathSegment(state.mapCacheTileVersion)}/{z}/{x}/{y}.${config.format}`);
}

function onlineMapTileLayerOptions() {
  const provider = currentOnlineMapProviderConfig();
  const maxProviderZoom = provider.maxZoom || 20;
  const zoomOffset = state.mapTileZoomOffset;
  return {
    maxZoom: 20,
    maxNativeZoom: Math.max(0, maxProviderZoom - zoomOffset),
    tileSize: Math.round(ONLINE_TILE_BASE_SIZE / Math.pow(2, zoomOffset)),
    zoomOffset,
  };
}

function onlineMapTileLayerSignature() {
  return `${normalizeOnlineMapProvider(state.onlineMapProvider)}|${state.mapTileZoomOffset}`;
}

/**
 * 功能：判断当前是否运行在 iPhone 紧凑工作台。
 * 输入：无。
 * 输出：iPad 返回 false；iPhone / 小屏返回 true。
 */
function isPhoneWorkbench() {
  return document.documentElement.dataset.device !== "pad";
}

function isCompactPhoneMap() {
  return isPhoneWorkbench()
    && (!window.matchMedia || window.matchMedia("(max-width: 1024px), (orientation: landscape)").matches);
}

function compactPhoneValue(value, scale = 0.72, minimum = 0) {
  return isCompactPhoneMap() ? Math.max(minimum, value * scale) : value;
}

function routeStrokeWeight(value) {
  return isPhoneWorkbench() ? value * 0.8 : value;
}

function compactPhoneSize(size) {
  if (!isCompactPhoneMap()) {
    return size;
  }
  return size.map((value) => Math.max(5, Math.round(value * 0.72)));
}

const MAP_COLORS = {
  route: "#2f80ff",
  routeHover: "#71b8ff",
  manualRoute: "#ffd166",
  manualRouteHover: "#fff0a6",
  sid: "#48d597",
  star: "#ff7185",
  approach: "#a76cff",
  airway: "#347fbd",
  airwayActive: "#1f6f8d",
  runway: "#263c51",
  ils: "#d84f67",
  departure: "#48d597",
  arrival: "#ff7185",
};

function normalizeRouteLayerKind(kind) {
  return kind === "manualRoute" ? "manualRoute" : "route";
}

function routeLayerGroupForKind(kind) {
  return normalizeRouteLayerKind(kind) === "manualRoute" ? manualRouteLayerGroup : autoRouteLayerGroup;
}

function routeStyleForKind(kind) {
  const normalized = normalizeRouteLayerKind(kind);
  return normalized === "manualRoute"
    ? { color: MAP_COLORS.manualRoute, hoverColor: MAP_COLORS.manualRouteHover }
    : { color: MAP_COLORS.route, hoverColor: MAP_COLORS.routeHover };
}

function inferRouteLayerKind(payload) {
  return payload?.generated || payload?.source_provider === "track-match" ? "route" : "manualRoute";
}

const BASE_MAPS = {
  terrain: {
    labelKey: "map.terrain.label",
    titleKey: "map.terrain.title",
  },
  vector: {
    labelKey: "map.vector.label",
    titleKey: "map.vector.title",
  },
  aero: {
    labelKey: "map.aero.label",
    titleKey: "map.aero.title",
  },
  offline: {
    labelKey: "map.offline.label",
    titleKey: "map.offline.title",
  },
};

const MAP_OVERLAY_CONTROLS = Object.freeze([
  { key: "baseMap", labelKey: "map.overlay.base", icon: "base" },
  { key: "route", labelKey: "map.overlay.route", icon: "route" },
  { key: "manualRoute", labelKey: "map.overlay.manualRoute", icon: "manualRoute" },
  { key: "procedures", labelKey: "map.overlay.procedure", icon: "procedure" },
  { key: "fr24", labelKey: "map.overlay.fr24", icon: "fr24" },
  { key: "terminalWaypoints", labelKey: "map.overlay.terminal", icon: "terminal" },
  { key: "otherWaypoints", labelKey: "map.overlay.points", icon: "points" },
]);

const VECTOR_MAP_STYLE = "https://tiles.openfreemap.org/styles/liberty";
const VECTOR_ATTRIBUTION = 'Map data: &copy; <a href="https://openfreemap.org/" target="_blank" rel="noreferrer">OpenFreeMap</a>';
const OFFLINE_VECTOR_ATTRIBUTION = "离线矢量地形来自 map_offline";
const VECTOR_TERRAIN_DEM_TILE_URL = apiResourceUrl("/api/terrain/terrarium/{z}/{x}/{y}.png");
const VECTOR_BASE_MAP_TYPES = new Set(["vector", "aero"]);
const MAPLIBRE_ZOOM_OFFSET = 1;
const VECTOR_PAN_BUFFER_MIN_PX = 520;
const VECTOR_PAN_BUFFER_MAX_PX = 1120;
const ASYNC_CACHED_TILE_REQUEST_TIMEOUT_MS = 6500;
const ASYNC_CACHED_TILE_RETRY_DELAYS_MS = [120, 260, 520, 1000, 1800, 3200, 5200, 8000];
const ROUTE_WORLD_COPY_OFFSETS = [-720, -360, 0, 360, 720];
const FR24_TRACK_GAP_NM = 10;
const FR24_TRACK_CURVE_MIN_NM = 4;
const FR24_TRACK_CURVE_TURN_DEG = 38;
const AIRPORT_SLOTS = ["departure", "arrival", "manual"];
const AIRPORT_SLOT_LABELS = {
  departure: "airport.slot.departure",
  arrival: "airport.slot.arrival",
  manual: "airport.slot.manual",
};
const OFFLINE_MAP_DEFAULT_DOWNLOAD = Object.freeze({
  west: -180,
  south: -85,
  east: 180,
  north: 85,
  minZoom: 0,
  maxZoom: 14,
  sourceMaxZoom: 10,
  baseMaxZoom: 5,
});
const OFFLINE_MAP_GLOBAL_BOUNDS = Object.freeze({ west: -180, south: -85.0511, east: 180, north: 85.0511 });

const elements = {
  departureInput: document.querySelector("#departureInput"),
  arrivalInput: document.querySelector("#arrivalInput"),
  manualInput: document.querySelector("#manualInput"),
  routeInput: document.querySelector("#routeInput"),
  departureResults: document.querySelector("#departureResults"),
  arrivalResults: document.querySelector("#arrivalResults"),
  manualResults: document.querySelector("#manualResults"),
  planDepartureRunway: document.querySelector("#planDepartureRunway"),
  planArrivalRunway: document.querySelector("#planArrivalRunway"),
  planButton: document.querySelector("#planButton"),
  recalculateButton: document.querySelector("#recalculateButton"),
  planClearTrackButton: document.querySelector("#planClearTrackButton"),
  stopRequestButton: document.querySelector("#stopRequestButton"),
  statusText: document.querySelector("#statusText"),
  routeLegs: document.querySelector("#routeLegs"),
  selectedProcedures: document.querySelector("#selectedProcedures"),
  airportEmpty: document.querySelector("#airportEmpty"),
  airportPanels: document.querySelector("#airportPanels"),
  departureAirportTab: document.querySelector("#departureAirportTab"),
  arrivalAirportTab: document.querySelector("#arrivalAirportTab"),
  manualAirportTab: document.querySelector("#manualAirportTab"),
  departureAirportIdent: document.querySelector("#departureAirportIdent"),
  departureAirportName: document.querySelector("#departureAirportName"),
  departureAirportMeta: document.querySelector("#departureAirportMeta"),
  departureRunwayList: document.querySelector("#departureRunwayList"),
  departureCommList: document.querySelector("#departureCommList"),
  departureSidList: document.querySelector("#departureSidList"),
  departureStarList: document.querySelector("#departureStarList"),
  departureApproachList: document.querySelector("#departureApproachList"),
  departureRunwaySelect: document.querySelector("#departureRunwaySelect"),
  arrivalAirportIdent: document.querySelector("#arrivalAirportIdent"),
  arrivalAirportName: document.querySelector("#arrivalAirportName"),
  arrivalAirportMeta: document.querySelector("#arrivalAirportMeta"),
  arrivalRunwayList: document.querySelector("#arrivalRunwayList"),
  arrivalCommList: document.querySelector("#arrivalCommList"),
  arrivalSidList: document.querySelector("#arrivalSidList"),
  arrivalStarList: document.querySelector("#arrivalStarList"),
  arrivalApproachList: document.querySelector("#arrivalApproachList"),
  arrivalRunwaySelect: document.querySelector("#arrivalRunwaySelect"),
  manualAirportIdent: document.querySelector("#manualAirportIdent"),
  manualAirportName: document.querySelector("#manualAirportName"),
  manualAirportMeta: document.querySelector("#manualAirportMeta"),
  manualRunwayList: document.querySelector("#manualRunwayList"),
  manualCommList: document.querySelector("#manualCommList"),
  manualSidList: document.querySelector("#manualSidList"),
  manualStarList: document.querySelector("#manualStarList"),
  manualApproachList: document.querySelector("#manualApproachList"),
  manualRunwaySelect: document.querySelector("#manualRunwaySelect"),
  selectionInfo: document.querySelector("#selectionInfo"),
  focusDepartureButton: document.querySelector("#focusDepartureButton"),
  focusArrivalButton: document.querySelector("#focusArrivalButton"),
  focusManualButton: document.querySelector("#focusManualButton"),
  mapExpandButton: document.querySelector("#mapExpandButton"),
  sidebarExpandButton: document.querySelector("#sidebarExpandButton"),
  detailModeTabButtons: document.querySelectorAll("[data-detail-tab]"),
  detailTabPanels: document.querySelectorAll("[data-detail-panel]"),
  detailPanel: document.querySelector(".detail-panel"),
  mobileBottomTabButtons: document.querySelectorAll("[data-mobile-tab]"),
  mobilePanelDragHandle: document.querySelector("#mobilePanelDragHandle"),
  databaseNameText: document.querySelector("#databaseNameText"),
  databaseStatusText: document.querySelector("#databaseStatusText"),
  selectDatabaseButton: document.querySelector("#selectDatabaseButton"),
  databaseStorageSummary: document.querySelector("#databaseStorageSummary"),
  databaseSearchInput: document.querySelector("#databaseSearchInput"),
  refreshDatabaseListButton: document.querySelector("#refreshDatabaseListButton"),
  restoreBundledDatabaseButton: document.querySelector("#restoreBundledDatabaseButton"),
  databaseList: document.querySelector("#databaseList"),
  themeChoiceButtons: document.querySelectorAll("[data-theme-choice]"),
  languageChoiceButtons: document.querySelectorAll("[data-language-choice]"),
  appIconChoiceButtons: document.querySelectorAll("[data-app-icon-choice]"),
  mapSourceChoiceButtons: document.querySelectorAll("[data-map-source-choice]"),
  onlineMapProviderButtons: document.querySelectorAll("[data-online-map-provider]"),
  mapTileZoomOffsetSliderFrame: document.querySelector("#mapTileZoomOffsetSliderFrame"),
  mapTileZoomOffsetInput: document.querySelector("#mapTileZoomOffsetInput"),
  mapTileZoomOffsetValue: document.querySelector("#mapTileZoomOffsetValue"),
  mapTileZoomOffsetScaleLabels: document.querySelectorAll("[data-zoom-offset-value]"),
  onlineMapSettingsPanel: document.querySelector("#onlineMapSettingsPanel"),
  offlineMapSettingsPanel: document.querySelector("#offlineMapSettingsPanel"),
  offlineMapSummaryTitle: document.querySelector("#offlineMapSummaryTitle"),
  offlineMapSummaryText: document.querySelector("#offlineMapSummaryText"),
  manageOfflineMapsButton: document.querySelector("#manageOfflineMapsButton"),
  refreshOfflineMapsButton: document.querySelector("#refreshOfflineMapsButton"),
  mapCacheSummaryTitle: document.querySelector("#mapCacheSummaryTitle"),
  mapCacheSummaryText: document.querySelector("#mapCacheSummaryText"),
  refreshMapCacheButton: document.querySelector("#refreshMapCacheButton"),
  clearMapCacheButton: document.querySelector("#clearMapCacheButton"),
  resetAllSettingsButton: document.querySelector("#resetAllSettingsButton"),
  fr24SearchButton: document.querySelector("#fr24SearchButton"),
  fr24ImportGPXButton: document.querySelector("#fr24ImportGPXButton"),
  fr24ManualHistoryInput: document.querySelector("#fr24ManualHistoryInput"),
  fr24ManualHistoryButton: document.querySelector("#fr24ManualHistoryButton"),
  fr24QueryStatus: document.querySelector("#fr24QueryStatus"),
  fr24ProfileCard: document.querySelector("#fr24ProfileCard"),
  fr24ProfileSvg: document.querySelector("#fr24ProfileSvg"),
  fr24ProfileSlider: document.querySelector("#fr24ProfileSlider"),
  fr24ProfileReadout: document.querySelector("#fr24ProfileReadout"),
  calculateSection: document.querySelector("#calculateSection"),
  calcManufacturerSelect: document.querySelector("#calcManufacturerSelect"),
  calcAircraftSelect: document.querySelector("#calcAircraftSelect"),
  calcCruiseAltitudeInput: document.querySelector("#calcCruiseAltitudeInput"),
  calcCruiseAltitudeValue: document.querySelector("#calcCruiseAltitudeValue"),
  calcCruiseAltitudeTicks: document.querySelector("#calcCruiseAltitudeTicks"),
  calcCruiseMachInput: document.querySelector("#calcCruiseMachInput"),
  calcCruiseMachValue: document.querySelector("#calcCruiseMachValue"),
  calcCruiseMachTicks: document.querySelector("#calcCruiseMachTicks"),
  calcDescentRateInput: document.querySelector("#calcDescentRateInput"),
  calcDescentRateValue: document.querySelector("#calcDescentRateValue"),
  calcDescentRateTicks: document.querySelector("#calcDescentRateTicks"),
  calcWeatherSourceButtons: document.querySelectorAll("[data-calc-weather-source]"),
  calcStatusText: document.querySelector("#calcStatusText"),
  calcLayerButtons: document.querySelectorAll("[data-calc-layer]"),
  calcWeatherReadout: document.querySelector("#calcWeatherReadout"),
  calcWeatherProfileSvg: document.querySelector("#calcWeatherProfileSvg"),
  calcProfileZoomInput: document.querySelector("#calcProfileZoomInput"),
  calcResetProfileButton: document.querySelector("#calcResetProfileButton"),
  calcSpeedReadout: document.querySelector("#calcSpeedReadout"),
  calcSpeedProfileSvg: document.querySelector("#calcSpeedProfileSvg"),
  calcFuelSummary: document.querySelector("#calcFuelSummary"),
  calcFuelBrief: document.querySelector("#calcFuelBrief"),
  fr24FlightList: document.querySelector("#fr24FlightList"),
  fr24CacheSearchInput: document.querySelector("#fr24CacheSearchInput"),
  fr24CacheSearchButton: document.querySelector("#fr24CacheSearchButton"),
  fr24CacheList: document.querySelector("#fr24CacheList"),
  fr24CacheTitle: document.querySelector("#fr24CacheTitle"),
  fr24CacheSummary: document.querySelector("#fr24CacheSummary"),
  fr24AccessSummary: document.querySelector("#fr24AccessSummary"),
  fr24OpenBrowserButton: document.querySelector("#fr24OpenBrowserButton"),
  fr24SyncBrowserButton: document.querySelector("#fr24SyncBrowserButton"),
  fr24CookieInput: document.querySelector("#fr24CookieInput"),
  fr24FrPlInput: document.querySelector("#fr24FrPlInput"),
  fr24SaveAccessButton: document.querySelector("#fr24SaveAccessButton"),
  fr24ClearAccessButton: document.querySelector("#fr24ClearAccessButton"),
  fr24RefreshAccessButton: document.querySelector("#fr24RefreshAccessButton"),
  fr24ClearTrackButton: document.querySelector("#fr24ClearTrackButton"),
  fr24RestoreMatchButton: document.querySelector("#fr24RestoreMatchButton"),
  fr24ClearCacheButton: document.querySelector("#fr24ClearCacheButton"),
  fr24RefreshCacheButton: document.querySelector("#fr24RefreshCacheButton"),
  fr24OpenCacheDirectoryButton: document.querySelector("#fr24OpenCacheDirectoryButton"),
};

function applyStaticTranslations() {
  document.title = t("app.title");
  document.querySelectorAll("[data-i18n]").forEach((element) => {
    element.textContent = t(element.dataset.i18n);
  });
  document.querySelectorAll("[data-i18n-placeholder]").forEach((element) => {
    element.setAttribute("placeholder", t(element.dataset.i18nPlaceholder));
  });
  document.querySelectorAll("[data-i18n-aria-label]").forEach((element) => {
    element.setAttribute("aria-label", t(element.dataset.i18nAriaLabel));
  });
  document.querySelectorAll("[data-i18n-title]").forEach((element) => {
    element.setAttribute("title", t(element.dataset.i18nTitle));
  });
  updateMapOverlayControlLabels();
  syncCalculateControls();
}

const map = L.map("map", {
  attributionControl: false,
  zoomControl: false,
  zoomSnap: 0,
  zoomDelta: MAP_ZOOM.controlStep,
  scrollWheelZoom: false,
  doubleClickZoom: false,
  zoomAnimation: true,
  markerZoomAnimation: false,
  preferCanvas: true,
  worldCopyJump: true,
}).setView([28.6, 104.0], 4);

map.getContainer().dataset.baseMap = state.baseMap;
map.getPane("popupPane").classList.add("planner-popup-pane");
map.createPane("terrainPane");
map.getPane("terrainPane").classList.add("terrain-pane");
map.createPane("navPane");
map.getPane("navPane").style.zIndex = 360;
map.getPane("navPane").classList.add("nav-pane");
map.createPane("pointPane");
map.getPane("pointPane").style.zIndex = 365;
map.getPane("pointPane").classList.add("point-pane");
map.createPane("navLabelPane");
map.getPane("navLabelPane").style.zIndex = 370;
map.getPane("navLabelPane").classList.add("nav-label-pane");
map.createPane("routeHitPane");
map.getPane("routeHitPane").style.zIndex = 355;
map.getPane("routeHitPane").classList.add("route-hit-pane");
map.createPane("routePane");
map.getPane("routePane").style.zIndex = 640;
map.getPane("routePane").classList.add("route-pane");
map.createPane("labelPane");
map.getPane("labelPane").style.zIndex = 660;
map.getPane("labelPane").classList.add("label-pane");

const baseLayers = {
  terrain: null,
  offline: L.tileLayer(apiResourceUrl(`/api/offline-maps/tile/${versionPathSegment(state.offlineMapTileVersion)}/{z}/{x}/{y}.png`), {
    maxZoom: 19,
    updateWhenZooming: true,
    updateWhenIdle: false,
    updateInterval: 80,
    keepBuffer: 5,
    pane: "terrainPane",
    attribution: "Offline terrain from map_offline",
  }),
};

let onlineBaseLayerSwap = null;
let vectorMap = null;
let vectorMapContainer = null;
let vectorMapSyncFrame = 0;
let vectorMapResizeFrame = 0;
let vectorMapPanMirrorFrame = 0;
let vectorMapPanMirrorActive = false;
let vectorMapZoomMirrorFrame = 0;
let vectorMapZoomMirrorActive = false;
let vectorMapResizeObserver = null;
let vectorMapErrorShown = false;
let vectorMapStyleReady = false;
let vectorMapStyleMode = "";
let vectorMapLastSyncKey = "";
let vectorMapLastSizeKey = "";
let vectorMapPanStartPoint = null;
let vectorMapPanStartZoom = 0;
let vectorMapZoomStartPoint = null;
let vectorMapZoomStartZoom = 0;
let vectorMapPanBufferPx = 0;
let terrainDemSource = null;
let pmtilesProtocol = null;
let mapOverlayControlContainer = null;
let trackHistoryControlContainer = null;
let offlineMapControlContainer = null;
let offlineMapModalElement = null;
let offlineBoundsMiniMap = null;
let offlineBoundsMiniMapContainer = null;
let offlineBoundsRectangle = null;
let offlineBoundsDraftRectangle = null;

/**
 * 功能：创建一个只在真实缓存瓦片可用时才完成加载的异步瓦片图层。
 * 输入：urlTemplate 为瓦片 URL 模板，options 为 Leaflet 瓦片图层配置。
 * 输出：支持后台缓存排队和轮询补齐的 Leaflet 瓦片图层。
 */
function createAsyncCachedTileLayer(urlTemplate, options = {}) {
  const layer = new AsyncCachedTileLayer(urlTemplate, options);
  layer.on("tileunload", ({ tile }) => {
    cancelAsyncCachedTile(tile);
  });
  return layer;
}

function createOnlineBaseLayer() {
  const layer = createAsyncCachedTileLayer(onlineMapTileUrl(), {
    ...onlineMapTileLayerOptions(),
    updateWhenZooming: true,
    updateWhenIdle: false,
    updateInterval: 80,
    keepBuffer: 5,
    pane: "terrainPane",
    attribution: "Map data: cached terrain",
  });
  layer._plannerLayerSignature = onlineMapTileLayerSignature();
  return layer;
}

function clearOnlineBaseLayerSwap({ removePrevious = false } = {}) {
  if (!onlineBaseLayerSwap) {
    return;
  }
  const swap = onlineBaseLayerSwap;
  onlineBaseLayerSwap = null;
  swap.timers.forEach((timer) => window.clearTimeout(timer));
  swap.layer.off("tileload", swap.onTileLoad);
  swap.layer.off("tileerror", swap.onTileError);
  swap.layer.off("load", swap.onLoad);
  if (removePrevious && swap.previousLayer && map.hasLayer(swap.previousLayer)) {
    map.removeLayer(swap.previousLayer);
  }
}

function warmSwapOnlineBaseLayer(nextLayer, previousLayer) {
  clearOnlineBaseLayerSwap({ removePrevious: true });
  if (!previousLayer || previousLayer === nextLayer || !map.hasLayer(previousLayer)) {
    return;
  }

  const timers = new Set();
  let loadedTiles = 0;
  let committed = false;
  const schedule = (delay, callback) => {
    const timer = window.setTimeout(() => {
      timers.delete(timer);
      callback();
    }, delay);
    timers.add(timer);
  };
  const commit = () => {
    if (committed) {
      return;
    }
    committed = true;
    clearOnlineBaseLayerSwap();
    if (map.hasLayer(previousLayer)) {
      map.removeLayer(previousLayer);
    }
  };
  const onTileLoad = () => {
    loadedTiles += 1;
    schedule(loadedTiles >= 4 ? 90 : 900, commit);
  };
  const onTileError = () => {
    if (loadedTiles > 0) {
      schedule(1200, commit);
    }
  };
  const onLoad = () => schedule(80, commit);

  onlineBaseLayerSwap = {
    layer: nextLayer,
    previousLayer,
    timers,
    onTileLoad,
    onTileError,
    onLoad,
  };
  nextLayer.on("tileload", onTileLoad);
  nextLayer.on("tileerror", onTileError);
  nextLayer.on("load", onLoad);
}

/**
 * 功能：取消一个异步缓存瓦片的后续轮询并释放对象 URL。
 * 输入：tile 为 createTile 创建的图片元素。
 * 输出：无返回值；仅清理前端资源。
 */
function cancelAsyncCachedTile(tile) {
  if (!tile) {
    return;
  }
  tile._plannerCancelled = true;
  if (tile._plannerRetryTimer) {
    window.clearTimeout(tile._plannerRetryTimer);
    tile._plannerRetryTimer = 0;
  }
  if (tile._plannerAbortController) {
    tile._plannerAbortController.abort();
    tile._plannerAbortController = null;
  }
  if (tile._plannerObjectUrl) {
    URL.revokeObjectURL(tile._plannerObjectUrl);
    tile._plannerObjectUrl = "";
  }
}

/**
 * 功能：判断后端是否只返回了“已排队/下载中”的透明占位瓦片。
 * 输入：response 为 fetch 返回的 HTTP 响应。
 * 输出：排队或下载中返回 true，其它响应返回 false。
 */
function isQueuedTileResponse(response) {
  return ["QUEUED", "PENDING", "MISS"].includes(response.headers.get("X-Map-Cache"));
}

/**
 * 功能：按指数退避轮询缺失瓦片，直到真实缓存瓦片可用。
 * 输入：tile 为图片元素，attempt 为当前重试次数，requestTile 为实际请求函数。
 * 输出：无返回值；通过定时器触发后续请求。
 */
function scheduleAsyncCachedTileRetry(tile, attempt, requestTile) {
  if (tile._plannerCancelled) {
    return;
  }
  const delay = ASYNC_CACHED_TILE_RETRY_DELAYS_MS[Math.min(attempt, ASYNC_CACHED_TILE_RETRY_DELAYS_MS.length - 1)];
  tile._plannerRetryTimer = window.setTimeout(() => requestTile(attempt + 1), delay);
}

function supportedTileImageMimeType(buffer) {
  const bytes = new Uint8Array(buffer || []);
  if (bytes.length < 4) {
    return "";
  }
  const isPNG = bytes.length >= 20
    && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47
    && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a
    && bytes[bytes.length - 12] === 0x00 && bytes[bytes.length - 11] === 0x00
    && bytes[bytes.length - 10] === 0x00 && bytes[bytes.length - 9] === 0x00
    && bytes[bytes.length - 8] === 0x49 && bytes[bytes.length - 7] === 0x45
    && bytes[bytes.length - 6] === 0x4e && bytes[bytes.length - 5] === 0x44
    && bytes[bytes.length - 4] === 0xae && bytes[bytes.length - 3] === 0x42
    && bytes[bytes.length - 2] === 0x60 && bytes[bytes.length - 1] === 0x82;
  if (isPNG) {
    return "image/png";
  }
  const isJPEG = bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8;
  if (!isJPEG) {
    return "";
  }
  let tailIndex = bytes.length - 1;
  while (tailIndex > 2 && (bytes[tailIndex] === 0x00 || bytes[tailIndex] === 0x0a || bytes[tailIndex] === 0x0d || bytes[tailIndex] === 0x20)) {
    tailIndex -= 1;
  }
  return tailIndex >= 3 && bytes[tailIndex - 1] === 0xff && bytes[tailIndex] === 0xd9 ? "image/jpeg" : "";
}

/**
 * 功能：把已命中的真实瓦片 URL 或 blob URL 写入图片元素，并在图片可显示后通知 Leaflet。
 * 输入：tile 为图片元素，url 为本地瓦片 URL / blob URL，done 为 Leaflet 的加载完成回调。
 * 输出：无返回值；成功后底图才会替换旧瓦片。
 */
function loadAsyncCachedTileUrl(tile, url, done) {
  if (tile._plannerCancelled) {
    return;
  }
  if (tile._plannerObjectUrl) {
    URL.revokeObjectURL(tile._plannerObjectUrl);
    tile._plannerObjectUrl = "";
  }
  tile.onload = () => {
    if (!tile._plannerCancelled && !tile._plannerDone) {
      tile._plannerDone = true;
      done(null, tile);
    }
  };
  tile.onerror = () => {
    if (!tile._plannerCancelled && !tile._plannerDone) {
      if (tile._plannerObjectUrl) {
        URL.revokeObjectURL(tile._plannerObjectUrl);
        tile._plannerObjectUrl = "";
      }
      tile._plannerDone = true;
      done(new Error("Tile image decode failed."), tile);
    }
  };
  tile.src = url;
}

function loadAsyncCachedTileBuffer(tile, buffer, mimeType, done) {
  if (tile._plannerCancelled) {
    return;
  }
  const blob = new Blob([buffer], { type: mimeType || "image/png" });
  const objectUrl = URL.createObjectURL(blob);
  loadAsyncCachedTileUrl(tile, objectUrl, done);
  tile._plannerObjectUrl = objectUrl;
}

const AsyncCachedTileLayer = L.TileLayer.extend({
  /**
   * 功能：创建单个异步缓存瓦片，避免透明占位图覆盖已有底图。
   * 输入：coords 为 Leaflet 瓦片坐标，done 为瓦片加载完成回调。
   * 输出：图片元素；真实瓦片命中前不会调用 done。
   */
  createTile(coords, done) {
    const tile = document.createElement("img");
    tile.alt = "";
    tile.setAttribute("role", "presentation");
    tile._plannerCancelled = false;
    tile._plannerDone = false;
    tile._plannerObjectUrl = "";
    tile._plannerRetryTimer = 0;
    tile._plannerAbortController = null;

    const requestTile = async (attempt = 0) => {
      if (tile._plannerCancelled || tile._plannerDone) {
        return;
      }
      const tileUrl = this.getTileUrl(coords);
      const controller = new AbortController();
      const timeoutTimer = ASYNC_CACHED_TILE_REQUEST_TIMEOUT_MS > 0
        ? window.setTimeout(() => controller.abort(), ASYNC_CACHED_TILE_REQUEST_TIMEOUT_MS)
        : 0;
      tile._plannerAbortController = controller;
      try {
        const response = await fetch(tileUrl, {
          cache: "no-store",
          signal: controller.signal,
        });
        if (isQueuedTileResponse(response)) {
          await response.arrayBuffer().catch(() => {});
          scheduleAsyncCachedTileRetry(tile, attempt, requestTile);
          return;
        }
        if (!response.ok) {
          throw new Error(`Tile request failed: ${response.status}`);
        }
        const buffer = await response.arrayBuffer();
        const mimeType = supportedTileImageMimeType(buffer);
        if (!mimeType) {
          throw new Error("Tile response is not a supported image.");
        }
        loadAsyncCachedTileBuffer(tile, buffer, mimeType, done);
      } catch (_error) {
        scheduleAsyncCachedTileRetry(tile, attempt, requestTile);
      } finally {
        if (timeoutTimer) {
          window.clearTimeout(timeoutTimer);
        }
        if (tile._plannerAbortController === controller) {
          tile._plannerAbortController = null;
        }
      }
    };

    requestTile();
    return tile;
  },
});

baseLayers.terrain = createOnlineBaseLayer();

baseLayers.terrain.addTo(map);
L.control.zoom({ position: "bottomright" }).addTo(map);

installSmoothWheelZoom(map);
installTrackpadGestureZoom(map);
installMapDoubleClickZoom(map);
installPageDoubleTapZoomGuard();
installMobileViewportLock();
installMobilePanelDragHandle();
installMobileInputTouchFocus();
installPhoneLandscapeSafeAreaTuning();

const autoRouteLayerGroup = L.layerGroup().addTo(map);
const manualRouteLayerGroup = L.layerGroup().addTo(map);
let routeLayerGroup = autoRouteLayerGroup;
const fr24TrackLayerGroup = L.layerGroup().addTo(map);
let fr24TrackCursorMarker = null;
let navAirwayLayerGroup = L.layerGroup().addTo(map);
let navAirwayLabelLayerGroup = L.layerGroup().addTo(map);
let navLayerGroup = L.layerGroup().addTo(map);
let navLabelLayerGroup = L.layerGroup().addTo(map);
let navTerminalLayerGroup = L.layerGroup().addTo(map);
let navTerminalLabelLayerGroup = L.layerGroup().addTo(map);
let navPointLayerGroup = L.layerGroup().addTo(map);
let navPointLabelLayerGroup = L.layerGroup().addTo(map);
const navRenderer = isPhoneWorkbench()
  ? L.svg({ pane: "navPane", padding: 0.42 })
  : L.canvas({ pane: "navPane", padding: 0.35 });
const pointRenderer = isPhoneWorkbench()
  ? L.svg({ pane: "pointPane", padding: 0.42 })
  : L.canvas({ pane: "pointPane", padding: 0.35 });
const waypointHighlightRenderer = L.svg({ pane: "routePane", padding: 0.48 });
const markerLayerGroup = L.layerGroup().addTo(map);
const selectionHighlightLayerGroup = L.layerGroup().addTo(map);
const labelLayerGroup = L.layerGroup().addTo(map);
const procedureLayerGroups = {
  sid: L.layerGroup().addTo(map),
  star: L.layerGroup().addTo(map),
  approach: L.layerGroup().addTo(map),
};
createMapOverlayControl().addTo(map);
createTrackHistoryControl().addTo(map);
applyMapOverlayVisibility();

/**
 * 功能：确保 `ensureVectorMapContainer` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function ensureVectorMapContainer() {
  if (vectorMapContainer) {
    return vectorMapContainer;
  }
  vectorMapContainer = document.createElement("div");
  vectorMapContainer.className = "vector-maplibre-base";
  vectorMapContainer.setAttribute("aria-hidden", "true");
  map.getContainer().insertBefore(vectorMapContainer, map.getContainer().firstChild);
  return vectorMapContainer;
}

/**
 * 功能：执行 `leafletZoomToMapLibreZoom` 对应的业务逻辑。
 * 输入：zoom。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function leafletZoomToMapLibreZoom(zoom) {
  return Math.max(0, zoom - MAPLIBRE_ZOOM_OFFSET);
}

/**
 * 功能：获取当前活动的离线地图资源元数据。
 * 输入：status 为离线地图状态；默认使用全局状态。
 * 输出：活动资源对象；不存在时返回 null。
 */
function activeOfflineResource(status = state.offlineMapStatus) {
  if (!status?.active) {
    return null;
  }
  return (status.resources || []).find((resource) => resource.name === status.active) || null;
}

function hasOfflineResources(status = state.offlineMapStatus) {
  return Array.isArray(status?.resources) && status.resources.length > 0;
}

/**
 * 功能：读取离线资源实际拥有的源瓦片最大级别。
 * 输入：resource 为离线地图资源元数据。
 * 输出：源瓦片最大级别；缺省时回退到显示最大级别。
 */
function offlineResourceSourceMaxZoom(resource) {
  return Number(resource?.source_max_zoom ?? resource?.max_zoom ?? 19);
}

/**
 * 功能：读取离线资源允许显示的最大级别。
 * 输入：resource 为离线地图资源元数据。
 * 输出：显示最大级别；缺省时回退到源瓦片最大级别。
 */
function offlineResourceDisplayMaxZoom(resource) {
  return Number(resource?.max_zoom ?? resource?.source_max_zoom ?? 19);
}

/**
 * 功能：将离线地图资源类型转为中文显示文本。
 * 输入：kind 为 API 返回的资源或供应商类型。
 * 输出：中文类型名称。
 */
function offlineKindLabel(kind) {
  const normalized = String(kind || "").toLowerCase();
  if (normalized === "vector") {
    return t("offline.kind.vector");
  }
  if (normalized === "raster") {
    return t("offline.kind.raster");
  }
  if (normalized === "resource") {
    return t("offline.kind.resource");
  }
  return kind ? String(kind) : t("offline.kind.resource");
}

/**
 * 功能：将离线地图格式转为中文显示文本。
 * 输入：format 为 API 返回的格式。
 * 输出：中文格式名称。
 */
function offlineFormatLabel(format) {
  const normalized = String(format || "").toLowerCase();
  const zh = currentLanguage() === "zh-Hans";
  const labels = {
    png: zh ? "PNG 瓦片" : "PNG tiles",
    jpg: zh ? "JPEG 瓦片" : "JPEG tiles",
    jpeg: zh ? "JPEG 瓦片" : "JPEG tiles",
    webp: zh ? "WebP 瓦片" : "WebP tiles",
    pbf: zh ? "PBF 矢量瓦片" : "PBF vector tiles",
    mvt: zh ? "MVT 矢量瓦片" : "MVT vector tiles",
    pmtiles: "PMTiles",
    mbtiles: "MBTiles",
    sqlite: zh ? "SQLite 瓦片库" : "SQLite tile database",
  };
  return labels[normalized] || (format ? String(format).toUpperCase() : t("offline.unknownFormat"));
}

/**
 * 功能：判断当前状态是否有可作为离线地形显示的离线资源。
 * 输入：status 为离线地图状态。
 * 输出：存在栅格或矢量活动资源时返回 true。
 */
function hasActiveOfflineDisplayResource(status) {
  const resource = activeOfflineResource(status);
  return resource?.kind === "raster" || resource?.kind === "vector";
}

/**
 * 功能：判断指定底图类型是否应由 MapLibre 矢量引擎绘制。
 * 输入：type 为底图类型。
 * 输出：Topo/Aero 或活动离线矢量资源返回 true。
 */
function isVectorBaseMap(type = state.baseMap) {
  if (VECTOR_BASE_MAP_TYPES.has(type)) {
    return true;
  }
  return type === "offline" && activeOfflineResource()?.kind === "vector";
}

/**
 * 功能：按离线栅格资源元数据设置 Leaflet 过缩放参数。
 * 输入：resource 为当前活动离线栅格资源；缺省时读取全局活动资源。
 * 输出：无返回值；更新离线栅格图层选项。
 */
function configureOfflineRasterLayer(resource = activeOfflineResource()) {
  const displayMaxZoom = offlineResourceDisplayMaxZoom(resource);
  const sourceMaxZoom = offlineResourceSourceMaxZoom(resource);
  if (Number.isFinite(displayMaxZoom)) {
    baseLayers.offline.options.maxZoom = displayMaxZoom;
  }
  if (Number.isFinite(sourceMaxZoom) && sourceMaxZoom < displayMaxZoom) {
    baseLayers.offline.options.maxNativeZoom = sourceMaxZoom;
  } else {
    delete baseLayers.offline.options.maxNativeZoom;
  }
}

/**
 * 功能：生成离线矢量瓦片的本地 URL 模板。
 * 输入：resource 为活动离线矢量资源。
 * 输出：MapLibre 可使用的瓦片 URL 模板。
 */
function offlineVectorTileUrl(resource) {
  const name = encodeURIComponent(resource.name || "");
  const format = resource.format || "pbf";
  return apiResourceUrl(`/api/offline-maps/resource/${name}/${versionPathSegment(state.offlineMapTileVersion)}/{z}/{x}/{y}.${format}`);
}

/**
 * 功能：生成离线 PMTiles 单文件 URL。
 * 输入：resource 为活动离线资源。
 * 输出：可供 pmtiles:// protocol 读取的 HTTP URL。
 */
function offlinePmtilesUrl(resource) {
  const name = encodeURIComponent(resource.name || "");
  return apiResourceUrl(`/api/offline-maps/pmtiles/${versionPathSegment(state.offlineMapTileVersion)}/${name}.pmtiles`);
}

/**
 * 功能：确保 MapLibre 已注册 PMTiles protocol。
 * 输入：无。
 * 输出：注册成功返回 true，否则返回 false。
 */
function ensurePmtilesProtocol() {
  if (pmtilesProtocol) {
    return true;
  }
  if (!window.pmtiles || !window.maplibregl) {
    return false;
  }
  pmtilesProtocol = new window.pmtiles.Protocol();
  window.maplibregl.addProtocol("pmtiles", pmtilesProtocol.tile);
  return true;
}

/**
 * 功能：为离线矢量瓦片构造轻量地形底图样式。
 * 输入：resource 为活动离线矢量资源。
 * 输出：MapLibre style object。
 */
function buildOfflineVectorStyle(resource) {
  const source = "offline-vector";
  return {
    version: 8,
    sources: {
      [source]: {
        type: "vector",
        ...(resource.storage_layout === "pmtiles_v1"
          ? { url: `pmtiles://${offlinePmtilesUrl(resource)}` }
          : { tiles: [offlineVectorTileUrl(resource)] }),
        minzoom: Number(resource.min_zoom ?? 0),
        maxzoom: offlineResourceSourceMaxZoom(resource),
      },
    },
    layers: [
      { id: "offline-background", type: "background", paint: { "background-color": "#e7eee8" } },
      { id: "offline-landcover", type: "fill", source, "source-layer": "landcover", paint: { "fill-color": "#cfe0bd", "fill-opacity": 0.34 } },
      { id: "offline-landuse", type: "fill", source, "source-layer": "landuse", paint: { "fill-color": "#d6e2c6", "fill-opacity": 0.24 } },
      { id: "offline-park", type: "fill", source, "source-layer": "park", paint: { "fill-color": "#b8d7a3", "fill-opacity": 0.34 } },
      { id: "offline-water", type: "fill", source, "source-layer": "water", paint: { "fill-color": "#9fc2d0", "fill-opacity": 0.92 } },
      { id: "offline-waterway", type: "line", source, "source-layer": "waterway", minzoom: 4, paint: { "line-color": "#85b3c5", "line-width": ["interpolate", ["linear"], ["zoom"], 5, 0.35, 10, 0.85, 14, 1.4] } },
      { id: "offline-boundary", type: "line", source, "source-layer": "boundary", minzoom: 3, paint: { "line-color": "rgba(54, 68, 78, 0.45)", "line-width": ["interpolate", ["linear"], ["zoom"], 3, 0.5, 8, 1.1, 12, 1.6] } },
      {
        id: "offline-roads",
        type: "line",
        source,
        "source-layer": "transportation",
        minzoom: 5,
        filter: ["match", ["get", "class"], ["motorway", "trunk", "primary", "secondary", "tertiary"], true, false],
        paint: { "line-color": "rgba(158, 122, 76, 0.34)", "line-width": ["interpolate", ["linear"], ["zoom"], 5, 0.25, 10, 0.85, 14, 1.8] },
      },
      { id: "offline-aeroway", type: "line", source, "source-layer": "aeroway", minzoom: 7, paint: { "line-color": "#24384a", "line-width": ["interpolate", ["linear"], ["zoom"], 7, 1.2, 12, 3.2, 14, 5] } },
    ],
  };
}

/**
 * 功能：获取当前 MapLibre 应使用的样式。
 * 输入：无。
 * 输出：在线矢量样式 URL 或离线矢量 style object。
 */
function currentVectorMapStyle() {
  const resource = activeOfflineResource();
  if (state.baseMap === "offline" && resource?.kind === "vector") {
    return buildOfflineVectorStyle(resource);
  }
  return VECTOR_MAP_STYLE;
}

/**
 * 功能：生成当前矢量样式标识，用于判断是否需要重新 setStyle。
 * 输入：无。
 * 输出：稳定样式标识字符串。
 */
function currentVectorStyleKey() {
  const resource = activeOfflineResource();
  if (state.baseMap === "offline" && resource?.kind === "vector") {
    return `offline:${resource.name}:${resource.format}:${offlineResourceSourceMaxZoom(resource)}:${state.offlineMapTileVersion}`;
  }
  return state.baseMap;
}

/**
 * 功能：确保 `ensureTerrainDemSource` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function ensureTerrainDemSource() {
  if (terrainDemSource || !window.mlcontour || !window.maplibregl) {
    return terrainDemSource;
  }
  terrainDemSource = new window.mlcontour.DemSource({
    url: VECTOR_TERRAIN_DEM_TILE_URL,
    encoding: "terrarium",
    maxzoom: 13,
    worker: true,
    cacheSize: 96,
    timeoutMs: ASYNC_CACHED_TILE_REQUEST_TIMEOUT_MS,
  });
  terrainDemSource.setupMaplibre(window.maplibregl);
  return terrainDemSource;
}

/**
 * 功能：安装 `installVectorTerrainLayers` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function installVectorTerrainLayers() {
  if (!vectorMap || state.baseMap === "offline" || vectorMap.getSource("terrain-dem")) {
    return;
  }
  const styleLayers = vectorMap.getStyle().layers || [];
  const beforeRoadLayer = styleLayers.find((layer) => layer.id.startsWith("road_"))?.id;
  const beforeRoadLabelLayer = styleLayers.find((layer) => layer.id.startsWith("highway-name-"))?.id;
  vectorMap.addSource("terrain-dem", {
    type: "raster-dem",
    encoding: "terrarium",
    tiles: [VECTOR_TERRAIN_DEM_TILE_URL],
    maxzoom: 13,
    tileSize: 256,
  });
  vectorMap.addLayer({
    id: "terrain-hillshade",
    type: "hillshade",
    source: "terrain-dem",
    paint: {
      "hillshade-accent-color": "#8fa680",
      "hillshade-exaggeration": 0.34,
      "hillshade-highlight-color": "rgba(255, 255, 238, 0.78)",
      "hillshade-shadow-color": "rgba(64, 54, 45, 0.44)",
    },
  }, beforeRoadLayer);

  if (!terrainDemSource) {
    return;
  }
  vectorMap.addSource("terrain-contours", {
    type: "vector",
    tiles: [
      terrainDemSource.contourProtocolUrl({
        thresholds: {
          6: [500, 2000],
          8: [250, 1000],
          10: [100, 500],
          12: [50, 250],
          14: [20, 100],
        },
        contourLayer: "contours",
        elevationKey: "ele",
        levelKey: "level",
        extent: 4096,
        buffer: 1,
      }),
    ],
    maxzoom: 15,
  });
  vectorMap.addLayer({
    id: "terrain-contour-lines",
    type: "line",
    source: "terrain-contours",
    "source-layer": "contours",
    paint: {
      "line-color": [
        "match",
        ["get", "level"],
        1,
        "rgba(116, 86, 52, 0.52)",
        "rgba(116, 86, 52, 0.28)",
      ],
      "line-opacity": ["interpolate", ["linear"], ["zoom"], 5, 0.28, 8, 0.42, 12, 0.68],
      "line-width": ["match", ["get", "level"], 1, 0.9, 0.42],
    },
  }, beforeRoadLayer);
  vectorMap.addLayer({
    id: "terrain-contour-labels",
    type: "symbol",
    source: "terrain-contours",
    "source-layer": "contours",
    filter: [">", ["get", "level"], 0],
    layout: {
      "symbol-placement": "line",
      "text-field": ["concat", ["number-format", ["get", "ele"], {}], " m"],
      "text-font": ["Noto Sans Regular"],
      "text-size": ["interpolate", ["linear"], ["zoom"], 9, 9, 13, 10],
      "text-padding": 3,
    },
    paint: {
      "text-color": "rgba(90, 67, 44, 0.78)",
      "text-halo-color": "rgba(250, 248, 235, 0.88)",
      "text-halo-width": 1.2,
    },
  }, beforeRoadLabelLayer);
}

/**
 * 功能：设置 `setVectorPaint` 对应的业务逻辑。
 * 输入：layerId、property、value。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function setVectorPaint(layerId, property, value) {
  if (vectorMap?.getLayer(layerId)) {
    vectorMap.setPaintProperty(layerId, property, value);
  }
}

/**
 * 功能：设置 MapLibre 图层布局属性。
 * 输入：layerId 为图层 ID，property 为布局属性名，value 为属性值。
 * 输出：无返回值；图层不存在时不做处理。
 */
function setVectorLayout(layerId, property, value) {
  if (vectorMap?.getLayer(layerId)) {
    vectorMap.setLayoutProperty(layerId, property, value);
  }
}

/**
 * 功能：设置 `setVectorVisibility` 对应的业务逻辑。
 * 输入：layerId、visible。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function setVectorVisibility(layerId, visible) {
  if (vectorMap?.getLayer(layerId)) {
    vectorMap.setLayoutProperty(layerId, "visibility", visible ? "visible" : "none");
  }
}

/**
 * 功能：判断 MapLibre 样式图层是否包含文字标注。
 * 输入：layer 为 MapLibre 样式图层对象。
 * 输出：包含 text-field 的 symbol 图层返回 true。
 */
function isVectorTextLayer(layer) {
  return layer?.type === "symbol" && Boolean(layer.layout?.["text-field"]);
}

/**
 * 功能：判断 Topo Vector 中是否应完全隐藏某类底图文字。
 * 输入：layerId 为 MapLibre 图层 ID。
 * 输出：道路名、POI、交通和盾牌等干扰航空叠加层的标签返回 true。
 */
function shouldHideTopoVectorLabel(layerId) {
  const id = String(layerId || "").toLowerCase();
  return [
    "poi",
    "transit",
    "road",
    "highway",
    "shield",
    "building",
    "housenumber",
    "path",
    "airport",
  ].some((token) => id.includes(token));
}

/**
 * 功能：判断 Topo Vector 中是否属于主要地名标签。
 * 输入：layerId 为 MapLibre 图层 ID。
 * 输出：国家、省州、城市等主要地名返回 true。
 */
function isMajorTopoVectorLabel(layerId) {
  const id = String(layerId || "").toLowerCase();
  return id.includes("country")
    || id.includes("state")
    || id.includes("city")
    || id.includes("capital")
    || id.includes("place");
}

/**
 * 功能：降低 Topo Vector 底图文字密度，避免高缩放时遮挡航路和航点。
 * 输入：无。
 * 输出：无返回值；直接修改当前 MapLibre 样式。
 */
function applyTopoVectorStyle() {
  if (!vectorMap || state.baseMap !== "vector") {
    return;
  }
  const layers = vectorMap.getStyle()?.layers || [];
  layers.forEach((layer) => {
    if (!isVectorTextLayer(layer)) {
      return;
    }
    if (layer.id === "terrain-contour-labels") {
      setVectorPaint(layer.id, "text-opacity", ["interpolate", ["linear"], ["zoom"], 7, 0.18, 10, 0.28, 13, 0.34]);
      return;
    }
    if (shouldHideTopoVectorLabel(layer.id)) {
      setVectorVisibility(layer.id, false);
      return;
    }
    const major = isMajorTopoVectorLabel(layer.id);
    setVectorPaint(
      layer.id,
      "text-opacity",
      major
        ? ["interpolate", ["linear"], ["zoom"], 4, 0.56, 7, 0.36, 10, 0.18, 12, 0.08]
        : ["interpolate", ["linear"], ["zoom"], 4, 0.34, 7, 0.16, 9, 0.04, 10, 0],
    );
    setVectorPaint(layer.id, "text-color", major ? "rgba(24, 31, 40, 0.72)" : "rgba(48, 58, 68, 0.42)");
    setVectorPaint(layer.id, "text-halo-color", "rgba(246, 242, 234, 0.68)");
    setVectorPaint(layer.id, "text-halo-width", major ? 0.9 : 0.45);
    setVectorLayout(
      layer.id,
      "text-size",
      major
        ? ["interpolate", ["linear"], ["zoom"], 4, 10, 8, 12, 12, 12]
        : ["interpolate", ["linear"], ["zoom"], 4, 8, 8, 9, 10, 9],
    );
  });
}

/**
 * 功能：应用 `applyAeroVectorStyle` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function applyAeroVectorStyle() {
  if (!vectorMap || state.baseMap !== "aero") {
    return;
  }

  setVectorPaint("background", "background-color", "#e8eee8");
  setVectorPaint("natural_earth", "raster-opacity", 0.34);
  setVectorPaint("water", "fill-color", "#a9c6d3");
  setVectorPaint("water", "fill-opacity", 0.9);
  setVectorPaint("landcover_wood", "fill-color", "rgba(146, 178, 132, 0.34)");
  setVectorPaint("landcover_grass", "fill-color", "rgba(180, 199, 143, 0.22)");
  setVectorPaint("landcover_wetland", "fill-color", "rgba(137, 176, 166, 0.2)");
  setVectorPaint("park", "fill-color", "rgba(139, 183, 124, 0.24)");
  setVectorPaint("boundary_2", "line-color", "rgba(62, 75, 86, 0.5)");
  setVectorPaint("boundary_2", "line-width", ["interpolate", ["linear"], ["zoom"], 3, 0.8, 7, 1.2, 11, 1.7]);
  setVectorPaint("boundary_3", "line-color", "rgba(82, 97, 109, 0.32)");
  setVectorPaint("aeroway_runway", "line-color", "#263746");
  setVectorPaint("aeroway_runway", "line-width", ["interpolate", ["linear"], ["zoom"], 7, 1.4, 12, 4.5]);
  setVectorPaint("aeroway_taxiway", "line-color", "rgba(38, 55, 70, 0.42)");

  [
    "building",
    "building-3d",
    "poi_r20",
    "poi_r7",
    "poi_r1",
    "poi_transit",
    "road_one_way_arrow",
    "road_one_way_arrow_opposite",
    "road_shield_us",
    "highway-shield-non-us",
    "highway-shield-us-interstate",
    "highway-name-path",
    "highway-name-minor",
    "road_area_pattern",
    "road_path_pedestrian",
    "bridge_path_pedestrian",
    "tunnel_path_pedestrian",
  ].forEach((layerId) => setVectorVisibility(layerId, false));

  [
    "road_minor",
    "road_service_track",
    "road_link",
    "road_secondary_tertiary",
    "road_trunk_primary",
    "road_motorway",
    "bridge_street",
    "bridge_secondary_tertiary",
    "bridge_trunk_primary",
    "bridge_motorway",
    "tunnel_minor",
    "tunnel_secondary_tertiary",
    "tunnel_trunk_primary",
    "tunnel_motorway",
  ].forEach((layerId) => {
    setVectorPaint(layerId, "line-color", "rgba(178, 139, 82, 0.54)");
    setVectorPaint(layerId, "line-opacity", ["interpolate", ["linear"], ["zoom"], 4, 0.05, 8, 0.18, 12, 0.34]);
  });

  ["label_country_1", "label_country_2", "label_country_3", "label_state", "label_city", "label_city_capital", "airport"].forEach((layerId) => {
    setVectorPaint(layerId, "text-color", "#172536");
    setVectorPaint(layerId, "text-halo-color", "rgba(242, 246, 238, 0.92)");
    setVectorPaint(layerId, "text-halo-width", 1.2);
  });
}

/**
 * 功能：执行 `markVectorStyleReady` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function markVectorStyleReady() {
  vectorMapStyleReady = true;
  vectorMapErrorShown = false;
  installVectorTerrainLayers();
  applyTopoVectorStyle();
  applyAeroVectorStyle();
  vectorMap.resize();
  syncVectorMap();
}

/**
 * 功能：清理 MapLibre 容器上的临时位移。
 * 输入：无。
 * 输出：无返回值；用于从旧的拖拽镜像逻辑安全过渡，避免残留 transform 造成错位。
 */
function clearVectorMapTransform() {
  if (!vectorMapContainer) {
    return;
  }
  vectorMapContainer.style.transform = "";
  vectorMapContainer.style.transformOrigin = "";
}

/**
 * 功能：按 Leaflet 投影坐标计算本次拖动的屏幕位移。
 * 输入：无。
 * 输出：包含 dx/dy 像素偏移的对象；未开始拖动时返回 0/0。
 */
function vectorMapPanOffsetFromStart() {
  if (!vectorMapPanStartPoint) {
    return { dx: 0, dy: 0 };
  }
  return vectorMapOffsetFromStart(vectorMapPanStartPoint, vectorMapPanStartZoom);
}

/**
 * 功能：按指定起点和起始缩放计算 Leaflet 视口的屏幕位移。
 * 输入：startPoint/startZoom 为开始镜像时的投影位置和缩放。
 * 输出：包含 dx/dy 的像素偏移，已处理日期变更线世界宽度。
 */
function vectorMapOffsetFromStart(startPoint, startZoom) {
  if (!startPoint) {
    return { dx: 0, dy: 0 };
  }
  const currentPoint = map.project(map.getCenter(), startZoom);
  let dx = startPoint.x - currentPoint.x;
  const dy = startPoint.y - currentPoint.y;
  const worldBounds = map.getPixelWorldBounds(startZoom);
  const worldWidth = worldBounds?.getSize?.().x || 0;
  if (worldWidth > 0 && Math.abs(dx) > worldWidth / 2) {
    dx += dx > 0 ? -worldWidth : worldWidth;
  }
  return { dx, dy };
}

/**
 * 功能：根据地图视口尺寸计算矢量底图拖动缓冲。
 * 输入：无。
 * 输出：应设置在 MapLibre 容器四周的缓冲像素。
 */
function desiredVectorMapPanBuffer() {
  const rect = map.getContainer().getBoundingClientRect();
  const viewportSize = Math.max(rect.width || 0, rect.height || 0);
  return Math.round(Math.min(
    VECTOR_PAN_BUFFER_MAX_PX,
    Math.max(VECTOR_PAN_BUFFER_MIN_PX, viewportSize),
  ));
}

/**
 * 功能：更新 MapLibre 容器四周隐藏缓冲尺寸。
 * 输入：无。
 * 输出：缓冲尺寸发生变化时返回 true，否则返回 false。
 */
function updateVectorMapPanBuffer() {
  if (!vectorMapContainer) {
    return false;
  }
  const nextBuffer = desiredVectorMapPanBuffer();
  if (Math.abs(nextBuffer - vectorMapPanBufferPx) < 1) {
    return false;
  }
  vectorMapPanBufferPx = nextBuffer;
  vectorMapContainer.style.setProperty("--vector-pan-buffer", `${nextBuffer}px`);
  vectorMapLastSizeKey = "";
  return true;
}

/**
 * 功能：把离线/矢量底图按 Leaflet 拖动增量做同帧 CSS 平移。
 * 输入：无。
 * 输出：无返回值；拖动时底图和 Leaflet 航路层使用同一位移，避免动画半拍不同步。
 */
function applyVectorMapPanMirror() {
  vectorMapPanMirrorFrame = 0;
  if (!vectorMapPanMirrorActive || !vectorMapContainer || !isVectorBaseMap()) {
    return;
  }
  const { dx, dy } = vectorMapPanOffsetFromStart();
  if (Math.abs(dx) < 0.1 && Math.abs(dy) < 0.1) {
    clearVectorMapTransform();
    return;
  }
  vectorMapContainer.style.transform = `translate3d(${dx}px, ${dy}px, 0)`;
  vectorMapContainer.style.transformOrigin = "0 0";
}

/**
 * 功能：把拖动镜像安排到下一帧。
 * 输入：无。
 * 输出：无返回值；合并高频 drag/move 事件。
 */
function scheduleVectorMapPanMirror() {
  if (!vectorMapPanMirrorActive || vectorMapPanMirrorFrame) {
    return;
  }
  vectorMapPanMirrorFrame = window.requestAnimationFrame(applyVectorMapPanMirror);
}

/**
 * 功能：按 Leaflet 缩放动画镜像 MapLibre 容器。
 * 输入：无。
 * 输出：无返回值；缩放期间只做 CSS transform，结束后再同步真实 MapLibre 相机。
 */
function applyVectorMapZoomMirror() {
  vectorMapZoomMirrorFrame = 0;
  if (!vectorMapZoomMirrorActive || !vectorMapContainer || !isVectorBaseMap()) {
    return;
  }
  const zoom = map.getZoom();
  const scale = map.getZoomScale(zoom, vectorMapZoomStartZoom || zoom);
  const { dx, dy } = vectorMapOffsetFromStart(vectorMapZoomStartPoint, vectorMapZoomStartZoom || zoom);
  const size = map.getSize();
  const originX = vectorMapPanBufferPx + size.x / 2;
  const originY = vectorMapPanBufferPx + size.y / 2;
  vectorMapContainer.style.transformOrigin = `${originX}px ${originY}px`;
  vectorMapContainer.style.transform = `translate3d(${dx}px, ${dy}px, 0) scale(${scale})`;
}

/**
 * 功能：把缩放镜像安排到下一帧。
 * 输入：无。
 * 输出：无返回值；合并高频 zoom/move 事件。
 */
function scheduleVectorMapZoomMirror() {
  if (!vectorMapZoomMirrorActive || vectorMapZoomMirrorFrame) {
    return;
  }
  vectorMapZoomMirrorFrame = window.requestAnimationFrame(applyVectorMapZoomMirror);
}

/**
 * 功能：开始矢量底图缩放镜像模式。
 * 输入：无。
 * 输出：无返回值；避免缩放期间反复 jumpTo 造成 MapLibre 与航路层半拍不同步。
 */
function beginVectorMapZoomMirror() {
  if (!vectorMap || !vectorMapContainer || !isVectorBaseMap()) {
    return;
  }
  updateVectorMapPanBuffer();
  if (vectorMapSyncFrame) {
    window.cancelAnimationFrame(vectorMapSyncFrame);
    vectorMapSyncFrame = 0;
  }
  vectorMapZoomMirrorActive = true;
  vectorMapZoomStartZoom = map.getZoom();
  vectorMapZoomStartPoint = map.project(map.getCenter(), vectorMapZoomStartZoom);
  vectorMapContainer.classList.add("is-viewport-mirroring");
  scheduleVectorMapZoomMirror();
}

/**
 * 功能：结束矢量底图缩放镜像并同步真实相机。
 * 输入：无。
 * 输出：无返回值；缩放结束后恢复无 transform 的精确 MapLibre 状态。
 */
function finishVectorMapZoomMirror() {
  if (vectorMapZoomMirrorFrame) {
    window.cancelAnimationFrame(vectorMapZoomMirrorFrame);
    vectorMapZoomMirrorFrame = 0;
  }
  const wasMirroring = vectorMapZoomMirrorActive;
  vectorMapZoomMirrorActive = false;
  vectorMapZoomStartPoint = null;
  vectorMapContainer?.classList.remove("is-viewport-mirroring");
  if (wasMirroring) {
    syncVectorMap();
  } else {
    clearVectorMapTransform();
  }
}

/**
 * 功能：开始拖动镜像模式。
 * 输入：无。
 * 输出：无返回值；记录拖动起点的 Leaflet mapPane 位移。
 */
function beginVectorMapPanMirror() {
  if (!vectorMap || !vectorMapContainer || !isVectorBaseMap()) {
    return;
  }
  updateVectorMapPanBuffer();
  if (vectorMapSyncFrame) {
    window.cancelAnimationFrame(vectorMapSyncFrame);
    vectorMapSyncFrame = 0;
  }
  vectorMapPanMirrorActive = true;
  vectorMapPanStartZoom = map.getZoom();
  vectorMapPanStartPoint = map.project(map.getCenter(), vectorMapPanStartZoom);
  vectorMapContainer.classList.add("is-pan-mirroring");
  scheduleVectorMapPanMirror();
}

/**
 * 功能：结束拖动镜像模式并同步 MapLibre 真实相机。
 * 输入：无。
 * 输出：无返回值；拖动结束后恢复无 transform 的精确相机状态。
 */
function finishVectorMapPanMirror() {
  if (vectorMapPanMirrorFrame) {
    window.cancelAnimationFrame(vectorMapPanMirrorFrame);
    vectorMapPanMirrorFrame = 0;
  }
  const wasMirroring = vectorMapPanMirrorActive;
  vectorMapPanMirrorActive = false;
  vectorMapPanStartPoint = null;
  vectorMapContainer?.classList.remove("is-pan-mirroring");
  if (wasMirroring) {
    syncVectorMap();
  } else {
    clearVectorMapTransform();
  }
}

/**
 * 功能：读取 MapLibre 容器当前尺寸标识。
 * 输入：无。
 * 输出：`宽x高` 字符串；容器不存在时返回空字符串。
 */
function vectorMapSizeKey() {
  if (!vectorMapContainer) {
    return "";
  }
  const rect = vectorMapContainer.getBoundingClientRect();
  return `${Math.round(rect.width)}x${Math.round(rect.height)}`;
}

/**
 * 功能：在地图容器尺寸变化后刷新 MapLibre 画布并同步相机。
 * 输入：无。
 * 输出：无返回值；避免侧栏伸缩或窗口变化后底图画布尺寸滞后。
 */
function resizeAndSyncVectorMap() {
  vectorMapResizeFrame = 0;
  if (!vectorMap || !isVectorBaseMap()) {
    return;
  }
  updateVectorMapPanBuffer();
  const sizeKey = vectorMapSizeKey();
  if (sizeKey && sizeKey !== vectorMapLastSizeKey) {
    vectorMapLastSizeKey = sizeKey;
    vectorMap.resize();
    vectorMapLastSyncKey = "";
  }
  if (vectorMapPanMirrorActive) {
    scheduleVectorMapPanMirror();
    return;
  }
  if (vectorMapZoomMirrorActive) {
    scheduleVectorMapZoomMirror();
    return;
  }
  syncVectorMap();
}

/**
 * 功能：把 MapLibre resize/sync 合并到下一帧执行。
 * 输入：无。
 * 输出：无返回值；防止 CSS 过渡和 ResizeObserver 连续触发时重复重绘。
 */
function shouldDeferVectorMapResizeSync() {
  return state.mobilePanelDrag || document.body.dataset.mobilePanelDragging === "true";
}

function scheduleVectorMapResizeSync(options = {}) {
  if (!options.force && shouldDeferVectorMapResizeSync()) {
    state.mobilePanelDeferredVectorResize = true;
    return;
  }
  if (vectorMapResizeFrame) {
    return;
  }
  vectorMapResizeFrame = window.requestAnimationFrame(resizeAndSyncVectorMap);
}

function flushDeferredVectorMapResizeSync() {
  if (!state.mobilePanelDeferredVectorResize) {
    return;
  }
  state.mobilePanelDeferredVectorResize = false;
  scheduleVectorMapResizeSync({ force: true });
}

/**
 * 功能：安装地图容器尺寸监听器。
 * 输入：无。
 * 输出：无返回值；浏览器不支持 ResizeObserver 时退回既有 resize 事件。
 */
function ensureVectorMapResizeObserver() {
  if (vectorMapResizeObserver || !window.ResizeObserver || !vectorMapContainer) {
    return;
  }
  vectorMapResizeObserver = new ResizeObserver(scheduleVectorMapResizeSync);
  vectorMapResizeObserver.observe(vectorMapContainer);
}

/**
 * 功能：按 Leaflet 当前相机实时同步 MapLibre 底图。
 * 输入：无。
 * 输出：无返回值；避免离线矢量底图和 Leaflet 叠加层在拖拽时使用两套平移状态。
 */
function applyVectorMapScheduledSync() {
  vectorMapSyncFrame = 0;
  applyVectorMapSync();
}

/**
 * 功能：把 MapLibre 相机同步安排到下一帧，避免同一帧内重复 jumpTo。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function scheduleVectorMapSync() {
  if (!vectorMap || !isVectorBaseMap() || vectorMapSyncFrame) {
    return;
  }
  vectorMapSyncFrame = window.requestAnimationFrame(applyVectorMapScheduledSync);
}

/**
 * 功能：应用 `applyVectorMapSync` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function applyVectorMapSync() {
  if (!vectorMap || !isVectorBaseMap()) {
    return;
  }
  const center = map.getCenter();
  const mapLibreZoom = leafletZoomToMapLibreZoom(map.getZoom());
  const syncKey = [
    center.lng.toFixed(7),
    center.lat.toFixed(7),
    mapLibreZoom.toFixed(4),
    state.baseMap,
    currentVectorStyleKey(),
  ].join(":");
  if (syncKey === vectorMapLastSyncKey) {
    clearVectorMapTransform();
    return;
  }
  vectorMapLastSyncKey = syncKey;
  vectorMap.jumpTo({
    center: [center.lng, center.lat],
    zoom: mapLibreZoom,
    bearing: 0,
    pitch: 0,
  });
  clearVectorMapTransform();
}

/**
 * 功能：同步 `syncVectorMap` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function syncVectorMap() {
  if (vectorMapPanMirrorActive) {
    scheduleVectorMapPanMirror();
    return;
  }
  if (vectorMapZoomMirrorActive) {
    scheduleVectorMapZoomMirror();
    return;
  }
  if (vectorMapSyncFrame) {
    window.cancelAnimationFrame(vectorMapSyncFrame);
    vectorMapSyncFrame = 0;
  }
  vectorMapLastSyncKey = "";
  applyVectorMapSync();
}

/**
 * 功能：显示 `showVectorMap` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function showVectorMap() {
  const container = ensureVectorMapContainer();
  container.classList.add("is-visible");
  ensureVectorMapResizeObserver();
  updateVectorMapPanBuffer();
  if (!window.maplibregl) {
    container.classList.add("has-error");
    container.textContent = t("map.vectorRuntimeError");
    setStatus(t("map.vectorRuntimeError"), true);
    return;
  }
  if (!window.mlcontour) {
    setStatus(t("map.contourRuntimeError"), true);
  }
  if (state.baseMap === "offline" && activeOfflineResource()?.storage_layout === "pmtiles_v1" && !ensurePmtilesProtocol()) {
    container.classList.add("has-error");
    container.textContent = t("map.pmtilesRuntimeError");
    setStatus(t("map.pmtilesRuntimeError"), true);
    return;
  }
  ensureTerrainDemSource();
  container.classList.remove("has-error");
  if (!vectorMap) {
    container.textContent = "";
    const center = map.getCenter();
    vectorMapStyleReady = false;
    vectorMapStyleMode = currentVectorStyleKey();
    vectorMap = new window.maplibregl.Map({
      container,
      style: currentVectorMapStyle(),
      center: [center.lng, center.lat],
      zoom: leafletZoomToMapLibreZoom(map.getZoom()),
      attributionControl: false,
      antialias: false,
      preserveDrawingBuffer: false,
      fadeDuration: 0,
      interactive: false,
      pitchWithRotate: false,
      refreshExpiredTiles: false,
      cancelPendingTileRequestsWhileZooming: true,
      maxTileCacheSize: 512,
      trackResize: false,
    });
    vectorMap.on("style.load", markVectorStyleReady);
    vectorMap.on("load", markVectorStyleReady);
    vectorMap.on("error", (event) => {
      console.warn("Vector map failed", event?.error || event);
      if (!vectorMapErrorShown && !vectorMapStyleReady) {
        vectorMapErrorShown = true;
        window.setTimeout(() => {
          if (!vectorMapStyleReady) {
            setStatus(t("map.vectorBaseError"), true);
          }
        }, 2200);
      }
    });
  } else {
    const nextStyleKey = currentVectorStyleKey();
    if (vectorMapStyleMode !== nextStyleKey) {
      vectorMapStyleReady = false;
      vectorMapStyleMode = nextStyleKey;
      vectorMap.setStyle(currentVectorMapStyle());
    } else {
      installVectorTerrainLayers();
      applyTopoVectorStyle();
      applyAeroVectorStyle();
      scheduleVectorMapResizeSync();
    }
  }
}

/**
 * 功能：隐藏 `hideVectorMap` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function hideVectorMap() {
  vectorMapContainer?.classList.remove("is-visible");
}

/**
 * 功能：显示指定栅格底图并移除其它栅格底图。
 * 输入：type 为 `terrain` 或 `offline`。
 * 输出：无返回值；更新 Leaflet 底图图层。
 */
function setRasterBaseLayer(type) {
  Object.entries(baseLayers).forEach(([layerType, layer]) => {
    const shouldShow = layerType === type;
    const isShown = map.hasLayer(layer);
    if (shouldShow && !isShown) {
      if (layerType === "offline") {
        configureOfflineRasterLayer();
      }
      layer.addTo(map);
    } else if (!shouldShow && isShown) {
      map.removeLayer(layer);
    }
  });
  if (type !== "terrain") {
    clearOnlineBaseLayerSwap({ removePrevious: true });
  }
}

/**
 * 功能：更新离线地图管理按钮的显隐状态。
 * 输入：无。
 * 输出：无返回值；仅修改地图控件样式。
 */
function updateOfflineMapControlVisibility() {
  offlineMapControlContainer?.classList.toggle("hidden", state.baseMap !== "offline");
}

/**
 * 功能：刷新离线底图瓦片 URL，避免切换资源后浏览器复用旧图块。
 * 输入：无。
 * 输出：无返回值；更新离线图层 URL 并重绘。
 */
function refreshOfflineBaseLayer() {
  state.offlineMapTileVersion = Date.now();
  configureOfflineRasterLayer();
  baseLayers.offline.setUrl(apiResourceUrl(`/api/offline-maps/tile/${versionPathSegment(state.offlineMapTileVersion)}/{z}/{x}/{y}.png`));
  if (map.hasLayer(baseLayers.offline)) {
    baseLayers.offline.redraw();
  }
  if (state.baseMap === "offline" && activeOfflineResource()?.kind === "vector" && vectorMap) {
    vectorMapStyleMode = "";
    showVectorMap();
  }
}

/**
 * 功能：刷新在线底图瓦片 URL，应用当前在线 provider 和缓存版本。
 * 输入：bumpVersion 表示是否强制更新 cache-busting 版本。
 * 输出：无返回值；仅影响在线底图层。
 */
function refreshOnlineBaseLayer({ bumpVersion = false } = {}) {
  if (bumpVersion) {
    state.mapCacheTileVersion = Date.now();
  }
  const nextSignature = onlineMapTileLayerSignature();
  const shouldRebuildLayer = baseLayers.terrain?._plannerLayerSignature !== nextSignature || bumpVersion;
  const wasShown = Boolean(baseLayers.terrain && map.hasLayer(baseLayers.terrain));
  if (shouldRebuildLayer) {
    const previousLayer = baseLayers.terrain;
    const nextLayer = createOnlineBaseLayer();
    baseLayers.terrain = nextLayer;
    if (wasShown) {
      nextLayer.addTo(map);
      warmSwapOnlineBaseLayer(nextLayer, previousLayer);
    }
    return;
  }
  Object.assign(baseLayers.terrain.options, onlineMapTileLayerOptions());
  baseLayers.terrain.setUrl(onlineMapTileUrl());
  if (wasShown) {
    baseLayers.terrain.redraw();
  }
}

function updateMapTileZoomOffsetControl() {
  const label = mapTileZoomOffsetLabel();
  if (elements.mapTileZoomOffsetInput) {
    elements.mapTileZoomOffsetInput.value = String(state.mapTileZoomOffset);
    elements.mapTileZoomOffsetInput.style.setProperty("--zoom-offset-progress", mapTileZoomOffsetProgress());
  }
  if (elements.mapTileZoomOffsetSliderFrame) {
    elements.mapTileZoomOffsetSliderFrame.style.setProperty("--zoom-offset-progress", mapTileZoomOffsetProgress());
    elements.mapTileZoomOffsetSliderFrame.dataset.offsetValue = String(state.mapTileZoomOffset);
  }
  elements.mapTileZoomOffsetScaleLabels?.forEach((item) => {
    item.classList.toggle("active", Number.parseInt(item.dataset.zoomOffsetValue || "", 10) === state.mapTileZoomOffset);
  });
  if (elements.mapTileZoomOffsetValue) {
    elements.mapTileZoomOffsetValue.textContent = t("map.zoomOffsetValue", {
      value: state.mapTileZoomOffset === 0 ? `${label} (${t("map.zoomOffsetDefault")})` : label,
    });
  }
}

function applyMapTileZoomOffset(value, { persist = true, announce = true } = {}) {
  const normalized = normalizeMapTileZoomOffset(value);
  if (normalized === state.mapTileZoomOffset) {
    updateMapTileZoomOffsetControl();
    return;
  }
  state.mapTileZoomOffset = normalized;
  if (persist) {
    writeLocalStorageValue("navplannerMapTileZoomOffset", String(normalized));
  }
  updateMapTileZoomOffsetControl();
  refreshOnlineBaseLayer({ bumpVersion: true });
  if (announce) {
    setStatus(t("map.zoomOffsetChanged", { value: mapTileZoomOffsetLabel(normalized) }));
  }
}

/**
 * 功能：同步地图类型菜单按钮的选中状态。
 * 输入：无。
 * 输出：无返回值；更新按钮 class 与 aria-pressed。
 */
function updateMapTypeOptionState() {
  document.querySelectorAll(".map-type-option").forEach((button) => {
    const active = button.dataset.mapType === state.baseMap;
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  elements.mapSourceChoiceButtons.forEach((button) => {
    const active = button.dataset.mapSourceChoice === currentMapSourceMode();
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  elements.onlineMapProviderButtons.forEach((button) => {
    const active = button.dataset.onlineMapProvider === state.onlineMapProvider;
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  elements.onlineMapSettingsPanel?.classList.toggle("hidden", currentMapSourceMode() !== "online");
  elements.offlineMapSettingsPanel?.classList.toggle("hidden", currentMapSourceMode() !== "offline");
}

function updateMapTypeOptionLabels() {
  document.querySelectorAll(".map-type-toggle").forEach((button) => {
    button.setAttribute("aria-label", t("map.typeAria"));
    button.title = t("map.typeTitle");
  });
  document.querySelectorAll(".map-type-option").forEach((button) => {
    const config = BASE_MAPS[button.dataset.mapType];
    if (!config) {
      return;
    }
    button.innerHTML = `
      <span>${escapeHtml(t(config.labelKey))}</span>
      <small>${escapeHtml(t(config.titleKey))}</small>
    `;
  });
  elements.mapSourceChoiceButtons.forEach((button) => {
    const isOffline = button.dataset.mapSourceChoice === "offline";
    button.innerHTML = `
      <span>${escapeHtml(t(isOffline ? "map.source.offline" : "map.source.online"))}</span>
      <small>${escapeHtml(t(isOffline ? "map.source.offlineHint" : "map.source.onlineHint"))}</small>
    `;
  });
  elements.onlineMapProviderButtons.forEach((button) => {
    const config = ONLINE_MAP_PROVIDERS[button.dataset.onlineMapProvider];
    if (!config) {
      return;
    }
    button.innerHTML = `
      <span>${escapeHtml(t(config.labelKey))}</span>
      <small>${escapeHtml(t(config.titleKey))}</small>
    `;
  });
}

function updateOfflineMapControlLabel() {
  document.querySelectorAll(".offline-map-toggle").forEach((button) => {
    button.title = t("map.offlineControl");
    button.setAttribute("aria-label", t("map.offlineControl"));
  });
}

/**
 * 功能：兼容无 attributionControl 的地图实例，彻底隐藏底图版权水印时避免调用报错。
 * 输入：text 为版权文本。
 * 输出：无返回值；存在控件时才更新 Leaflet 版权列表。
 */
function addMapAttribution(text) {
  map.attributionControl?.addAttribution?.(text);
}

/**
 * 功能：兼容无 attributionControl 的地图实例，移除底图版权文本。
 * 输入：text 为版权文本。
 * 输出：无返回值；存在控件时才更新 Leaflet 版权列表。
 */
function removeMapAttribution(text) {
  map.attributionControl?.removeAttribution?.(text);
}

/**
 * 功能：当离线地形暂无可用资源时回退到地形图并给出可操作提示。
 * 输入：openManager 表示是否自动打开离线资源管理器。
 * 输出：无返回值；更新底图、控件和状态栏。
 */
function handleOfflineTerrainUnavailable({ openManager = false, preserveSettingsMode = false, messageKey = "offline.unavailable" } = {}) {
  if (state.baseMap === "offline") {
    state.baseMap = "terrain";
    map.getContainer().dataset.baseMap = "terrain";
    if (!preserveSettingsMode) {
      setMapSourceMode("online");
    }
    hideVectorMap();
    removeMapAttribution(VECTOR_ATTRIBUTION);
    removeMapAttribution(OFFLINE_VECTOR_ATTRIBUTION);
    setRasterBaseLayer("terrain");
    updateOfflineMapControlVisibility();
    updateMapTypeOptionState();
    map.invalidateSize({ pan: false });
  }
  setStatus(t(messageKey), true);
  if (openManager) {
    state.offlineMapManagerTab = "manage";
    openOfflineMapManager();
  }
}

/**
 * 功能：设置 `setBaseMap` 对应的业务逻辑。
 * 输入：type。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function setBaseMap(type, { preserveSettingsMode = false, openManagerWhenUnavailable = true } = {}) {
  if (!BASE_MAPS[type]) {
    return false;
  }
  if (state.baseMap === type && type !== "offline") {
    setMapSourceMode(mapSourceModeForBaseMap(type));
    updateMapTypeOptionState();
    return true;
  }
  if (type === "offline" && state.offlineMapStatus && !hasActiveOfflineDisplayResource(state.offlineMapStatus)) {
    const noInstalledOfflineMaps = !hasOfflineResources(state.offlineMapStatus);
    handleOfflineTerrainUnavailable({
      openManager: openManagerWhenUnavailable && noInstalledOfflineMaps,
      preserveSettingsMode,
      messageKey: noInstalledOfflineMaps ? "offline.notInstalledPrompt" : "offline.unavailable",
    });
    return false;
  }
  state.offlineSelectionRequested = type === "offline";
  state.baseMap = type;
  setMapSourceMode(mapSourceModeForBaseMap(type));
  map.getContainer().dataset.baseMap = type;
  if (isVectorBaseMap(type)) {
    setRasterBaseLayer("");
    if (type === "offline") {
      removeMapAttribution(VECTOR_ATTRIBUTION);
      addMapAttribution(OFFLINE_VECTOR_ATTRIBUTION);
    } else {
      removeMapAttribution(OFFLINE_VECTOR_ATTRIBUTION);
      addMapAttribution(VECTOR_ATTRIBUTION);
    }
    showVectorMap();
  } else {
    hideVectorMap();
    removeMapAttribution(VECTOR_ATTRIBUTION);
    removeMapAttribution(OFFLINE_VECTOR_ATTRIBUTION);
    setRasterBaseLayer(type === "offline" ? "offline" : "terrain");
    if (type === "offline" && !state.offlineMapStatus) {
      refreshOfflineMapStatus().catch(setErrorStatus);
    }
  }
  updateOfflineMapControlVisibility();
  updateMapTypeOptionState();
  map.invalidateSize({ pan: false });
  return true;
}

function applyMapSourceChoice(mode) {
  const normalized = normalizeMapSourceMode(mode);
  setMapSourceMode(normalized);
  updateMapTypeOptionState();
  const didSwitch = setBaseMap(
    normalized === "offline" ? "offline" : "terrain",
    { preserveSettingsMode: normalized === "offline" },
  );
  updateMapTypeOptionState();
  if (didSwitch && currentMapSourceMode() === normalized) {
    setStatus(t("map.sourceChanged", {
      mode: t(normalized === "offline" ? "map.source.offline" : "map.source.online"),
    }));
  }
}

function applyOnlineMapProvider(provider) {
  const normalized = normalizeOnlineMapProvider(provider);
  if (state.onlineMapProvider === normalized && currentMapSourceMode() === "online") {
    return;
  }
  state.onlineMapProvider = normalized;
  writeLocalStorageValue("navplannerOnlineMapProvider", normalized);
  refreshOnlineBaseLayer({ bumpVersion: true });
  setBaseMap("terrain");
  updateMapTypeOptionState();
  setStatus(t("map.providerChanged", { provider: t(currentOnlineMapProviderConfig(normalized).labelKey) }));
}

/**
 * 功能：创建 `createMapTypeControl` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function createMapTypeControl() {
  const control = L.control({ position: "bottomright" });
  control.onAdd = () => {
    const container = L.DomUtil.create("div", "leaflet-control map-type-control");
    const toggle = L.DomUtil.create("button", "map-type-toggle", container);
    toggle.type = "button";
    toggle.setAttribute("aria-label", t("map.typeAria"));
    toggle.setAttribute("aria-expanded", "false");
    toggle.title = t("map.typeTitle");
    toggle.innerHTML = `
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4.5 7.2 12 3.8l7.5 3.4-7.5 3.4-7.5-3.4Z" />
        <path d="M4.5 12 12 15.4 19.5 12" />
        <path d="M4.5 16.8 12 20.2l7.5-3.4" />
      </svg>
    `;

    const menu = L.DomUtil.create("div", "map-type-menu", container);
    menu.hidden = true;
    Object.entries(BASE_MAPS).forEach(([type, config]) => {
      const option = L.DomUtil.create("button", "map-type-option", menu);
      option.type = "button";
      option.dataset.mapType = type;
      option.setAttribute("aria-pressed", String(type === state.baseMap));
      option.innerHTML = `
        <span>${escapeHtml(t(config.labelKey))}</span>
        <small>${escapeHtml(t(config.titleKey))}</small>
      `;
      option.classList.toggle("active", type === state.baseMap);
      option.addEventListener("click", () => {
        setBaseMap(type);
        container.classList.remove("is-open");
        menu.hidden = true;
        toggle.setAttribute("aria-expanded", "false");
      });
    });

    const closeMenu = () => {
      container.classList.remove("is-open");
      menu.hidden = true;
      toggle.setAttribute("aria-expanded", "false");
    };

    toggle.addEventListener("click", () => {
      const isOpen = !container.classList.contains("is-open");
      container.classList.toggle("is-open", isOpen);
      menu.hidden = !isOpen;
      toggle.setAttribute("aria-expanded", String(isOpen));
    });
    map.on("click", closeMenu);
    L.DomEvent.disableClickPropagation(container);
    L.DomEvent.disableScrollPropagation(container);
    return container;
  };
  return control;
}

function mapOverlayIconMarkup(icon) {
  switch (icon) {
    case "base":
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M4.2 7.2 12 3.8l7.8 3.4-7.8 3.5-7.8-3.5Z" />
          <path d="M5.3 12.1 12 15l6.7-2.9" />
          <path d="M5.3 16.7 12 19.6l6.7-2.9" />
        </svg>
      `;
    case "route":
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path class="overlay-icon-route" d="M4.5 17.5 C8 8.2 13 15.8 19.5 6.5" />
          <circle cx="4.5" cy="17.5" r="1.8" />
          <circle cx="19.5" cy="6.5" r="1.8" />
        </svg>
      `;
    case "manualRoute":
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path class="overlay-icon-manual" d="M5 16.7 8.9 9.7l4.2 4.7L19 7.4" />
          <circle cx="5" cy="16.7" r="1.5" />
          <circle cx="19" cy="7.4" r="1.5" />
        </svg>
      `;
    case "procedure":
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path class="overlay-icon-sid" d="M4.5 7.3 H12.4" />
          <path class="overlay-icon-star" d="M4.5 12 H18.5" />
          <path class="overlay-icon-approach" d="M4.5 16.7 H14.7" />
        </svg>
      `;
    case "fr24":
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path class="overlay-icon-fr24" d="M4.3 15.8 C8 7.8 12.2 18.2 19.7 7.2" />
          <path class="overlay-icon-fr24-dash" d="M4.3 18.6 H19.7" />
        </svg>
      `;
    case "terminal":
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 4.6 16.4 12 12 19.4 7.6 12 12 4.6Z" />
          <circle cx="12" cy="12" r="2.1" />
        </svg>
      `;
    case "points":
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 4.4 17.8 8.1v7.8L12 19.6l-5.8-3.7V8.1L12 4.4Z" />
          <circle cx="12" cy="12" r="2.4" />
        </svg>
      `;
    default:
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="12" cy="12" r="7" />
        </svg>
      `;
  }
}

function setLayerGroupVisible(layerGroup, visible) {
  if (!layerGroup) {
    return;
  }
  const isShown = map.hasLayer(layerGroup);
  if (visible && !isShown) {
    layerGroup.addTo(map);
  } else if (!visible && isShown) {
    map.removeLayer(layerGroup);
  }
}

function isMapOverlayVisible(key) {
  return state.mapOverlayVisibility[key] !== false;
}

function updateMapOverlayControlState() {
  document.querySelectorAll(".map-overlay-toggle").forEach((button) => {
    const visible = isMapOverlayVisible(button.dataset.mapOverlay);
    button.classList.toggle("is-hidden", !visible);
    button.setAttribute("aria-pressed", String(visible));
  });
}

function updateMapOverlayControlLabels() {
  document.querySelectorAll(".map-overlay-toggle").forEach((button) => {
    const config = MAP_OVERLAY_CONTROLS.find((item) => item.key === button.dataset.mapOverlay);
    if (!config) {
      return;
    }
    const label = t(config.labelKey);
    button.title = label;
    button.setAttribute("aria-label", label);
  });
}

function applyMapOverlayVisibility() {
  map.getContainer().dataset.overlayBaseMap = isMapOverlayVisible("baseMap") ? "visible" : "hidden";
  setLayerGroupVisible(autoRouteLayerGroup, isMapOverlayVisible("route"));
  setLayerGroupVisible(navAirwayLayerGroup, isMapOverlayVisible("route"));
  setLayerGroupVisible(navAirwayLabelLayerGroup, isMapOverlayVisible("route"));
  setLayerGroupVisible(manualRouteLayerGroup, isMapOverlayVisible("manualRoute"));
  Object.values(procedureLayerGroups).forEach((group) => {
    setLayerGroupVisible(group, isMapOverlayVisible("procedures"));
  });
  setLayerGroupVisible(fr24TrackLayerGroup, isMapOverlayVisible("fr24"));
  updateFR24ProfilePanel();
  setLayerGroupVisible(navTerminalLayerGroup, isMapOverlayVisible("terminalWaypoints"));
  setLayerGroupVisible(navTerminalLabelLayerGroup, isMapOverlayVisible("terminalWaypoints"));
  setLayerGroupVisible(navPointLayerGroup, isMapOverlayVisible("otherWaypoints"));
  setLayerGroupVisible(navPointLabelLayerGroup, isMapOverlayVisible("otherWaypoints"));
  setLayerGroupVisible(navLayerGroup, true);
  setLayerGroupVisible(navLabelLayerGroup, true);
  setLayerGroupVisible(markerLayerGroup, true);
  setLayerGroupVisible(labelLayerGroup, true);
  setLayerGroupVisible(selectionHighlightLayerGroup, true);
  updateMapOverlayControlState();
}

function toggleMapOverlay(key) {
  if (!Object.prototype.hasOwnProperty.call(state.mapOverlayVisibility, key)) {
    return;
  }
  state.mapOverlayVisibility[key] = !isMapOverlayVisible(key);
  applyMapOverlayVisibility();
}

function createMapOverlayControl() {
  const control = L.control({ position: "topleft" });
  control.onAdd = () => {
    const container = L.DomUtil.create("div", "leaflet-control map-overlay-control");
    mapOverlayControlContainer = container;
    MAP_OVERLAY_CONTROLS.forEach((config) => {
      const button = L.DomUtil.create("button", `map-overlay-toggle map-overlay-${config.icon}`, container);
      button.type = "button";
      button.dataset.mapOverlay = config.key;
      button.setAttribute("aria-pressed", String(isMapOverlayVisible(config.key)));
      button.innerHTML = mapOverlayIconMarkup(config.icon);
      button.addEventListener("click", () => toggleMapOverlay(config.key));
    });
    updateMapOverlayControlLabels();
    updateMapOverlayControlState();
    L.DomEvent.disableClickPropagation(container);
    L.DomEvent.disableScrollPropagation(container);
    return container;
  };
  return control;
}

function trackHistoryIconMarkup(action) {
  switch (action) {
    case "undo":
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M9.2 7.2 4.8 11.6l4.4 4.4" />
          <path d="M5.4 11.6h8.4c3.1 0 5.4 2 5.4 4.9" />
        </svg>
      `;
    case "redo":
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M14.8 7.2 19.2 11.6l-4.4 4.4" />
          <path d="M18.6 11.6h-8.4c-3.1 0-5.4 2-5.4 4.9" />
        </svg>
      `;
    case "clear":
      return `
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M6.3 7.2h11.4" />
          <path d="M9.2 7.2V5.4h5.6v1.8" />
          <path d="M8 9.7l.7 8.5h6.6l.7-8.5" />
          <path d="M10.7 11.6v4.6" />
          <path d="M13.3 11.6v4.6" />
        </svg>
      `;
    default:
      return "";
  }
}

function updateTrackHistoryControlLabels() {
  document.querySelectorAll("[data-track-history-action]").forEach((button) => {
    const labelKey = button.dataset.trackHistoryLabelKey;
    if (!labelKey) {
      return;
    }
    const label = t(labelKey);
    button.title = label;
    button.setAttribute("aria-label", label);
  });
}

function emptyDrawingSnapshot() {
  return {
    route: null,
    procedures: {
      sid: null,
      star: null,
      approach: null,
    },
    fr24Track: null,
  };
}

function normalizeDrawingSnapshot(snapshot) {
  const empty = emptyDrawingSnapshot();
  if (!snapshot) {
    return empty;
  }
  return {
    route: snapshot.route || null,
    procedures: {
      sid: snapshot.procedures?.sid || null,
      star: snapshot.procedures?.star || null,
      approach: snapshot.procedures?.approach || null,
    },
    fr24Track: snapshot.fr24Track || null,
  };
}

function cloneDrawingSnapshot(snapshot) {
  return cloneJSON(normalizeDrawingSnapshot(snapshot));
}

function cloneRouteDrawingSnapshot() {
  const payload = cloneJSON(state.currentRoutePayload);
  if (!payload || !Array.isArray(payload.points) || payload.points.length < 2) {
    return null;
  }
  return {
    payload,
    airports: cloneJSON(state.currentRouteAirports),
    routeLayerKind: normalizeRouteLayerKind(state.currentRouteLayerKind),
    lastRouteWasGenerated: Boolean(state.lastRouteWasGenerated),
    lastGeneratedRouteDisplay: state.lastGeneratedRouteDisplay || "",
    routeInputValue: elements.routeInput?.value || routeStringFromPayload(payload),
  };
}

function cloneProcedureDrawingSnapshot(type) {
  const selected = state.selectedProcedures[type];
  if (!selected) {
    return null;
  }
  const payload = state.procedureCache.get(procedureCacheKey(type, selected.airport, selected.procedure, selected.transition));
  if (!payload) {
    return null;
  }
  return {
    selected: cloneJSON(selected),
    payload: cloneJSON(payload),
  };
}

function currentDrawingSnapshot() {
  return {
    route: cloneRouteDrawingSnapshot(),
    procedures: {
      sid: cloneProcedureDrawingSnapshot("sid"),
      star: cloneProcedureDrawingSnapshot("star"),
      approach: cloneProcedureDrawingSnapshot("approach"),
    },
    fr24Track: cloneFR24TrackPayload(),
  };
}

function drawingSnapshotHasContent(snapshot) {
  const normalized = normalizeDrawingSnapshot(snapshot);
  return Boolean(
    normalized.route ||
    normalized.procedures.sid ||
    normalized.procedures.star ||
    normalized.procedures.approach ||
    normalized.fr24Track,
  );
}

function drawingSnapshotsEqual(left, right) {
  return JSON.stringify(normalizeDrawingSnapshot(left)) === JSON.stringify(normalizeDrawingSnapshot(right));
}

function trimDrawingHistoryStack(stack) {
  while (stack.length > DRAWING_HISTORY_LIMIT) {
    stack.shift();
  }
}

function pushDrawingUndoState() {
  if (state.restoringDrawingSnapshot) {
    return false;
  }
  const snapshot = currentDrawingSnapshot();
  const lastSnapshot = state.drawingUndoStack.at(-1);
  if (state.drawingUndoStack.length && drawingSnapshotsEqual(snapshot, lastSnapshot)) {
    updateTrackHistoryControlState();
    return false;
  }
  state.drawingUndoStack.push(cloneDrawingSnapshot(snapshot));
  trimDrawingHistoryStack(state.drawingUndoStack);
  state.drawingRedoStack = [];
  updateTrackHistoryControlState();
  return true;
}

function pushDrawingRedoState(snapshot) {
  state.drawingRedoStack.push(cloneDrawingSnapshot(snapshot));
  trimDrawingHistoryStack(state.drawingRedoStack);
}

function clearRouteDrawingState() {
  autoRouteLayerGroup.clearLayers();
  manualRouteLayerGroup.clearLayers();
  markerLayerGroup.clearLayers();
  clearLabels();
  routeLayerGroup = autoRouteLayerGroup;
  state.currentRoutePayload = null;
  state.currentRouteAirports = null;
  state.currentRouteLayerKind = "route";
  state.lastRouteWasGenerated = false;
  state.lastGeneratedRouteDisplay = "";
  state.airportMarkers.clear();
  resetAirportSlotMarkerKeys();
  state.airwaySegmentLayers.clear();
  state.airwayLegChips.clear();
  state.hoveredAirwayKey = null;
  renderLegs([]);
  state.calculateRouteSignature = "";
  state.calculateAltitudeOverrides.clear();
  scheduleCalculateRender();
}

function clearProcedureDrawingState(type) {
  state.procedureRequestVersion[type] += 1;
  procedureLayerGroups[type].clearLayers();
  state.procedureVisualLayers[type] = null;
  state.selectedProcedures[type] = null;
}

function rerenderProcedureListsForLoadedAirports() {
  if (state.departureAirport?.airport_identifier) {
    rerenderProcedureLists("departure", state.departureAirport.airport_identifier);
  }
  if (state.arrivalAirport?.airport_identifier) {
    rerenderProcedureLists("arrival", state.arrivalAirport.airport_identifier);
  }
  if (state.manualAirport?.airport_identifier) {
    rerenderProcedureLists("manual", state.manualAirport.airport_identifier);
  }
}

function restoreRouteDrawingSnapshot(routeSnapshot) {
  if (!routeSnapshot?.payload) {
    return;
  }
  const payload = cloneJSON(routeSnapshot.payload);
  const routeLayerKind = normalizeRouteLayerKind(routeSnapshot.routeLayerKind || inferRouteLayerKind(payload));
  drawRoute(payload, { routeLayerKind, fitBounds: false });
  state.currentRoutePayload = payload;
  state.currentRouteAirports = cloneJSON(routeSnapshot.airports);
  state.currentRouteLayerKind = routeLayerKind;
  state.lastRouteWasGenerated = Boolean(routeSnapshot.lastRouteWasGenerated);
  state.lastGeneratedRouteDisplay = routeSnapshot.lastGeneratedRouteDisplay || "";
  if (elements.routeInput && typeof routeSnapshot.routeInputValue === "string") {
    elements.routeInput.value = routeSnapshot.routeInputValue;
  }
  renderLegs(payload.legs || []);
}

function restoreProcedureDrawingSnapshot(type, procedureSnapshot) {
  if (!procedureSnapshot?.selected || !procedureSnapshot?.payload) {
    return;
  }
  const selected = cloneJSON(procedureSnapshot.selected);
  const payload = cloneJSON(procedureSnapshot.payload);
  const points = (payload.items || []).filter((item) => item.waypoint_latitude !== null && item.waypoint_longitude !== null);
  if (!points.length) {
    return;
  }
  rememberProcedurePayload(procedureCacheKey(type, selected.airport, selected.procedure, selected.transition), payload);
  if (type === "approach") {
    drawApproach(payload.primary_path, payload.missed_path, points, { skipFitBounds: true });
  } else {
    drawProcedure(type, payload.path, points, type === "sid" ? MAP_COLORS.sid : MAP_COLORS.star, { skipFitBounds: true });
  }
  state.selectedProcedures[type] = selected;
}

function restoreDrawingSnapshot(snapshot) {
  const normalized = normalizeDrawingSnapshot(snapshot);
  state.restoringDrawingSnapshot = true;
  try {
    clearRouteDrawingState();
    ["sid", "star", "approach"].forEach((type) => clearProcedureDrawingState(type));
    fr24TrackLayerGroup.clearLayers();
    state.fr24TrackPayload = null;

    restoreRouteDrawingSnapshot(normalized.route);
    ["sid", "star", "approach"].forEach((type) => {
      restoreProcedureDrawingSnapshot(type, normalized.procedures[type]);
    });
    if (normalized.fr24Track) {
      renderFR24TrackPayload(normalized.fr24Track, { fitBounds: false });
    }

    renderSelectedProcedures();
    rerenderProcedureListsForLoadedAirports();
    applyMapOverlayVisibility();
  } finally {
    state.restoringDrawingSnapshot = false;
    updateTrackHistoryControlState();
    scheduleCalculateRender();
  }
}

function setDrawingHistoryStatus(message, isError = false) {
  setFR24QueryStatus(message, isError);
  setStatus(message, isError);
}

function clearAllMapDrawings(options = {}) {
  const eventLike = options && typeof options === "object" && "target" in options;
  const recordHistory = eventLike ? true : options.recordHistory !== false;
  const snapshot = currentDrawingSnapshot();
  if (!drawingSnapshotHasContent(snapshot)) {
    setDrawingHistoryStatus(t("query.noTrack"), true);
    updateTrackHistoryControlState();
    return;
  }
  if (recordHistory) {
    pushDrawingUndoState();
  }
  restoreDrawingSnapshot(emptyDrawingSnapshot());
  setDrawingHistoryStatus(t("query.trackCleared"));
}

function undoMapDrawing() {
  if (!state.drawingUndoStack.length) {
    setDrawingHistoryStatus(t("query.noTrackUndo"), true);
    updateTrackHistoryControlState();
    return;
  }
  const current = currentDrawingSnapshot();
  const previous = state.drawingUndoStack.pop();
  pushDrawingRedoState(current);
  restoreDrawingSnapshot(previous);
  setDrawingHistoryStatus(drawingSnapshotHasContent(previous) ? t("query.trackUndoRestored") : t("query.trackUndoCleared"));
}

function redoMapDrawing() {
  if (!state.drawingRedoStack.length) {
    setDrawingHistoryStatus(t("query.noTrackRedo"), true);
    updateTrackHistoryControlState();
    return;
  }
  const current = currentDrawingSnapshot();
  const next = state.drawingRedoStack.pop();
  state.drawingUndoStack.push(cloneDrawingSnapshot(current));
  trimDrawingHistoryStack(state.drawingUndoStack);
  restoreDrawingSnapshot(next);
  setDrawingHistoryStatus(drawingSnapshotHasContent(next) ? t("query.trackRedoRestored") : t("query.trackCleared"));
}

function updateTrackHistoryControlState() {
  if (!trackHistoryControlContainer) {
    return;
  }
  const hasDrawing = drawingSnapshotHasContent(currentDrawingSnapshot());
  trackHistoryControlContainer.querySelectorAll("[data-track-history-action]").forEach((button) => {
    const action = button.dataset.trackHistoryAction;
    const disabled = action === "undo"
      ? state.drawingUndoStack.length === 0
      : action === "redo"
        ? state.drawingRedoStack.length === 0
        : !hasDrawing;
    button.disabled = disabled;
    button.setAttribute("aria-disabled", String(disabled));
  });
}

function createTrackHistoryControl() {
  const control = L.control({ position: "topright" });
  control.onAdd = () => {
    const container = L.DomUtil.create("div", "leaflet-control track-history-control");
    trackHistoryControlContainer = container;
    [
      { action: "undo", labelKey: "query.undoTrack" },
      { action: "redo", labelKey: "query.redoTrack" },
      { action: "clear", labelKey: "query.clearAllTrack" },
    ].forEach((config) => {
      const button = L.DomUtil.create("button", `track-history-button track-history-${config.action}`, container);
      button.type = "button";
      button.dataset.trackHistoryAction = config.action;
      button.dataset.trackHistoryLabelKey = config.labelKey;
      button.innerHTML = trackHistoryIconMarkup(config.action);
      button.addEventListener("click", () => {
        if (config.action === "undo") {
          undoMapDrawing();
        } else if (config.action === "redo") {
          redoMapDrawing();
        } else {
          clearAllMapDrawings();
        }
      });
    });
    updateTrackHistoryControlLabels();
    updateTrackHistoryControlState();
    L.DomEvent.disableClickPropagation(container);
    L.DomEvent.disableScrollPropagation(container);
    return container;
  };
  return control;
}

/**
 * 功能：创建离线地图管理入口按钮。
 * 输入：无。
 * 输出：Leaflet 控件实例；仅在离线地形底图启用时显示。
 */
function createOfflineMapControl() {
  const control = L.control({ position: "bottomright" });
  control.onAdd = () => {
    const container = L.DomUtil.create("div", "leaflet-control offline-map-control hidden");
    offlineMapControlContainer = container;
    const button = L.DomUtil.create("button", "offline-map-toggle", container);
    button.type = "button";
    button.title = t("map.offlineControl");
    button.setAttribute("aria-label", t("map.offlineControl"));
    button.innerHTML = `
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <ellipse cx="12" cy="5.5" rx="7" ry="3" />
        <path d="M5 5.5v6c0 1.7 3.1 3 7 3s7-1.3 7-3v-6" />
        <path d="M5 11.5v6c0 1.7 3.1 3 7 3s7-1.3 7-3v-6" />
      </svg>
    `;
    button.addEventListener("click", () => openOfflineMapManager());
    L.DomEvent.disableClickPropagation(container);
    L.DomEvent.disableScrollPropagation(container);
    return container;
  };
  return control;
}

/**
 * 功能：确保离线地图管理弹窗 DOM 已创建。
 * 输入：无。
 * 输出：离线地图管理弹窗根节点。
 */
function ensureOfflineMapModal() {
  if (offlineMapModalElement) {
    return offlineMapModalElement;
  }
  offlineMapModalElement = document.createElement("div");
  offlineMapModalElement.className = "offline-map-modal hidden";
  offlineMapModalElement.innerHTML = `
    <div class="offline-map-backdrop" data-offline-close="true"></div>
    <section class="offline-map-dialog" role="dialog" aria-modal="true" aria-label="${escapeHtml(t("offline.modalAria"))}">
      <header class="offline-map-head">
        <div>
          <div class="offline-map-kicker">${escapeHtml(t("offline.modalKicker"))}</div>
          <h2>${escapeHtml(t("offline.modalTitle"))}</h2>
          <p>${escapeHtml(t("offline.modalDescription"))}</p>
        </div>
        <button type="button" class="offline-map-close" data-offline-close="true" aria-label="${escapeHtml(t("offline.modalClose"))}">&times;</button>
      </header>
      <div class="offline-map-tabs" role="tablist">
        <button type="button" class="offline-map-tab active" data-offline-tab="manage">${escapeHtml(t("offline.tabManage"))}</button>
        <button type="button" class="offline-map-tab" data-offline-tab="download">${escapeHtml(t("offline.tabDownload"))}</button>
      </div>
      <div class="offline-map-panels">
        <div id="offlineMapManagePanel" class="offline-map-panel"></div>
        <div id="offlineMapDownloadPanel" class="offline-map-panel hidden"></div>
      </div>
    </section>
  `;
  offlineMapModalElement.addEventListener("click", handleOfflineModalClick);
  offlineMapModalElement.addEventListener("input", handleOfflineDownloadFormChange);
  offlineMapModalElement.addEventListener("change", handleOfflineDownloadFormChange);
  offlineMapModalElement.addEventListener("submit", handleOfflineDownloadSubmit);
  document.body.appendChild(offlineMapModalElement);
  return offlineMapModalElement;
}

/**
 * 功能：打开离线地图管理弹窗并刷新资源状态。
 * 输入：无。
 * 输出：无返回值；显示弹窗并触发状态请求。
 */
function openOfflineMapManager() {
  const modal = ensureOfflineMapModal();
  modal.classList.remove("hidden");
  renderOfflineMapModal();
  refreshOfflineMapStatus().catch(setErrorStatus);
}

/**
 * 功能：关闭离线地图管理弹窗。
 * 输入：无。
 * 输出：无返回值；隐藏弹窗并停止界面轮询。
 */
function closeOfflineMapManager() {
  offlineMapModalElement?.classList.add("hidden");
  window.clearTimeout(state.offlineMapPollTimer);
  state.offlineMapPollTimer = 0;
}

/**
 * 功能：切换离线地图管理弹窗中的标签页。
 * 输入：tab 为 `manage` 或 `download`。
 * 输出：无返回值；更新弹窗内容区显隐。
 */
function setOfflineMapManagerTab(tab) {
  state.offlineMapManagerTab = tab === "download" ? "download" : "manage";
  renderOfflineMapModal();
}

/**
 * 功能：把字节数格式化为便于阅读的大小文本。
 * 输入：bytes 为文件大小字节数。
 * 输出：格式化后的字符串。
 */
function formatBytes(bytes) {
  const value = Number(bytes);
  if (!Number.isFinite(value) || value <= 0) {
    return "0 B";
  }
  const units = ["B", "KB", "MB", "GB"];
  let size = value;
  let unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  return `${size >= 10 || unitIndex === 0 ? size.toFixed(0) : size.toFixed(1)} ${units[unitIndex]}`;
}

/**
 * 功能：更新 Settings 中的离线地图摘要。
 * 输入：status 为离线地图 API 返回值。
 * 输出：无返回值；只刷新设置页文本，不重建地图。
 */
function updateOfflineMapSettingsSummary(status = state.offlineMapStatus) {
  if (!elements.offlineMapSummaryTitle || !elements.offlineMapSummaryText) {
    return;
  }
  if (!status) {
    elements.offlineMapSummaryTitle.textContent = t("offline.unread");
    elements.offlineMapSummaryText.textContent = t("offline.refreshPrompt");
    return;
  }
  const resources = status.resources || [];
  const active = activeOfflineResource(status);
  const job = status.download_job;
  if (job?.running) {
    const downloaded = formatCount(job.downloaded || 0);
    const total = formatCount(job.total || 0);
    elements.offlineMapSummaryTitle.textContent = t("offline.downloadingTitle", { name: job.name || t("offline.defaultName") });
    elements.offlineMapSummaryText.textContent = t("offline.downloadSummary", { downloaded, total, size: formatBytes(job.bytes_downloaded) });
    return;
  }
  if (active) {
    elements.offlineMapSummaryTitle.textContent = t("offline.enabledTitle", { name: active.name });
    elements.offlineMapSummaryText.textContent = t("offline.enabledSummary", {
      provider: active.provider_label || active.provider || t("offline.localResource"),
      kind: offlineKindLabel(active.kind),
      size: formatBytes(active.size_bytes),
      count: formatCount(active.tile_count || 0),
    });
    return;
  }
  elements.offlineMapSummaryTitle.textContent = resources.length ? t("offline.notEnabled") : t("offline.noResources");
  elements.offlineMapSummaryText.textContent = resources.length
    ? t("offline.foundResources", { count: resources.length })
    : t("offline.noResourcesHint");
}

/**
 * 功能：从 Settings 打开离线地图管理器。
 * 输入：tab 为 manage 或 download。
 * 输出：无返回值；先切换到设置语境，再打开原有管理弹窗。
 */
function openOfflineMapManagerFromSettings(tab = "manage") {
  state.offlineMapManagerTab = tab === "download" ? "download" : "manage";
  openOfflineMapManager();
}

/**
 * 功能：更新 Settings 中的在线地图缓存摘要。
 * 输入：payload 为 `/api/map-cache/status` 或 clear 返回值。
 * 输出：无返回值；显示文件数、大小和后台请求状态。
 */
function updateMapCacheSummary(payload = state.mapCacheStatus) {
  if (!elements.mapCacheSummaryTitle || !elements.mapCacheSummaryText) {
    return;
  }
  if (!payload) {
    elements.mapCacheSummaryTitle.textContent = t("settings.mapCache");
    elements.mapCacheSummaryText.textContent = t("cache.unread");
    return;
  }
  const sizeText = formatBytes(payload.size_bytes);
  const fileCount = formatCount(payload.file_count || 0);
  const pending = Number(payload.pending_count || 0);
  const failed = Number(payload.failed_count || 0);
  elements.mapCacheSummaryTitle.textContent = currentLanguage() === "zh-Hans"
    ? `${sizeText} · ${fileCount} 个文件`
    : `${sizeText} · ${fileCount} files`;
  elements.mapCacheSummaryText.textContent = t("cache.summary", { pending, failed });
}

/**
 * 功能：刷新在线地图缓存状态。
 * 输入：announce 表示是否写入 Plan 状态栏。
 * 输出：Promise，解析为缓存 payload。
 */
async function refreshMapCacheStatus({ announce = false } = {}) {
  const payload = await fetchJson("/api/map-cache/status");
  state.mapCacheStatus = payload;
  updateMapCacheSummary(payload);
  if (announce) {
    setStatus(t("cache.status", { size: formatBytes(payload.size_bytes), count: formatCount(payload.file_count || 0) }));
  }
  return payload;
}

/**
 * 功能：清理在线地图缓存并刷新地形底图 URL。
 * 输入：无。
 * 输出：Promise；只影响在线增强底图缓存，不影响离线地图包。
 */
async function clearMapCache() {
  if (!window.confirm(t("cache.clearConfirm"))) {
    return;
  }
  elements.clearMapCacheButton.disabled = true;
  try {
    const payload = await fetchJson("/api/map-cache/clear", { method: "POST" });
    state.mapCacheStatus = payload;
    updateMapCacheSummary(payload);
    refreshOnlineBaseLayer({ bumpVersion: true });
    setStatus(currentLanguage() === "zh-Hans" && payload.message ? payload.message : t("cache.cleared"));
  } finally {
    elements.clearMapCacheButton.disabled = false;
  }
}

async function resetAllSettingsAndCaches() {
  if (!window.confirm(t("settings.resetAllConfirm"))) {
    return;
  }
  const button = elements.resetAllSettingsButton;
  if (button) {
    button.disabled = true;
    button.textContent = t("settings.resetAllWorking");
  }
  try {
    LOCAL_SETTING_KEYS.forEach(removeLocalStorageValue);
    const mapCachePayload = await fetchJson("/api/map-cache/clear", { method: "POST" });
    const fr24CachePayload = await fetchJson("/api/fr24/cache/clear", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ include_favorites: true }),
    });
    state.mapCacheStatus = mapCachePayload;
    state.fr24CacheStatus = fr24CachePayload;
    state.onlineMapProvider = "arcgis";
    setMapSourceMode("online", { persist: false });
    state.baseMap = "terrain";
    state.mapTileZoomOffset = 0;
    state.themeMode = "system";
    state.languageMode = "system";
    state.effectiveLanguage = resolveLanguageMode("system");
    state.appIconChoice = "primary";
    state.fr24CacheItems = [];
    state.fr24CacheFlights.clear();
    updateMapCacheSummary(mapCachePayload);
    updateFR24CacheSummary(fr24CachePayload);
    renderFR24CacheFlights([]);
    applyLanguageMode("system", { persist: false, refresh: true });
    applyThemeMode("system", { persist: false });
    applyAppIconChoice("primary", { persist: false, notifyNative: true });
    updateMapTypeOptionLabels();
    updateMapTileZoomOffsetControl();
    map.getContainer().dataset.baseMap = "terrain";
    hideVectorMap();
    removeMapAttribution(VECTOR_ATTRIBUTION);
    removeMapAttribution(OFFLINE_VECTOR_ATTRIBUTION);
    setRasterBaseLayer("terrain");
    updateOfflineMapControlVisibility();
    updateMapTypeOptionState();
    refreshOnlineBaseLayer({ bumpVersion: true });
    map.invalidateSize({ pan: false });
    setStatus(t("settings.resetAllDone"));
  } finally {
    if (button) {
      button.disabled = false;
      button.textContent = t("settings.resetAllButton");
    }
  }
}

/**
 * 功能：格式化离线地图资源覆盖范围。
 * 输入：bounds 为 west/south/east/north 对象。
 * 输出：范围文本。
 */
function formatOfflineBounds(bounds) {
  if (!bounds) {
    return t("offline.boundsUnknown");
  }
  return [
    `W ${Number(bounds.west).toFixed(1)}`,
    `S ${Number(bounds.south).toFixed(1)}`,
    `E ${Number(bounds.east).toFixed(1)}`,
    `N ${Number(bounds.north).toFixed(1)}`,
  ].join(" / ");
}

/**
 * 功能：查找当前下载表单所选的离线地图供应商配置。
 * 输入：providerKey 为供应商 key。
 * 输出：供应商配置对象；不存在时返回 null。
 */
function offlineProviderByKey(providerKey) {
  return (state.offlineMapStatus?.providers || []).find((provider) => provider.key === providerKey) || null;
}

/**
 * 功能：把数值限制在指定范围内。
 * 输入：value 为原值，min/max 为边界。
 * 输出：限制后的数值。
 */
function clampNumber(value, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return min;
  }
  return Math.max(min, Math.min(max, number));
}

/**
 * 功能：把经度转换为离线估算用的瓦片 x 坐标。
 * 输入：lon 为经度，zoom 为缩放等级。
 * 输出：Web Mercator 瓦片 x 坐标。
 */
function offlineLonToTileX(lon, zoom) {
  const n = 2 ** zoom;
  const value = Math.floor(((Number(lon) + 180) / 360) * n);
  return Math.max(0, Math.min(n - 1, value));
}

/**
 * 功能：把纬度转换为离线估算用的瓦片 y 坐标。
 * 输入：lat 为纬度，zoom 为缩放等级。
 * 输出：Web Mercator 瓦片 y 坐标。
 */
function offlineLatToTileY(lat, zoom) {
  const clamped = clampNumber(lat, -85.05112878, 85.05112878);
  const latRad = clamped * Math.PI / 180;
  const n = 2 ** zoom;
  const value = Math.floor((1 - Math.asinh(Math.tan(latRad)) / Math.PI) / 2 * n);
  return Math.max(0, Math.min(n - 1, value));
}

/**
 * 功能：计算指定范围和缩放等级覆盖的瓦片数量。
 * 输入：bounds 为 west/south/east/north，minZoom/maxZoom 为缩放范围。
 * 输出：预计下载瓦片数量。
 */
function estimateOfflineTileCount(bounds, minZoom, maxZoom) {
  if (!bounds) {
    return 0;
  }
  let total = 0;
  for (let zoom = minZoom; zoom <= maxZoom; zoom += 1) {
    const maxIndex = 2 ** zoom;
    const xRanges = bounds.west > bounds.east
      ? [
          [offlineLonToTileX(bounds.west, zoom), maxIndex - 1],
          [0, offlineLonToTileX(bounds.east, zoom)],
        ]
      : [[
          Math.min(offlineLonToTileX(bounds.west, zoom), offlineLonToTileX(bounds.east, zoom)),
          Math.max(offlineLonToTileX(bounds.west, zoom), offlineLonToTileX(bounds.east, zoom)),
        ]];
    const y1 = offlineLatToTileY(bounds.north, zoom);
    const y2 = offlineLatToTileY(bounds.south, zoom);
    const yCount = Math.abs(y2 - y1) + 1;
    xRanges.forEach(([x1, x2]) => {
      total += (Math.abs(x2 - x1) + 1) * yCount;
    });
  }
  return total;
}

/**
 * 功能：按分级混合策略估算瓦片数。
 * 输入：detailBounds 为高缩放区域，min/sourceMax/baseMaxZoom 为实际下载缩放参数，tiered 表示是否启用分级。
 * 输出：预计瓦片数量。
 */
function estimateOfflineDownloadTileCount(detailBounds, minZoom, sourceMaxZoom, baseMaxZoom, tiered) {
  if (!tiered) {
    return estimateOfflineTileCount(detailBounds, minZoom, sourceMaxZoom);
  }
  const baseZoomEnd = Math.min(sourceMaxZoom, Math.max(minZoom, baseMaxZoom));
  const baseTiles = estimateOfflineTileCount(OFFLINE_MAP_GLOBAL_BOUNDS, minZoom, baseZoomEnd);
  const detailTiles = baseZoomEnd < sourceMaxZoom
    ? estimateOfflineTileCount(detailBounds, baseZoomEnd + 1, sourceMaxZoom)
    : 0;
  return baseTiles + detailTiles;
}

/**
 * 功能：获取供应商推荐的实际下载源瓦片最大级别。
 * 输入：provider 为离线地图供应商，displayMaxZoom 为用户希望显示到的最大级别。
 * 输出：适合估算和默认表单值的源瓦片最大级别。
 */
function recommendedOfflineSourceMaxZoom(provider, displayMaxZoom) {
  const fallback = provider?.kind === "vector" ? OFFLINE_MAP_DEFAULT_DOWNLOAD.sourceMaxZoom : displayMaxZoom;
  const providerValue = Number(provider?.recommended_source_max_zoom ?? fallback);
  return clampNumber(providerValue, 0, displayMaxZoom);
}

/**
 * 功能：估算单个离线地图瓦片的平均大小。
 * 输入：provider 为离线地图供应商配置。
 * 输出：估计字节数。
 */
function estimatedBytesPerOfflineTile(provider) {
  if (!provider) {
    return 32000;
  }
  const matchingResources = (state.offlineMapStatus?.resources || []).filter((resource) => (
    resource.provider === provider.key
    && Number(resource.tile_count) > 0
    && Number(resource.size_bytes) > 0
  ));
  const calibratedBytes = matchingResources.reduce((sum, resource) => sum + Number(resource.size_bytes || 0), 0);
  const calibratedTiles = matchingResources.reduce((sum, resource) => sum + Number(resource.tile_count || 0), 0);
  if (calibratedBytes > 0 && calibratedTiles > 0) {
    return calibratedBytes / calibratedTiles;
  }
  const providerEstimate = Number(provider.estimated_tile_bytes);
  if (Number.isFinite(providerEstimate) && providerEstimate > 0) {
    return providerEstimate;
  }
  return provider.kind === "vector" ? 6500 : 32000;
}

/**
 * 功能：把边界参数格式化为资源名片段。
 * 输入：value 为边界数值。
 * 输出：适合资源名使用的短文本。
 */
function offlineNameNumber(value) {
  return String(Math.round(Number(value) * 100) / 100).replace("-", "m").replace(".", "p");
}

/**
 * 功能：根据供应商、缩放和范围自动生成离线资源名。
 * 输入：providerKey、minZoom、maxZoom、bounds/sourceMaxZoom 为下载参数。
 * 输出：只含安全字符的资源名称。
 */
function buildOfflineResourceName(providerKey, minZoom, maxZoom, bounds, sourceMaxZoom = maxZoom) {
  const zoomPart = sourceMaxZoom < maxZoom ? `z${minZoom}_${maxZoom}_src${sourceMaxZoom}` : `z${minZoom}_${maxZoom}`;
  if (!bounds) {
    return `${providerKey || "offline"}_${zoomPart}_unselected`;
  }
  return [
    providerKey || "offline",
    zoomPart,
    `w${offlineNameNumber(bounds.west)}`,
    `s${offlineNameNumber(bounds.south)}`,
    `e${offlineNameNumber(bounds.east)}`,
    `n${offlineNameNumber(bounds.north)}`,
  ].join("_").slice(0, 80);
}

/**
 * 功能：从下载表单读取供应商、缩放和范围参数。
 * 输入：form 为离线下载表单元素。
 * 输出：参数对象，包含 provider、zoom 和 bounds。
 */
function readOfflineDownloadFormValues(form) {
  const providerKey = form.elements.provider?.value || "";
  const provider = offlineProviderByKey(providerKey);
  const maxProviderZoom = Number(provider?.max_zoom ?? 19);
  const minZoom = clampNumber(form.elements.min_zoom?.value, 0, maxProviderZoom);
  const maxZoom = clampNumber(form.elements.max_zoom?.value, minZoom, maxProviderZoom);
  const recommendedSourceMax = recommendedOfflineSourceMaxZoom(provider, maxZoom);
  const sourceMaxRaw = form.elements.source_max_zoom?.value;
  const sourceMaxZoom = clampNumber(sourceMaxRaw === undefined || sourceMaxRaw === "" ? recommendedSourceMax : sourceMaxRaw, minZoom, maxZoom);
  const tiered = Boolean(form.elements.tiered?.checked);
  const baseMaxZoom = clampNumber(form.elements.base_max_zoom?.value, minZoom, sourceMaxZoom);
  const parseBound = (key) => {
    const raw = String(form.elements[key]?.value ?? "").trim();
    return raw === "" ? Number.NaN : Number(raw);
  };
  const values = {
    west: parseBound("west"),
    south: parseBound("south"),
    east: parseBound("east"),
    north: parseBound("north"),
  };
  const hasBounds = Object.values(values).every(Number.isFinite);
  const bounds = hasBounds
    ? {
        west: clampNumber(values.west, -180, 180),
        south: clampNumber(values.south, -85.0511, 85.0511),
        east: clampNumber(values.east, -180, 180),
        north: clampNumber(values.north, -85.0511, 85.0511),
      }
    : null;
  if (bounds && bounds.south > bounds.north) {
    [bounds.south, bounds.north] = [bounds.north, bounds.south];
  }
  return { providerKey, provider, minZoom, maxZoom, sourceMaxZoom, baseMaxZoom, tiered, bounds };
}

/**
 * 功能：把范围参数写回下载表单输入框。
 * 输入：form 为下载表单，bounds 为范围对象或 null。
 * 输出：无返回值；更新表单显示。
 */
function writeOfflineBoundsToForm(form, bounds) {
  ["west", "south", "east", "north"].forEach((key) => {
    if (!form.elements[key]) {
      return;
    }
    form.elements[key].value = bounds ? String(Math.round(bounds[key] * 10000) / 10000) : "";
  });
}

/**
 * 功能：同步离线下载表单的资源名、最大缩放限制、估算和按钮状态。
 * 输入：form 为离线下载表单。
 * 输出：无返回值；直接更新表单 DOM。
 */
function syncOfflineDownloadForm(form) {
  if (!form) {
    return;
  }
  let values = readOfflineDownloadFormValues(form);
  if (form.dataset.offlineProviderKey !== values.providerKey && form.elements.source_max_zoom) {
    form.dataset.offlineProviderKey = values.providerKey;
    form.elements.source_max_zoom.value = String(recommendedOfflineSourceMaxZoom(values.provider, values.maxZoom));
    values = readOfflineDownloadFormValues(form);
  }
  const maxProviderZoom = Number(values.provider?.max_zoom ?? 19);
  form.elements.min_zoom.max = String(maxProviderZoom);
  form.elements.max_zoom.max = String(maxProviderZoom);
  form.elements.min_zoom.value = String(values.minZoom);
  form.elements.max_zoom.value = String(values.maxZoom);
  if (form.elements.source_max_zoom) {
    form.elements.source_max_zoom.min = String(values.minZoom);
    form.elements.source_max_zoom.max = String(values.maxZoom);
    form.elements.source_max_zoom.value = String(values.sourceMaxZoom);
  }
  if (form.elements.base_max_zoom) {
    form.elements.base_max_zoom.min = String(values.minZoom);
    form.elements.base_max_zoom.max = String(values.sourceMaxZoom);
    form.elements.base_max_zoom.value = String(values.baseMaxZoom);
  }
  if (values.bounds) {
    state.offlineDownloadBounds = {
      ...values.bounds,
      minZoom: values.minZoom,
      maxZoom: values.maxZoom,
      sourceMaxZoom: values.sourceMaxZoom,
    };
    writeOfflineBoundsToForm(form, values.bounds);
  }
  const resourceName = buildOfflineResourceName(values.providerKey, values.minZoom, values.maxZoom, values.bounds, values.sourceMaxZoom);
  form.elements.name.value = resourceName;
  form.elements.name.title = resourceName;
  const tileCount = estimateOfflineDownloadTileCount(values.bounds, values.minZoom, values.sourceMaxZoom, values.baseMaxZoom, values.tiered);
  const bytesPerTile = estimatedBytesPerOfflineTile(values.provider);
  const bytes = tileCount * bytesPerTile;
  const limit = Number(state.offlineMapStatus?.max_download_tiles || 0);
  const tooLarge = Boolean(limit && tileCount > limit);
  const invalid = !values.providerKey || !values.bounds || tileCount <= 0 || tooLarge;
  const estimate = form.querySelector("#offlineDownloadEstimate");
  if (estimate) {
    const baseZoomEnd = Math.min(values.sourceMaxZoom, Math.max(values.minZoom, values.baseMaxZoom));
    const overzoomText = values.sourceMaxZoom < values.maxZoom
      ? t("offline.estimate.overzoomDisplay", { min: values.minZoom, max: values.maxZoom, source: values.sourceMaxZoom })
      : t("offline.estimate.displayDownload", { min: values.minZoom, max: values.maxZoom });
    const strategyText = values.tiered
      ? (baseZoomEnd < values.sourceMaxZoom
        ? t("offline.estimate.strategyTiered", { min: values.minZoom, base: baseZoomEnd, next: baseZoomEnd + 1, source: values.sourceMaxZoom })
        : t("offline.estimate.strategyGlobal", { min: values.minZoom, source: values.sourceMaxZoom }))
      : t("offline.estimate.strategyBounds", { min: values.minZoom, source: values.sourceMaxZoom });
    const rasterWarning = values.provider?.kind === "raster" && (values.sourceMaxZoom >= 13 || values.sourceMaxZoom < values.maxZoom);
    const warningText = values.provider?.kind === "raster"
      ? (values.sourceMaxZoom < values.maxZoom
        ? t("offline.estimate.rasterOverzoom")
        : (values.sourceMaxZoom >= 13 ? t("offline.estimate.rasterLarge") : ""))
      : (values.sourceMaxZoom < values.maxZoom ? t("offline.estimate.vectorOverzoom") : "");
    estimate.innerHTML = values.bounds
      ? escapeHtml(t("offline.estimate.summary", {
          count: formatCount(tileCount),
          size: formatBytes(bytes),
          tileSize: formatBytes(bytesPerTile),
          overzoom: overzoomText,
          strategy: strategyText,
          warning: warningText,
          limit: tooLarge ? t("offline.estimate.limitExceeded", { limit: formatCount(limit) }) : "",
        }))
      : escapeHtml(t("offline.estimate.needsBounds"));
    estimate.classList.toggle("error", tooLarge || !values.bounds);
    estimate.classList.toggle("warning", !tooLarge && Boolean(values.bounds) && rasterWarning);
  }
  const button = form.querySelector("button[type='submit']");
  if (button) {
    button.disabled = invalid;
    button.textContent = values.bounds
      ? t("offline.startDownloadWithCount", { count: formatCount(tileCount), size: formatBytes(bytes) })
      : t("offline.startDownloadNeedsBounds");
  }
  updateOfflineBoundsRectangle(values.bounds);
}

/**
 * 功能：获取离线下载弹窗内的表单元素。
 * 输入：无。
 * 输出：表单元素；不存在时返回 null。
 */
function offlineDownloadFormElement() {
  return offlineMapModalElement?.querySelector("#offlineDownloadForm") || null;
}

/**
 * 功能：把普通 bounds 对象转换为 Leaflet LatLngBounds。
 * 输入：bounds 为 west/south/east/north 对象。
 * 输出：Leaflet LatLngBounds；无范围时返回 null。
 */
function leafletBoundsFromOfflineBounds(bounds) {
  if (!bounds) {
    return null;
  }
  return L.latLngBounds(
    [bounds.south, bounds.west],
    [bounds.north, bounds.east],
  );
}

/**
 * 功能：把 Leaflet LatLngBounds 转换为离线下载范围对象。
 * 输入：bounds 为 Leaflet LatLngBounds。
 * 输出：west/south/east/north 范围对象。
 */
function offlineBoundsFromLeafletBounds(bounds) {
  return {
    west: clampNumber(bounds.getWest(), -180, 180),
    south: clampNumber(bounds.getSouth(), -85.0511, 85.0511),
    east: clampNumber(bounds.getEast(), -180, 180),
    north: clampNumber(bounds.getNorth(), -85.0511, 85.0511),
  };
}

/**
 * 功能：更新离线范围小地图上的选择矩形。
 * 输入：bounds 为当前下载范围。
 * 输出：无返回值；直接更新小地图图层。
 */
function updateOfflineBoundsRectangle(bounds) {
  if (!offlineBoundsMiniMap) {
    return;
  }
  if (offlineBoundsRectangle) {
    offlineBoundsMiniMap.removeLayer(offlineBoundsRectangle);
    offlineBoundsRectangle = null;
  }
  const leafletBounds = leafletBoundsFromOfflineBounds(bounds);
  if (!leafletBounds?.isValid()) {
    return;
  }
  offlineBoundsRectangle = L.rectangle(leafletBounds, {
    color: "#54bdff",
    weight: 2,
    fillColor: "#54bdff",
    fillOpacity: 0.16,
    interactive: false,
  }).addTo(offlineBoundsMiniMap);
}

/**
 * 功能：把小地图框选结果写入下载表单并刷新估算。
 * 输入：bounds 为 Leaflet LatLngBounds。
 * 输出：无返回值；更新表单和估算。
 */
function applyOfflineBoundsSelection(bounds) {
  const form = offlineDownloadFormElement();
  if (!form || !bounds?.isValid()) {
    return;
  }
  const nextBounds = offlineBoundsFromLeafletBounds(bounds);
  state.offlineDownloadBounds = {
    ...nextBounds,
    minZoom: Number(form.elements.min_zoom?.value || 0),
    maxZoom: Number(form.elements.max_zoom?.value || 0),
    sourceMaxZoom: Number(form.elements.source_max_zoom?.value || 0),
  };
  writeOfflineBoundsToForm(form, nextBounds);
  syncOfflineDownloadForm(form);
}

/**
 * 功能：进入或退出离线范围小地图框选模式。
 * 输入：enabled 表示是否启用框选。
 * 输出：无返回值；更新状态和小地图样式。
 */
function setOfflineBoundsSelecting(enabled) {
  state.offlineBoundsSelecting = Boolean(enabled);
  offlineBoundsMiniMapContainer?.classList.toggle("is-selecting", state.offlineBoundsSelecting);
  offlineMapModalElement
    ?.querySelector("[data-offline-bounds-action='select']")
    ?.classList.toggle("active", state.offlineBoundsSelecting);
}

/**
 * 功能：处理离线范围小地图的拖拽框选。
 * 输入：event 为 Leaflet mousedown 事件。
 * 输出：无返回值；拖拽结束后写入范围。
 */
function beginOfflineBoundsDrag(event) {
  if (!offlineBoundsMiniMap || !state.offlineBoundsSelecting) {
    return;
  }
  const start = event.latlng;
  if (offlineBoundsDraftRectangle) {
    offlineBoundsMiniMap.removeLayer(offlineBoundsDraftRectangle);
  }
  offlineBoundsDraftRectangle = L.rectangle(L.latLngBounds(start, start), {
    color: "#ffd166",
    weight: 2,
    dashArray: "5 5",
    fillColor: "#ffd166",
    fillOpacity: 0.12,
    interactive: false,
  }).addTo(offlineBoundsMiniMap);
  offlineBoundsMiniMap.dragging.disable();

  const onMove = (moveEvent) => {
    offlineBoundsDraftRectangle.setBounds(L.latLngBounds(start, moveEvent.latlng));
  };
  const onUp = (upEvent) => {
    offlineBoundsMiniMap.off("mousemove", onMove);
    offlineBoundsMiniMap.off("mouseup", onUp);
    offlineBoundsMiniMap.dragging.enable();
    const selected = L.latLngBounds(start, upEvent.latlng);
    offlineBoundsMiniMap.removeLayer(offlineBoundsDraftRectangle);
    offlineBoundsDraftRectangle = null;
    setOfflineBoundsSelecting(false);
    applyOfflineBoundsSelection(selected);
  };
  offlineBoundsMiniMap.on("mousemove", onMove);
  offlineBoundsMiniMap.on("mouseup", onUp);
}

/**
 * 功能：创建或刷新离线范围选择小地图。
 * 输入：无。
 * 输出：无返回值；初始化后可在小地图中框选下载范围。
 */
function ensureOfflineBoundsMiniMap() {
  const container = offlineMapModalElement?.querySelector("#offlineBoundsMap");
  if (!container) {
    return;
  }
  if (offlineBoundsMiniMapContainer !== container) {
    offlineBoundsMiniMap?.remove();
    offlineBoundsMiniMapContainer = container;
    offlineBoundsMiniMap = L.map(container, {
      attributionControl: false,
      zoomControl: false,
      scrollWheelZoom: true,
      doubleClickZoom: false,
      boxZoom: false,
      worldCopyJump: true,
    }).setView([20, 0], 1);
    disableDoubleTapZoom(offlineBoundsMiniMap);
    createAsyncCachedTileLayer(onlineMapTileUrl(), {
      maxZoom: 6,
      minZoom: 0,
      keepBuffer: 2,
    }).addTo(offlineBoundsMiniMap);
    offlineBoundsMiniMap.on("mousedown", beginOfflineBoundsDrag);
  }
  window.setTimeout(() => {
    const form = offlineDownloadFormElement();
    offlineBoundsMiniMap.invalidateSize();
    updateOfflineBoundsRectangle(form ? readOfflineDownloadFormValues(form).bounds : null);
  }, 80);
}

/**
 * 功能：处理离线范围快捷按钮。
 * 输入：action 为 global、clear 或 select。
 * 输出：无返回值；更新表单或框选模式。
 */
function handleOfflineBoundsAction(action) {
  const form = offlineDownloadFormElement();
  if (!form) {
    return;
  }
  if (action === "global") {
    setOfflineBoundsSelecting(false);
    writeOfflineBoundsToForm(form, OFFLINE_MAP_DEFAULT_DOWNLOAD);
    syncOfflineDownloadForm(form);
    offlineBoundsMiniMap?.setView([20, 0], 1);
    return;
  }
  if (action === "clear") {
    setOfflineBoundsSelecting(false);
    state.offlineDownloadBounds = null;
    writeOfflineBoundsToForm(form, null);
    syncOfflineDownloadForm(form);
    return;
  }
  if (action === "select") {
    setOfflineBoundsSelecting(!state.offlineBoundsSelecting);
  }
}

/**
 * 功能：计算离线下载任务进度百分比。
 * 输入：job 为后端返回的下载任务。
 * 输出：0 到 100 的百分比数值。
 */
function offlineJobPercent(job) {
  const total = Number(job?.total || 0);
  if (!total) {
    return 0;
  }
  return Math.max(0, Math.min(100, (Number(job.downloaded || 0) / total) * 100));
}

/**
 * 功能：渲染离线下载任务进度区域。
 * 输入：job 为后端返回的下载任务。
 * 输出：HTML 字符串。
 */
function offlineJobHtml(job) {
  if (!job) {
    return `<div class="offline-map-empty">${escapeHtml(t("offline.noJob"))}</div>`;
  }
  const percent = offlineJobPercent(job);
  const isAborted = Boolean(job.aborted);
  const hasFailed = isAborted || (!job.running && Number(job.failed || 0) > 0);
  const stateText = isAborted
    ? (job.running ? t("offline.state.canceling") : t("offline.state.aborted"))
    : (job.running ? t("offline.state.running") : t("offline.state.done"));
  const workerText = Number(job.download_workers || 0) > 1 ? t("offline.workers", { count: Number(job.download_workers) }) : t("offline.singleWorker");
  const speedText = t("offline.speed", { speed: formatBytes(Number(job.bytes_per_second || 0)) });
  const inflightText = Number(job.inflight_limit || 0) > 0
    ? t("offline.inflight", { active: Number(job.active_downloads || 0), limit: Number(job.inflight_limit || 0) })
    : "";
  const zoomText = Number(job.source_max_zoom) < Number(job.max_zoom)
    ? t("offline.displaySourceZoom", { min: job.min_zoom, max: job.max_zoom, source: job.source_max_zoom })
    : t("offline.zoomRange", { min: job.min_zoom, max: job.max_zoom });
  const actualBytes = Number(job.bytes_downloaded || job.downloaded_bytes || 0);
  const estimatedBytes = Number(job.estimated_bytes || 0);
  const sizeText = actualBytes > 0
    ? t("offline.writtenSize", { size: formatBytes(actualBytes) })
    : (estimatedBytes > 0 ? t("offline.estimatedSize", { size: formatBytes(estimatedBytes) }) : "");
  const cancelButton = job.running && !isAborted
    ? `<button type="button" class="offline-action-button danger compact" data-offline-action="cancel-download">${escapeHtml(t("offline.cancelDownload"))}</button>`
    : "";
  return `
    <div class="offline-download-job ${hasFailed ? "failed" : ""}">
      <div class="offline-download-job-head">
        <div>
          <strong>${escapeHtml(job.name || t("offline.defaultName"))}</strong>
          <span>${escapeHtml(stateText)}</span>
        </div>
        ${cancelButton}
      </div>
      <div class="offline-progress" aria-label="${escapeHtml(t("offline.progress"))}">
        <span style="width:${percent.toFixed(1)}%"></span>
      </div>
      <div class="offline-download-meta">
        <span>${escapeHtml(String(job.provider_label || job.provider || t("offline.unknownProvider")))}</span>
        <span>${escapeHtml(zoomText)}</span>
        <span>${escapeHtml(t("offline.tileProgress", { downloaded: formatCount(job.downloaded || 0), total: formatCount(job.total || 0) }))}</span>
        <span>${escapeHtml(t("offline.failedCount", { count: Number(job.failed || 0) }))}</span>
        ${sizeText ? `<span>${escapeHtml(sizeText)}</span>` : ""}
        <span>${escapeHtml(workerText)}</span>
        <span>${escapeHtml(speedText)}</span>
        ${inflightText ? `<span>${escapeHtml(inflightText)}</span>` : ""}
      </div>
      <p>${escapeHtml(job.message || "")}</p>
    </div>
  `;
}

/**
 * 功能：渲染单个离线地图资源卡片。
 * 输入：resource 为离线地图资源元数据。
 * 输出：HTML 字符串。
 */
function offlineResourceCardHtml(resource) {
  const isVector = resource.kind === "vector";
  const isDisplayable = resource.kind === "raster" || isVector;
  const canSelect = isDisplayable && !resource.active;
  const canCompact = resource.storage_layout !== "sqlite_v1";
  const activeText = resource.active ? `<span class="offline-badge active">${escapeHtml(t("offline.current"))}</span>` : "";
  const kindText = isVector ? t("offline.kind.vectorDesc") : t("offline.kind.rasterDesc");
  const storageText = resource.storage_layout === "sqlite_v1"
    ? t("offline.storageSQLite")
    : (resource.storage_layout === "pmtiles_v1"
      ? t("offline.storagePMTiles")
      : (resource.storage_layout === "files_legacy" ? t("offline.storageLegacy") : (resource.storage_layout || t("common.unknown"))));
  const displayMaxZoom = offlineResourceDisplayMaxZoom(resource);
  const sourceMaxZoom = offlineResourceSourceMaxZoom(resource);
  const zoomText = sourceMaxZoom < displayMaxZoom
    ? `${t("offline.form.maxZoom")} ${resource.min_zoom ?? "--"} - ${displayMaxZoom} / ${t("offline.form.sourceMaxZoom")} ${resource.min_zoom ?? "--"} - ${sourceMaxZoom}`
    : `${resource.min_zoom ?? "--"} - ${displayMaxZoom}`;
  return `
    <article class="offline-resource-card">
      <div class="offline-resource-head">
        <div>
          <strong>${escapeHtml(resource.name)}</strong>
          <span>${escapeHtml(resource.provider_label || resource.provider || t("offline.unknownProvider"))}</span>
        </div>
        ${activeText || `<span class="offline-badge">${escapeHtml(offlineKindLabel(resource.kind))}</span>`}
      </div>
      <div class="offline-resource-grid">
        <span>${escapeHtml(t("offline.field.type"))}</span><strong>${escapeHtml(kindText)}</strong>
        <span>${escapeHtml(t("offline.field.zoom"))}</span><strong>${escapeHtml(zoomText)}</strong>
        <span>${escapeHtml(t("offline.field.tiles"))}</span><strong>${escapeHtml(String(resource.tile_count ?? "--"))}</strong>
        <span>${escapeHtml(t("offline.field.size"))}</span><strong>${escapeHtml(formatBytes(resource.size_bytes))}</strong>
        <span>${escapeHtml(t("offline.field.storage"))}</span><strong>${escapeHtml(storageText)}</strong>
        ${resource.average_tile_bytes ? `<span>${escapeHtml(t("offline.field.average"))}</span><strong>${escapeHtml(formatBytes(resource.average_tile_bytes))} / ${escapeHtml(t("offline.field.tiles"))}</strong>` : ""}
        <span>${escapeHtml(t("offline.field.bounds"))}</span><strong>${escapeHtml(formatOfflineBounds(resource.bounds))}</strong>
      </div>
      <div class="offline-resource-actions">
        <button type="button" class="offline-action-button primary" data-offline-action="select" data-name="${escapeHtml(resource.name)}" ${canSelect ? "" : "disabled"}>
          ${escapeHtml(resource.active ? t("offline.action.enabled") : (isDisplayable ? t("offline.action.setBase") : t("offline.action.unavailable")))}
        </button>
        ${canCompact ? `<button type="button" class="offline-action-button" data-offline-action="compact" data-name="${escapeHtml(resource.name)}">${escapeHtml(t("offline.action.compact"))}</button>` : ""}
        <button type="button" class="offline-action-button danger" data-offline-action="delete" data-name="${escapeHtml(resource.name)}">${escapeHtml(t("offline.action.delete"))}</button>
      </div>
    </article>
  `;
}

/**
 * 功能：渲染离线地图资源管理标签页。
 * 输入：status 为离线地图 API 状态。
 * 输出：HTML 字符串。
 */
function offlineManagePanelHtml(status) {
  const resources = status?.resources || [];
  const active = status?.active || "";
  const resourceHtml = resources.length
    ? resources.map(offlineResourceCardHtml).join("")
    : `<div class="offline-map-empty">${escapeHtml(t("offline.emptyManage"))}</div>`;
  return `
    <div class="offline-panel-toolbar">
      <div>
        <strong>${escapeHtml(t("offline.localResource"))}</strong>
        <span>${escapeHtml(t("offline.activeResource", { name: active || t("offline.unset") }))}</span>
      </div>
      <button type="button" class="offline-action-button" data-offline-action="refresh">${escapeHtml(t("offline.action.refresh"))}</button>
    </div>
    <div class="offline-resource-list">${resourceHtml}</div>
  `;
}

/**
 * 功能：渲染离线地图下载供应商选项。
 * 输入：providers 为后端返回的供应商列表。
 * 输出：HTML 字符串。
 */
function offlineProviderOptionsHtml(providers) {
  if (!providers?.length) {
    return `<option value="">${escapeHtml(t("offline.noProviders"))}</option>`;
  }
  const defaultProvider = providers.find((provider) => provider.key === "openfreemap_vector") || providers.find((provider) => provider.key === "esri_topo") || providers[0];
  return providers.map((provider) => `
    <option value="${escapeHtml(provider.key)}" ${provider.key === defaultProvider?.key ? "selected" : ""}>${escapeHtml(provider.label)} · ${escapeHtml(offlineKindLabel(provider.kind))}</option>
  `).join("");
}

/**
 * 功能：渲染离线地图供应商说明卡片。
 * 输入：providers 为后端返回的供应商列表。
 * 输出：HTML 字符串。
 */
function offlineProviderNotesHtml(providers) {
  if (!providers?.length) {
    return "";
  }
  return providers.map((provider) => `
    <div class="offline-provider-card">
      <div>
        <strong>${escapeHtml(provider.label)}</strong>
        <span>${escapeHtml(offlineKindLabel(provider.kind))} · ${escapeHtml(offlineFormatLabel(provider.format))} · ${escapeHtml(t("offline.maxZoom", { zoom: provider.max_zoom }))}${provider.recommended_source_max_zoom ? ` · ${escapeHtml(t("offline.recommendedSource", { zoom: provider.recommended_source_max_zoom }))}` : ""}</span>
      </div>
      <p>${escapeHtml(provider.description || "")}</p>
    </div>
  `).join("");
}

/**
 * 功能：渲染离线地图下载标签页。
 * 输入：status 为离线地图 API 状态。
 * 输出：HTML 字符串。
 */
function offlineDownloadPanelHtml(status) {
  const providers = status?.providers || [];
  const defaultProvider = providers.find((provider) => provider.key === "openfreemap_vector") || providers.find((provider) => provider.key === "esri_topo") || providers[0] || null;
  const defaultMaxZoom = Math.min(OFFLINE_MAP_DEFAULT_DOWNLOAD.maxZoom, Number(defaultProvider?.max_zoom ?? OFFLINE_MAP_DEFAULT_DOWNLOAD.maxZoom));
  const defaultSourceMaxZoom = recommendedOfflineSourceMaxZoom(defaultProvider, defaultMaxZoom);
  const defaultBaseMaxZoom = Math.min(OFFLINE_MAP_DEFAULT_DOWNLOAD.baseMaxZoom, defaultSourceMaxZoom);
  const initialBounds = state.offlineDownloadBounds || null;
  const defaultName = buildOfflineResourceName(defaultProvider?.key || "", OFFLINE_MAP_DEFAULT_DOWNLOAD.minZoom, defaultMaxZoom, initialBounds, defaultSourceMaxZoom);
  const downloadError = state.offlineDownloadError ? localizedErrorMessage(state.offlineDownloadError) : "";
  return `
    <form id="offlineDownloadForm" class="offline-download-form">
      <div id="offlineDownloadError" class="offline-download-alert ${downloadError ? "" : "hidden"}" role="alert">
        ${escapeHtml(downloadError)}
      </div>
      <div class="offline-download-layout">
        <div class="offline-form-grid">
          <label>
            <span>${escapeHtml(t("offline.form.provider"))}</span>
            <select name="provider" required>${offlineProviderOptionsHtml(providers)}</select>
          </label>
          <label>
            <span>${escapeHtml(t("offline.form.name"))}</span>
            <input name="name" value="${escapeHtml(defaultName)}" autocomplete="off" readonly />
          </label>
          <label>
            <span>${escapeHtml(t("offline.form.minZoom"))}</span>
            <input name="min_zoom" type="number" min="0" max="${escapeHtml(defaultProvider?.max_zoom ?? 19)}" value="${OFFLINE_MAP_DEFAULT_DOWNLOAD.minZoom}" />
          </label>
          <label>
            <span>${escapeHtml(t("offline.form.maxZoom"))}</span>
            <input name="max_zoom" type="number" min="0" max="${escapeHtml(defaultProvider?.max_zoom ?? 19)}" value="${defaultMaxZoom}" />
          </label>
          <label>
            <span>${escapeHtml(t("offline.form.sourceMaxZoom"))}</span>
            <input name="source_max_zoom" type="number" min="0" max="${escapeHtml(defaultProvider?.max_zoom ?? 19)}" value="${defaultSourceMaxZoom}" />
          </label>
          <label>
            <span>${escapeHtml(t("offline.form.baseMaxZoom"))}</span>
            <input name="base_max_zoom" type="number" min="0" max="${escapeHtml(defaultProvider?.max_zoom ?? 19)}" value="${defaultBaseMaxZoom}" />
          </label>
          <label class="offline-tiered-field">
            <span>${escapeHtml(t("offline.form.strategy"))}</span>
            <label class="offline-inline-check">
              <input name="tiered" type="checkbox" checked />
              <span>${escapeHtml(t("offline.form.tiered"))}</span>
            </label>
          </label>
          <label>
            <span>${escapeHtml(t("offline.form.west"))}</span>
            <input name="west" type="number" step="0.0001" value="${initialBounds?.west ?? ""}" />
          </label>
          <label>
            <span>${escapeHtml(t("offline.form.south"))}</span>
            <input name="south" type="number" step="0.0001" value="${initialBounds?.south ?? ""}" />
          </label>
          <label>
            <span>${escapeHtml(t("offline.form.east"))}</span>
            <input name="east" type="number" step="0.0001" value="${initialBounds?.east ?? ""}" />
          </label>
          <label>
            <span>${escapeHtml(t("offline.form.north"))}</span>
            <input name="north" type="number" step="0.0001" value="${initialBounds?.north ?? ""}" />
          </label>
        </div>
        <div class="offline-bounds-picker">
          <div id="offlineBoundsMap" class="offline-bounds-map" aria-label="${escapeHtml(t("offline.boundsMap"))}"></div>
          <div class="offline-bounds-actions">
            <button type="button" class="offline-action-button" data-offline-bounds-action="global">${escapeHtml(t("offline.bounds.global"))}</button>
            <button type="button" class="offline-action-button" data-offline-bounds-action="clear">${escapeHtml(t("offline.bounds.clear"))}</button>
            <button type="button" class="offline-action-button primary" data-offline-bounds-action="select">${escapeHtml(t("offline.bounds.select"))}</button>
          </div>
        </div>
      </div>
      <div id="offlineDownloadEstimate" class="offline-download-estimate"></div>
      <div class="offline-download-note">
        ${escapeHtml(t("offline.downloadNote", { limit: status?.max_download_tiles || "--" })).replace(/\n/g, "<br />")}
      </div>
      <button type="submit" class="offline-action-button primary wide">${escapeHtml(t("offline.startDownload"))}</button>
    </form>
    <div class="offline-provider-notes">${offlineProviderNotesHtml(providers)}</div>
    <div id="offlineDownloadJobArea">${offlineJobHtml(status?.download_job)}</div>
  `;
}

/**
 * 功能：渲染离线地图管理弹窗当前状态。
 * 输入：无。
 * 输出：无返回值；更新弹窗 DOM。
 */
function renderOfflineMapModal() {
  const modal = ensureOfflineMapModal();
  const status = state.offlineMapStatus;
  updateOfflineMapSettingsSummary(status);
  const dialog = modal.querySelector(".offline-map-dialog");
  dialog?.setAttribute("aria-label", t("offline.modalAria"));
  const kicker = modal.querySelector(".offline-map-kicker");
  if (kicker) kicker.textContent = t("offline.modalKicker");
  const title = modal.querySelector(".offline-map-head h2");
  if (title) title.textContent = t("offline.modalTitle");
  const description = modal.querySelector(".offline-map-head p");
  if (description) description.textContent = t("offline.modalDescription");
  const closeButton = modal.querySelector(".offline-map-close");
  closeButton?.setAttribute("aria-label", t("offline.modalClose"));
  modal.querySelectorAll(".offline-map-tab").forEach((button) => {
    const active = button.dataset.offlineTab === state.offlineMapManagerTab;
    button.classList.toggle("active", active);
    button.setAttribute("aria-selected", String(active));
    button.textContent = button.dataset.offlineTab === "download" ? t("offline.tabDownload") : t("offline.tabManage");
  });
  const managePanel = modal.querySelector("#offlineMapManagePanel");
  const downloadPanel = modal.querySelector("#offlineMapDownloadPanel");
  managePanel.classList.toggle("hidden", state.offlineMapManagerTab !== "manage");
  downloadPanel.classList.toggle("hidden", state.offlineMapManagerTab !== "download");
  if (!status) {
    managePanel.innerHTML = `<div class="offline-map-empty">${escapeHtml(t("offline.readingResources"))}</div>`;
    downloadPanel.innerHTML = `<div class="offline-map-empty">${escapeHtml(t("offline.readingProviders"))}</div>`;
    return;
  }
  managePanel.innerHTML = offlineManagePanelHtml(status);
  downloadPanel.innerHTML = offlineDownloadPanelHtml(status);
  if (state.offlineMapManagerTab === "download") {
    const form = offlineDownloadFormElement();
    syncOfflineDownloadForm(form);
    ensureOfflineBoundsMiniMap();
  }
}

/**
 * 功能：从离线地图下载表单读取并规范化参数。
 * 输入：form 为下载表单元素。
 * 输出：可提交给后端的下载任务参数。
 */
function offlineDownloadPayloadFromForm(form) {
  syncOfflineDownloadForm(form);
  const values = readOfflineDownloadFormValues(form);
  return {
    provider: values.providerKey,
    name: form.elements.name.value,
    min_zoom: values.minZoom,
    max_zoom: values.maxZoom,
    source_max_zoom: values.sourceMaxZoom,
    base_max_zoom: values.baseMaxZoom,
    tiered: values.tiered,
    base_west: OFFLINE_MAP_GLOBAL_BOUNDS.west,
    base_south: OFFLINE_MAP_GLOBAL_BOUNDS.south,
    base_east: OFFLINE_MAP_GLOBAL_BOUNDS.east,
    base_north: OFFLINE_MAP_GLOBAL_BOUNDS.north,
    west: values.bounds?.west,
    south: values.bounds?.south,
    east: values.bounds?.east,
    north: values.bounds?.north,
  };
}

/**
 * 功能：处理离线地图弹窗中的按钮点击。
 * 输入：event 为点击事件。
 * 输出：无返回值；根据按钮动作调用对应 API。
 */
function handleOfflineModalClick(event) {
  const target = event.target instanceof Element ? event.target : null;
  if (!target) {
    return;
  }
  if (target.closest("[data-offline-close]")) {
    closeOfflineMapManager();
    return;
  }
  const tabButton = target.closest("[data-offline-tab]");
  if (tabButton) {
    setOfflineMapManagerTab(tabButton.dataset.offlineTab);
    return;
  }
  const boundsButton = target.closest("[data-offline-bounds-action]");
  if (boundsButton) {
    handleOfflineBoundsAction(boundsButton.dataset.offlineBoundsAction);
    return;
  }
  const actionButton = target.closest("[data-offline-action]");
  if (!actionButton) {
    return;
  }
  handleOfflineResourceAction(actionButton).catch(setErrorStatus);
}

/**
 * 功能：处理离线下载表单参数变化。
 * 输入：event 为 input/change 事件。
 * 输出：无返回值；同步资源名、范围、估算和按钮状态。
 */
function handleOfflineDownloadFormChange(event) {
  const form = event.target instanceof Element ? event.target.closest("#offlineDownloadForm") : null;
  if (!form) {
    return;
  }
  state.offlineDownloadError = "";
  syncOfflineDownloadForm(form);
}

/**
 * 功能：处理离线地图资源管理动作。
 * 输入：button 为带 data-offline-action 的按钮。
 * 输出：Promise，完成后刷新弹窗状态。
 */
async function handleOfflineResourceAction(button) {
  const action = button.dataset.offlineAction;
  const name = button.dataset.name || "";
  if (action === "refresh") {
    await refreshOfflineMapStatus();
    return;
  }
  if (action === "cancel-download") {
    button.disabled = true;
    button.textContent = t("offline.state.canceling");
    try {
      const response = await fetchJson("/api/offline-maps/cancel", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
      });
      state.offlineMapStatus = {
        ...(state.offlineMapStatus || {}),
        download_job: response.download_job,
      };
      renderOfflineMapModal();
      scheduleOfflineMapPoll();
      setStatus(t("offline.cancelRequested"));
    } catch (error) {
      button.disabled = false;
      button.textContent = t("offline.cancelDownload");
      throw error;
    }
    return;
  }
  if (action === "select") {
    state.offlineMapStatus = await fetchJson("/api/offline-maps/select", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });
    refreshOfflineBaseLayer();
    setBaseMap("offline");
    renderOfflineMapModal();
    setStatus(t("offline.selectedResource", { name }));
    return;
  }
  if (action === "delete") {
    if (!window.confirm(t("offline.deleteConfirm", { name }))) {
      return;
    }
    state.offlineMapStatus = await fetchJson("/api/offline-maps/delete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });
    refreshOfflineBaseLayer();
    renderOfflineMapModal();
    setStatus(t("offline.deletedResource", { name }));
    return;
  }
  if (action === "compact") {
    button.disabled = true;
    button.textContent = t("offline.compacting");
    state.offlineMapStatus = await fetchJson("/api/offline-maps/compact", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });
    refreshOfflineBaseLayer();
    renderOfflineMapModal();
    setStatus(t("offline.compactedResource", { name }));
  }
}

/**
 * 功能：处理离线地图下载表单提交。
 * 输入：event 为表单提交事件。
 * 输出：无返回值；启动后端下载任务并开启轮询。
 */
function handleOfflineDownloadSubmit(event) {
  if (!(event.target instanceof HTMLFormElement) || event.target.id !== "offlineDownloadForm") {
    return;
  }
  event.preventDefault();
  state.offlineDownloadError = "";
  const payload = offlineDownloadPayloadFromForm(event.target);
  fetchJson("/api/offline-maps/download", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  })
    .then((response) => {
      state.offlineMapStatus = {
        ...(state.offlineMapStatus || {}),
        download_job: response.download_job,
      };
      renderOfflineMapModal();
      scheduleOfflineMapPoll();
      setStatus(t("offline.startedDownload", { name: response.download_job.name }));
    })
    .catch((error) => {
      const message = localizedErrorMessage(error.message);
      state.offlineDownloadError = message;
      const alert = event.target.querySelector("#offlineDownloadError");
      if (alert) {
        alert.textContent = message;
        alert.classList.remove("hidden");
      }
      const estimate = event.target.querySelector("#offlineDownloadEstimate");
      if (estimate) {
        estimate.textContent = t("offline.downloadNotStarted", { message });
        estimate.classList.add("error");
      }
      if (state.offlineMapStatus?.download_job && !state.offlineMapStatus.download_job.running) {
        state.offlineMapStatus.download_job = null;
        const jobArea = offlineMapModalElement?.querySelector("#offlineDownloadJobArea");
        if (jobArea) {
          jobArea.innerHTML = offlineJobHtml(null);
        }
      }
      setStatus(message, true);
    });
}

/**
 * 功能：刷新离线地图管理状态。
 * 输入：无。
 * 输出：Promise，解析为最新离线地图状态。
 */
async function refreshOfflineMapStatus() {
  const payload = await fetchJson("/api/offline-maps");
  const previousJob = state.offlineMapStatus?.download_job;
  state.offlineMapStatus = payload;
  updateOfflineMapSettingsSummary(payload);
  renderOfflineMapModal();
  if (state.baseMap === "offline" && !hasActiveOfflineDisplayResource(payload)) {
    const noInstalledOfflineMaps = !hasOfflineResources(payload);
    const shouldOpenManager = state.offlineSelectionRequested && noInstalledOfflineMaps;
    state.offlineSelectionRequested = false;
    handleOfflineTerrainUnavailable({
      openManager: shouldOpenManager,
      preserveSettingsMode: shouldOpenManager || currentMapSourceMode() === "offline",
      messageKey: noInstalledOfflineMaps ? "offline.notInstalledPrompt" : "offline.unavailable",
    });
    scheduleOfflineMapPoll();
    return payload;
  }
  if (state.baseMap === "offline") {
    setBaseMap("offline");
  }
  state.offlineSelectionRequested = false;
  if (previousJob?.running && payload.download_job && !payload.download_job.running) {
    setStatus(currentLanguage() === "zh-Hans" && payload.download_job.message ? payload.download_job.message : t("offline.downloadEnded"));
  }
  scheduleOfflineMapPoll();
  return payload;
}

/**
 * 功能：在下载任务运行时定时刷新离线地图状态。
 * 输入：无。
 * 输出：无返回值；使用 timeout 安排下一次刷新。
 */
function scheduleOfflineMapPoll() {
  window.clearTimeout(state.offlineMapPollTimer);
  state.offlineMapPollTimer = 0;
  const modalHidden = offlineMapModalElement?.classList.contains("hidden") ?? true;
  const settingsVisible = state.activeMobileTab === "settings" || state.activeDetailTab === "settings";
  if (!state.offlineMapStatus?.download_job?.running || (modalHidden && !settingsVisible)) {
    return;
  }
  state.offlineMapPollTimer = window.setTimeout(() => {
    refreshOfflineMapStatus().catch(setErrorStatus);
  }, 1400);
}

/**
 * 功能：获取 `fetchJson` 对应的业务逻辑。
 * 输入：path、options。
 * 输出：Promise，解析为函数处理结果。
 */
async function fetchJson(path, options = {}) {
  const response = await fetch(path, options);
  let data = {};
  try {
    data = await response.json();
  } catch (_error) {
    if (response.ok) {
      throw new Error(t("error.invalidJson"));
    }
  }
  if (!response.ok) {
    throw new Error(data.error || `Request failed: ${response.status}`);
  }
  return data;
}

/**
 * 功能：执行 `debounce` 对应的业务逻辑。
 * 输入：fn、wait。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function debounce(fn, wait = 220) {
  let timeout;
  return (...args) => {
    window.clearTimeout(timeout);
    timeout = window.setTimeout(() => fn(...args), wait);
  };
}

/**
 * 功能：执行 `clampZoom` 对应的业务逻辑。
 * 输入：mapInstance、zoom。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function clampZoom(mapInstance, zoom) {
  const minZoom = mapInstance.getMinZoom();
  const maxZoom = mapInstance.getMaxZoom();
  return Math.max(minZoom, Math.min(maxZoom, zoom));
}

/**
 * 功能：获取地图容器内的事件坐标。
 * 输入：mapInstance、event。
 * 输出：Leaflet point。
 */
function mapContainerPointFromEvent(mapInstance, event) {
  const container = mapInstance.getContainer();
  const bounds = container.getBoundingClientRect();
  return L.point(event.clientX - bounds.left, event.clientY - bounds.top);
}

/**
 * 功能：按地图容器坐标缩放，供滚轮、触控板和双击共用。
 * 输入：mapInstance、anchorPoint、zoom、options。
 * 输出：更新地图相机。
 */
function zoomAroundContainerPoint(mapInstance, anchorPoint, zoom, options = {}) {
  const nextZoom = clampZoom(mapInstance, zoom);
  mapInstance.setZoomAround(anchorPoint, nextZoom, options);
}

/**
 * 功能：取消尚未打开的地图 popup 点击动作。
 * 输入：无。
 * 输出：清空 pending timer。
 */
function cancelPendingMapPopupAction() {
  if (!state.pendingMapPopupTimer) {
    return;
  }
  window.clearTimeout(state.pendingMapPopupTimer);
  state.pendingMapPopupTimer = 0;
}

/**
 * 功能：在地图缩放手势期间临时禁止 popup 点击动作。
 * 输入：duration 为保护时长。
 * 输出：取消待打开 popup，并设置保护时间窗。
 */
function suppressMapPopupActions(duration = MAP_ZOOM.doubleClickPopupGuard) {
  cancelPendingMapPopupAction();
  state.mapPopupSuppressUntil = Math.max(
    state.mapPopupSuppressUntil || 0,
    window.performance.now() + duration,
  );
}

/**
 * 功能：判断当前地图点击是否应被双击/缩放手势吞掉。
 * 输入：event 为 Leaflet 事件。
 * 输出：需要忽略 popup 动作时返回 true。
 */
function shouldSuppressMapPopupAction(event) {
  if (window.performance.now() < (state.mapPopupSuppressUntil || 0)) {
    return true;
  }
  if ((event?.originalEvent?.detail || 0) > 1) {
    suppressMapPopupActions();
    return true;
  }
  return false;
}

/**
 * 功能：延迟执行地图 popup 动作，让双击缩放有机会取消第一次点击。
 * 输入：event、action。
 * 输出：调度成功返回 true。
 */
function scheduleMapPopupAction(event, action) {
  stopMapEvent(event);
  if (event?._plannerMapPopupScheduled || event?.originalEvent?._plannerMapPopupScheduled) {
    if (shouldSuppressMapPopupAction(event)) {
      return false;
    }
    action();
    return true;
  }
  if (shouldSuppressMapPopupAction(event)) {
    return false;
  }
  cancelPendingMapPopupAction();
  const delay = (event?.originalEvent?.detail || 0) === 1
    ? MAP_ZOOM.doubleClickPopupDelay
    : 0;
  const run = () => {
    state.pendingMapPopupTimer = 0;
    if (window.performance.now() < (state.mapPopupSuppressUntil || 0)) {
      return;
    }
    if (event) {
      event._plannerMapPopupScheduled = true;
    }
    if (event?.originalEvent) {
      event.originalEvent._plannerMapPopupScheduled = true;
    }
    try {
      action();
    } finally {
      if (event) {
        event._plannerMapPopupScheduled = false;
      }
      if (event?.originalEvent) {
        event.originalEvent._plannerMapPopupScheduled = false;
      }
    }
  };
  if (delay <= 0) {
    run();
  } else {
    state.pendingMapPopupTimer = window.setTimeout(run, delay);
  }
  return true;
}

/**
 * 功能：规范化 `normalizeWheelDelta` 对应的业务逻辑。
 * 输入：event。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function normalizeWheelDelta(event) {
  let modeMultiplier = 1;
  if (typeof WheelEvent !== "undefined" && event.deltaMode === WheelEvent.DOM_DELTA_LINE) {
    modeMultiplier = 18;
  } else if (typeof WheelEvent !== "undefined" && event.deltaMode === WheelEvent.DOM_DELTA_PAGE) {
    modeMultiplier = 320;
  }
  return -event.deltaY * modeMultiplier * MAP_ZOOM.wheelSpeed;
}

/**
 * 功能：处理地图缩放手势结束后的视觉状态。
 * 输入：container、delay。
 * 输出：延迟移除缩放中的 class。
 */
function finishMapInputZoom(container, delay = MAP_ZOOM.wheelIdleDelay) {
  window.clearTimeout(container._plannerZoomIdleTimer || 0);
  container._plannerZoomIdleTimer = window.setTimeout(() => {
    container.classList.remove("is-smooth-zooming");
    container._plannerZoomIdleTimer = 0;
  }, delay);
}

/**
 * 功能：安装 `installSmoothWheelZoom` 对应的业务逻辑。
 * 输入：mapInstance。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function installSmoothWheelZoom(mapInstance) {
  const container = mapInstance.getContainer();
  let queuedDelta = 0;
  let anchorPoint = null;
  let frameId = 0;

  const applyZoom = () => {
    frameId = 0;
    if (!queuedDelta || !anchorPoint) {
      return;
    }
    const frameDelta = Math.max(-MAP_ZOOM.wheelMaxFrameDelta, Math.min(MAP_ZOOM.wheelMaxFrameDelta, queuedDelta));
    queuedDelta = 0;
    zoomAroundContainerPoint(mapInstance, anchorPoint, mapInstance.getZoom() + frameDelta, { animate: false });
  };

  container.addEventListener(
    "wheel",
    (event) => {
      if (event.defaultPrevented) {
        return;
      }
      event.preventDefault();
      anchorPoint = mapContainerPointFromEvent(mapInstance, event);
      queuedDelta += normalizeWheelDelta(event);
      container.classList.add("is-smooth-zooming");
      finishMapInputZoom(container);
      if (!frameId) {
        frameId = window.requestAnimationFrame(applyZoom);
      }
    },
    { passive: false },
  );
}

/**
 * 功能：安装 WebKit 触控板捏合缩放。
 * 输入：mapInstance。
 * 输出：监听 gesturestart / gesturechange / gestureend。
 */
function installTrackpadGestureZoom(mapInstance) {
  const container = mapInstance.getContainer();
  let startZoom = mapInstance.getZoom();
  let anchorPoint = null;

  const resetGesture = () => {
    finishMapInputZoom(container);
    anchorPoint = null;
  };

  container.addEventListener(
    "gesturestart",
    (event) => {
      event.preventDefault();
      suppressMapPopupActions();
      startZoom = mapInstance.getZoom();
      anchorPoint = mapContainerPointFromEvent(mapInstance, event);
      container.classList.add("is-smooth-zooming");
    },
    { passive: false },
  );
  container.addEventListener(
    "gesturechange",
    (event) => {
      if (!anchorPoint) {
        anchorPoint = mapContainerPointFromEvent(mapInstance, event);
      }
      event.preventDefault();
      suppressMapPopupActions();
      const scale = Math.max(0.05, Number(event.scale) || 1);
      const delta = Math.log2(scale) * MAP_ZOOM.trackpadGestureSpeed;
      container.classList.add("is-smooth-zooming");
      zoomAroundContainerPoint(mapInstance, anchorPoint, startZoom + delta, { animate: false });
    },
    { passive: false },
  );
  container.addEventListener("gestureend", resetGesture, { passive: true });
  container.addEventListener("gesturecancel", resetGesture, { passive: true });
}

/**
 * 功能：安装主地图双击缩放，并阻止双击落到弹窗点击逻辑。
 * 输入：mapInstance。
 * 输出：dblclick 仅缩放地图，不打开航点 / 航路弹窗。
 */
function installMapDoubleClickZoom(mapInstance) {
  mapInstance.doubleClickZoom?.disable();
  const container = mapInstance.getContainer();
  container.addEventListener(
    "click",
    (event) => {
      if ((event.detail || 0) <= 1) {
        return;
      }
      suppressMapPopupActions();
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation?.();
    },
    { capture: true },
  );
  container.addEventListener(
    "dblclick",
    (event) => {
      if (event.target instanceof Element && event.target.closest(
        "button, input, textarea, select, a, .leaflet-control, .leaflet-popup, .map-type-menu, .offline-map-dialog",
      )) {
        return;
      }
      suppressMapPopupActions();
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation?.();
      const direction = event.shiftKey ? -1 : 1;
      const anchorPoint = mapContainerPointFromEvent(mapInstance, event);
      zoomAroundContainerPoint(
        mapInstance,
        anchorPoint,
        mapInstance.getZoom() + (MAP_ZOOM.doubleClickStep * direction),
        { animate: true },
      );
    },
    { capture: true },
  );
}

/**
 * 功能：禁用地图空白处双击/双击触控缩放，保留单指拖动、双指缩放和控件点击。
 * 输入：mapInstance 为 Leaflet 地图实例。
 * 输出：无返回值；关闭 doubleClickZoom 并拦截 dblclick 默认行为。
 */
function disableDoubleTapZoom(mapInstance) {
  mapInstance.doubleClickZoom?.disable();
  const container = mapInstance.getContainer();
  container.addEventListener(
    "dblclick",
    (event) => {
      if (event.target instanceof Element && event.target.closest("button, input, textarea, select, a")) {
        return;
      }
      event.preventDefault();
      event.stopPropagation();
    },
    { capture: true },
  );
}

/**
 * 功能：判断触控目标是否属于原生交互控件。
 * 输入：target 为事件目标。
 * 输出：按钮、输入框、链接、Leaflet 控件和弹窗类控件返回 true。
 */
function isNativeInteractiveTarget(target) {
  return target instanceof Element && Boolean(target.closest(
    "button, input, textarea, select, a, label, summary, [contenteditable='true'], .leaflet-control, .map-type-menu, .offline-map-dialog",
  ));
}

/**
 * 功能：阻止页面级双击放大，同时不影响输入框、按钮和地图控件的正常点击。
 * 输入：event 为 dblclick 或第二次 touchend 事件。
 * 输出：拦截成功返回 true。
 */
function suppressPageZoomEvent(event) {
  if (isNativeInteractiveTarget(event.target)) {
    return false;
  }
  if (event.target instanceof Element && event.target.closest("#map")) {
    return false;
  }
  event.preventDefault();
  event.stopPropagation();
  return true;
}

/**
 * 功能：防止 iOS WKWebView 在地图或面板空白处双击/双触时触发页面级放大。
 * 输入：无。
 * 输出：安装 document 级捕获监听；保留单指拖动、双指缩放、按钮点击和文本输入。
 */
function installPageDoubleTapZoomGuard() {
  let lastTouchEndAt = 0;
  document.addEventListener(
    "dblclick",
    (event) => {
      suppressPageZoomEvent(event);
    },
    { capture: true },
  );
  document.addEventListener(
    "touchend",
    (event) => {
      if (event.touches.length > 0 || event.changedTouches.length !== 1) {
        return;
      }
      if (isNativeInteractiveTarget(event.target)) {
        lastTouchEndAt = 0;
        return;
      }
      const timestamp = event.timeStamp || window.performance.now();
      if (timestamp - lastTouchEndAt > 0 && timestamp - lastTouchEndAt < DOUBLE_TAP_ZOOM_GUARD_MS) {
        suppressPageZoomEvent(event);
        lastTouchEndAt = 0;
        return;
      }
      lastTouchEndAt = timestamp;
    },
    { capture: true, passive: false },
  );
}

/**
 * 功能：锁住 iPhone WKWebView 页面级滚动，并在键盘出现时把工作台重新排进可见视口。
 * 输入：无。
 * 输出：安装轻量监听；键盘态隐藏底部 Tab，让当前输入面板停在键盘上方。
 */
function installMobileViewportLock() {
  if (!isPhoneWorkbench()) {
    return;
  }
  const root = document.documentElement;
  let layoutViewportHeight = Math.max(window.innerHeight || 0, document.documentElement.clientHeight || 0);
  const resetDocumentScroll = () => {
    const scrollingElement = document.scrollingElement || document.documentElement;
    if (window.scrollX || window.scrollY || scrollingElement.scrollTop || document.body.scrollTop) {
      window.scrollTo(0, 0);
      scrollingElement.scrollTop = 0;
      document.documentElement.scrollTop = 0;
      document.body.scrollTop = 0;
    }
  };
  const activeInputControl = () => {
    const active = document.activeElement;
    if (active instanceof Element && active.matches("input, textarea, select")) {
      return active;
    }
    return null;
  };
  const focusedControl = () => {
    const active = activeInputControl();
    if (active) {
      return active;
    }
    return state.mobileFocusedControl?.isConnected ? state.mobileFocusedControl : null;
  };
  const visualHeight = () => {
    const viewport = window.visualViewport;
    return Math.max(320, Math.round(viewport?.height || window.innerHeight || document.documentElement.clientHeight || 0));
  };
  const keyboardOverlap = () => {
    const viewport = window.visualViewport;
    if (!viewport) {
      return 0;
    }
    const currentLayoutHeight = Math.max(window.innerHeight || 0, document.documentElement.clientHeight || 0, layoutViewportHeight);
    if (!focusedControl() || viewport.height >= layoutViewportHeight - 2) {
      layoutViewportHeight = currentLayoutHeight;
    } else {
      layoutViewportHeight = Math.max(layoutViewportHeight, currentLayoutHeight);
    }
    return Math.max(0, layoutViewportHeight - viewport.height - Math.max(0, viewport.offsetTop || 0));
  };
  const refreshMapAfterLayout = () => {
    window.setTimeout(() => map.invalidateSize({ animate: false, pan: false }), 40);
    window.setTimeout(() => map.invalidateSize({ animate: false, pan: false }), 260);
  };
  const setKeyboardLayout = (open, overlap = 0) => {
    const roundedOverlap = Math.max(0, Math.round(overlap));
    const visible = open ? visualHeight() : 0;
    const changed = Boolean(document.body.dataset.mobileKeyboard) !== open
      || roundedOverlap !== state.mobileKeyboardLift
      || visible !== state.mobileVisualHeight;
    state.mobileKeyboardLift = roundedOverlap;
    state.mobileVisualHeight = visible;
    root.style.setProperty("--mobile-keyboard-height", `${roundedOverlap}px`);
    root.style.setProperty("--mobile-visual-height", open ? `${visible}px` : "100%");
    if (open) {
      document.body.dataset.mobileKeyboard = "open";
    } else {
      delete document.body.dataset.mobileKeyboard;
    }
    if (changed) {
      refreshMapAfterLayout();
    }
  };
  const ensureFocusedControlVisible = () => {
    const control = focusedControl();
    if (!control) {
      return;
    }
    const scrollHost = control.closest(".planner-panel, .detail-panel, .offline-map-panels, .offline-map-dialog");
    if (!(scrollHost instanceof HTMLElement)) {
      return;
    }
    const viewport = window.visualViewport;
    const viewportTop = Math.max(0, Math.round(viewport?.offsetTop || 0));
    const viewportBottom = Math.round((viewport?.height || window.innerHeight || document.documentElement.clientHeight || 0) + viewportTop);
    const rect = control.getBoundingClientRect();
    const hostRect = scrollHost.getBoundingClientRect();
    const topLimit = Math.max(hostRect.top, viewportTop) + MOBILE_KEYBOARD_MARGIN_PX;
    const bottomLimit = Math.min(hostRect.bottom, viewportBottom) - MOBILE_KEYBOARD_MARGIN_PX;
    if (rect.bottom > bottomLimit) {
      scrollHost.scrollTop += Math.ceil(rect.bottom - bottomLimit);
    } else if (rect.top < topLimit) {
      scrollHost.scrollTop -= Math.ceil(topLimit - rect.top);
    }
  };
  const updateKeyboardLayout = () => {
    state.mobileKeyboardFrame = 0;
    resetDocumentScroll();
    const control = focusedControl();
    const overlap = keyboardOverlap();
    const open = Boolean(control && overlap > MOBILE_KEYBOARD_MIN_OVERLAP_PX);
    setKeyboardLayout(open, open ? overlap : 0);
    if (open) {
      window.requestAnimationFrame(ensureFocusedControlVisible);
      window.setTimeout(ensureFocusedControlVisible, 150);
    }
  };
  const scheduleKeyboardLayout = () => {
    if (state.mobileKeyboardFrame) {
      window.cancelAnimationFrame(state.mobileKeyboardFrame);
    }
    state.mobileKeyboardFrame = window.requestAnimationFrame(updateKeyboardLayout);
  };
  const scheduleReset = () => {
    window.requestAnimationFrame(resetDocumentScroll);
    window.setTimeout(resetDocumentScroll, 80);
    scheduleKeyboardLayout();
  };
  window.addEventListener("scroll", scheduleReset, { passive: true });
  window.visualViewport?.addEventListener?.("resize", scheduleReset, { passive: true });
  window.visualViewport?.addEventListener?.("scroll", scheduleReset, { passive: true });
  document.addEventListener(
    "focusin",
    (event) => {
      if (event.target instanceof Element && event.target.matches("input, textarea, select")) {
        state.mobileFocusedControl = event.target;
        window.clearTimeout(state.mobileKeyboardResetTimer);
        scheduleReset();
        window.setTimeout(scheduleKeyboardLayout, 80);
        window.setTimeout(scheduleKeyboardLayout, 160);
        window.setTimeout(scheduleKeyboardLayout, 280);
        window.setTimeout(scheduleKeyboardLayout, 460);
        window.setTimeout(scheduleKeyboardLayout, 660);
      }
    },
    true,
  );
  document.addEventListener(
    "focusout",
    () => {
      scheduleReset();
      window.clearTimeout(state.mobileKeyboardResetTimer);
      state.mobileKeyboardResetTimer = window.setTimeout(() => {
        if (!activeInputControl()) {
          state.mobileFocusedControl = null;
          setKeyboardLayout(false, 0);
        }
      }, 110);
    },
    true,
  );
  scheduleReset();
}

function clampMobilePanelMapRatio(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return MOBILE_PANEL_DEFAULT_MAP_RATIO;
  }
  const clamped = Math.max(MOBILE_PANEL_MIN_MAP_RATIO, Math.min(MOBILE_PANEL_DEFAULT_MAP_RATIO, numeric));
  if (Math.abs(clamped - MOBILE_PANEL_DEFAULT_MAP_RATIO) < MOBILE_PANEL_RATIO_STEP) {
    return MOBILE_PANEL_DEFAULT_MAP_RATIO;
  }
  if (Math.abs(clamped - MOBILE_PANEL_MIN_MAP_RATIO) < MOBILE_PANEL_RATIO_STEP) {
    return MOBILE_PANEL_MIN_MAP_RATIO;
  }
  return Math.round(clamped / MOBILE_PANEL_RATIO_STEP) * MOBILE_PANEL_RATIO_STEP;
}

function scheduleMobilePanelMapResize() {
  if (state.mobilePanelResizeFrame) {
    return;
  }
  state.mobilePanelResizeFrame = window.requestAnimationFrame(() => {
    state.mobilePanelResizeFrame = 0;
    map.invalidateSize({ animate: false, pan: false });
    scheduleVectorMapResizeSync();
  });
}

function applyMobilePanelStateDataset(ratio) {
  document.body.dataset.mobilePanel = ratio <= MOBILE_PANEL_MIN_MAP_RATIO + 0.5 ? "expanded" : "custom";
  if (Math.abs(ratio - MOBILE_PANEL_DEFAULT_MAP_RATIO) < 0.5) {
    delete document.body.dataset.mobilePanel;
  }
}

function mobilePanelPanelRatioForMapRatio(ratio) {
  return Math.max(100 - ratio, 100 - MOBILE_PANEL_DEFAULT_MAP_RATIO);
}

function setMobilePanelDragVariable(name, value) {
  const rootStyle = document.documentElement.style;
  if (rootStyle.getPropertyValue(name) === value) {
    return;
  }
  rootStyle.setProperty(name, value);
}

function clearMobilePanelDragVariables() {
  ["--mobile-map-row-size", "--mobile-panel-row-size"].forEach((name) => {
    document.documentElement.style.removeProperty(name);
  });
  state.mobilePanelMapRowValue = "";
  state.mobilePanelPanelRowValue = "";
}

function activeMobilePanelElement() {
  const candidates = [document.querySelector(".planner-panel"), document.querySelector(".detail-panel")];
  return candidates.find((element) => {
    if (!element) {
      return false;
    }
    const style = window.getComputedStyle(element);
    return style.display !== "none" && style.visibility !== "hidden";
  }) || candidates.find(Boolean) || null;
}

function mobilePanelTrackHeight() {
  const mapRect = document.querySelector(".map-wrap")?.getBoundingClientRect();
  const panelRect = activeMobilePanelElement()?.getBoundingClientRect();
  const total = (mapRect?.height || 0) + (panelRect?.height || 0);
  return Math.max(1, total || window.innerHeight || 1);
}

function applyMobilePanelDragRatio(value, drag = state.mobilePanelDrag) {
  if (!drag) {
    return;
  }
  const ratio = clampMobilePanelMapRatio(value);
  const panelRatio = mobilePanelPanelRatioForMapRatio(ratio);
  const trackHeight = Math.max(1, drag.trackHeight || mobilePanelTrackHeight());
  const mapRowValue = `${(trackHeight * (ratio / 100)).toFixed(2)}px`;
  const panelRowValue = `${(trackHeight * (panelRatio / 100)).toFixed(2)}px`;
  drag.lastRatio = ratio;
  state.mobilePanelMapRatio = ratio;
  if (state.mobilePanelMapRowValue !== mapRowValue) {
    setMobilePanelDragVariable("--mobile-map-row-size", mapRowValue);
    state.mobilePanelMapRowValue = mapRowValue;
  }
  if (state.mobilePanelPanelRowValue !== panelRowValue) {
    setMobilePanelDragVariable("--mobile-panel-row-size", panelRowValue);
    state.mobilePanelPanelRowValue = panelRowValue;
  }
}

function applyMobilePanelMapRatio(value, options = {}) {
  const ratio = clampMobilePanelMapRatio(value);
  state.mobilePanelMapRatio = ratio;
  const panelRatio = mobilePanelPanelRatioForMapRatio(ratio);
  const mapFlexValue = `${ratio}fr`;
  const panelFlexValue = `${panelRatio}fr`;
  if (state.mobilePanelMapFlexValue !== mapFlexValue) {
    document.documentElement.style.setProperty("--mobile-map-flex", mapFlexValue);
    state.mobilePanelMapFlexValue = mapFlexValue;
  }
  if (state.mobilePanelPanelFlexValue !== panelFlexValue) {
    document.documentElement.style.setProperty("--mobile-panel-flex", panelFlexValue);
    state.mobilePanelPanelFlexValue = panelFlexValue;
  }
  if (!options.dragging) {
    delete document.body.dataset.mobilePanelDragging;
    delete document.body.dataset.mobilePanelPressing;
    applyMobilePanelStateDataset(ratio);
    scheduleMobilePanelMapResize();
  }
}

function installMobilePanelDragHandle() {
  const handle = elements.mobilePanelDragHandle;
  if (!handle || !isPhoneWorkbench()) {
    return;
  }
  applyMobilePanelMapRatio(state.mobilePanelMapRatio);
  const isPortraitPhone = () => !window.matchMedia || window.matchMedia("(orientation: portrait)").matches;
  const armTapGuard = (drag) => {
    state.mobilePanelTapGuard = {
      until: performance.now() + 460,
      x: drag?.lastX ?? drag?.startX ?? 0,
      y: drag?.lastY ?? drag?.startY ?? 0,
    };
  };
  const suppressGuardedTapEvent = (event) => {
    const guard = state.mobilePanelTapGuard;
    if (!guard) {
      return;
    }
    if (performance.now() > guard.until) {
      state.mobilePanelTapGuard = null;
      return;
    }
    if (event.type === "focusin" && event.target && typeof event.target.blur === "function") {
      event.target.blur();
    }
    event.preventDefault?.();
    event.stopPropagation?.();
    event.stopImmediatePropagation?.();
  };
  ["click", "auxclick", "mouseup", "mousedown", "touchend", "focusin"].forEach((type) => {
    document.addEventListener(type, suppressGuardedTapEvent, { capture: true, passive: false });
  });
  const togglePanelByTap = () => {
    const isExpanded = state.mobilePanelMapRatio <= MOBILE_PANEL_MIN_MAP_RATIO + 0.5;
    const targetRatio = isExpanded ? MOBILE_PANEL_DEFAULT_MAP_RATIO : MOBILE_PANEL_MIN_MAP_RATIO;
    window.requestAnimationFrame(() => {
      applyMobilePanelMapRatio(targetRatio);
      window.setTimeout(() => map.invalidateSize({ animate: false, pan: false }), 180);
    });
  };
  const cancelPendingDragFrame = () => {
    if (state.mobilePanelDragFrame) {
      window.cancelAnimationFrame(state.mobilePanelDragFrame);
      state.mobilePanelDragFrame = 0;
    }
    state.mobilePanelDragPendingRatio = null;
  };
  const scheduleDragRatio = (ratio) => {
    const nextRatio = clampMobilePanelMapRatio(ratio);
    if (
      state.mobilePanelDragPendingRatio !== null
      && Math.abs(state.mobilePanelDragPendingRatio - nextRatio) < 0.01
    ) {
      return;
    }
    if (
      state.mobilePanelDragPendingRatio === null
      && Math.abs(state.mobilePanelMapRatio - nextRatio) < 0.01
    ) {
      return;
    }
    state.mobilePanelDragPendingRatio = nextRatio;
    if (state.mobilePanelDragFrame) {
      return;
    }
    state.mobilePanelDragFrame = window.requestAnimationFrame(() => {
      state.mobilePanelDragFrame = 0;
      const pendingRatio = state.mobilePanelDragPendingRatio;
      state.mobilePanelDragPendingRatio = null;
      if (pendingRatio !== null && state.mobilePanelDrag?.previewing) {
        applyMobilePanelDragRatio(pendingRatio);
      }
    });
  };
  const finishDrag = (event) => {
    const drag = state.mobilePanelDrag;
    if (!drag) {
      return;
    }
    event?.preventDefault?.();
    event?.stopPropagation?.();
    event?.stopImmediatePropagation?.();
    if (event && Number.isFinite(event.clientX) && Number.isFinite(event.clientY)) {
      drag.lastX = event.clientX;
      drag.lastY = event.clientY;
    }
    const finalRatio = state.mobilePanelDragPendingRatio;
    cancelPendingDragFrame();
    const commitRatio = finalRatio !== null
      ? clampMobilePanelMapRatio(finalRatio)
      : (drag.lastRatio ?? drag.startRatio);
    state.mobilePanelDrag = null;
    delete document.body.dataset.mobilePanelPressing;
    if (!drag.moved) {
      delete document.body.dataset.mobilePanelDragging;
      clearMobilePanelDragVariables();
      armTapGuard(drag);
      togglePanelByTap();
      return;
    }
    if (drag.previewing) {
      applyMobilePanelDragRatio(commitRatio, drag);
    }
    applyMobilePanelMapRatio(commitRatio, { dragging: true });
    applyMobilePanelStateDataset(commitRatio);
    window.requestAnimationFrame(() => {
      delete document.body.dataset.mobilePanelDragging;
      clearMobilePanelDragVariables();
      scheduleMobilePanelMapResize();
      flushDeferredVectorMapResizeSync();
      window.setTimeout(() => map.invalidateSize({ animate: false, pan: false }), 120);
    });
  };

  handle.addEventListener("pointerdown", (event) => {
    if (document.body.dataset.mobileKeyboard === "open" || !isPortraitPhone()) {
      return;
    }
    event.preventDefault();
    handle.setPointerCapture?.(event.pointerId);
    const shellRect = document.querySelector(".shell")?.getBoundingClientRect();
    state.mobilePanelDrag = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      lastX: event.clientX,
      lastY: event.clientY,
      startRatio: state.mobilePanelMapRatio,
      shellHeight: Math.max(1, shellRect?.height || window.innerHeight || 1),
      trackHeight: mobilePanelTrackHeight(),
      moved: false,
      previewing: false,
    };
    document.body.dataset.mobilePanelPressing = "true";
  });

  handle.addEventListener("pointermove", (event) => {
    const drag = state.mobilePanelDrag;
    if (!drag || drag.pointerId !== event.pointerId) {
      return;
    }
    event.preventDefault();
    const trackHeight = Math.max(1, drag.trackHeight || drag.shellHeight || 1);
    const deltaRatio = ((event.clientY - drag.startY) / trackHeight) * 100;
    const nextRatio = drag.startRatio + deltaRatio;
    if (Math.abs(event.clientY - drag.startY) > 6) {
      drag.moved = true;
      if (!drag.previewing) {
        drag.previewing = true;
        document.body.dataset.mobilePanelDragging = "true";
        applyMobilePanelDragRatio(nextRatio, drag);
      }
    }
    drag.lastX = event.clientX;
    drag.lastY = event.clientY;
    if (drag.previewing) {
      scheduleDragRatio(nextRatio);
    }
  });

  handle.addEventListener("pointerup", finishDrag);
  handle.addEventListener("pointercancel", finishDrag);
  handle.addEventListener("lostpointercapture", finishDrag);
  window.addEventListener("resize", () => applyMobilePanelMapRatio(state.mobilePanelMapRatio));
  window.addEventListener("orientationchange", () => {
    finishDrag();
    window.setTimeout(() => applyMobilePanelMapRatio(state.mobilePanelMapRatio), 180);
  });
}

/**
 * 功能：在 iPhone WKWebView 的真实点击阶段兜底唤起输入框编辑态。
 * 输入：无。
 * 输出：只处理表单控件点击，不抢占 touchstart 原生输入流程。
 */
function installMobileInputTouchFocus() {
  if (!isPhoneWorkbench()) {
    return;
  }
  const focusControl = (control) => {
    if (!control || control.disabled || control.readOnly) {
      return;
    }
    if (document.activeElement !== control) {
      try {
        control.focus({ preventScroll: true });
      } catch (_error) {
        control.focus();
      }
    }
    if (typeof control.setSelectionRange === "function" && control.value) {
      const end = control.value.length;
      control.setSelectionRange(end, end);
    }
  };
  // iOS WKWebView 在 touchstart 阶段强制 focus 会导致键盘闪现后被系统点击流程关闭。
  // 这里只在 click 用户手势阶段兜底，原生单击聚焦路径优先。
  document.addEventListener(
    "click",
    (event) => {
      const control = event.target instanceof Element
        ? event.target.closest("input, textarea, select")
        : null;
      if (!control || control.disabled || control.readOnly) {
        return;
      }
      focusControl(control);
    },
    { capture: true },
  );
}

/**
 * 功能：iPhone 横屏时只在刘海侧保留完整安全区，另一侧释放给工作台。
 * 输入：无。
 * 输出：在 html 上写入 data-landscape-notch-side，并随方向变化更新。
 */
function installPhoneLandscapeSafeAreaTuning() {
  if (!isPhoneWorkbench()) {
    return;
  }
  const root = document.documentElement;
  const landscapeQuery = typeof window.matchMedia === "function"
    ? window.matchMedia("(orientation: landscape)")
    : null;
  const currentOrientationAngle = () => {
    const angle = Number(window.screen?.orientation?.angle);
    if (Number.isFinite(angle)) {
      return angle;
    }
    return window.innerWidth >= window.innerHeight ? 90 : 0;
  };
  const isLandscape = () => landscapeQuery?.matches || window.innerWidth > window.innerHeight;
  const updateLandscapeSafeArea = () => {
    if (!isLandscape()) {
      delete root.dataset.landscapeNotchSide;
      return;
    }
    const normalized = ((currentOrientationAngle() % 360) + 360) % 360;
    root.dataset.landscapeNotchSide = normalized === 270 ? "right" : "left";
    window.setTimeout(() => map.invalidateSize({ animate: false, pan: false }), 80);
  };
  updateLandscapeSafeArea();
  window.setTimeout(updateLandscapeSafeArea, 160);
  window.addEventListener("resize", updateLandscapeSafeArea, { passive: true });
  window.addEventListener("orientationchange", updateLandscapeSafeArea, { passive: true });
  window.screen?.orientation?.addEventListener?.("change", updateLandscapeSafeArea);
  landscapeQuery?.addEventListener?.("change", updateLandscapeSafeArea);
}

/**
 * 功能：设置 `setStatus` 对应的业务逻辑。
 * 输入：text、isError。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function setStatus(text, isError = false) {
  elements.statusText.textContent = text;
  elements.statusText.classList.toggle("error", isError);
}

/**
 * 功能：获取设置页显示用的数据库文件名。
 * 输入：payload 为 header/status API 返回值。
 * 输出：可显示的数据库名称。
 */
function databaseDisplayName(payload = {}) {
  if (payload.database_name) {
    return payload.database_name;
  }
  const path = String(payload.database_path || "");
  return path.split(/[\\/]/).filter(Boolean).at(-1) || "navdata.sqlite";
}

/**
 * 功能：把本地数据库状态同步到设置页。
 * 输入：payload 为 header/status/import 结果。
 * 输出：无返回值；更新设置页面文案。
 */
function updateDatabaseStatus(payload = {}) {
  state.databaseStatus = payload;
  if (elements.databaseNameText) {
    elements.databaseNameText.textContent = databaseDisplayName(payload);
  }
  if (elements.databaseStatusText) {
    const ready = !payload.local_status || payload.local_status === "ready";
    const airacText = payload.current_airac ? `AIRAC ${payload.current_airac}` : "";
    const revisionText = payload.revision ? t("database.revision", { revision: payload.revision }) : "";
    const fallback = [airacText, revisionText].filter(Boolean).join(" / ") || (ready ? t("database.ready") : t("database.unavailable"));
    elements.databaseStatusText.textContent = currentLanguage() === "zh-Hans" && payload.message ? payload.message : fallback;
    elements.databaseStatusText.classList.toggle("settings-status-error", !ready);
  }
}

function formatDatabaseModified(timestamp) {
  const value = Number(timestamp || 0);
  if (!Number.isFinite(value) || value <= 0) {
    return "--";
  }
  return new Intl.DateTimeFormat(currentLanguage(), {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value * 1000));
}

function updateDatabaseStorageSummary(payload = state.databaseListStatus) {
  state.databaseListStatus = payload || null;
  if (!elements.databaseStorageSummary) {
    return;
  }
  if (!payload) {
    elements.databaseStorageSummary.textContent = t("database.storageInitial");
    return;
  }
  elements.databaseStorageSummary.textContent = t("database.storageSummary", {
    count: formatCount(payload.file_count || 0),
    size: formatBytes(payload.size_bytes || 0),
  });
}

function databaseBadgeList(item = {}) {
  const badges = [];
  if (item.active) {
    badges.push(t("database.active"));
  }
  if (item.built_in) {
    badges.push(t("database.builtIn"));
  }
  if (item.valid === false) {
    badges.push(t("database.invalid"));
  }
  return badges;
}

function databaseMetaParts(item = {}) {
  const parts = [];
  if (item.current_airac) {
    parts.push(t("database.airac", { airac: item.current_airac }));
  }
  if (item.revision) {
    parts.push(t("database.revision", { revision: item.revision }));
  }
  parts.push(formatBytes(item.size_bytes || 0));
  parts.push(t("database.modified", { time: formatDatabaseModified(item.modified_at) }));
  if (item.message) {
    parts.push(cleanErrorMessage(item.message));
  }
  return parts;
}

function renderDatabaseList(items = state.databaseItems) {
  if (!elements.databaseList) {
    return;
  }
  state.databaseItems = items || [];
  if (!state.databaseItems.length) {
    elements.databaseList.innerHTML = `<div class="query-empty">${escapeHtml(t("database.listEmpty"))}</div>`;
    return;
  }
  elements.databaseList.innerHTML = state.databaseItems.map((item) => {
    const name = String(item.name || "");
    const badges = databaseBadgeList(item)
      .map((label) => `<span class="database-badge">${escapeHtml(label)}</span>`)
      .join("");
    const meta = databaseMetaParts(item)
      .map((part) => `<span>${escapeHtml(part)}</span>`)
      .join("");
    const canUse = item.valid !== false && !item.active;
    const canDelete = item.deletable === true;
    return `
      <div class="database-file-card${item.valid === false ? " is-invalid" : ""}">
        <div class="query-flight-head">
          <div>
            <div class="query-flight-number">${escapeHtml(name || "navdata.sqlite")}</div>
            <div class="query-flight-meta">${meta}</div>
          </div>
          <div class="database-badges">${badges}</div>
        </div>
        <div class="database-actions">
          <button class="ghost-button compact-button" type="button" data-database-action="select" data-database-name="${escapeHtml(name)}"${canUse ? "" : " disabled"}>${escapeHtml(t("database.use"))}</button>
          <button class="ghost-button compact-button danger-button" type="button" data-database-action="delete" data-database-name="${escapeHtml(name)}"${canDelete ? "" : " disabled"}>${escapeHtml(t("database.delete"))}</button>
        </div>
      </div>
    `;
  }).join("");
}

async function refreshDatabaseList({ announce = false } = {}) {
  if (elements.databaseList) {
    elements.databaseList.innerHTML = `<div class="query-empty">${escapeHtml(t("database.listLoading"))}</div>`;
  }
  const query = elements.databaseSearchInput?.value.trim() || "";
  const params = new URLSearchParams({ query, limit: "200" });
  const payload = await fetchJson(`/api/databases/list?${params.toString()}`);
  updateDatabaseStorageSummary(payload);
  if (payload.database) {
    updateDatabaseStatus(payload.database);
  }
  renderDatabaseList(payload.items || []);
  if (announce) {
    setStatus(t("database.listLoaded", { count: payload.file_count || 0 }));
  }
  return payload;
}

async function applyDatabaseManagementPayload(payload = {}, { invalidate = false, statusKey = "database.switched" } = {}) {
  if (payload.database) {
    updateDatabaseStatus(payload.database);
  } else {
    updateDatabaseStatus(payload);
  }
  if (payload.databases) {
    updateDatabaseStorageSummary(payload.databases);
    renderDatabaseList(payload.databases.items || []);
  } else {
    await refreshDatabaseList({ announce: false });
  }
  if (invalidate) {
    resetDatabaseDependentCaches();
    try {
      await refreshHeaderStatus({ announce: false });
      await refreshNavOverlay();
    } catch (error) {
      setErrorStatus(error);
      return;
    }
  }
  const message = currentLanguage() === "zh-Hans" && payload.message ? payload.message : t(statusKey);
  setStatus(message);
}

async function selectStoredDatabase(name) {
  if (!name) {
    return;
  }
  const payload = await fetchJson("/api/databases/select", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  await applyDatabaseManagementPayload(payload, { invalidate: true, statusKey: "database.switched" });
}

async function deleteStoredDatabase(name) {
  if (!name) {
    return;
  }
  if (!window.confirm(t("database.deleteConfirm", { name }))) {
    return;
  }
  const payload = await fetchJson("/api/databases/delete", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  await applyDatabaseManagementPayload(payload, { statusKey: "database.deleted" });
}

async function restoreBundledDatabase() {
  const payload = await fetchJson("/api/databases/restore-bundled", { method: "POST" });
  await applyDatabaseManagementPayload(payload, { invalidate: true, statusKey: "database.restored" });
}

function handleDatabaseListAction(event) {
  const button = event.target.closest("[data-database-action]");
  if (!button) {
    return;
  }
  const name = button.dataset.databaseName || "";
  if (button.dataset.databaseAction === "select") {
    selectStoredDatabase(name).catch(setErrorStatus);
    return;
  }
  if (button.dataset.databaseAction === "delete") {
    deleteStoredDatabase(name).catch(setErrorStatus);
  }
}

/**
 * 功能：刷新 header，同时同步设置页数据库状态。
 * 输入：announce 表示是否把状态写入 Plan 状态栏。
 * 输出：Promise，解析为 header payload。
 */
async function refreshHeaderStatus({ announce = true } = {}) {
  const header = await fetchJson("/api/header");
  updateDatabaseStatus(header);
  if (announce) {
    setStatus(t("database.loaded", { airac: header.current_airac || "--", revision: header.revision || "--" }));
  }
  return header;
}

/**
 * 功能：清理与数据库内容相关的前端缓存，避免切库后沿用旧查询结果。
 * 输入：无。
 * 输出：无返回值；下一次刷新会重新读取本地数据库。
 */
function resetDatabaseDependentCaches() {
  state.procedureCache.clear();
  state.airportPopupCache.clear();
  state.navOverlayPayload = null;
  state.navOverlayFetchBounds = null;
  state.navOverlayDrawBounds = null;
  state.navOverlayZoom = null;
  state.navOverlayDrawZoom = null;
}

/**
 * 功能：请求 Swift 侧弹出本地数据库文件选择器。
 * 输入：无。
 * 输出：无返回值；App 内通过 JS bridge 触发 UIDocumentPicker。
 */
function requestDatabaseSelection() {
  const handler = window.webkit?.messageHandlers?.navplanner;
  if (!handler) {
    setStatus(t("database.iosOnly"), true);
    return;
  }
  handler.postMessage({ type: "selectDatabase" });
}

/**
 * 功能：向 SwiftUI 外壳同步 Web 工作台状态。
 * 输入：type 为事件名，payload 为 JSON 兼容数据。
 * 输出：无返回值；非 iOS WebView 环境下静默忽略。
 */
function postNativeEvent(type, payload = {}) {
  window.webkit?.messageHandlers?.navplanner?.postMessage({ type, payload });
}

/**
 * 功能：处理 Swift 导入数据库后的回调。
 * 输入：payload 为 Swift 本地服务状态。
 * 输出：无返回值；刷新 header、nav-overlay 和设置页。
 */
async function handleNativeDatabaseSelected(payload = {}) {
  updateDatabaseStatus(payload);
  if (payload.local_status === "cancelled") {
    setStatus(currentLanguage() === "zh-Hans" && payload.message ? payload.message : t("database.cancelled"));
    return;
  }
  if (payload.local_status && payload.local_status !== "ready") {
    setStatus(currentLanguage() === "zh-Hans" && payload.message ? payload.message : t("database.importFailed"), true);
    return;
  }
  resetDatabaseDependentCaches();
  setStatus(currentLanguage() === "zh-Hans" && payload.message ? payload.message : t("database.switched"));
  try {
    if (payload.databases) {
      updateDatabaseStorageSummary(payload.databases);
      renderDatabaseList(payload.databases.items || []);
    } else {
      await refreshDatabaseList({ announce: false });
    }
    await refreshHeaderStatus({ announce: false });
    await refreshNavOverlay();
  } catch (error) {
    setErrorStatus(error);
  }
}

function refreshLocalizedDynamicText() {
  updateLayoutButtonLabels();
  updateMapTypeOptionLabels();
  updateMapTypeOptionState();
  updateMapTileZoomOffsetControl();
  updateMapOverlayControlLabels();
  updateTrackHistoryControlLabels();
  updateOfflineMapControlLabel();
  if (state.databaseStatus) {
    updateDatabaseStatus(state.databaseStatus);
  }
  updateDatabaseStorageSummary(state.databaseListStatus);
  renderDatabaseList(state.databaseItems);
  updateOfflineMapSettingsSummary(state.offlineMapStatus);
  updateMapCacheSummary(state.mapCacheStatus);
  updateFR24CacheSummary(state.fr24CacheStatus || {});
  updateFR24AccessSummary(state.fr24AccessStatus || {});
  updateFR24ProfilePanel();
  renderFR24Flights(state.fr24SearchFlights);
  updateAirportPanelVisibility();
  AIRPORT_SLOTS.forEach((slot) => {
    const payload = state.airportPayloads[slot];
    if (payload) {
      renderAirportPayload(slot, payload);
    } else {
      renderRunwayButtons(slot);
    }
  });
  renderSelectedProcedures();
  if (state.activeSelectionProcedure) {
    const { type, airport, procedure, transition, payload } = state.activeSelectionProcedure;
    renderProcedureSelectionTable(type, airport, procedure, transition, payload);
  }
  if (offlineMapModalElement && !offlineMapModalElement.classList.contains("hidden")) {
    renderOfflineMapModal();
  }
  refreshActiveNavPopup();
}

function updateLayoutButtonLabels() {
  if (elements.mapExpandButton) {
    const mapExpanded = document.body.classList.contains("map-expanded");
    const label = mapExpanded ? t("layout.restoreMap") : t("layout.expandMap");
    elements.mapExpandButton.setAttribute("aria-label", label);
    elements.mapExpandButton.setAttribute("title", label);
  }
  if (elements.sidebarExpandButton) {
    const sidebarExpanded = document.body.classList.contains("left-panel-expanded");
    const label = sidebarExpanded ? t("layout.restoreSidebar") : t("layout.expandSidebar");
    elements.sidebarExpandButton.setAttribute("aria-label", label);
    elements.sidebarExpandButton.setAttribute("title", label);
  }
}

function applyLanguageMode(mode, { persist = true, refresh = true } = {}) {
  const normalized = normalizeLanguageMode(mode);
  const effectiveLanguage = resolveLanguageMode(normalized);
  state.languageMode = normalized;
  state.effectiveLanguage = effectiveLanguage;
  document.documentElement.lang = effectiveLanguage;
  document.documentElement.dataset.languageMode = normalized;
  document.documentElement.dataset.language = effectiveLanguage;
  elements.languageChoiceButtons.forEach((button) => {
    const active = button.dataset.languageChoice === normalized;
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  if (persist) {
    writeLocalStorageValue("navplannerLanguageMode", normalized);
  }
  applyStaticTranslations();
  if (refresh) {
    refreshLocalizedDynamicText();
  }
}

/**
 * 功能：根据日间/夜间/系统自动设置应用主题。
 * 输入：mode 为 system/day/night，persist 表示是否写入 localStorage。
 * 输出：无返回值；通过 html data 属性驱动 CSS。
 */
function applyThemeMode(mode, { persist = true } = {}) {
  const normalized = THEME_MODES.has(mode) ? mode : "system";
  state.themeMode = normalized;
  const effectiveTheme = normalized === "system"
    ? (themeMediaQuery?.matches ? "day" : "night")
    : normalized;
  document.documentElement.dataset.themeMode = normalized;
  document.documentElement.dataset.theme = effectiveTheme;
  elements.themeChoiceButtons.forEach((button) => {
    const active = button.dataset.themeChoice === normalized;
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  if (persist) {
    writeLocalStorageValue("navplannerThemeMode", normalized);
  }
  postNativeEvent("themeChanged", {
    mode: normalized,
    effectiveTheme,
  });
}

/**
 * 功能：根据设置页选择切换 iOS 主屏幕 App 图标。
 * 输入：choice 为 day-high/primary/day-soft/night-high/night-medium/night-soft，persist 表示是否写入本地偏好。
 * 输出：无返回值；iOS App 内通过 Swift bridge 调用备用图标 API。
 */
function applyAppIconChoice(choice, { persist = true, notifyNative = true } = {}) {
  const normalized = APP_ICON_CHOICES.has(choice) ? choice : "primary";
  state.appIconChoice = normalized;
  elements.appIconChoiceButtons.forEach((button) => {
    const active = button.dataset.appIconChoice === normalized;
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  if (persist) {
    writeLocalStorageValue("navplannerAppIconChoice", normalized);
  }
  if (notifyNative) {
    postNativeEvent("setAppIcon", { iconChoice: normalized });
  }
}

function appIconChoiceLabel(choice) {
  const key = {
    "day-high": "appIcon.choice.dayHigh",
    primary: "appIcon.choice.primary",
    "day-soft": "appIcon.choice.daySoft",
    "night-high": "appIcon.choice.nightHigh",
    "night-medium": "appIcon.choice.nightMedium",
    "night-soft": "appIcon.choice.nightSoft",
  }[choice] || "appIcon.choice.primary";
  return t(key);
}

function appIconBridgeStatusMessage(payload = {}) {
  const rawMessage = cleanErrorMessage(payload.message || "");
  if (payload.error) {
    if (/不支持|unsupported/i.test(rawMessage)) {
      return t("appIcon.unsupported");
    }
    return currentLanguage() === "zh-Hans" && rawMessage ? rawMessage : t("appIcon.changeFailed");
  }
  if (/已是当前|already/i.test(rawMessage)) {
    return t("appIcon.alreadySelected");
  }
  return t("appIcon.changed", { name: appIconChoiceLabel(payload.icon_choice || state.appIconChoice) });
}

/**
 * 功能：处理 Swift 切换 App 图标后的回调。
 * 输入：payload 为 Swift 返回的状态。
 * 输出：无返回值；同步按钮状态和状态栏提示。
 */
function handleNativeAppIconChanged(payload = {}) {
  if (payload.icon_choice) {
    applyAppIconChoice(payload.icon_choice, { persist: true, notifyNative: false });
  }
  if (payload.message) {
    setStatus(appIconBridgeStatusMessage(payload), Boolean(payload.error));
  }
}

/**
 * 功能：切换 iPad 详情栏中的 Airport / Query / Calculate / Settings 页面。
 * 输入：tab 为 airport、query、calculate 或 settings。
 * 输出：无返回值；只切换右侧详情区域，不触碰地图状态。
 */
function setDetailTab(tab) {
  const normalized = ["airport", "query", "calculate", "settings"].includes(tab) ? tab : "airport";
  state.activeDetailTab = normalized;
  elements.detailModeTabButtons.forEach((button) => {
    const active = button.dataset.detailTab === normalized;
    button.classList.toggle("active", active);
    button.setAttribute("aria-selected", String(active));
  });
  elements.detailTabPanels.forEach((panel) => {
    panel.classList.toggle("hidden", panel.dataset.detailPanel !== normalized);
  });
  if (normalized === "settings") {
    updateMapTileZoomOffsetControl();
    refreshDatabaseList().catch((error) => console.warn("本地数据库列表刷新失败", error));
    refreshOfflineMapStatus().catch((error) => console.warn("离线地图状态刷新失败", error));
    refreshMapCacheStatus().catch((error) => console.warn("在线地图缓存状态刷新失败", error));
  }
  if (normalized === "query") {
    refreshFR24CacheStatus().catch((error) => console.warn("FR24 缓存状态刷新失败", error));
    refreshFR24AccessStatus().catch((error) => console.warn("FR24 访问状态刷新失败", error));
    scheduleFR24ProfileChartResize();
    scheduleFR24ProfileChartResize(180);
  }
  if (normalized === "calculate") {
    scheduleCalculateRender();
    scheduleCalculateRender(180);
  }
}

/**
 * 功能：切换 iPhone 下部 Plan / Airport / Query / Calculate / Settings 标签。
 * 输入：tab 为 plan、airport、query、calculate 或 settings。
 * 输出：无返回值；顶部地图保持原实例和当前视图。
 */
function setMobileBottomTab(tab) {
  const normalized = ["plan", "airport", "query", "calculate", "settings"].includes(tab) ? tab : "plan";
  const changed = normalized !== state.activeMobileTab;
  if (changed && document.activeElement instanceof HTMLElement) {
    document.activeElement.blur();
  }
  state.activeMobileTab = normalized;
  document.body.dataset.mobileTab = normalized;
  elements.mobileBottomTabButtons.forEach((button) => {
    const active = button.dataset.mobileTab === normalized;
    button.classList.toggle("active", active);
    button.setAttribute("aria-selected", String(active));
  });
  if (normalized === "airport" || normalized === "query" || normalized === "calculate" || normalized === "settings") {
    setDetailTab(normalized);
  }
  window.setTimeout(() => {
    map.invalidateSize({ pan: false });
    scheduleVectorMapResizeSync();
    if (normalized === "settings") {
      updateMapTileZoomOffsetControl();
    }
    if (normalized === "query") {
      scheduleFR24ProfileChartResize();
    }
    if (normalized === "calculate") {
      scheduleCalculateRender();
    }
  }, 90);
}

/**
 * 功能：设置 `setRouteControlsBusy` 对应的业务逻辑。
 * 输入：isBusy。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function setRouteControlsBusy(isBusy) {
  [elements.planButton, elements.recalculateButton, elements.fr24SearchButton].forEach((button) => {
    if (button) {
      button.disabled = isBusy;
    }
  });
  if (elements.stopRequestButton) {
    elements.stopRequestButton.disabled = !isBusy;
    elements.stopRequestButton.classList.toggle("hidden", !isBusy);
  }
}

/**
 * 功能：执行 `beginRouteOperation` 对应的业务逻辑。
 * 输入：label。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function beginRouteOperation(label) {
  state.activeRouteAbortController?.abort();
  const controller = new AbortController();
  state.activeRouteAbortController = controller;
  state.activeRouteOperation = label;
  setRouteControlsBusy(true);
  return controller;
}

/**
 * 功能：执行 `endRouteOperation` 对应的业务逻辑。
 * 输入：controller。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function endRouteOperation(controller) {
  if (state.activeRouteAbortController !== controller) {
    return;
  }
  state.activeRouteAbortController = null;
  state.activeRouteOperation = "";
  setRouteControlsBusy(false);
}

/**
 * 功能：执行 `stopActiveRouteOperation` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function stopActiveRouteOperation() {
  const controller = state.activeRouteAbortController;
  if (!controller) {
    return;
  }
  const label = state.activeRouteOperation || t("route.currentTask");
  controller.abort();
  state.activeRouteAbortController = null;
  state.activeRouteOperation = "";
  setRouteControlsBusy(false);
  setStatus(t("route.operationStopped", { label }));
}

/**
 * 功能：执行 `throwIfAborted` 对应的业务逻辑。
 * 输入：signal。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function throwIfAborted(signal) {
  if (signal?.aborted) {
    throw new DOMException("Operation was aborted.", "AbortError");
  }
}

/**
 * 功能：执行 `isAbortError` 对应的业务逻辑。
 * 输入：error。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function isAbortError(error) {
  return error?.name === "AbortError";
}

/**
 * 功能：执行 `cleanErrorMessage` 对应的业务逻辑。
 * 输入：message。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function cleanErrorMessage(message) {
  return String(message || "Request failed.")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 260);
}

/**
 * 功能：把常见底层英文错误转换为中文状态栏文案。
 * 输入：message 为后端或浏览器错误字符串。
 * 输出：中文优先的用户可见错误；未知文本原样保留。
 */
function localizedErrorMessage(message) {
  const clean = cleanErrorMessage(message);
  const replacements = [
    [/^Request failed:?\s*(\d+)\.?$/i, (_match, code) => t("error.http", { code })],
    [/^Failed to fetch\.?$/i, () => t("error.fetch")],
    [/^Load failed\.?$/i, () => t("error.fetch")],
    [/The Internet connection appears to be offline\.?/i, () => t("error.offline")],
    [/^Unknown navplanner host\.?$/i, () => t("error.unknownHost")],
    [/^Web resource not found\.?$/i, () => t("error.webNotFound")],
    [/^API not found\.?$/i, () => t("error.apiNotFound")],
    [/^Airport not found\.?$/i, () => t("error.airportNotFound")],
    [/^Offline maps API not found\.?$/i, () => t("error.offlineApi")],
    [/^PMTiles resource not found\.?$/i, () => t("error.pmtilesNotFound")],
    [/^Invalid map tile path\.?$/i, () => t("error.tilePath")],
    [/^Invalid map tile coordinate\.?$/i, () => t("error.tileCoord")],
    [/^Track match requires POST\.?$/i, () => t("error.trackPost")],
    [/^Departure or arrival could not be resolved\.?$/i, () => t("error.airportsUnresolved")],
    [/^DCT must follow a known fix or airport\.?$/i, () => t("error.dctSource")],
    [/^DCT is missing the target fix\.?$/i, () => t("error.dctMissing")],
    [/^DCT target (.+) not found\.?$/i, (_match, fix) => t("error.dctTarget", { fix })],
    [/^\*\*\* must be between two fixes\.?$/i, () => t("error.starsBetween")],
    [/^\*\*\* is missing the target fix\.?$/i, () => t("error.starsMissing")],
    [/^\*\*\* source (.+) not found\.?$/i, (_match, fix) => t("error.starsSource", { fix })],
    [/^\*\*\* target (.+) not found\.?$/i, (_match, fix) => t("error.starsTarget", { fix })],
    [/^Airway (.+) must follow a fix\.?$/i, (_match, airway) => t("error.airwaySource", { airway })],
    [/^Airway (.+) is missing an exit fix\.?$/i, (_match, airway) => t("error.airwayExit", { airway })],
    [/^Exit fix (.+) not found\.?$/i, (_match, fix) => t("error.exitFix", { fix })],
    [/^Airway (.+) does not connect (.+) to (.+)\.?$/i, (_match, airway, from, to) => t("error.airwayConnect", { airway, from, to })],
    [/^Waypoint (.+) not found\.?$/i, (_match, fix) => t("error.waypoint", { fix })],
    [/^No legal airway path could be built from the imported trajectory\.?$/i, () => t("error.trackNoPath")],
    [/^No drawable route points could be built from the imported trajectory\.?$/i, () => t("error.trackNoPoints")],
    [/^FR24 web access was blocked\. Open FR24 verification in Query, complete verification, then sync the session\.?$/i, () => t("error.fr24Session")],
    [/^FR24 web access was blocked by Cloudflare verification\.?$/i, () => t("error.fr24Cloudflare")],
    [/^FR24 web returned an HTML response\.?$/i, () => t("error.fr24Cloudflare")],
    [/^FR24 web playback did not return enough trajectory points\.?$/i, () => t("error.fr24NotEnough")],
    [/^FR24 flightId missing\.?$/i, () => t("error.fr24MissingId")],
  ];
  for (const [pattern, build] of replacements) {
    const match = clean.match(pattern);
    if (match) {
      return build(...match);
    }
  }
  return clean || t("error.requestFailed");
}

/**
 * 功能：显示统一本地化后的错误状态。
 * 输入：error 可以是 Error 或字符串。
 * 输出：无返回值；状态栏显示错误。
 */
function setErrorStatus(error) {
  setStatus(localizedErrorMessage(error?.message ?? error), true);
}

/**
 * 功能：格式化 `formatCoord` 对应的业务逻辑。
 * 输入：value、suffixes。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatCoord(value, suffixes) {
  if (value === null || value === undefined) {
    return "--";
  }
  const abs = Math.abs(value).toFixed(4);
  return `${abs}°${value >= 0 ? suffixes[0] : suffixes[1]}`;
}

/**
 * 功能：渲染 `renderSearchResults` 对应的业务逻辑。
 * 输入：container、items、onSelect。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function renderSearchResults(container, items, onSelect) {
  container.innerHTML = "";
  if (!items.length) {
    container.classList.add("hidden");
    return;
  }
  items.forEach((item) => {
    const row = document.createElement("button");
    row.type = "button";
    row.className = "search-item";
    row.innerHTML = `
      <div class="search-item-main">
        <div class="search-item-title">${escapeHtml(item.ident)}</div>
        <div class="search-item-subtitle">${escapeHtml(item.name)}</div>
      </div>
      <span class="search-kind-pill">${escapeHtml(item.kind)}</span>
    `;
    row.addEventListener("click", () => onSelect(item));
    container.appendChild(row);
  });
  [elements.departureResults, elements.arrivalResults, elements.manualResults]
    .filter((item) => item && item !== container)
    .forEach((item) => item.classList.add("hidden"));
  container.classList.remove("hidden");
}

/**
 * 功能：隐藏 `hideSearchResults` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function hideSearchResults() {
  state.searchSuppressedUntil = performance.now() + 350;
  elements.departureResults.classList.add("hidden");
  elements.arrivalResults.classList.add("hidden");
  elements.manualResults.classList.add("hidden");
}

/**
 * 功能：处理 `airportSlotForInput` 对应的业务逻辑。
 * 输入：target。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airportSlotForInput(target) {
  if (target === elements.arrivalInput) {
    return "arrival";
  }
  if (target === elements.manualInput) {
    return "manual";
  }
  return "departure";
}

/**
 * 功能：搜索 `searchEntities` 对应的业务逻辑。
 * 输入：target、container。
 * 输出：Promise，解析为函数处理结果。
 */
async function searchEntities(target, container) {
  if (performance.now() < state.searchSuppressedUntil) {
    container.classList.add("hidden");
    return;
  }
  if (document.activeElement !== target) {
    container.classList.add("hidden");
    return;
  }
  const query = target.value.trim();
  if (query.length < 2) {
    container.classList.add("hidden");
    container.innerHTML = "";
    return;
  }
  const payload = await fetchJson(`/api/search?q=${encodeURIComponent(query)}`);
  if (performance.now() < state.searchSuppressedUntil || document.activeElement !== target) {
    container.classList.add("hidden");
    return;
  }
  renderSearchResults(container, payload.results, (item) => {
    target.value = item.ident;
    container.classList.add("hidden");
    if (item.kind === "airport") {
      const slot = airportSlotForInput(target);
      loadAirportIntoPanel(item.ident, slot, { focusMap: true }).catch((error) => {
        setErrorStatus(error);
      });
      return;
    }
    flyToPoint(item);
  });
}

/**
 * 功能：执行 `markerKeyForPoint` 对应的业务逻辑。
 * 输入：point、options。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function markerKeyForPoint(point, options = {}) {
  return `${point.kind}:${point.ident}:${options.keySuffix || ""}`;
}

/**
 * 功能：移除 `removeAirportMarkerByKey` 对应的业务逻辑。
 * 输入：key。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function removeAirportMarkerByKey(key) {
  if (!key) {
    return;
  }
  const marker = state.airportMarkers.get(key);
  if (!marker) {
    return;
  }
  markerLayerGroup.removeLayer(marker);
  state.airportMarkers.delete(key);
}

/**
 * 功能：清理 `clearAirportSlotMarker` 对应的业务逻辑。
 * 输入：slot。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function clearAirportSlotMarker(slot) {
  if (!AIRPORT_SLOTS.includes(slot)) {
    return;
  }
  removeAirportMarkerByKey(state.airportSlotMarkerKeys[slot]);
  state.airportSlotMarkerKeys[slot] = null;
}

/**
 * 功能：执行 `resetAirportSlotMarkerKeys` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function resetAirportSlotMarkerKeys() {
  AIRPORT_SLOTS.forEach((slot) => {
    state.airportSlotMarkerKeys[slot] = null;
  });
}

/**
 * 功能：绘制 `drawAirportSlotMarker` 对应的业务逻辑。
 * 输入：slot、point。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function drawAirportSlotMarker(slot, point) {
  const keySuffix = `airport-slot:${slot}`;
  clearAirportSlotMarker(slot);
  const marker = drawPointMarker(point, true, { keySuffix });
  state.airportSlotMarkerKeys[slot] = markerKeyForPoint(point, { keySuffix });
  return marker;
}

/**
 * 功能：绘制 `drawPointMarker` 对应的业务逻辑。
 * 输入：point、highlighted、options。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function drawPointMarker(point, highlighted = false, options = {}) {
  const key = markerKeyForPoint(point, options);
  if (state.airportMarkers.has(key)) {
    return state.airportMarkers.get(key);
  }
  const radius = compactPhoneValue(highlighted ? 7 : 5, 0.72, highlighted ? 4.5 : 3.2);
  const marker = L.circleMarker([point.lat, point.lon], {
    pane: "pointPane",
    radius,
    color: highlighted ? "#2ee6c7" : "#00b4ff",
    weight: compactPhoneValue(2, 0.74, 1.2),
    fillColor: highlighted ? "#2ee6c7" : "#00b4ff",
    fillOpacity: highlighted ? 0.95 : 0.75,
    renderer: pointRenderer,
    bubblingMouseEvents: false,
  })
    .addTo(options.group || markerLayerGroup);
  marker.on("click", (event) => {
    scheduleMapPopupAction(event, () => {
      const popupPoint = options.popupPoint || normalizePopupPoint(point);
      showNavPointPopup(popupPoint, event.latlng);
    });
  });
  state.airportMarkers.set(key, marker);
  return marker;
}

/**
 * 功能：执行 `flyToPoint` 对应的业务逻辑。
 * 输入：point。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function flyToPoint(point) {
  drawPointMarker(point, true);
  map.flyTo([point.lat, point.lon], 8, { duration: 0.75 });
}

/**
 * 功能：渲染 `renderLegs` 对应的业务逻辑。
 * 输入：legs。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function renderLegs(legs) {
  state.airwayLegChips.clear();
  elements.routeLegs.innerHTML = "";
  if (!legs.length) {
    elements.routeLegs.innerHTML = `<div class="helper-text">${escapeHtml(t("route.noIntermediateLegs"))}</div>`;
    return;
  }
  legs.forEach((leg) => {
    const chip = document.createElement("div");
    const isDrawableLeg = ["airway", "direct"].includes(leg.type);
    const airwayKey = isDrawableLeg ? airwayKeyForLeg(leg) : "";
    chip.className = `route-leg ${isDrawableLeg ? "airway" : ""}`;
    chip.textContent =
      leg.type === "airway"
        ? `${leg.name} ${leg.entry}→${leg.exit}`
        : leg.type === "direct"
          ? `DCT ${leg.entry}→${leg.exit}`
        : leg.name;
    if (isDrawableLeg) {
      chip.dataset.airwayKey = airwayKey;
      chip.addEventListener("pointerenter", () => setAirwayHighlight(airwayKey, true));
      chip.addEventListener("pointerleave", () => setAirwayHighlight(airwayKey, false));
      state.airwayLegChips.set(airwayKey, chip);
    }
    elements.routeLegs.appendChild(chip);
  });
}

/**
 * 功能：渲染 `renderSelectedProcedures` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function renderSelectedProcedures() {
  state.procedureChips.clear();
  elements.selectedProcedures.innerHTML = "";
  const selected = Object.entries(state.selectedProcedures).filter(([, value]) => value);
  if (!selected.length) {
    elements.selectedProcedures.innerHTML = `<div class="helper-text">${escapeHtml(t("selection.noSelectedProcedure"))}</div>`;
    return;
  }
  selected.forEach(([type, value]) => {
    const chip = document.createElement("div");
    chip.className = `route-leg selected-procedure ${type}`;
    chip.dataset.procedureType = type;
    const sourceTag = value.source === "auto" ? t("common.auto") : t("common.manual");
    chip.innerHTML = `<span>${procedureTypeLabel(type)} ${value.procedure} ${value.transition} <span class="info-chip">${sourceTag}</span></span>`;
    chip.addEventListener("pointerenter", () => setProcedureHighlight(type, true));
    chip.addEventListener("pointerleave", () => setProcedureHighlight(type, false));
    chip.addEventListener("click", (event) => {
      if (event.target instanceof Element && event.target.closest(".selected-remove")) {
        return;
      }
      showSelectedProcedureDetails(type);
    });
    state.procedureChips.set(type, chip);
    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "selected-remove";
    remove.textContent = "x";
    remove.addEventListener("click", () => clearProcedure(type));
    chip.appendChild(remove);
    elements.selectedProcedures.appendChild(chip);
  });
}

/**
 * 功能：格式化 `formatProcedureTitle` 对应的业务逻辑。
 * 输入：type、procedure、transition。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatProcedureTitle(type, procedure, transition) {
  return `${procedureTypeLabel(type)} ${procedure} / ${transition || "ALL"}`;
}

/**
 * 功能：返回程序类型在界面中的显示名称。
 * 输入：type 为 sid/star/approach。
 * 输出：用于芯片和选择表标题的中文/航空缩写标签。
 */
function procedureTypeLabel(type) {
  if (type === "sid") return "SID";
  if (type === "star") return "STAR";
  if (type === "approach") return "APPROACH";
  return String(type || "").toUpperCase();
}

/**
 * 功能：格式化 `formatNumeric` 对应的业务逻辑。
 * 输入：value、suffix。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatNumeric(value, suffix = "") {
  if (value === null || value === undefined || value === "") {
    return "";
  }
  const number = Number(value);
  const text = Number.isFinite(number) ? String(Math.round(number * 10) / 10) : String(value);
  return `${text}${suffix}`;
}

/**
 * 功能：格式化 `formatAltitudeRestriction` 对应的业务逻辑。
 * 输入：item。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatAltitudeRestriction(item) {
  const altitude1 = formatNumeric(item.altitude1);
  const altitude2 = formatNumeric(item.altitude2);
  const code = String(item.altitude_description || "").trim();
  if (!altitude1 && !altitude2) {
    return "—";
  }
  if (code === "+") {
    return `≥ ${altitude1} ft`;
  }
  if (code === "-") {
    return `≤ ${altitude1} ft`;
  }
  if (code === "B" && altitude1 && altitude2) {
    return `${altitude2}–${altitude1} ft`;
  }
  const altitudeText = altitude1 && altitude2 ? `${altitude1} / ${altitude2}` : altitude1 || altitude2;
  return `${altitudeText} ft${code ? ` (${code})` : ""}`;
}

/**
 * 功能：格式化 `formatSpeedRestriction` 对应的业务逻辑。
 * 输入：item。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatSpeedRestriction(item) {
  const speed = formatNumeric(item.speed_limit);
  if (!speed) {
    return "—";
  }
  const description = String(item.speed_limit_description || "").trim();
  if (description === "+") {
    return `≥ ${speed} kt`;
  }
  if (description === "-" || !description) {
    return `≤ ${speed} kt`;
  }
  return `${description} ${speed} kt`;
}

/**
 * 功能：处理 `procedureFeatureText` 对应的业务逻辑。
 * 输入：item。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function procedureFeatureText(item) {
  const path = String(item.path_termination || "").toUpperCase() || "—";
  const turn = String(item.turn_direction || "").trim().toUpperCase();
  const features = [path];
  if (turn) {
    features.push(turn === "L" ? t("procedure.feature.left") : turn === "R" ? t("procedure.feature.right") : t("procedure.feature.turn", { turn }));
  }
  if (["RF", "AF"].includes(path)) {
    features.push(item.center_waypoint ? t("procedure.feature.arcVia", { waypoint: item.center_waypoint }) : t("procedure.feature.arc"));
  }
  if (["HA", "HF", "HM"].includes(path)) {
    features.push(t("procedure.feature.hold"));
  }
  if (item.magnetic_course !== null && item.magnetic_course !== undefined) {
    features.push(`${formatNumeric(item.magnetic_course, "°")}`);
  }
  if (item.route_distance_holding_distance_time !== null && item.route_distance_holding_distance_time !== undefined) {
    features.push(`${formatNumeric(item.route_distance_holding_distance_time, " nm")}`);
  }
  if (item.rnp !== null && item.rnp !== undefined) {
    features.push(`RNP ${formatNumeric(item.rnp)}`);
  }
  if (item.vertical_angle !== null && item.vertical_angle !== undefined) {
    features.push(`VPA ${formatNumeric(item.vertical_angle, "°")}`);
  }
  return features.join(" · ");
}

/**
 * 功能：执行 `isRunwayWaypointIdent` 对应的业务逻辑。
 * 输入：ident。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function isRunwayWaypointIdent(ident) {
  return String(ident || "").toUpperCase().startsWith("RW");
}

/**
 * 功能：处理 `procedureRowsWithPhase` 对应的业务逻辑。
 * 输入：type、items。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function procedureRowsWithPhase(type, items) {
  let missed = false;
  return items.map((item) => {
    const ident = item.waypoint_identifier || item.path_termination || "—";
    const isRunway = isRunwayWaypointIdent(ident);
    const phase = type === "approach"
      ? (missed ? t("selection.phase.missed") : isRunway ? t("selection.phase.runway") : t("selection.phase.final"))
      : t("selection.phase.main");
    if (type === "approach" && isRunway) {
      missed = true;
    }
    return { ...item, selectionPhase: phase };
  });
}

/**
 * 功能：处理 `procedureItemLatLng` 对应的业务逻辑。
 * 输入：item。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function procedureItemLatLng(item) {
  const lat = Number(item?.waypoint_latitude);
  const lon = Number(item?.waypoint_longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return null;
  }
  return L.latLng(lat, lon);
}

/**
 * 功能：清理 `clearSelectionWaypointHighlight` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function clearSelectionWaypointHighlight() {
  selectionHighlightLayerGroup.clearLayers();
  state.selectionHighlightLayer = null;
  elements.selectionInfo
    ?.querySelectorAll(".selection-table-row.active")
    .forEach((row) => row.classList.remove("active"));
}

function addWaypointHighlightMarker(latlng, layerGroup, options = {}) {
  const color = options.color || "#fff4b5";
  const fillColor = options.fillColor || MAP_COLORS.approach;
  const outer = L.circleMarker(latlng, {
    pane: "routePane",
    radius: options.outerRadius || 10,
    color,
    weight: options.weight || 3,
    opacity: 0.98,
    fillColor,
    fillOpacity: options.fillOpacity ?? 0.34,
    interactive: false,
    className: "waypoint-highlight-pulse",
    renderer: waypointHighlightRenderer,
  }).addTo(layerGroup);
  const inner = L.circleMarker(latlng, {
    pane: "routePane",
    radius: options.innerRadius || 4,
    color: "#ffffff",
    weight: 1.5,
    opacity: 0.95,
    fillColor: options.innerFillColor || "#17243a",
    fillOpacity: 0.9,
    interactive: false,
    className: "waypoint-highlight-core",
    renderer: waypointHighlightRenderer,
  }).addTo(layerGroup);
  return { outer, inner };
}

/**
 * 功能：执行 `highlightSelectionWaypoint` 对应的业务逻辑。
 * 输入：item、rowElement。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function highlightSelectionWaypoint(item, rowElement) {
  const latlng = procedureItemLatLng(item);
  clearSelectionWaypointHighlight();
  if (!latlng) {
    return;
  }
  rowElement?.classList.add("active");
  state.selectionHighlightLayer = addWaypointHighlightMarker(latlng, selectionHighlightLayerGroup).outer;
  if (!map.getBounds().pad(-0.08).contains(latlng)) {
    map.panTo(latlng, { animate: true, duration: 0.35 });
  }
}

/**
 * 功能：执行 `attachSelectionRowHandlers` 对应的业务逻辑。
 * 输入：rows。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function attachSelectionRowHandlers(rows) {
  elements.selectionInfo.querySelectorAll(".selection-table-row.is-clickable").forEach((row) => {
    const index = Number(row.dataset.selectionIndex);
    if (!Number.isInteger(index) || !rows[index]) {
      return;
    }
    const activate = () => highlightSelectionWaypoint(rows[index], row);
    row.addEventListener("click", activate);
    row.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" && event.key !== " ") {
        return;
      }
      event.preventDefault();
      activate();
    });
  });
}

/**
 * 功能：渲染 `renderProcedureSelectionTable` 对应的业务逻辑。
 * 输入：type、airport、procedure、transition、payload。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function renderProcedureSelectionTable(type, airport, procedure, transition, payload) {
  const rows = procedureRowsWithPhase(type, payload.items || []);
  state.activeSelectionProcedure = { type, airport, procedure, transition, payload };
  clearSelectionWaypointHighlight();
  if (!rows.length) {
    elements.selectionInfo.innerHTML = `<div class="selection-empty">${escapeHtml(t("selection.noLegs"))}</div>`;
    return;
  }
  const body = rows.map((item, index) => {
    const hasCoordinate = Boolean(procedureItemLatLng(item));
    return `
    <tr class="selection-table-row${hasCoordinate ? " is-clickable" : ""}" data-selection-index="${index}" tabindex="${hasCoordinate ? "0" : "-1"}">
      <td class="selection-seq">${escapeHtml(item.seqno ?? "—")}</td>
      <td>
        <strong>${escapeHtml(item.waypoint_identifier || "—")}</strong>
        <span>${escapeHtml(item.selectionPhase)}</span>
      </td>
      <td class="selection-altitude">${escapeHtml(formatAltitudeRestriction(item))}</td>
      <td class="selection-speed">${escapeHtml(formatSpeedRestriction(item))}</td>
      <td class="selection-leg-turn">${escapeHtml(procedureFeatureText(item))}</td>
    </tr>
  `;
  }).join("");
  elements.selectionInfo.innerHTML = `
    <div class="selection-summary">
      <div>
        <strong>${escapeHtml(formatProcedureTitle(type, procedure, transition))}</strong>
        <span>${escapeHtml(t("selection.legCount", { airport, count: rows.length }))}</span>
      </div>
    </div>
    <div class="selection-table-wrap">
      <table class="selection-table">
        <colgroup>
          <col class="selection-col-seq" />
          <col class="selection-col-waypoint" />
          <col class="selection-col-altitude" />
          <col class="selection-col-speed" />
          <col class="selection-col-leg-turn" />
        </colgroup>
        <thead>
          <tr>
            <th>SEQ</th>
            <th>WAYPOINT</th>
            <th>ALTITUDE</th>
            <th>SPEED</th>
            <th>LEG / TURN</th>
          </tr>
        </thead>
        <tbody>${body}</tbody>
      </table>
    </div>
  `;
  attachSelectionRowHandlers(rows);
}

/**
 * 功能：渲染 `renderSelectionMessage` 对应的业务逻辑。
 * 输入：message。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function renderSelectionMessage(message) {
  state.activeSelectionProcedure = null;
  clearSelectionWaypointHighlight();
  elements.selectionInfo.innerHTML = `<div class="selection-empty">${escapeHtml(message)}</div>`;
}

/**
 * 功能：显示 `showSelectedProcedureDetails` 对应的业务逻辑。
 * 输入：type。
 * 输出：Promise，解析为函数处理结果。
 */
async function showSelectedProcedureDetails(type) {
  const selected = state.selectedProcedures[type];
  if (!selected) {
    return;
  }
  const payload = await loadProcedurePayload(type, selected.airport, selected.procedure, selected.transition);
  renderProcedureSelectionTable(type, selected.airport, selected.procedure, selected.transition, payload);
}

/**
 * 功能：处理 `routeStringFromPayload` 对应的业务逻辑。
 * 输入：payload。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function routeStringFromPayload(payload) {
  if (payload.route_display) {
    return payload.route_display;
  }
  if (!payload.legs?.length) {
    return "";
  }
  const tokens = [];
  payload.legs.forEach((leg, index) => {
    if (leg.type === "fix") {
      tokens.push(leg.name);
      return;
    }
    if (leg.type !== "airway") {
      return;
    }
    if (index === 0) {
      tokens.push(leg.entry);
    }
    tokens.push(leg.name, leg.exit);
  });
  return tokens.join(" ");
}

/**
 * 功能：执行 `unwrapLongitudeNear` 对应的业务逻辑。
 * 输入：lon、referenceLon。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function unwrapLongitudeNear(lon, referenceLon) {
  let adjusted = Number(lon);
  if (!Number.isFinite(adjusted) || !Number.isFinite(referenceLon)) {
    return adjusted;
  }
  while (adjusted - referenceLon > 180) adjusted -= 360;
  while (adjusted - referenceLon < -180) adjusted += 360;
  return adjusted;
}

/**
 * 功能：规范化 `normalizeLongitude` 对应的业务逻辑。
 * 输入：lon。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function normalizeLongitude(lon) {
  const value = Number(lon);
  if (!Number.isFinite(value)) {
    return value;
  }
  return ((value + 540) % 360) - 180;
}

/**
 * 功能：执行 `withDisplayLongitudes` 对应的业务逻辑。
 * 输入：points。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function withDisplayLongitudes(points) {
  let previousLon = null;
  return points.map((point) => {
    const originalLon = Number(point.lon);
    const displayLon = previousLon === null ? originalLon : unwrapLongitudeNear(originalLon, previousLon);
    previousLon = Number.isFinite(displayLon) ? displayLon : previousLon;
    return {
      ...point,
      originalLon,
      lon: displayLon,
    };
  });
}

/**
 * 功能：执行 `restoreOriginalLongitude` 对应的业务逻辑。
 * 输入：point。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function restoreOriginalLongitude(point) {
  return {
    ...point,
    lon: normalizeLongitude(Number.isFinite(point.originalLon) ? point.originalLon : point.lon),
  };
}

/**
 * 功能：执行 `latLngForPoint` 对应的业务逻辑。
 * 输入：point。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function latLngForPoint(point) {
  return [point.lat, point.lon];
}

/**
 * 功能：处理 `routeWorldCopy` 对应的业务逻辑。
 * 输入：points、longitudeOffset。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function routeWorldCopy(points, longitudeOffset) {
  if (!longitudeOffset) {
    return points;
  }
  return points.map((point) => ({
    ...point,
    lon: point.lon + longitudeOffset,
  }));
}

function greatCircleDistanceNm(pointA, pointB) {
  const lat1 = Number(pointA?.lat);
  const lat2 = Number(pointB?.lat);
  const lon1 = Number.isFinite(pointA?.originalLon) ? Number(pointA.originalLon) : Number(pointA?.lon);
  const lon2 = Number.isFinite(pointB?.originalLon) ? Number(pointB.originalLon) : Number(pointB?.lon);
  if (![lat1, lat2, lon1, lon2].every(Number.isFinite)) {
    return 0;
  }
  const toRad = (value) => (value * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(normalizeLongitude(lon2 - lon1));
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 3440.065 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)));
}

function initialBearingDeg(pointA, pointB) {
  const lat1 = Number(pointA?.lat);
  const lat2 = Number(pointB?.lat);
  const lon1 = Number.isFinite(pointA?.originalLon) ? Number(pointA.originalLon) : Number(pointA?.lon);
  const lon2 = Number.isFinite(pointB?.originalLon) ? Number(pointB.originalLon) : Number(pointB?.lon);
  if (![lat1, lat2, lon1, lon2].every(Number.isFinite)) {
    return null;
  }
  const toRad = (value) => (value * Math.PI) / 180;
  const toDeg = (value) => (value * 180) / Math.PI;
  const phi1 = toRad(lat1);
  const phi2 = toRad(lat2);
  const lambda = toRad(normalizeLongitude(lon2 - lon1));
  const y = Math.sin(lambda) * Math.cos(phi2);
  const x = Math.cos(phi1) * Math.sin(phi2) - Math.sin(phi1) * Math.cos(phi2) * Math.cos(lambda);
  return (toDeg(Math.atan2(y, x)) + 360) % 360;
}

function bearingDeltaDeg(a, b) {
  if (!Number.isFinite(a) || !Number.isFinite(b)) {
    return 0;
  }
  const diff = Math.abs(((a - b + 540) % 360) - 180);
  return Number.isFinite(diff) ? diff : 0;
}

function fr24SegmentLooksSparseCurve(points, index, distanceNm) {
  if (distanceNm < FR24_TRACK_CURVE_MIN_NM) {
    return false;
  }
  const previousPrevious = points[index - 2];
  const previous = points[index - 1];
  const current = points[index];
  const next = points[index + 1];
  const beforeTurn = previousPrevious
    ? bearingDeltaDeg(initialBearingDeg(previousPrevious, previous), initialBearingDeg(previous, current))
    : 0;
  const afterTurn = next
    ? bearingDeltaDeg(initialBearingDeg(previous, current), initialBearingDeg(current, next))
    : 0;
  return Math.max(beforeTurn, afterTurn) >= FR24_TRACK_CURVE_TURN_DEG;
}

function splitFR24TrackSegments(points) {
  if (!Array.isArray(points) || points.length < 2) {
    return [];
  }
  const segments = [];
  let solidRun = [points[0]];
  for (let index = 1; index < points.length; index += 1) {
    const previous = points[index - 1];
    const current = points[index];
    const distanceNm = greatCircleDistanceNm(previous, current);
    const shouldDash = distanceNm > FR24_TRACK_GAP_NM
      || fr24SegmentLooksSparseCurve(points, index, distanceNm);
    if (shouldDash) {
      if (solidRun.length >= 2) {
        segments.push({ points: solidRun, dashed: false });
      }
      segments.push({ points: [previous, current], dashed: true });
      solidRun = [current];
    } else {
      solidRun.push(current);
    }
  }
  if (solidRun.length >= 2) {
    segments.push({ points: solidRun, dashed: false });
  }
  return segments;
}

/**
 * 功能：执行 `currentMapBounds` 对应的业务逻辑。
 * 输入：paddingDeg、paddingRatio。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function currentMapBounds(paddingDeg = 0, paddingRatio = 0) {
  const bounds = map.getBounds();
  const south = bounds.getSouth();
  const north = bounds.getNorth();
  let west = bounds.getWest();
  let east = bounds.getEast();
  if (west > east) {
    east += 360;
  }
  const latPadding = paddingDeg + Math.max(north - south, 0) * paddingRatio;
  const lonPadding = paddingDeg + Math.max(east - west, 0) * paddingRatio;
  return {
    south: Math.max(-90, south - latPadding),
    west: west - lonPadding,
    north: Math.min(90, north + latPadding),
    east: east + lonPadding,
  };
}

/**
 * 功能：执行 `worldCopyOffsetsForBounds` 对应的业务逻辑。
 * 输入：bounds、extraCopies。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function worldCopyOffsetsForBounds(bounds, extraCopies = 0) {
  const offsets = ROUTE_WORLD_COPY_OFFSETS.filter((offset) => (
    bounds.east >= -180 + offset && bounds.west <= 180 + offset
  ));
  const expanded = new Set(offsets.length ? offsets : [0]);
  for (const offset of [...expanded]) {
    for (let index = 1; index <= extraCopies; index += 1) {
      expanded.add(offset - 360 * index);
      expanded.add(offset + 360 * index);
    }
  }
  return ROUTE_WORLD_COPY_OFFSETS.filter((offset) => expanded.has(offset));
}

/**
 * 功能：执行 `boundsContainBounds` 对应的业务逻辑。
 * 输入：outer、inner。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function boundsContainBounds(outer, inner) {
  return Boolean(
    outer &&
    inner &&
    outer.south <= inner.south &&
    outer.north >= inner.north &&
    outer.west <= inner.west &&
    outer.east >= inner.east,
  );
}

/**
 * 功能：执行 `navPointWorldCopy` 对应的业务逻辑。
 * 输入：point、longitudeOffset。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function navPointWorldCopy(point, longitudeOffset) {
  const originalLon = Number.isFinite(point.originalLon) ? point.originalLon : Number(point.lon);
  return {
    ...point,
    originalLon: normalizeLongitude(originalLon),
    lon: Number(point.lon) + longitudeOffset,
  };
}

/**
 * 功能：执行 `pathLatLngsForWorld` 对应的业务逻辑。
 * 输入：path、longitudeOffset。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function pathLatLngsForWorld(path, longitudeOffset = 0) {
  let previousLon = null;
  return (path || []).map(([lat, lon]) => {
    const numericLon = Number(lon);
    const displayLon = previousLon === null ? numericLon : unwrapLongitudeNear(numericLon, previousLon);
    if (Number.isFinite(displayLon)) {
      previousLon = displayLon;
    }
    return [Number(lat), displayLon + longitudeOffset];
  });
}

/**
 * 功能：执行 `latLngPathIntersectsBounds` 对应的业务逻辑。
 * 输入：latlngs、bounds。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function latLngPathIntersectsBounds(latlngs, bounds) {
  if (!latlngs.length) {
    return false;
  }
  let minLat = Infinity;
  let maxLat = -Infinity;
  let minLon = Infinity;
  let maxLon = -Infinity;
  // 叠加层刷新会高频调用这里；单次循环避免临时数组和大规模展开运算带来的 GC 压力。
  for (const [lat, lon] of latlngs) {
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lon < minLon) minLon = lon;
    if (lon > maxLon) maxLon = lon;
  }
  return !(maxLat < bounds.south || minLat > bounds.north || maxLon < bounds.west || minLon > bounds.east);
}

/**
 * 功能：执行 `navPointIntersectsBounds` 对应的业务逻辑。
 * 输入：point、bounds。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function navPointIntersectsBounds(point, bounds) {
  const lat = Number(point.lat);
  const lon = Number(point.lon);
  return lat >= bounds.south && lat <= bounds.north && lon >= bounds.west && lon <= bounds.east;
}

/**
 * 功能：执行 `latLngForWorld` 对应的业务逻辑。
 * 输入：item、longitudeOffset。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function latLngForWorld(item, longitudeOffset = 0) {
  return [Number(item[0]), Number(item[1]) + longitudeOffset];
}

/**
 * 功能：执行 `smoothLatLngs` 对应的业务逻辑。
 * 输入：points、iterations。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function smoothLatLngs(points, iterations = 10) {
  if (points.length < 3) {
    return points.map((point) => [point.lat, point.lon]);
  }
  const result = [];
  for (let index = 0; index < points.length - 1; index += 1) {
    const p0 = points[Math.max(0, index - 1)];
    const p1 = points[index];
    const p2 = points[index + 1];
    const p3 = points[Math.min(points.length - 1, index + 2)];
    for (let step = 0; step < iterations; step += 1) {
      const t = step / iterations;
      const t2 = t * t;
      const t3 = t2 * t;
      const lat =
        0.5 *
        ((2 * p1.lat) +
          (-p0.lat + p2.lat) * t +
          (2 * p0.lat - 5 * p1.lat + 4 * p2.lat - p3.lat) * t2 +
          (-p0.lat + 3 * p1.lat - 3 * p2.lat + p3.lat) * t3);
      const lon =
        0.5 *
        ((2 * p1.lon) +
          (-p0.lon + p2.lon) * t +
          (2 * p0.lon - 5 * p1.lon + 4 * p2.lon - p3.lon) * t2 +
          (-p0.lon + 3 * p1.lon - 3 * p2.lon + p3.lon) * t3);
      result.push([lat, lon]);
    }
  }
  const last = points.at(-1);
  result.push([last.lat, last.lon]);
  return result;
}

/**
 * 功能：清理 `clearLabels` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function clearLabels() {
  labelLayerGroup.clearLayers();
  state.labelMarkers = [];
}

/**
 * 功能：执行 `stopMapEvent` 对应的业务逻辑。
 * 输入：event。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function stopMapEvent(event) {
  if (!event?.originalEvent) {
    return;
  }
  event.originalEvent._plannerMapHandled = true;
  L.DomEvent.stop(event.originalEvent);
}

/**
 * 功能：执行 `isHandledMapClick` 对应的业务逻辑。
 * 输入：event。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function isHandledMapClick(event) {
  if (event?.originalEvent?._plannerMapHandled) {
    return true;
  }
  const target = event?.originalEvent?.target;
  return target instanceof Element && Boolean(
    target.closest(".leaflet-popup, .leaflet-control, .map-label, .nav-symbol"),
  );
}

/**
 * 功能：规范化 `normalizePopupPoint` 对应的业务逻辑。
 * 输入：point、fallbackKind。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function normalizePopupPoint(point, fallbackKind = "waypoint") {
  const kind = ["departure", "arrival", "airway-fix"].includes(point.kind)
    ? (point.kind === "airway-fix" ? "waypoint" : "airport")
    : (point.kind || fallbackKind);
  return {
    ...point,
    kind,
    ident: point.ident || point.label || "POINT",
    name: point.name || point.label || "",
    lat: Number(point.lat),
    lon: normalizeLongitude(Number(point.lon)),
    associated_routes: point.associated_routes || [],
  };
}

/**
 * 功能：添加 `addTextLabel` 对应的业务逻辑。
 * 输入：lat、lon、text、className、options。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function addTextLabel(lat, lon, text, className, options = {}) {
  const marker = L.marker([lat, lon], {
    pane: "labelPane",
    interactive: Boolean(options.interactive),
    bubblingMouseEvents: false,
    icon: L.divIcon({
      className: `map-label ${className} ${options.interactive ? "is-interactive" : ""}`,
      html: `<span>${escapeHtml(text)}</span>`,
    }),
  }).addTo(options.group || labelLayerGroup);
  if (options.onClick) {
    marker.on("click", (event) => {
      scheduleMapPopupAction(event, () => options.onClick(event.latlng, event));
    });
  }
  state.labelMarkers.push(marker);
  return marker;
}

/**
 * 功能：添加 `addNavLabel` 对应的业务逻辑。
 * 输入：lat、lon、text、className、options。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function addNavLabel(lat, lon, text, className, options = {}) {
  const isAirwayLabel = className === "nav-airway-label";
  const compact = isCompactPhoneMap();
  const airwayWidth = isAirwayLabel
    ? Math.max(compact ? 20 : 28, Math.min(compact ? 36 : 50, String(text).length * (compact ? 4.1 : 5.4) + (compact ? 5 : 8)))
    : null;
  const airwayHeight = compact ? 10 : 18;
  const marker = L.marker([lat, lon], {
    pane: "navLabelPane",
    interactive: Boolean(options.interactive),
    bubblingMouseEvents: false,
    icon: L.divIcon({
      className: `map-label nav-label ${className} ${options.interactive ? "is-interactive" : ""}`,
      html: isAirwayLabel
        ? `<div class="nav-airway-badge ${options.directionClass || ""}" style="width:${airwayWidth}px">${text}</div>`
        : `<span style="--label-angle:${options.angleDeg || 0}deg">${text}</span>`,
      iconSize: isAirwayLabel ? [airwayWidth, airwayHeight] : undefined,
      iconAnchor: isAirwayLabel ? [airwayWidth / 2, airwayHeight / 2] : undefined,
    }),
  }).addTo(options.group || navLabelLayerGroup);
  if (options.onClick) {
    marker.on("click", (event) => {
      scheduleMapPopupAction(event, () => options.onClick(event.latlng, event));
    });
  }
  if (options.airwayName) {
    const list = state.navAirwayLabels.get(options.airwayName) || [];
    list.push(marker);
    state.navAirwayLabels.set(options.airwayName, list);
  }
  return marker;
}

/**
 * 功能：执行 `offsetSegmentLabel` 对应的业务逻辑。
 * 输入：path、offsetNm。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function offsetSegmentLabel(path, offsetNm = 0.18) {
  if (!Array.isArray(path) || path.length < 2) {
    return null;
  }
  const [a, b] = [path[0], path[path.length - 1]];
  const midLat = (a[0] + b[0]) / 2;
  const midLon = (a[1] + b[1]) / 2;
  const cosLat = Math.max(0.2, Math.cos((midLat * Math.PI) / 180));
  const dx = (b[1] - a[1]) * cosLat;
  const dy = b[0] - a[0];
  const length = Math.hypot(dx, dy) || 1;
  const nx = -dy / length;
  const ny = dx / length;
  const offsetDeg = offsetNm / 60;
  return [
    midLat + ny * offsetDeg,
    midLon + (nx * offsetDeg) / cosLat,
  ];
}

/**
 * 功能：执行 `thresholdLabelPosition` 对应的业务逻辑。
 * 输入：path、offsetNm、alongNm。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function thresholdLabelPosition(path, offsetNm = 0.1, alongNm = 0.03) {
  if (!Array.isArray(path) || path.length < 2) {
    return null;
  }
  const [a, b] = [path[0], path[1]];
  const cosLat = Math.max(0.2, Math.cos((a[0] * Math.PI) / 180));
  const dx = (b[1] - a[1]) * cosLat;
  const dy = b[0] - a[0];
  const length = Math.hypot(dx, dy) || 1;
  const ux = dx / length;
  const uy = dy / length;
  const nx = -uy;
  const ny = ux;
  const offsetDeg = offsetNm / 60;
  const alongDeg = alongNm / 60;
  return [
    a[0] + ny * offsetDeg - uy * alongDeg,
    a[1] + (nx * offsetDeg - ux * alongDeg) / cosLat,
  ];
}

/**
 * 功能：执行 `escapeHtml` 对应的业务逻辑。
 * 输入：value。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => (
    {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;",
    }[char]
  ));
}

/**
 * 功能：执行 `navPopupType` 对应的业务逻辑。
 * 输入：point。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function navPopupType(point) {
  if (point.kind === "airport") return t("popup.airport");
  if (point.kind === "vor") return point.has_dme ? "VOR/DME" : "VOR";
  if (point.kind === "ndb") return "NDB";
  if (point.kind === "airway") return t("popup.airway");
  if (point.kind === "direct") return t("popup.direct");
  if (point.kind === "terminal_waypoint") return t("popup.terminalWaypoint");
  return t("popup.waypoint");
}

/**
 * 功能：执行 `airwayRestrictionText` 对应的业务逻辑。
 * 输入：direction。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airwayRestrictionText(direction) {
  if (direction === "F") return t("popup.direction.forward");
  if (direction === "B") return t("popup.direction.backward");
  return t("popup.direction.both");
}

/**
 * 功能：执行 `airwayRestrictionGlyph` 对应的业务逻辑。
 * 输入：direction。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airwayRestrictionGlyph(direction) {
  if (direction === "F") return "▶";
  if (direction === "B") return "◀";
  return "";
}

/**
 * 功能：格式化 `formatAssociatedRoutes` 对应的业务逻辑。
 * 输入：routes。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatAssociatedRoutes(routes) {
  if (!routes || !routes.length) {
    return `<div class="nav-popup-empty">${escapeHtml(t("common.none"))}</div>`;
  }
  return `<ul class="nav-popup-routes">${routes.map((route) => `
    <li>
      <button type="button" class="nav-popup-route-name nav-popup-route-button" data-airway-name="${escapeHtml(route.name)}">${escapeHtml(route.name)}</button>
      <span class="nav-popup-route-meta">
        ${airwayRestrictionGlyph(route.direction) ? `<span class="route-direction">${escapeHtml(airwayRestrictionGlyph(route.direction))}</span>` : ""}
        <span>${escapeHtml(route.from)} → ${escapeHtml(route.to)}${route.area_code ? ` / ${escapeHtml(route.area_code)}` : ""}</span>
      </span>
    </li>
  `).join("")}</ul>`;
}

/**
 * 功能：执行 `isAirportActionCandidate` 对应的业务逻辑。
 * 输入：point。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function isAirportActionCandidate(point) {
  return point.kind === "airport";
}

/**
 * 功能：格式化 `formatAirportPopupActions` 对应的业务逻辑。
 * 输入：point。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatAirportPopupActions(point) {
  if (!isAirportActionCandidate(point)) {
    return "";
  }
  const ident = escapeHtml(point.ident || "");
  return `
    <div class="nav-popup-actions" aria-label="${escapeHtml(t("popup.actionsAria"))}">
      <button type="button" class="nav-popup-action" data-airport-action="departure" data-airport-ident="${ident}">${escapeHtml(t("popup.setDeparture"))}</button>
      <button type="button" class="nav-popup-action" data-airport-action="arrival" data-airport-ident="${ident}">${escapeHtml(t("popup.setArrival"))}</button>
      <button type="button" class="nav-popup-action" data-airport-action="manual" data-airport-ident="${ident}">${escapeHtml(t("popup.setManual"))}</button>
    </div>
  `;
}

/**
 * 功能：格式化 `formatPopupValue` 对应的业务逻辑。
 * 输入：value、suffix。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatPopupValue(value, suffix = "") {
  if (value === null || value === undefined || value === "") {
    return "—";
  }
  return `${value}${suffix}`;
}

/**
 * 功能：格式化 `formatAirportBoolean` 对应的业务逻辑。
 * 输入：value。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatAirportBoolean(value) {
  if (value === null || value === undefined || value === "") {
    return "—";
  }
  if (value === "Y") return t("common.yes");
  if (value === "N") return t("common.no");
  return value;
}

/**
 * 功能：格式化 `formatTransitionAltitude` 对应的业务逻辑。
 * 输入：value。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatTransitionAltitude(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return "—";
  }
  return `${numeric} ft`;
}

/**
 * 功能：格式化 `formatLongestRunwayType` 对应的业务逻辑。
 * 输入：value。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatLongestRunwayType(value) {
  const code = String(value || "").trim();
  const labels = {
    H: t("airport.surface.hard"),
    S: t("airport.surface.soft"),
    W: t("airport.surface.water"),
    U: t("airport.surface.unknown"),
  };
  if (!code) {
    return "—";
  }
  return labels[code] ? `${code} (${labels[code]})` : code;
}

/**
 * 功能：格式化 `formatRunwayDimensions` 对应的业务逻辑。
 * 输入：runway。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function formatRunwayDimensions(runway) {
  const length = runway.runway_length ? `${runway.runway_length}` : "";
  const width = runway.runway_width ? `${runway.runway_width}` : "";
  if (length && width) {
    return `${length} x ${width} ft`;
  }
  return length ? `${length} ft` : "—";
}

/**
 * 功能：处理 `airportPopupExtraShell` 对应的业务逻辑。
 * 输入：point。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airportPopupExtraShell(point) {
  if (!isAirportActionCandidate(point)) {
    return "";
  }
  return `
    <div class="nav-popup-airport-extra hidden" data-airport-ident="${escapeHtml(point.ident || "")}" data-show-loading="${point.kind === "airport" ? "true" : "false"}"></div>
  `;
}

/**
 * 功能：处理 `airportPopupDetailsHtml` 对应的业务逻辑。
 * 输入：payload。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airportPopupDetailsHtml(payload) {
  const airport = payload.airport || {};
  const runways = payload.runways || [];
  const metaRows = [
    [t("airport.elevation"), formatPopupValue(airport.elevation, " ft")],
    ["IATA", airport.iata_ata_designator || "—"],
    [t("airport.transitionAltLevel"), airport.transition_altitude || airport.transition_level
      ? `${formatTransitionAltitude(airport.transition_altitude)} / ${formatTransitionAltitude(airport.transition_level)}`
      : "—"],
    [t("airport.ifrCapability"), formatAirportBoolean(airport.ifr_capability)],
    [t("airport.longestSurface"), formatLongestRunwayType(airport.longest_runway_surface_code)],
  ].map(([label, value]) => `
    <div class="nav-popup-row nav-popup-row-compact">
      <span>${escapeHtml(label)}</span>
      <strong>${escapeHtml(String(value))}</strong>
    </div>
  `).join("");
  const runwayRows = runways.length ? runways.map((runway) => `
    <div class="nav-popup-runway-card">
      <div class="nav-popup-runway-head">
        <strong>${escapeHtml(runway.runway_identifier || "RWY")}</strong>
        <span>${escapeHtml(formatRunwayDimensions(runway))}</span>
      </div>
      <div class="nav-popup-runway-grid">
        <span>${escapeHtml(t("airport.thresholdElevation"))}</span><strong>${escapeHtml(formatPopupValue(runway.landing_threshold_elevation, " ft"))}</strong>
        <span>${escapeHtml(t("airport.surface"))}</span><strong>${escapeHtml(formatPopupValue(runway.surface_code))}</strong>
        <span>${escapeHtml(t("airport.magneticBearing"))}</span><strong>${escapeHtml(formatPopupValue(runway.runway_magnetic_bearing, "°"))}</strong>
        <span>${escapeHtml(t("airport.trueBearing"))}</span><strong>${escapeHtml(formatPopupValue(runway.runway_true_bearing, "°"))}</strong>
        <span>${escapeHtml(t("airport.displacedThreshold"))}</span><strong>${escapeHtml(formatPopupValue(runway.displaced_threshold_distance, " ft"))}</strong>
        <span>TCH</span><strong>${escapeHtml(formatPopupValue(runway.threshold_crossing_height, " ft"))}</strong>
        <span>${escapeHtml(t("airport.gradient"))}</span><strong>${escapeHtml(formatPopupValue(runway.runway_gradient, "%"))}</strong>
        <span>ILS/GLS</span><strong>${escapeHtml(runway.llz_identifier || runway.llz_mls_gls_category || "—")}</strong>
      </div>
    </div>
  `).join("") : `<div class="nav-popup-empty">${escapeHtml(t("airport.noRunwayDetails"))}</div>`;
  return `
    <div class="nav-popup-section-title">${escapeHtml(t("airport.details"))}</div>
    ${metaRows}
    <div class="nav-popup-section-title nav-popup-section-title-spaced">${escapeHtml(t("airport.runwayCount", { count: runways.length }))}</div>
    <div class="nav-popup-runways">${runwayRows}</div>
  `;
}

/**
 * 功能：执行 `hydrateAirportPopupDetails` 对应的业务逻辑。
 * 输入：ident。
 * 输出：Promise，解析为函数处理结果。
 */
async function hydrateAirportPopupDetails(ident) {
  if (!ident) {
    return;
  }
  const normalizedIdent = ident.toUpperCase();
  const extra = map.getContainer().querySelector(".nav-popup-airport-extra");
  if (!extra || extra.dataset.airportIdent?.toUpperCase() !== normalizedIdent) {
    return;
  }
  const showLoading = extra.dataset.showLoading === "true";
  if (showLoading) {
    extra.classList.remove("hidden");
    extra.innerHTML = `
      <div class="nav-popup-section-title">${escapeHtml(t("airport.details"))}</div>
      <div class="nav-popup-loading">${escapeHtml(t("airport.detailsLoading"))}</div>
    `;
  }
  try {
    if (!state.airportPopupCache.has(normalizedIdent)) {
      const request = fetchJson(`/api/airport/${encodeURIComponent(normalizedIdent)}`).catch((error) => {
        state.airportPopupCache.delete(normalizedIdent);
        throw error;
      });
      state.airportPopupCache.set(normalizedIdent, request);
    }
    const payload = await state.airportPopupCache.get(normalizedIdent);
    if (!extra.isConnected || extra.dataset.airportIdent?.toUpperCase() !== normalizedIdent) {
      return;
    }
    extra.classList.remove("hidden");
    extra.innerHTML = airportPopupDetailsHtml(payload);
  } catch (error) {
    if (!extra.isConnected || extra.dataset.airportIdent?.toUpperCase() !== normalizedIdent) {
      return;
    }
    if (!showLoading) {
      extra.remove();
      return;
    }
    extra.innerHTML = `
      <div class="nav-popup-section-title">${escapeHtml(t("airport.details"))}</div>
      <div class="nav-popup-empty">${escapeHtml(t("airport.detailsUnavailable"))}</div>
    `;
  }
}

function latLngSnapshot(latlng) {
  return {
    lat: Number(latlng?.lat ?? latlng?.[0] ?? 0),
    lng: Number(latlng?.lng ?? latlng?.lon ?? latlng?.[1] ?? 0),
  };
}

function rememberActiveNavPopup(point, latlng) {
  state.activeNavPopup = {
    point: normalizePopupPoint({ ...point }, point.kind || "waypoint"),
    latlng: latLngSnapshot(latlng),
  };
}

function refreshActiveNavPopup() {
  const active = state.activeNavPopup;
  if (!active) {
    return;
  }
  state.refreshingNavPopup = true;
  try {
    showNavPointPopup(active.point, active.latlng);
  } finally {
    state.refreshingNavPopup = false;
  }
}

/**
 * 功能：显示 `showNavPointPopup` 对应的业务逻辑。
 * 输入：point、latlng。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function showNavPointPopup(point, latlng) {
  point = normalizePopupPoint(point, point.kind || "waypoint");
  const compact = isCompactPhoneMap();
  const coord = `${Number(point.lat).toFixed(5)}, ${Number(point.lon).toFixed(5)}`;
  const type = navPopupType(point);
  const routes = point.associated_routes || [];
  const title = point.ident || "POINT";
  const rawSubtitle = point.name || point.label || "";
  const subtitle = rawSubtitle && rawSubtitle.toUpperCase() !== title.toUpperCase() ? rawSubtitle : "";
  const popupClass = ["nav-point-popup", point.kind === "airport" ? "airport-popup" : ""]
    .filter(Boolean)
    .join(" ");
  const popup = L.popup({
    className: popupClass,
    closeButton: true,
    closeOnClick: false,
    autoPan: true,
    keepInView: true,
    maxWidth: compact ? 180 : 346,
    autoPanPadding: compact ? [32, 34] : [96, 76],
    offset: compact ? [0, -4] : [0, -8],
  })
    .setLatLng(latlng)
    .setContent(`
      <div class="nav-popup-card">
        <div class="nav-popup-head">
          <div class="nav-popup-kicker">${escapeHtml(type)}</div>
          <div class="nav-popup-head-main">
            <span class="nav-popup-ident">${escapeHtml(title)}</span>
            ${subtitle ? `<span class="nav-popup-name">${escapeHtml(subtitle)}</span>` : ""}
          </div>
        </div>
        <div class="nav-popup-body">
          <div class="nav-popup-row"><span>${escapeHtml(t("popup.region"))}</span><strong>${escapeHtml(point.region || point.area_code || "—")}</strong></div>
          <div class="nav-popup-row"><span>${escapeHtml(t("popup.frequency"))}</span><strong>${point.frequency ? escapeHtml(String(point.frequency)) : "—"}</strong></div>
          <div class="nav-popup-row"><span>${escapeHtml(t("popup.coordinates"))}</span><strong>${escapeHtml(coord)}</strong></div>
          ${point.kind === "airway" ? `<div class="nav-popup-row"><span>${escapeHtml(t("popup.directionRestriction"))}</span><strong>${escapeHtml(airwayRestrictionText(point.direction || ""))}</strong></div>` : ""}
          ${airportPopupExtraShell(point)}
          <div class="nav-popup-section">
            <div class="nav-popup-section-title">${escapeHtml(t("popup.associatedRoutes", { count: routes.length }))}</div>
            ${formatAssociatedRoutes(routes)}
          </div>
          ${formatAirportPopupActions(point)}
        </div>
      </div>
    `)
    .openOn(map);
  rememberActiveNavPopup(point, latlng);
  if (isAirportActionCandidate(point)) {
    hydrateAirportPopupDetails(point.ident || "");
  }
  return popup;
}

/**
 * 功能：显示 `showAirwayPopup` 对应的业务逻辑。
 * 输入：airway、latlng。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function showAirwayPopup(airway, latlng) {
  showNavPointPopup({
    kind: "airway",
    ident: airway.name,
    name: `${airway.from} → ${airway.to}`,
    lat: latlng.lat,
    lon: latlng.lng,
    region: airway.area_code || "",
    direction: airway.direction || "",
    associated_routes: [{
      name: airway.name,
      from: airway.from,
      to: airway.to,
      direction: airway.direction || "",
      area_code: airway.area_code || "",
    }],
  }, latlng);
}

/**
 * 功能：显示 `showAirwayPopupFromEvent` 对应的业务逻辑。
 * 输入：airway、event。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function showAirwayPopupFromEvent(airway, event) {
  scheduleMapPopupAction(event, () => {
    toggleSelectedNavAirway(airway.name);
    showAirwayPopup(airway, event.latlng);
  });
}

/**
 * 功能：计算 `pointSegmentDistanceSq` 对应的业务逻辑。
 * 输入：point、start、end。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function pointSegmentDistanceSq(point, start, end) {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  if (!dx && !dy) {
    return point.distanceTo(start) ** 2;
  }
  const t = Math.max(0, Math.min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)));
  const projection = L.point(start.x + t * dx, start.y + t * dy);
  return point.distanceTo(projection) ** 2;
}

/**
 * 功能：执行 `nearestAirwayForLatLng` 对应的业务逻辑。
 * 输入：latlng、candidates、maxDistancePx。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function nearestAirwayForLatLng(latlng, candidates, maxDistancePx = 18) {
  const target = map.latLngToLayerPoint(latlng);
  let best = null;
  let bestDistanceSq = maxDistancePx * maxDistancePx;
  candidates.forEach((candidate) => {
    const path = candidate.path || [];
    for (let index = 1; index < path.length; index += 1) {
      const start = map.latLngToLayerPoint(path[index - 1]);
      const end = map.latLngToLayerPoint(path[index]);
      const distanceSq = pointSegmentDistanceSq(target, start, end);
      if (distanceSq < bestDistanceSq) {
        bestDistanceSq = distanceSq;
        best = candidate.airway;
      }
    }
  });
  return best;
}

/**
 * 功能：设置 `setNavAirwayHighlight` 对应的业务逻辑。
 * 输入：name、active。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function setNavAirwayHighlight(name, active) {
  const layers = state.navAirwayLayers.get(name) || [];
  const labels = state.navAirwayLabels.get(name) || [];
  const zoom = map.getZoom();
  const vectorDeclutter = state.baseMap === "vector";
  const baseWeight = zoom >= 8 ? 1.8 : zoom >= 6 ? 1.25 : 0.95;
  const baseOpacity = vectorDeclutter
    ? (zoom >= 8 ? 0.78 : zoom >= 6 ? 0.56 : 0.4)
    : (zoom >= 8 ? 0.55 : zoom >= 6 ? 0.36 : 0.24);
  const baseColor = vectorDeclutter ? "#176d9f" : MAP_COLORS.airway;
  layers.forEach((layer) => {
    layer.setStyle({
      weight: active ? 3.3 : baseWeight,
      opacity: active ? 0.92 : baseOpacity,
      color: active ? MAP_COLORS.airwayActive : baseColor,
    });
    if (active) {
      layer.bringToFront();
    }
  });
  labels.forEach((marker) => {
    marker.getElement()?.classList.toggle("active", active);
  });
}

/**
 * 功能：切换 `toggleSelectedNavAirway` 对应的业务逻辑。
 * 输入：name。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function toggleSelectedNavAirway(name) {
  if (state.selectedNavAirway && state.selectedNavAirway !== name) {
    setNavAirwayHighlight(state.selectedNavAirway, false);
  }
  if (state.selectedNavAirway === name) {
    setNavAirwayHighlight(name, false);
    state.selectedNavAirway = null;
    return;
  }
  state.selectedNavAirway = name;
  setNavAirwayHighlight(name, true);
}

/**
 * 功能：添加 `addPopupHitCircle` 对应的业务逻辑。
 * 输入：point、latlng、options。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function addPopupHitCircle(point, latlng, options = {}) {
  return L.circleMarker(latlng || [point.lat, point.lon], {
    pane: options.pane || "navPane",
    radius: options.radius ?? 14,
    color: "#ffffff",
    weight: 0,
    opacity: 0,
    fillOpacity: 0,
    renderer: options.renderer || navRenderer,
    interactive: true,
    bubblingMouseEvents: false,
  })
    .addTo(options.group || navLayerGroup)
    .on("click", (event) => {
      scheduleMapPopupAction(event, () => options.onClick?.(event.latlng, event));
    });
}

/**
 * 功能：绘制 `drawNavSymbol` 对应的业务逻辑。
 * 输入：point、className、options。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function drawNavSymbol(point, className, options = {}) {
  const group = options.group || navLayerGroup;
  const labelGroup = options.labelGroup || navLabelLayerGroup;
  const marker = L.circleMarker([point.lat, point.lon], {
    pane: "navPane",
    radius: compactPhoneValue(options.radius ?? 2.5, 0.72, 1.8),
    color: options.color ?? "#4b83b7",
    weight: compactPhoneValue(options.weight ?? 1, 0.78, 0.7),
    opacity: options.opacity ?? 0.78,
    fillColor: options.fillColor ?? "#e8f2fb",
    fillOpacity: options.fillOpacity ?? 0.72,
    renderer: navRenderer,
    interactive: Boolean(options.interactive),
    bubblingMouseEvents: false,
  }).addTo(group);
  if (options.interactive) {
    marker.on("click", (event) => {
      scheduleMapPopupAction(event, () => showNavPointPopup(point, event.latlng));
    });
    addPopupHitCircle(point, [point.lat, point.lon], {
      group,
      radius: options.hitRadius ?? 14,
      onClick: (latlng) => showNavPointPopup(point, latlng),
    });
  }
  if (options.label !== false) {
    addNavLabel(point.lat, point.lon, point.ident, className, {
      interactive: true,
      group: labelGroup,
      onClick: (latlng) => showNavPointPopup(point, latlng),
    });
  }
  return marker;
}

/**
 * 功能：绘制 `drawNavIcon` 对应的业务逻辑。
 * 输入：point、className、symbolClass、options。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function drawNavIcon(point, className, symbolClass, options = {}) {
  const group = options.group || navLayerGroup;
  const labelGroup = options.labelGroup || navLabelLayerGroup;
  const symbolSize = options.iconSize ? compactPhoneSize(options.iconSize) : navSymbolSize(symbolClass);
  const symbolAnchor = options.iconAnchor || [symbolSize[0] / 2, symbolSize[1] / 2];
  addPopupHitCircle(point, [point.lat, point.lon], {
    group,
    radius: options.hitRadius ?? 12,
    onClick: (latlng) => showNavPointPopup(point, latlng),
  });
  const marker = L.marker([point.lat, point.lon], {
    pane: "navPane",
    interactive: true,
    bubblingMouseEvents: false,
    icon: L.divIcon({
      className: `nav-symbol ${symbolClass}`,
      html: "",
      iconSize: symbolSize,
      iconAnchor: symbolAnchor,
    }),
  }).addTo(group);
  marker.on("click", (event) => {
    scheduleMapPopupAction(event, () => showNavPointPopup(point, event.latlng));
  });
  if (options.label !== false) {
    addNavLabel(point.lat, point.lon, point.ident, className, {
      interactive: true,
      group: labelGroup,
      onClick: (latlng) => showNavPointPopup(point, latlng),
    });
  }
}

/**
 * 功能：执行 `navSymbolSize` 对应的业务逻辑。
 * 输入：symbolClass。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function navSymbolSize(symbolClass) {
  let size;
  switch (symbolClass) {
    case "nav-symbol-small-waypoint":
      size = [8, 8];
      break;
    case "nav-symbol-vordme":
    case "nav-symbol-vortac":
    case "nav-symbol-ndb":
      size = [19, 19];
      break;
    case "nav-symbol-vor":
    case "nav-symbol-dme":
    case "nav-symbol-tacan":
      size = [18, 18];
      break;
    default:
      size = [7, 7];
  }
  return compactPhoneSize(size);
}

function isTerminalWaypoint(point) {
  return point?.kind === "terminal_waypoint" || /^[A-Z]{2}\d{3}$/i.test(String(point?.ident || ""));
}

/**
 * 功能：执行 `airwayLabelText` 对应的业务逻辑。
 * 输入：airway。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airwayLabelText(airway) {
  return airway.name;
}

/**
 * 功能：执行 `airwayRawAngle` 对应的业务逻辑。
 * 输入：path。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airwayRawAngle(path) {
  if (!Array.isArray(path) || path.length < 2) {
    return 0;
  }
  const [a, b] = [path[0], path[path.length - 1]];
  const meanLat = ((a[0] + b[0]) / 2) * Math.PI / 180;
  const dx = (b[1] - a[1]) * Math.cos(meanLat);
  const dy = b[0] - a[0];
  return Math.atan2(dy, dx) * 180 / Math.PI;
}

/**
 * 功能：执行 `airwayLabelAngle` 对应的业务逻辑。
 * 输入：path。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airwayLabelAngle(path) {
  let angle = airwayRawAngle(path);
  if (angle > 90) angle -= 180;
  if (angle < -90) angle += 180;
  return angle;
}

/**
 * 功能：执行 `classifyNavaidSymbol` 对应的业务逻辑。
 * 输入：navaid。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function classifyNavaidSymbol(navaid) {
  if (navaid.kind === "ndb") {
    return "nav-symbol-ndb";
  }
  const cls = String(navaid.point_type || "").replace(/\s+/g, "").toUpperCase();
  const hasV = cls.includes("V");
  const hasD = cls.includes("D") || Boolean(navaid.has_dme);
  const hasT = cls.includes("T");
  const hasI = cls.includes("I") || cls.includes("L");
  if (hasI && !hasV) {
    return "nav-symbol-localizer";
  }
  if (hasV && hasT) {
    return "nav-symbol-vortac";
  }
  if (hasT) {
    return "nav-symbol-tacan";
  }
  if (hasV && hasD) {
    return "nav-symbol-vordme";
  }
  if (hasD && !hasV) {
    return "nav-symbol-dme";
  }
  if (hasI && !hasV && !hasT) {
    return "nav-symbol-localizer";
  }
  return "nav-symbol-vor";
}

/**
 * 功能：在新叠加层完成一次浏览器绘制后再移除旧层，降低 iPhone 缩放结束时的闪烁。
 * 输入：layer 为旧 Leaflet 图层组。
 * 输出：无返回值；iPhone 延后一帧移除，iPad/桌面立即移除。
 */
function removeNavOverlayLayerAfterPaint(layer) {
  if (!layer || !map.hasLayer(layer)) {
    return;
  }
  if (!isPhoneWorkbench()) {
    map.removeLayer(layer);
    return;
  }
  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(() => {
      if (map.hasLayer(layer)) {
        map.removeLayer(layer);
      }
    });
  });
}

/**
 * 功能：绘制 `drawNavOverlay` 对应的业务逻辑。
 * 输入：payload。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function drawNavOverlay(payload) {
  // 缩放或移动后重绘导航数据时，先在离屏图层组里完成新内容，再替换旧图层。
  // 这样旧航路不会在 fetch / draw 间隙先消失，避免 iPhone 上明显闪烁。
  const previousNavLayerGroup = navLayerGroup;
  const previousNavLabelLayerGroup = navLabelLayerGroup;
  const previousNavAirwayLayerGroup = navAirwayLayerGroup;
  const previousNavAirwayLabelLayerGroup = navAirwayLabelLayerGroup;
  const previousNavTerminalLayerGroup = navTerminalLayerGroup;
  const previousNavTerminalLabelLayerGroup = navTerminalLabelLayerGroup;
  const previousNavPointLayerGroup = navPointLayerGroup;
  const previousNavPointLabelLayerGroup = navPointLabelLayerGroup;
  const previousNavAirwayLayers = state.navAirwayLayers;
  const previousNavAirwayLabels = state.navAirwayLabels;
  navAirwayLayerGroup = L.layerGroup();
  navAirwayLabelLayerGroup = L.layerGroup();
  navLayerGroup = L.layerGroup();
  navLabelLayerGroup = L.layerGroup();
  navTerminalLayerGroup = L.layerGroup();
  navTerminalLabelLayerGroup = L.layerGroup();
  navPointLayerGroup = L.layerGroup();
  navPointLabelLayerGroup = L.layerGroup();
  const selectedAirway = state.selectedNavAirway;
  state.navAirwayLayers = new Map();
  state.navAirwayLabels = new Map();

  try {
  const zoom = map.getZoom();
  const roundedZoom = Math.round(zoom);
  const vectorDeclutter = state.baseMap === "vector";
  const airwayWeight = zoom >= 8 ? 1.8 : zoom >= 6 ? 1.25 : 0.95;
  const airwayOpacity = vectorDeclutter
    ? (zoom >= 8 ? 0.78 : zoom >= 6 ? 0.56 : 0.4)
    : (zoom >= 8 ? 0.55 : zoom >= 6 ? 0.36 : 0.24);
  const airwayColor = vectorDeclutter ? "#176d9f" : MAP_COLORS.airway;
  const viewBounds = currentMapBounds(0, NAV_OVERLAY_DRAW_PADDING_RATIO);
  const worldOffsets = worldCopyOffsetsForBounds(viewBounds, 1);
  // 同一帧绘制复用空列表，避免缺省字段在多轮循环里反复创建临时数组。
  const airways = payload.airways || EMPTY_LIST;
  const runways = payload.runways || EMPTY_LIST;
  const ilsList = payload.ils || EMPTY_LIST;
  const airports = payload.airports || EMPTY_LIST;
  const navaids = payload.navaids || EMPTY_LIST;
  const waypoints = payload.waypoints || EMPTY_LIST;
  const navaidIdents = new Set(navaids.map((item) => String(item.ident || "").toUpperCase()));

  if (zoom < NAV_AIRWAY_INTERACTIVE_MIN_ZOOM) {
    const batchedAirwayPaths = [];
    const batchedAirwayCandidates = [];
    airways.forEach((airway) => {
      if (!airway.path || airway.path.length < 2) {
        return;
      }
      worldOffsets.forEach((longitudeOffset) => {
        const airwayPath = pathLatLngsForWorld(airway.path, longitudeOffset);
        if (latLngPathIntersectsBounds(airwayPath, viewBounds)) {
          batchedAirwayPaths.push(airwayPath);
          batchedAirwayCandidates.push({ airway, path: airwayPath });
        }
      });
    });
    if (batchedAirwayPaths.length) {
      L.polyline(batchedAirwayPaths, {
        pane: "navPane",
        color: airwayColor,
        weight: airwayWeight,
        opacity: airwayOpacity,
        renderer: navRenderer,
        interactive: false,
        bubblingMouseEvents: false,
      }).addTo(navAirwayLayerGroup);
      const batchedAirwayHitLayer = L.polyline(batchedAirwayPaths, {
        pane: "navPane",
        color: "#ffffff",
        weight: Math.max(14, airwayWeight + 11),
        opacity: 0,
        renderer: navRenderer,
        interactive: true,
        bubblingMouseEvents: false,
      }).addTo(navAirwayLayerGroup);
      batchedAirwayHitLayer.on("click", (event) => {
        const airway = nearestAirwayForLatLng(event.latlng, batchedAirwayCandidates);
        if (airway) {
          showAirwayPopupFromEvent(airway, event);
        }
      });
    }
  } else {
    airways.forEach((airway) => {
      if (!airway.path || airway.path.length < 2) {
        return;
      }
      worldOffsets.forEach((longitudeOffset) => {
        const airwayPath = pathLatLngsForWorld(airway.path, longitudeOffset);
        if (!latLngPathIntersectsBounds(airwayPath, viewBounds)) {
          return;
        }
        const airwayLayer = L.polyline(airwayPath, {
          pane: "navPane",
          color: airwayColor,
          weight: airwayWeight,
          opacity: airwayOpacity,
          renderer: navRenderer,
          interactive: true,
          bubblingMouseEvents: false,
        }).addTo(navAirwayLayerGroup);
        airwayLayer.on("click", (event) => showAirwayPopupFromEvent(airway, event));
        const airwayHitLayer = L.polyline(airwayPath, {
          pane: "navPane",
          color: "#ffffff",
          weight: Math.max(12, airwayWeight + 9),
          opacity: 0,
          renderer: navRenderer,
          interactive: true,
          bubblingMouseEvents: false,
        }).addTo(navAirwayLayerGroup);
        airwayHitLayer.on("click", (event) => showAirwayPopupFromEvent(airway, event));
        const layerList = state.navAirwayLayers.get(airway.name) || [];
        layerList.push(airwayLayer);
        state.navAirwayLayers.set(airway.name, layerList);
        if (airway.label) {
          const labelAt = airway.label_at
            ? latLngForWorld(airway.label_at, longitudeOffset)
            : [
                (airwayPath[0][0] + airwayPath.at(-1)[0]) / 2,
                (airwayPath[0][1] + airwayPath.at(-1)[1]) / 2,
              ];
          if (!latLngPathIntersectsBounds([labelAt], viewBounds)) {
            return;
          }
          addNavLabel(labelAt[0], labelAt[1], airwayLabelText(airway), "nav-airway-label", {
            directionClass: airway.direction === "F" ? "dir-f" : airway.direction === "B" ? "dir-b" : "",
            interactive: true,
            group: navAirwayLabelLayerGroup,
            airwayName: airway.name,
            onClick: (_latlng, event) => showAirwayPopupFromEvent(airway, event),
          });
        }
      });
    });
  }

  runways.forEach((runway) => {
    worldOffsets.forEach((longitudeOffset) => {
      const runwayPath = pathLatLngsForWorld(runway.path, longitudeOffset);
      if (!latLngPathIntersectsBounds(runwayPath, viewBounds)) {
        return;
      }
      L.polyline(runwayPath, {
        pane: "navPane",
        color: MAP_COLORS.runway,
        weight: 3.6,
        opacity: 0.82,
        renderer: navRenderer,
        interactive: false,
      }).addTo(navLayerGroup);
      if (roundedZoom >= NAV_RUNWAY_LABEL_MIN_ZOOM) {
        const labelAt = thresholdLabelPosition(runwayPath, 0.12, 0.035) || [runway.lat, Number(runway.lon) + longitudeOffset];
        addNavLabel(labelAt[0], labelAt[1], (runway.ident || "").replace(/^RW/, ""), "nav-runway-label");
      }
    });
  });

  ilsList.forEach((ils) => {
    worldOffsets.forEach((longitudeOffset) => {
      const ilsPath = pathLatLngsForWorld(ils.path, longitudeOffset);
      if (!latLngPathIntersectsBounds(ilsPath, viewBounds)) {
        return;
      }
      L.polyline(ilsPath, {
        pane: "navPane",
        color: MAP_COLORS.ils,
        weight: 1.4,
        opacity: 0.78,
        dashArray: "6 6",
        renderer: navRenderer,
        interactive: false,
      }).addTo(navLayerGroup);
      if (roundedZoom >= NAV_RUNWAY_LABEL_MIN_ZOOM) {
        addNavLabel(ils.lat, Number(ils.lon) + longitudeOffset, ils.ident || "ILS", "nav-ils-label");
      }
    });
  });

  airports.forEach((airport) => {
    worldOffsets.forEach((longitudeOffset) => {
      const airportCopy = navPointWorldCopy({ ...airport, kind: "airport" }, longitudeOffset);
      if (!navPointIntersectsBounds(airportCopy, viewBounds)) {
        return;
      }
      drawNavSymbol(airportCopy, "nav-airport-label", {
        radius: zoom >= 6 ? 3.8 : 3,
        color: "#25394b",
        fillColor: "#ffffff",
        fillOpacity: 0.9,
        label: roundedZoom >= 5,
        interactive: true,
      });
    });
  });

  if (roundedZoom >= 6) {
    navaids.forEach((navaid) => {
      const className = navaid.kind === "ndb" ? "nav-ndb-label" : "nav-vor-label";
      const symbolClass = classifyNavaidSymbol(navaid);
      if (symbolClass === "nav-symbol-localizer") {
        return;
      }
      worldOffsets.forEach((longitudeOffset) => {
        const navaidCopy = navPointWorldCopy(navaid, longitudeOffset);
        if (!navPointIntersectsBounds(navaidCopy, viewBounds)) {
          return;
        }
        drawNavIcon(navaidCopy, className, symbolClass, {
          group: navPointLayerGroup,
          labelGroup: navPointLabelLayerGroup,
          label: roundedZoom >= 7,
        });
      });
    });
  }

  if (roundedZoom >= 8) {
    waypoints.forEach((waypoint) => {
      if (navaidIdents.has(String(waypoint.ident || "").toUpperCase())) {
        return;
      }
      const isSmall = isTerminalWaypoint(waypoint);
      if (isSmall && roundedZoom < NAV_TERMINAL_DETAIL_MIN_ZOOM) {
        return;
      }
      worldOffsets.forEach((longitudeOffset) => {
        const waypointCopy = navPointWorldCopy(waypoint, longitudeOffset);
        if (!navPointIntersectsBounds(waypointCopy, viewBounds)) {
          return;
        }
        const group = isSmall ? navTerminalLayerGroup : navPointLayerGroup;
        const labelGroup = isSmall ? navTerminalLabelLayerGroup : navPointLabelLayerGroup;
        drawNavIcon(waypointCopy, "nav-waypoint-label", isSmall ? "nav-symbol-small-waypoint" : "nav-symbol-waypoint", {
          group,
          labelGroup,
          label: true,
        });
      });
    });
  }

  if (selectedAirway) {
    setNavAirwayHighlight(selectedAirway, true);
  }
  state.navOverlayDrawZoom = roundedZoom;
  applyMapOverlayVisibility();
  [
    previousNavLayerGroup,
    previousNavLabelLayerGroup,
    previousNavAirwayLayerGroup,
    previousNavAirwayLabelLayerGroup,
    previousNavTerminalLayerGroup,
    previousNavTerminalLabelLayerGroup,
    previousNavPointLayerGroup,
    previousNavPointLabelLayerGroup,
  ].forEach(removeNavOverlayLayerAfterPaint);
  } catch (error) {
    navLayerGroup.clearLayers();
    navLabelLayerGroup.clearLayers();
    navAirwayLayerGroup.clearLayers();
    navAirwayLabelLayerGroup.clearLayers();
    navTerminalLayerGroup.clearLayers();
    navTerminalLabelLayerGroup.clearLayers();
    navPointLayerGroup.clearLayers();
    navPointLabelLayerGroup.clearLayers();
    navLayerGroup = previousNavLayerGroup;
    navLabelLayerGroup = previousNavLabelLayerGroup;
    navAirwayLayerGroup = previousNavAirwayLayerGroup;
    navAirwayLabelLayerGroup = previousNavAirwayLabelLayerGroup;
    navTerminalLayerGroup = previousNavTerminalLayerGroup;
    navTerminalLabelLayerGroup = previousNavTerminalLabelLayerGroup;
    navPointLayerGroup = previousNavPointLayerGroup;
    navPointLabelLayerGroup = previousNavPointLabelLayerGroup;
    state.navAirwayLayers = previousNavAirwayLayers;
    state.navAirwayLabels = previousNavAirwayLabels;
    throw error;
  }
}

/**
 * 功能：安排导航叠加层短延迟重试，避免缩放中断或瞬时网络失败后停留在低细节状态。
 * 输入：delayMs 为重试等待毫秒数。
 * 输出：无返回值；设置一次性定时器。
 */
function scheduleNavOverlayRetry(delayMs = 650) {
  window.clearTimeout(state.navOverlayRetryTimer);
  state.navOverlayRetryTimer = window.setTimeout(() => {
    state.navOverlayRetryTimer = 0;
    refreshNavOverlay().catch((error) => console.warn("Nav overlay retry failed", error));
  }, delayMs);
}

/**
 * 功能：执行 `refreshNavOverlay` 对应的业务逻辑。
 * 输入：无。
 * 输出：Promise，解析为函数处理结果。
 */
async function refreshNavOverlay() {
  const zoom = Math.round(map.getZoom());
  window.clearTimeout(state.navOverlayRetryTimer);
  state.navOverlayRetryTimer = 0;
  if (
    map.getContainer().classList.contains("is-map-moving") ||
    map.getContainer().classList.contains("is-smooth-zooming")
  ) {
    scheduleNavOverlayRetry(180);
    return;
  }
  const visibleBounds = currentMapBounds();
  if (
    state.navOverlayPayload &&
    state.navOverlayZoom === zoom &&
    state.navOverlayDrawZoom === zoom &&
    boundsContainBounds(state.navOverlayDrawBounds, visibleBounds)
  ) {
    return;
  }
  if (
    state.navOverlayPayload &&
    state.navOverlayZoom === zoom &&
    boundsContainBounds(state.navOverlayFetchBounds, visibleBounds)
  ) {
    drawNavOverlay(state.navOverlayPayload);
    state.navOverlayDrawBounds = currentMapBounds(0, NAV_OVERLAY_DRAW_PADDING_RATIO);
    return;
  }

  const version = (state.navOverlayVersion += 1);
  state.navOverlayAbortController?.abort();
  const controller = new AbortController();
  state.navOverlayAbortController = controller;
  const bounds = currentMapBounds(0, NAV_OVERLAY_FETCH_PADDING_RATIO);
  const params = new URLSearchParams({
    south: bounds.south.toFixed(4),
    west: bounds.west.toFixed(4),
    north: bounds.north.toFixed(4),
    east: bounds.east.toFixed(4),
    zoom: String(zoom),
  });
  try {
    const payload = await fetchJson(`/api/nav-overlay?${params.toString()}`, { signal: controller.signal });
    if (version !== state.navOverlayVersion) {
      return;
    }
    state.navOverlayPayload = payload;
    state.navOverlayFetchBounds = bounds;
    state.navOverlayDrawBounds = currentMapBounds(0, NAV_OVERLAY_DRAW_PADDING_RATIO);
    state.navOverlayZoom = zoom;
    drawNavOverlay(payload);
  } catch (error) {
    if (error.name === "AbortError") {
      return;
    }
    console.warn("Nav overlay failed", error);
    scheduleNavOverlayRetry();
  } finally {
    if (state.navOverlayAbortController === controller) {
      state.navOverlayAbortController = null;
    }
  }
}

const refreshNavOverlayDebounced = debounce(refreshNavOverlay, NAV_OVERLAY_REFRESH_DELAY_MS);
const clearZoomingClassDebounced = debounce(() => map.getContainer().classList.remove("is-smooth-zooming"), MAP_ZOOM.wheelIdleDelay);
map.on("zoomstart", () => {
  map.getContainer().classList.add("is-smooth-zooming");
  finishVectorMapPanMirror();
  beginVectorMapZoomMirror();
});
map.on("zoom", () => {
  if (vectorMapZoomMirrorActive) {
    scheduleVectorMapZoomMirror();
    return;
  }
  scheduleVectorMapSync();
});
map.on("zoomend", () => {
  clearZoomingClassDebounced();
  finishVectorMapZoomMirror();
});
map.on("movestart", () => {
  map.getContainer().classList.add("is-map-moving");
});
map.on("dragstart", beginVectorMapPanMirror);
map.on("drag", scheduleVectorMapPanMirror);
map.on("dragend", scheduleVectorMapPanMirror);
map.on("move", () => {
  if (vectorMapPanMirrorActive) {
    scheduleVectorMapPanMirror();
    return;
  }
  if (vectorMapZoomMirrorActive) {
    scheduleVectorMapZoomMirror();
    return;
  }
  scheduleVectorMapSync();
});
map.on("moveend", () => {
  map.getContainer().classList.remove("is-map-moving");
  if (vectorMapPanMirrorActive) {
    finishVectorMapPanMirror();
    return;
  }
  if (vectorMapZoomMirrorActive) {
    finishVectorMapZoomMirror();
    return;
  }
  syncVectorMap();
});
map.on("viewreset", syncVectorMap);
map.on("resize", () => {
  scheduleVectorMapResizeSync();
});
map.on("moveend zoomend", refreshNavOverlayDebounced);
map.on("popupclose", () => {
  if (!state.refreshingNavPopup) {
    state.activeNavPopup = null;
  }
});
map.on("click", (event) => {
  if (isHandledMapClick(event)) {
    return;
  }
  map.closePopup();
  if (state.selectedNavAirway) {
    setNavAirwayHighlight(state.selectedNavAirway, false);
    state.selectedNavAirway = null;
  }
});

/**
 * 功能：执行 `handleNavPopupRouteButtonClick` 对应的业务逻辑。
 * 输入：event。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function handleNavPopupRouteButtonClick(event) {
  const button = event.target instanceof Element ? event.target.closest(".nav-popup-route-button") : null;
  if (!button) {
    return;
  }
  event.preventDefault();
  event.stopPropagation();
  event.stopImmediatePropagation?.();
  const airwayName = button.dataset.airwayName;
  if (airwayName) {
    toggleSelectedNavAirway(airwayName);
  }
}

/**
 * 功能：执行 `handleAirportPopupActionClick` 对应的业务逻辑。
 * 输入：event。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function handleAirportPopupActionClick(event) {
  const button = event.target instanceof Element ? event.target.closest(".nav-popup-action") : null;
  if (!button) {
    return;
  }
  event.preventDefault();
  event.stopPropagation();
  event.stopImmediatePropagation?.();
  const ident = button.dataset.airportIdent;
  const slot = button.dataset.airportAction;
  if (!ident || !AIRPORT_SLOTS.includes(slot)) {
    return;
  }
  const input = elements[`${slot}Input`];
  if (input) {
    input.value = ident;
  }
  loadAirportIntoPanel(ident, slot).catch((error) => {
    setErrorStatus(error);
  });
  map.closePopup();
}

map.getContainer().addEventListener("click", handleNavPopupRouteButtonClick, true);
document.addEventListener("click", handleNavPopupRouteButtonClick, true);
map.getContainer().addEventListener("click", handleAirportPopupActionClick, true);
document.addEventListener("click", handleAirportPopupActionClick, true);

/**
 * 功能：计算 `pointDistance` 对应的业务逻辑。
 * 输入：a、b。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function pointDistance(a, b) {
  return Math.hypot(a.lat - b.lat, a.lon - b.lon);
}

/**
 * 功能：计算 `pointAtHalfLength` 对应的业务逻辑。
 * 输入：path。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function pointAtHalfLength(path) {
  if (!path.length) {
    return null;
  }
  let total = 0;
  for (let index = 1; index < path.length; index += 1) {
    total += pointDistance(path[index - 1], path[index]);
  }
  let traversed = 0;
  const halfway = total / 2;
  for (let index = 1; index < path.length; index += 1) {
    const segmentLength = pointDistance(path[index - 1], path[index]);
    if (traversed + segmentLength >= halfway) {
      const remain = halfway - traversed;
      const ratio = segmentLength === 0 ? 0 : remain / segmentLength;
      return {
        lat: path[index - 1].lat + (path[index].lat - path[index - 1].lat) * ratio,
        lon: path[index - 1].lon + (path[index].lon - path[index - 1].lon) * ratio,
      };
    }
    traversed += segmentLength;
  }
  return path.at(-1);
}

/**
 * 功能：执行 `midpointForLeg` 对应的业务逻辑。
 * 输入：points、leg。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function midpointForLeg(points, leg) {
  const startIndex = points.findIndex((point) => point.ident === leg.entry);
  const endIndex = points.findIndex((point, index) => index >= startIndex && point.ident === leg.exit);
  if (startIndex === -1 || endIndex === -1) {
    return null;
  }
  return pointAtHalfLength(points.slice(startIndex, endIndex + 1));
}

/**
 * 功能：计算 `pointsForLeg` 对应的业务逻辑。
 * 输入：points、leg。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function pointsForLeg(points, leg) {
  const startIndex = points.findIndex((point) => point.ident === leg.entry);
  const endIndex = points.findIndex((point, index) => index >= startIndex && point.ident === leg.exit);
  if (startIndex === -1 || endIndex === -1) {
    return [];
  }
  return points.slice(startIndex, endIndex + 1);
}

/**
 * 功能：执行 `airwayKeyForLeg` 对应的业务逻辑。
 * 输入：leg。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airwayKeyForLeg(leg) {
  return `${leg.type}:${leg.name || "DCT"}:${leg.entry}:${leg.exit}`;
}

/**
 * 功能：处理 `routeDetailForLeg` 对应的业务逻辑。
 * 输入：leg。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function routeDetailForLeg(leg) {
  return {
    name: leg.type === "airway" ? leg.name : "DCT",
    from: leg.entry,
    to: leg.exit,
    direction: "",
    area_code: "",
  };
}

/**
 * 功能：构建 `buildRoutePointAssociations` 对应的业务逻辑。
 * 输入：points、legs。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function buildRoutePointAssociations(points, legs) {
  const associations = new Map();
  const addAssociation = (ident, detail) => {
    if (!ident) {
      return;
    }
    const key = String(ident);
    const list = associations.get(key) || [];
    if (!list.some((item) => item.name === detail.name && item.from === detail.from && item.to === detail.to)) {
      list.push(detail);
    }
    associations.set(key, list);
  };

  legs
    .filter((leg) => ["airway", "direct"].includes(leg.type))
    .forEach((leg) => {
      const detail = routeDetailForLeg(leg);
      const legPoints = pointsForLeg(points, leg);
      if (legPoints.length) {
        legPoints.forEach((point) => addAssociation(point.ident, detail));
        return;
      }
      addAssociation(leg.entry, detail);
      addAssociation(leg.exit, detail);
    });
  return associations;
}

/**
 * 功能：显示 `showRouteLegPopup` 对应的业务逻辑。
 * 输入：leg、latlng。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function showRouteLegPopup(leg, latlng) {
  if (leg.type === "airway") {
    showAirwayPopup({
      name: leg.name,
      from: leg.entry,
      to: leg.exit,
      direction: "",
      area_code: "",
    }, latlng);
    return;
  }
  showNavPointPopup({
    kind: "direct",
    ident: "DCT",
    name: `${leg.entry} → ${leg.exit}`,
    lat: latlng.lat,
    lon: normalizeLongitude(latlng.lng),
    associated_routes: [routeDetailForLeg(leg)],
  }, latlng);
}

/**
 * 功能：执行 `popupPointWithRouteAssociations` 对应的业务逻辑。
 * 输入：point、associations。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function popupPointWithRouteAssociations(point, associations) {
  return normalizePopupPoint({
    ...point,
    associated_routes: associations.get(String(point.ident)) || point.associated_routes || [],
  });
}

/**
 * 功能：添加 `addRoutePointHitTarget` 对应的业务逻辑。
 * 输入：point、associations。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function addRoutePointHitTarget(point, associations) {
  const popupPoint = popupPointWithRouteAssociations(restoreOriginalLongitude(point), associations);
  L.circleMarker([point.lat, point.lon], {
    pane: "routeHitPane",
    radius: 12,
    color: "#ffffff",
    weight: 0,
    opacity: 0.001,
    fillColor: "#ffffff",
    fillOpacity: 0.001,
    interactive: true,
    bubblingMouseEvents: false,
  })
    .addTo(routeLayerGroup)
    .on("click", (event) => {
      scheduleMapPopupAction(event, () => showNavPointPopup(popupPoint, event.latlng));
    });
}

/**
 * 功能：执行 `registerAirwaySegmentLayer` 对应的业务逻辑。
 * 输入：airwayKey、visibleLayer、hitLayer。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function registerAirwaySegmentLayer(airwayKey, visibleLayer, hitLayer) {
  const layers = state.airwaySegmentLayers.get(airwayKey) || [];
  layers.push({ visible: visibleLayer, hit: hitLayer });
  state.airwaySegmentLayers.set(airwayKey, layers);
}

/**
 * 功能：设置 `setAirwayHighlight` 对应的业务逻辑。
 * 输入：airwayKey、hovered。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function setAirwayHighlight(airwayKey, hovered) {
  const layers = state.airwaySegmentLayers.get(airwayKey);
  const chip = state.airwayLegChips.get(airwayKey);
  if (!layers && !chip) {
    return;
  }
  if (hovered) {
    const style = routeStyleForKind(state.currentRouteLayerKind);
    if (state.hoveredAirwayKey && state.hoveredAirwayKey !== airwayKey) {
      setAirwayHighlight(state.hoveredAirwayKey, false);
    }
    state.hoveredAirwayKey = airwayKey;
    if (layers) {
      layers.forEach((layer) => {
        layer.visible.setStyle({ weight: routeStrokeWeight(10), opacity: 1, color: style.hoverColor });
        layer.visible.bringToFront();
        layer.hit.bringToFront();
      });
    }
    chip?.classList.add("hovered");
    return;
  }
  if (state.hoveredAirwayKey === airwayKey) {
    state.hoveredAirwayKey = null;
  }
  if (layers) {
    const style = routeStyleForKind(state.currentRouteLayerKind);
    layers.forEach((layer) => {
      layer.visible.setStyle({ weight: routeStrokeWeight(5), opacity: 0.98, color: style.color });
    });
  }
  chip?.classList.remove("hovered");
}

/**
 * 功能：设置 `setProcedureHighlight` 对应的业务逻辑。
 * 输入：type、hovered。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function setProcedureHighlight(type, hovered) {
  const layers = state.procedureVisualLayers[type];
  const chip = state.procedureChips.get(type);
  if (!layers && !chip) {
    return;
  }
  if (hovered) {
    layers?.primary.setStyle({ weight: routeStrokeWeight(9), opacity: 1 });
    layers?.primary.bringToFront();
    layers?.highlights?.forEach((marker) => {
      marker.outer.bringToFront();
      marker.inner.bringToFront();
    });
    chip?.classList.add("hovered");
    return;
  }
  layers?.primary.setStyle({ weight: routeStrokeWeight(5), opacity: 0.98, color: layers.color });
  layers?.highlights?.forEach((marker) => {
    marker.outer.bringToFront();
    marker.inner.bringToFront();
  });
  chip?.classList.remove("hovered");
}

/**
 * 功能：绘制 `drawRouteCopy` 对应的业务逻辑。
 * 输入：points、payload、routeAssociations、longitudeOffset、fitBoundsLatLngs。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function drawRouteCopy(points, payload, routeAssociations, longitudeOffset, fitBoundsLatLngs) {
  const routeStyle = routeStyleForKind(state.currentRouteLayerKind);
  const copyKey = String(longitudeOffset);
  const enroutePoints = points.slice(1, -1);
  const visiblePoints = [];
  const seenVisible = new Set();
  [points[0], ...enroutePoints, points.at(-1)]
    .filter(Boolean)
    .forEach((point) => {
      const key = `${point.ident}:${point.lat}:${point.lon}`;
      if (seenVisible.has(key)) {
        return;
      }
      seenVisible.add(key);
      visiblePoints.push(point);
    });

  visiblePoints.forEach((point, index) => {
    const popupPoint = popupPointWithRouteAssociations(restoreOriginalLongitude(point), routeAssociations);
    drawPointMarker(point, index === 0 || index === visiblePoints.length - 1, {
      popupPoint,
      keySuffix: copyKey,
      group: routeLayerGroup,
    });
    addTextLabel(point.lat, point.lon, point.ident, "waypoint-label", {
      interactive: true,
      group: routeLayerGroup,
      onClick: (latlng) => showNavPointPopup(popupPoint, latlng),
    });
  });

  payload.legs
    .filter((leg) => ["airway", "direct"].includes(leg.type))
    .forEach((leg) => {
      const airwayKey = airwayKeyForLeg(leg);
      const legPoints = pointsForLeg(points, leg);
      if (legPoints.length >= 2) {
        const latlngs = legPoints.map(latLngForPoint);
        const visibleLayer = L.polyline(latlngs, {
          pane: "routePane",
          color: routeStyle.color,
          weight: routeStrokeWeight(5),
          opacity: 0.98,
          interactive: false,
          lineCap: "round",
          lineJoin: "round",
        }).addTo(routeLayerGroup);
        if (!longitudeOffset) {
          fitBoundsLatLngs.push(...visibleLayer.getLatLngs());
        }
        const hitLayer = L.polyline(latlngs, {
          pane: "routeHitPane",
          color: "#ffffff",
          weight: 14,
          opacity: 0.01,
          interactive: true,
          bubblingMouseEvents: false,
          lineCap: "round",
          lineJoin: "round",
        }).addTo(routeLayerGroup);
        hitLayer.on("mouseover", () => setAirwayHighlight(airwayKey, true));
        hitLayer.on("mouseout", () => setAirwayHighlight(airwayKey, false));
        hitLayer.on("click", (event) => {
          scheduleMapPopupAction(event, () => {
            setAirwayHighlight(airwayKey, true);
            showRouteLegPopup(leg, event.latlng);
          });
        });
        registerAirwaySegmentLayer(airwayKey, visibleLayer, hitLayer);
      }
      const midpoint = midpointForLeg(points, leg);
      if (midpoint && leg.type === "airway") {
        addTextLabel(midpoint.lat, midpoint.lon, leg.name, "airway-label", {
          interactive: true,
          group: routeLayerGroup,
          onClick: (latlng) => {
            setAirwayHighlight(airwayKey, true);
            showRouteLegPopup(leg, latlng);
          },
        });
      }
    });

  if (!longitudeOffset) {
    visiblePoints.forEach((point, index) => {
      const isEndpoint = index === 0 || index === visiblePoints.length - 1;
      addWaypointHighlightMarker(latLngForPoint(point), routeLayerGroup, {
        outerRadius: compactPhoneValue(isEndpoint ? 8.5 : 7, 0.72, isEndpoint ? 5.6 : 4.8),
        innerRadius: compactPhoneValue(isEndpoint ? 3.3 : 2.7, 0.72, isEndpoint ? 2.5 : 2.1),
        color: "#fff4b5",
        fillColor: routeStyle.color,
        fillOpacity: isEndpoint ? 0.24 : 0.18,
        innerFillColor: "#071928",
      });
    });
  }

  visiblePoints.forEach((point) => addRoutePointHitTarget(point, routeAssociations));

  drawPointMarker({ ...points[0], kind: "departure" }, true, {
    popupPoint: popupPointWithRouteAssociations(restoreOriginalLongitude(points[0]), routeAssociations),
    keySuffix: `${copyKey}:departure`,
    group: routeLayerGroup,
  }).setStyle({
    color: MAP_COLORS.departure,
    fillColor: MAP_COLORS.departure,
  });
  drawPointMarker({ ...points.at(-1), kind: "arrival" }, true, {
    popupPoint: popupPointWithRouteAssociations(restoreOriginalLongitude(points.at(-1)), routeAssociations),
    keySuffix: `${copyKey}:arrival`,
    group: routeLayerGroup,
  }).setStyle({
    color: MAP_COLORS.arrival,
    fillColor: MAP_COLORS.arrival,
  });
}

/**
 * 功能：绘制 `drawRoute` 对应的业务逻辑。
 * 输入：payload。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function drawRoute(payload, options = {}) {
  const basePoints = withDisplayLongitudes(payload.points || []);
  if (basePoints.length < 2) {
    return;
  }
  state.currentRouteLayerKind = normalizeRouteLayerKind(options.routeLayerKind || inferRouteLayerKind(payload));
  routeLayerGroup = routeLayerGroupForKind(state.currentRouteLayerKind);
  autoRouteLayerGroup.clearLayers();
  manualRouteLayerGroup.clearLayers();
  markerLayerGroup.clearLayers();
  clearLabels();
  state.airportMarkers.clear();
  resetAirportSlotMarkerKeys();
  state.airwaySegmentLayers.clear();
  state.hoveredAirwayKey = null;

  const routeAssociations = buildRoutePointAssociations(basePoints, payload.legs || []);
  const fitBoundsLatLngs = [];
  ROUTE_WORLD_COPY_OFFSETS.forEach((longitudeOffset) => {
    drawRouteCopy(
      routeWorldCopy(basePoints, longitudeOffset),
      payload,
      routeAssociations,
      longitudeOffset,
      fitBoundsLatLngs,
    );
  });

  const fallbackBounds = basePoints.map(latLngForPoint);
  const boundsPolyline = L.polyline(fitBoundsLatLngs.length ? fitBoundsLatLngs : fallbackBounds, {
    pane: "routePane",
    color: "#000000",
    weight: 0,
    opacity: 0,
    interactive: false,
  }).addTo(routeLayerGroup);
  if (options.fitBounds !== false) {
    map.fitBounds(boundsPolyline.getBounds(), { padding: [36, 36] });
  }
  applyMapOverlayVisibility();
}

/**
 * 功能：清理 `clearProcedure` 对应的业务逻辑。
 * 输入：type。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function clearProcedure(type, options = {}) {
  if (options.recordHistory !== false && state.selectedProcedures[type]) {
    pushDrawingUndoState();
  }
  state.procedureRequestVersion[type] += 1;
  procedureLayerGroups[type].clearLayers();
  state.procedureVisualLayers[type] = null;
  const clearedProcedure = state.selectedProcedures[type];
  state.selectedProcedures[type] = null;
  if (
    clearedProcedure &&
    state.activeSelectionProcedure?.type === type &&
    state.activeSelectionProcedure?.airport === clearedProcedure.airport &&
    state.activeSelectionProcedure?.procedure === clearedProcedure.procedure &&
    state.activeSelectionProcedure?.transition === clearedProcedure.transition
  ) {
    renderSelectionMessage(t("selection.chooseProcedure"));
  }
  renderSelectedProcedures();
  if (state.departureAirport?.airport_identifier) {
    rerenderProcedureLists("departure", state.departureAirport.airport_identifier);
  }
  if (state.arrivalAirport?.airport_identifier) {
    rerenderProcedureLists("arrival", state.arrivalAirport.airport_identifier);
  }
  if (state.manualAirport?.airport_identifier) {
    rerenderProcedureLists("manual", state.manualAirport.airport_identifier);
  }
  updateTrackHistoryControlState();
  scheduleCalculateRender();
}

/**
 * 功能：清理 `clearAllProcedures` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function clearAllProcedures(options = {}) {
  if (options.recordHistory !== false && ["sid", "star", "approach"].some((type) => state.selectedProcedures[type])) {
    pushDrawingUndoState();
  }
  clearProcedure("sid", { recordHistory: false });
  clearProcedure("star", { recordHistory: false });
  clearProcedure("approach", { recordHistory: false });
}

/**
 * 功能：清理 `clearAutoSelectedProcedures` 对应的业务逻辑。
 * 输入：exceptType。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function clearAutoSelectedProcedures(exceptType = "", options = {}) {
  if (options.recordHistory !== false && Object.entries(state.selectedProcedures).some(([type, value]) => value?.source === "auto" && type !== exceptType)) {
    pushDrawingUndoState();
  }
  Object.entries(state.selectedProcedures).forEach(([type, value]) => {
    if (!value || value.source !== "auto" || type === exceptType) {
      return;
    }
    clearProcedure(type, { recordHistory: false });
  });
}

/**
 * 功能：执行 `latLngsFromProcedurePath` 对应的业务逻辑。
 * 输入：path、points。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function latLngsFromProcedurePath(path, points) {
  return (path?.length ? path : points.map((item) => ({
    lat: item.waypoint_latitude,
    lon: item.waypoint_longitude,
  }))).map((item) => [item.lat, item.lon]);
}

/**
 * 功能：执行 `panToLatLngsCenter` 对应的业务逻辑。
 * 输入：latlngs。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function panToLatLngsCenter(latlngs) {
  if (!latlngs.length) {
    return;
  }
  const bounds = L.latLngBounds(latlngs);
  if (bounds.isValid()) {
    map.panTo(bounds.getCenter(), { animate: true, duration: 0.42 });
  }
}

function addProcedureWaypointHighlights(type, points, color) {
  const markers = [];
  const seen = new Set();
  (points || []).forEach((item) => {
    const latlng = procedureItemLatLng(item);
    if (!latlng) {
      return;
    }
    const ident = String(item.waypoint_identifier || item.fix_identifier || "");
    const key = `${ident}:${latlng.lat.toFixed(6)}:${latlng.lng.toFixed(6)}`;
    if (seen.has(key)) {
      return;
    }
    seen.add(key);
    markers.push(addWaypointHighlightMarker(latlng, procedureLayerGroups[type], {
      outerRadius: compactPhoneValue(7, 0.72, 4.8),
      innerRadius: compactPhoneValue(2.7, 0.72, 2.1),
      color: "#fff4b5",
      fillColor: color,
      fillOpacity: 0.2,
      innerFillColor: "#071928",
    }));
  });
  return markers;
}

/**
 * 功能：绘制 `drawProcedure` 对应的业务逻辑。
 * 输入：type、path、points、color、options。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function drawProcedure(type, path, points, color, options = {}) {
  procedureLayerGroups[type].clearLayers();
  const latlngs = latLngsFromProcedurePath(path, points);
  const layer = L.polyline(latlngs, {
    pane: "routePane",
    color,
    weight: routeStrokeWeight(5),
    opacity: 0.98,
    interactive: false,
    lineCap: "round",
    lineJoin: "round",
  }).addTo(procedureLayerGroups[type]);
  const highlights = addProcedureWaypointHighlights(type, points, color);
  state.procedureVisualLayers[type] = { primary: layer, color, highlights };
  layer.bringToFront();
  highlights.forEach((marker) => {
    marker.outer.bringToFront();
    marker.inner.bringToFront();
  });
  if (!options.skipFitBounds) {
    panToLatLngsCenter(latlngs);
  }
}

/**
 * 功能：绘制 `drawApproach` 对应的业务逻辑。
 * 输入：primaryPath、missedPath、points、options。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function drawApproach(primaryPath, missedPath, points, options = {}) {
  procedureLayerGroups.approach.clearLayers();
  const latlngs = latLngsFromProcedurePath(primaryPath, points);
  const primary = L.polyline(latlngs, {
    pane: "routePane",
    color: MAP_COLORS.approach,
    weight: routeStrokeWeight(5),
    opacity: 0.98,
    interactive: false,
    lineCap: "round",
    lineJoin: "round",
  }).addTo(procedureLayerGroups.approach);
  const highlights = addProcedureWaypointHighlights("approach", points, MAP_COLORS.approach);
  state.procedureVisualLayers.approach = { primary, color: MAP_COLORS.approach, highlights };
  const panLatLngs = [...latlngs];
  if (missedPath?.length >= 2) {
    const missedLatLngs = missedPath.map((item) => [item.lat, item.lon]);
    L.polyline(missedLatLngs, {
      pane: "routePane",
      color: MAP_COLORS.approach,
      weight: routeStrokeWeight(2),
      opacity: 0.95,
      dashArray: "6 8",
      interactive: false,
      lineCap: "round",
      lineJoin: "round",
    }).addTo(procedureLayerGroups.approach);
    panLatLngs.push(...missedLatLngs);
  }
  primary.bringToFront();
  highlights.forEach((marker) => {
    marker.outer.bringToFront();
    marker.inner.bringToFront();
  });
  if (!options.skipFitBounds) {
    panToLatLngsCenter(panLatLngs);
  }
}

/**
 * 功能：渲染 `renderList` 对应的业务逻辑。
 * 输入：container、items、formatRow。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function renderList(container, items, formatRow, options = {}) {
  container.innerHTML = "";
  if (!items.length) {
    container.innerHTML = `<div class="helper-text">${escapeHtml(t("common.noData"))}</div>`;
    return;
  }
  const table = document.createElement("div");
  table.className = ["list-table", options.className].filter(Boolean).join(" ");
  items.forEach((item) => table.appendChild(formatRow(item)));
  container.appendChild(table);
}

/**
 * 功能：执行 `rowTemplate` 对应的业务逻辑。
 * 输入：title、meta。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function rowTemplate(title, meta) {
  const row = document.createElement("div");
  row.className = "list-row";
  row.innerHTML = `<div class="list-title">${title}</div><div class="list-meta">${meta}</div>`;
  return row;
}

/**
 * 功能：渲染 `renderCompactCommunications` 对应的业务逻辑。
 * 输入：container、items。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function renderCompactCommunications(container, items) {
  container.innerHTML = "";
  if (!items.length) {
    container.innerHTML = `<div class="helper-text">${escapeHtml(t("common.noData"))}</div>`;
    return;
  }
  const wrap = document.createElement("div");
  wrap.className = "route-legs";
  items.slice(0, 16).forEach((item) => {
    const chip = document.createElement("div");
    chip.className = "route-leg";
    chip.textContent = `${item.communication_type || "COM"} ${item.communication_frequency ?? "--"}`;
    wrap.appendChild(chip);
  });
  container.appendChild(wrap);
}

/**
 * 功能：规范化 `normalizeTransition` 对应的业务逻辑。
 * 输入：transition。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function normalizeTransition(transition) {
  return transition || "ALL";
}

/**
 * 功能：执行 `inferRunwayFromProcedure` 对应的业务逻辑。
 * 输入：type、item。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function inferRunwayFromProcedure(type, item) {
  const transition = normalizeTransition(item.transition_identifier).toUpperCase();
  if (transition.startsWith("RW")) {
    return transition;
  }

  const procedure = String(item.procedure_identifier || "").toUpperCase();
  if ((type === "sid" || type === "star") && !procedure.startsWith("DEP")) {
    return "ALL";
  }
  const match = procedure.match(/(?:^|[^0-9])(0?[0-9]{1,2}[LCRB]?)(?:[^0-9]|$)/);
  if (!match) {
    return "ALL";
  }
  const runwayCore = match[1].replace(/^0/, "");
  return `RW${runwayCore}`;
}

/**
 * 功能：解析 `parseRunwayIdentifier` 对应的业务逻辑。
 * 输入：runway。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function parseRunwayIdentifier(runway) {
  const match = String(runway || "").toUpperCase().match(/^RW(0?[0-9]{1,2})([LCRB]?)$/);
  if (!match) {
    return null;
  }
  return {
    number: String(Number(match[1])),
    suffix: match[2] || "",
  };
}

/**
 * 功能：执行 `runwayMatches` 对应的业务逻辑。
 * 输入：candidateRunway、selectedRunway。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function runwayMatches(candidateRunway, selectedRunway) {
  if (!selectedRunway || selectedRunway === "ALL") {
    return true;
  }
  if (!candidateRunway || candidateRunway === "ALL") {
    return true;
  }
  if (candidateRunway === selectedRunway) {
    return true;
  }
  const candidate = parseRunwayIdentifier(candidateRunway);
  const selected = parseRunwayIdentifier(selectedRunway);
  if (!candidate || !selected || candidate.number !== selected.number) {
    return false;
  }
  return (
    candidate.suffix === selected.suffix ||
    candidate.suffix === "B" ||
    selected.suffix === "B" ||
    !candidate.suffix ||
    !selected.suffix
  );
}

/**
 * 功能：处理 `procedureMatchesRunway` 对应的业务逻辑。
 * 输入：type、item、runway。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function procedureMatchesRunway(type, item, runway) {
  if (!runway || runway === "ALL") {
    return true;
  }
  return runwayMatches(inferRunwayFromProcedure(type, item), runway);
}

/**
 * 功能：规范化 `normalizeRunwayChoice` 对应的业务逻辑。
 * 输入：slot、value。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function normalizeRunwayChoice(slot, value) {
  const options = state.runwayButtonOptions[slot] || ["ALL"];
  return options.includes(value) ? value : "ALL";
}

/**
 * 功能：更新 `updateRunwayChoice` 对应的业务逻辑。
 * 输入：slot、value。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function updateRunwayChoice(slot, value) {
  state.selectedRunways[slot] = normalizeRunwayChoice(slot, value);
  renderRunwayButtons(slot);
  if (state[`${slot}Airport`]) {
    rerenderProcedureLists(slot, state[`${slot}Airport`].airport_identifier);
  }
}

/**
 * 功能：渲染 `renderRunwayButtons` 对应的业务逻辑。
 * 输入：slot。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function renderRunwayButtons(slot) {
  const options = state.runwayButtonOptions[slot] || ["ALL"];
  const value = normalizeRunwayChoice(slot, state.selectedRunways[slot]);
  state.selectedRunways[slot] = value;
  const filterContainer = elements[`${slot}RunwaySelect`];
  const planContainer = slot === "arrival" ? elements.planArrivalRunway : elements.planDepartureRunway;
  if (filterContainer) {
    renderChoiceGroup(filterContainer, options, value, (choice) => updateRunwayChoice(slot, choice), t("common.allRunways"));
  }
  if (slot !== "manual" && planContainer) {
    renderChoiceGroup(planContainer, options, value, (choice) => updateRunwayChoice(slot, choice), t("common.auto"));
  }
}

/**
 * 功能：渲染 `renderChoiceGroup` 对应的业务逻辑。
 * 输入：container、options、activeValue、onSelect、emptyLabel。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function renderChoiceGroup(container, options, activeValue, onSelect, emptyLabel = null) {
  container.innerHTML = "";
  const fallbackEmptyLabel = emptyLabel ?? t("common.auto");
  options.forEach((rawOption) => {
    const option = typeof rawOption === "string"
      ? { value: rawOption, label: rawOption === "ALL" ? fallbackEmptyLabel : rawOption }
      : rawOption;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "choice-button";
    button.textContent = option.label;
    if (option.value === activeValue) {
      button.classList.add("active");
    }
    button.addEventListener("click", () => onSelect(option.value));
    container.appendChild(button);
  });
  if (!options.length) {
    container.innerHTML = `<div class="helper-text">${escapeHtml(t("common.noOptions"))}</div>`;
  }
}

/**
 * 功能：渲染 `renderProcedureList` 对应的业务逻辑。
 * 输入：container、items、type、airportIdent、slot。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function renderProcedureList(container, items, type, airportIdent, slot) {
  container.innerHTML = "";
  const runway = state.selectedRunways[slot];
  const filteredItems = items.filter((item) => procedureMatchesRunway(type, item, runway));
  if (!filteredItems.length) {
    container.innerHTML = `<div class="helper-text">${escapeHtml(t("procedure.noAvailable"))}</div>`;
    return;
  }
  filteredItems.slice(0, 40).forEach((item) => {
    const chip = document.createElement("button");
    chip.type = "button";
    chip.className = "procedure-chip";
    const transition = normalizeTransition(item.transition_identifier);
    chip.textContent = `${item.procedure_identifier} ${transition}`;
    const selected = state.selectedProcedures[type];
    if (selected && selected.airport === airportIdent && selected.procedure === item.procedure_identifier && selected.transition === transition) {
      chip.classList.add("active");
    }
    chip.addEventListener("click", () =>
      previewProcedure(type, airportIdent, item.procedure_identifier, transition),
    );
    container.appendChild(chip);
  });
}

/**
 * 功能：处理 `airportForSlot` 对应的业务逻辑。
 * 输入：slot。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airportForSlot(slot) {
  return state[`${slot}Airport`];
}

/**
 * 功能：处理 `airportEmptyText` 对应的业务逻辑。
 * 输入：slot。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function airportEmptyText(slot) {
  if (slot === "manual") {
    return t("airport.empty.manual");
  }
  return t("airport.empty.slot", { slot: t(AIRPORT_SLOT_LABELS[slot]) });
}

/**
 * 功能：更新 `updateAirportTabs` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function updateAirportTabs() {
  AIRPORT_SLOTS.forEach((slot) => {
    const button = elements[`${slot}AirportTab`];
    if (!button) {
      return;
    }
    const airport = airportForSlot(slot);
    button.classList.toggle("active", state.activeAirportSlot === slot);
    button.setAttribute("aria-selected", String(state.activeAirportSlot === slot));
    button.innerHTML = `
      <span>${escapeHtml(t(AIRPORT_SLOT_LABELS[slot]))}</span>
      <strong>${escapeHtml(airport?.airport_identifier || "----")}</strong>
    `;
  });
}

/**
 * 功能：更新 `updateAirportPanelVisibility` 对应的业务逻辑。
 * 输入：无。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function updateAirportPanelVisibility() {
  const activeSlot = AIRPORT_SLOTS.includes(state.activeAirportSlot) ? state.activeAirportSlot : "departure";
  state.activeAirportSlot = activeSlot;
  const activeAirport = airportForSlot(activeSlot);
  updateAirportTabs();
  AIRPORT_SLOTS.forEach((slot) => {
    const panel = document.querySelector(`#${slot}AirportDetails`);
    panel?.classList.toggle("hidden", slot !== activeSlot || !activeAirport);
  });
  elements.airportEmpty.textContent = airportEmptyText(activeSlot);
  elements.airportEmpty.classList.toggle("hidden", Boolean(activeAirport));
  elements.airportPanels.classList.toggle("hidden", !activeAirport);
}

/**
 * 功能：设置 `setActiveAirportSlot` 对应的业务逻辑。
 * 输入：slot。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function setActiveAirportSlot(slot) {
  if (!AIRPORT_SLOTS.includes(slot)) {
    return;
  }
  state.activeAirportSlot = slot;
  updateAirportPanelVisibility();
}

/**
 * 功能：加载 `loadAirport` 对应的业务逻辑。
 * 输入：ident。
 * 输出：Promise，解析为函数处理结果。
 */
async function loadAirport(ident) {
  return loadAirportIntoPanel(ident, "departure");
}

function renderAirportPayload(prefix, payload) {
  if (!payload?.airport) {
    return;
  }
  const airport = payload.airport;
  elements[`${prefix}AirportIdent`].textContent = airport.airport_identifier;
  elements[`${prefix}AirportName`].textContent = airport.airport_name || t("airport.unnamed");
  elements[`${prefix}AirportMeta`].textContent = [
    `${formatCoord(airport.airport_ref_latitude, ["N", "S"])}`,
    `${formatCoord(airport.airport_ref_longitude, ["E", "W"])}`,
    `${t("airport.elevation")} ${airport.elevation ?? "--"} ft`,
    `TA ${airport.transition_altitude ?? "--"}`,
  ].join("  •  ");

  renderList(elements[`${prefix}RunwayList`], payload.runways || [], (item) =>
    rowTemplate(
      item.runway_identifier,
      `${item.runway_length ?? "--"} x ${item.runway_width ?? "--"} ft  •  ${t("airport.magneticBearing")} ${item.runway_magnetic_bearing ?? "--"}°  •  ${t("airport.surface")} ${item.surface_code ?? "--"}`,
    ),
    { className: "runway-list-table" },
  );
  renderCompactCommunications(elements[`${prefix}CommList`], payload.communications || []);

  populateRunwayFilter(prefix, payload.runways || []);
  rerenderProcedureLists(prefix, airport.airport_identifier);
}

/**
 * 功能：加载 `loadAirportIntoPanel` 对应的业务逻辑。
 * 输入：ident、slot、options。
 * 输出：Promise，解析为函数处理结果。
 */
async function loadAirportIntoPanel(ident, slot, options = {}) {
  const payload = await fetchJson(`/api/airport/${encodeURIComponent(ident)}`, {
    signal: options.signal,
  });
  throwIfAborted(options.signal);

  const prefix = AIRPORT_SLOTS.includes(slot) ? slot : "departure";
  state.selectedAirport = payload.airport;
  state[`${prefix}Airport`] = payload.airport;
  state.airportProcedureData[prefix] = payload.procedures;
  state.airportPayloads[prefix] = payload;
  renderAirportPayload(prefix, payload);
  setActiveAirportSlot(prefix);

  const airportPoint = {
    ident: payload.airport.airport_identifier,
    kind: "airport",
    lat: payload.airport.airport_ref_latitude,
    lon: payload.airport.airport_ref_longitude,
    label: payload.airport.airport_name,
  };
  drawAirportSlotMarker(prefix, airportPoint);
  if (options.focusMap) {
    map.flyTo([airportPoint.lat, airportPoint.lon], 8, { duration: 0.75 });
  }
}

/**
 * 功能：执行 `populateRunwayFilter` 对应的业务逻辑。
 * 输入：prefix、runways。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function populateRunwayFilter(prefix, runways) {
  const options = ["ALL", ...new Set(runways.map((item) => item.runway_identifier).filter(Boolean))];
  state.runwayButtonOptions[prefix] = options;
  state.selectedRunways[prefix] = normalizeRunwayChoice(prefix, state.selectedRunways[prefix]);
  renderRunwayButtons(prefix);
}

/**
 * 功能：执行 `rerenderProcedureLists` 对应的业务逻辑。
 * 输入：prefix、ident。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function rerenderProcedureLists(prefix, ident) {
  const procedures = state.airportProcedureData[prefix];
  if (!procedures) {
    return;
  }
  renderProcedureList(elements[`${prefix}SidList`], procedures.sid, "sid", ident, prefix);
  renderProcedureList(elements[`${prefix}StarList`], procedures.star, "star", ident, prefix);
  renderProcedureList(elements[`${prefix}ApproachList`], procedures.approach, "approach", ident, prefix);
}

/**
 * 功能：处理 `procedureCacheKey` 对应的业务逻辑。
 * 输入：type、airport、procedure、transition。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function procedureCacheKey(type, airport, procedure, transition) {
  return [type, airport, procedure, transition].map((item) => String(item || "").toUpperCase()).join("|");
}

/**
 * 功能：执行 `rememberProcedurePayload` 对应的业务逻辑。
 * 输入：key、payload。
 * 输出：函数处理结果，或对应的界面/地图副作用。
 */
function rememberProcedurePayload(key, payload) {
  if (state.procedureCache.has(key)) {
    state.procedureCache.delete(key);
  }
  state.procedureCache.set(key, payload);
  while (state.procedureCache.size > PROCEDURE_CACHE_LIMIT) {
    state.procedureCache.delete(state.procedureCache.keys().next().value);
  }
}

/**
 * 功能：加载 `loadProcedurePayload` 对应的业务逻辑。
 * 输入：type、airport、procedure、transition、options。
 * 输出：Promise，解析为函数处理结果。
 */
async function loadProcedurePayload(type, airport, procedure, transition, options = {}) {
  const key = procedureCacheKey(type, airport, procedure, transition);
  const cached = state.procedureCache.get(key);
  if (cached) {
    return cached;
  }
  const payload = await fetchJson(
    `/api/procedure/${type}/${encodeURIComponent(airport)}/${encodeURIComponent(procedure)}/${encodeURIComponent(transition)}`,
    { signal: options.signal },
  );
  rememberProcedurePayload(key, payload);
  return payload;
}

/**
 * 功能：执行 `previewProcedure` 对应的业务逻辑。
 * 输入：type、airport、procedure、transition、options。
 * 输出：Promise，解析为函数处理结果。
 */
async function previewProcedure(type, airport, procedure, transition, options = {}) {
  const source = options.source || "manual";
  const requestVersion = (state.procedureRequestVersion[type] += 1);
  try {
    const payload = await loadProcedurePayload(type, airport, procedure, transition, { signal: options.signal });
    throwIfAborted(options.signal);
    if (state.procedureRequestVersion[type] !== requestVersion) {
      return;
    }
    const points = payload.items.filter((item) => item.waypoint_latitude !== null && item.waypoint_longitude !== null);
    if (!points.length) {
      renderSelectionMessage(t("procedure.noDrawable", { procedure, transition }));
      return;
    }

    if (options.recordHistory !== false && source !== "auto") {
      pushDrawingUndoState();
    }
    if (source !== "auto") {
      clearAutoSelectedProcedures(type, { recordHistory: false });
    }
    procedureLayerGroups[type].clearLayers();
    state.procedureVisualLayers[type] = null;
    state.selectedProcedures[type] = null;
    if (type === "approach") {
      drawApproach(payload.primary_path, payload.missed_path, points, {
        skipFitBounds: options.skipFitBounds,
      });
    } else {
      drawProcedure(type, payload.path, points, type === "sid" ? MAP_COLORS.sid : MAP_COLORS.star, {
        skipFitBounds: options.skipFitBounds,
      });
    }
    state.selectedProcedures[type] = {
      airport,
      procedure,
      transition,
      source,
    };
    renderSelectedProcedures();
    updateTrackHistoryControlState();
    if (state.departureAirport?.airport_identifier === airport) {
      rerenderProcedureLists("departure", airport);
    }
    if (state.arrivalAirport?.airport_identifier === airport) {
      rerenderProcedureLists("arrival", airport);
    }
    if (state.manualAirport?.airport_identifier === airport) {
      rerenderProcedureLists("manual", airport);
    }

    if (!options.silent) {
      renderProcedureSelectionTable(type, airport, procedure, transition, payload);
    }
    scheduleCalculateRender();
  } catch (error) {
    if (state.procedureRequestVersion[type] !== requestVersion) {
      return;
    }
    renderSelectionMessage(t("procedure.loadFailed", { type: procedureTypeLabel(type), procedure, transition }));
    throw error;
  }
}

/**
 * 功能：应用 `applyAutoSelectedProcedures` 对应的业务逻辑。
 * 输入：selectedProcedures、options。
 * 输出：Promise，解析为函数处理结果。
 */
async function applyAutoSelectedProcedures(selectedProcedures = {}, options = {}) {
  clearAllProcedures({ recordHistory: false });
  const order = ["sid", "star", "approach"];
  for (const type of order) {
    throwIfAborted(options.signal);
    const item = selectedProcedures[type];
    if (!item) {
      continue;
    }
    try {
      await previewProcedure(type, item.airport, item.procedure, item.transition, {
        source: "auto",
        silent: true,
        skipFitBounds: true,
        signal: options.signal,
      });
    } catch {
      continue;
    }
  }
  if (Object.keys(selectedProcedures).length) {
    const selectedType = ["approach", "star", "sid"].find((type) => state.selectedProcedures[type]);
    if (selectedType) {
      await showSelectedProcedureDetails(selectedType);
    } else {
      renderSelectionMessage(t("procedure.autoLoaded"));
    }
  } else {
    renderSelectionMessage(t("selection.chooseProcedure"));
  }
}

/**
 * 功能：应用 `applyRoutePayload` 对应的业务逻辑。
 * 输入：payload、departure、arrival、options。
 * 输出：Promise，解析为函数处理结果。
 */
async function applyRoutePayload(payload, departure, arrival, options = {}) {
  throwIfAborted(options.signal);
  state.selectedRunways.departure = payload.selected_runways?.departure || state.selectedRunways.departure || "ALL";
  state.selectedRunways.arrival = payload.selected_runways?.arrival || state.selectedRunways.arrival || "ALL";
  await Promise.all([
    loadAirportIntoPanel(departure, "departure", { signal: options.signal }),
    loadAirportIntoPanel(arrival, "arrival", { signal: options.signal }),
  ]);
  throwIfAborted(options.signal);
  setActiveAirportSlot("departure");
  renderRunwayButtons("departure");
  renderRunwayButtons("arrival");
  if (state.departureAirport) {
    rerenderProcedureLists("departure", state.departureAirport.airport_identifier);
  }
  if (state.arrivalAirport) {
    rerenderProcedureLists("arrival", state.arrivalAirport.airport_identifier);
  }
  const routeLayerKind = normalizeRouteLayerKind(options.routeLayerKind || inferRouteLayerKind(payload));
  if (options.recordHistory !== false) {
    pushDrawingUndoState();
  }
  drawRoute(payload, { routeLayerKind });
  renderLegs(payload.legs || []);
  elements.routeInput.value = routeStringFromPayload(payload);
  state.lastRouteWasGenerated = Boolean(payload.generated);
  state.lastGeneratedRouteDisplay = payload.generated ? routeStringFromPayload(payload).toUpperCase() : "";
  state.currentRoutePayload = cloneJSON(payload);
  state.currentRouteAirports = { departure, arrival };
  state.currentRouteLayerKind = routeLayerKind;
  await applyAutoSelectedProcedures(payload.selected_procedures || {}, { signal: options.signal });
  updateTrackHistoryControlState();
  scheduleCalculateRender();
}

/**
 * 功能：构建 `buildRoute` 对应的业务逻辑。
 * 输入：options。
 * 输出：Promise，解析为函数处理结果。
 */
async function buildRoute(options = {}) {
  hideSearchResults();
  const departure = elements.departureInput.value.trim().toUpperCase();
  const arrival = elements.arrivalInput.value.trim().toUpperCase();
  const inputRoute = elements.routeInput.value.trim().toUpperCase();
  const shouldForceAuto =
    options.forceAuto ||
    (state.lastGeneratedRouteDisplay && inputRoute === state.lastGeneratedRouteDisplay);
  const route = shouldForceAuto ? "" : inputRoute;
  const departureRunway = state.selectedRunways.departure || "ALL";
  const arrivalRunway = state.selectedRunways.arrival || "ALL";

  if (!departure || !arrival) {
    setStatus(t("route.needAirports"), true);
    return;
  }

  const controller = beginRouteOperation(t("route.operation.resolve"));
  setStatus(t("route.parsing"));
  try {
    const payload = await fetchJson(
      `/api/route/resolve?departure=${encodeURIComponent(departure)}&arrival=${encodeURIComponent(arrival)}&route=${encodeURIComponent(route)}&departure_runway=${encodeURIComponent(departureRunway)}&arrival_runway=${encodeURIComponent(arrivalRunway)}`,
      { signal: controller.signal },
    );
    throwIfAborted(controller.signal);
    payload.selected_runways = payload.selected_runways || { departure: departureRunway, arrival: arrivalRunway };
    await applyRoutePayload(payload, departure, arrival, {
      signal: controller.signal,
      routeLayerKind: route ? "manualRoute" : "route",
    });
    setStatus(
      payload.generated
        ? t("route.generatedStatus", {
            message: currentLanguage() === "zh-Hans" && payload.message ? payload.message : t("route.generatedFallback"),
            distance: Math.round(payload.distance_nm || 0),
          })
        : t("route.resolvedStatus", { count: payload.points.length }),
    );
  } catch (error) {
    if (isAbortError(error)) {
      setStatus(t("route.resolveStopped"));
    } else {
      setErrorStatus(error);
    }
  } finally {
    endRouteOperation(controller);
  }
}

function cloneJSON(value) {
  return value === null || value === undefined ? value : JSON.parse(JSON.stringify(value));
}

function setFR24QueryStatus(message, isError = false) {
  if (!elements.fr24QueryStatus) {
    return;
  }
  elements.fr24QueryStatus.textContent = message;
  elements.fr24QueryStatus.classList.toggle("settings-status-error", Boolean(isError));
}

function setFR24QueryBusy(isBusy) {
  state.fr24QueryBusy = Boolean(isBusy);
  [
    elements.fr24SearchButton,
    elements.fr24ImportGPXButton,
    elements.fr24ManualHistoryButton,
    elements.fr24CacheSearchButton,
    elements.fr24OpenCacheDirectoryButton,
    ...Array.from(elements.fr24FlightList?.querySelectorAll("[data-fr24-action]") || []),
    ...Array.from(elements.fr24CacheList?.querySelectorAll("[data-fr24-action]") || []),
  ].forEach((button) => {
    button.disabled = Boolean(isBusy);
  });
  if (elements.fr24ManualHistoryInput) {
    elements.fr24ManualHistoryInput.disabled = Boolean(isBusy);
  }
  if (elements.fr24CacheSearchInput) {
    elements.fr24CacheSearchInput.disabled = Boolean(isBusy);
  }
}

function currentQueryRouteInputs() {
  const departure = elements.departureInput.value.trim().toUpperCase();
  const arrival = elements.arrivalInput.value.trim().toUpperCase();
  if (!departure || !arrival) {
    setStatus(t("route.needAirports"), true);
    setFR24QueryStatus(t("route.needAirports"), true);
    return null;
  }
  return { departure, arrival };
}

function optionalQueryRouteInputs() {
  const departure = elements.departureInput.value.trim().toUpperCase();
  const arrival = elements.arrivalInput.value.trim().toUpperCase();
  return departure && arrival ? { departure, arrival } : null;
}

function fr24FlightKey(flight, index = 0, prefix = "flight") {
  return [
    prefix,
    flight.fr24_id || flight.flight || flight.callsign || "unknown",
    flight.timestamp || flight.scheduled_departure || flight.actual_departure || index,
  ].map((part) => String(part).replace(/[^a-z0-9_-]+/gi, "-")).join("-");
}

function flightPrimaryLabel(flight) {
  return flight.flight || flight.callsign || flight.fr24_id || t("query.flightUnknown");
}

function flightAirportCode(flight, side) {
  const actualCode = flight[`${side}_actual_code`];
  const icao = flight[`${side}_icao`];
  const iata = flight[`${side}_iata`];
  return actualCode || icao || iata || "----";
}

function normalizeFlightTimestamp(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return null;
  }
  return numeric > 1_000_000_000_000 ? Math.floor(numeric / 1000) : Math.floor(numeric);
}

function formatFlightTime(value) {
  const timestamp = normalizeFlightTimestamp(value);
  if (!timestamp) {
    return "--";
  }
  try {
    return new Intl.DateTimeFormat(currentLanguage() === "zh-Hans" ? "zh-CN" : "en-US", {
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(new Date(timestamp * 1000));
  } catch (_error) {
    return new Date(timestamp * 1000).toISOString().slice(5, 16).replace("T", " ");
  }
}

function formatFlightDuration(seconds) {
  const value = Number(seconds);
  if (!Number.isFinite(value) || value <= 0) {
    return "--";
  }
  const minutes = Math.round(value / 60);
  const hours = Math.floor(minutes / 60);
  const remain = minutes % 60;
  return hours > 0 ? `${hours}h ${remain}m` : `${remain}m`;
}

function formatFlightTimes(flight) {
  const scheduled = [
    formatFlightTime(flight.scheduled_departure),
    formatFlightTime(flight.scheduled_arrival),
  ].join(" → ");
  const actual = [
    formatFlightTime(flight.actual_departure || flight.estimated_departure),
    formatFlightTime(flight.actual_arrival || flight.estimated_arrival),
  ].join(" → ");
  return t("query.scheduleActual", { scheduled, actual });
}

function formatFlightActualRoute(flight) {
  if (flight.actual_route_mismatch !== true) {
    return "";
  }
  const route = `${flightAirportCode(flight, "origin")} → ${flightAirportCode(flight, "dest")}`;
  return t("query.actualRoute", { route });
}

function getFR24FlightByKey(key) {
  return state.fr24Flights.get(key) || state.fr24CacheFlights.get(key) || null;
}

function renderFR24FlightActions(key) {
  return `
    <div class="query-flight-actions">
      <button class="ghost-button compact-button" type="button" data-fr24-action="draw" data-fr24-key="${escapeHtml(key)}">${escapeHtml(t("query.downloadDraw"))}</button>
      <button class="ghost-button compact-button" type="button" data-fr24-action="match" data-fr24-key="${escapeHtml(key)}">${escapeHtml(t("query.matchTrack"))}</button>
    </div>
  `;
}

function renderFR24CacheActions(flight, key) {
  const isFavorite = flight.favorite === true;
  const favoriteLabel = isFavorite ? t("query.cacheUnfavorite") : t("query.cacheFavorite");
  return `
    <div class="query-flight-actions query-cache-actions">
      <button class="ghost-button compact-button" type="button" data-fr24-action="draw" data-fr24-key="${escapeHtml(key)}">${escapeHtml(t("query.cacheDraw"))}</button>
      <button class="ghost-button compact-button" type="button" data-fr24-action="share-cache" data-fr24-key="${escapeHtml(key)}">${escapeHtml(t("query.cacheShare"))}</button>
      <button class="ghost-button compact-button" type="button" data-fr24-action="favorite-cache" data-fr24-key="${escapeHtml(key)}" data-fr24-favorite="${isFavorite ? "false" : "true"}">${escapeHtml(favoriteLabel)}</button>
      <button class="ghost-button compact-button danger-button" type="button" data-fr24-action="delete-cache" data-fr24-key="${escapeHtml(key)}">${escapeHtml(t("query.cacheDelete"))}</button>
    </div>
  `;
}

function renderFR24FlightCard(flight, key, { history = false, cacheItem = false } = {}) {
  const route = `${flightAirportCode(flight, "origin")} → ${flightAirportCode(flight, "dest")}`;
  const airline = flight.airline || t("query.airlineUnknown");
  const aircraft = [flight.aircraft, flight.aircraft_registration].filter(Boolean).join(" / ") || t("query.aircraftUnknown");
  const status = flight.status ? `<span>${escapeHtml(flight.status)}</span>` : "";
  const actualRoute = formatFlightActualRoute(flight);
  const actualRouteLine = actualRoute ? `<span class="query-flight-actual-route">${escapeHtml(actualRoute)}</span>` : "";
  const downloadedLine = cacheItem
    ? `<span>${escapeHtml(t("query.cacheDownloaded", {
      time: formatFlightTime(flight.downloaded_at),
      count: formatCount(flight.track_point_count || 0),
    }))}</span>`
    : "";
  const cacheBadge = flight.cache_hit === true
    ? `<span class="query-flight-badge">${escapeHtml(t("query.cacheHit"))}</span>`
    : "";
  const favoriteBadge = flight.favorite === true
    ? `<span class="query-flight-badge query-flight-badge-favorite">${escapeHtml(t("query.cacheFavoriteBadge"))}</span>`
    : "";
  return `
    <article class="query-flight-card ${history ? "is-history" : ""} ${cacheItem ? "is-cache" : ""}">
      <div class="query-flight-head">
        <div>
          <div class="query-flight-number">${escapeHtml(flightPrimaryLabel(flight))}</div>
          <div class="query-flight-route">${escapeHtml(route)}</div>
        </div>
        <div class="query-flight-badges">${cacheBadge}${favoriteBadge}</div>
      </div>
      <div class="query-flight-meta">
        <span>${escapeHtml(airline)}</span>
        <span>${escapeHtml(aircraft)}</span>
        ${status}
        ${actualRouteLine}
        <span>${escapeHtml(formatFlightTimes(flight))}</span>
        <span>${escapeHtml(t("query.duration", { duration: formatFlightDuration(flight.duration_seconds) }))}</span>
        ${downloadedLine}
      </div>
      ${cacheItem ? renderFR24CacheActions(flight, key) : renderFR24FlightActions(key)}
      ${history || cacheItem ? "" : `
        <details class="query-history">
          <summary>${escapeHtml(t("query.history"))}</summary>
          <button class="ghost-button compact-button query-history-load" type="button" data-fr24-action="history" data-fr24-key="${escapeHtml(key)}">${escapeHtml(t("query.loadHistory"))}</button>
          <div class="query-history-list" data-fr24-history-for="${escapeHtml(key)}">
            ${renderFR24HistoryList(key)}
          </div>
        </details>
      `}
    </article>
  `;
}

function renderFR24HistoryList(key) {
  const histories = state.fr24HistoryByKey.get(key);
  if (!histories) {
    return "";
  }
  if (!histories.length) {
    return `<div class="query-empty query-empty-inline">${escapeHtml(t("query.noHistory"))}</div>`;
  }
  return histories.map((flight, index) => {
    const historyKey = fr24FlightKey(flight, index, `history-${key}`);
    state.fr24Flights.set(historyKey, flight);
    return renderFR24FlightCard(flight, historyKey, { history: true });
  }).join("");
}

function renderFR24Flights(flights = [], options = {}) {
  if (!elements.fr24FlightList) {
    return;
  }
  state.fr24SearchRenderOptions = options;
  state.fr24SearchFlights = flights;
  state.fr24Flights.clear();
  if (!flights.length) {
    elements.fr24FlightList.innerHTML = `<div class="query-empty">${escapeHtml(t("query.empty"))}</div>`;
    return;
  }
  elements.fr24FlightList.innerHTML = flights.map((flight, index) => {
    const key = fr24FlightKey(flight, index, options.prefix || "flight");
    state.fr24Flights.set(key, flight);
    return renderFR24FlightCard(flight, key, { history: Boolean(options.history) });
  }).join("");
}

function renderFR24CacheFlights(items = []) {
  if (!elements.fr24CacheList) {
    return;
  }
  state.fr24CacheItems = items;
  state.fr24CacheFlights.clear();
  if (!items.length) {
    elements.fr24CacheList.innerHTML = `<div class="query-empty">${escapeHtml(t("query.cacheEmpty"))}</div>`;
    return;
  }
  elements.fr24CacheList.innerHTML = items.map((flight, index) => {
    const key = fr24FlightKey(flight, index, "cache");
    state.fr24CacheFlights.set(key, flight);
    return renderFR24FlightCard(flight, key, { history: true, cacheItem: true });
  }).join("");
}

function updateFR24CacheSummary(payload) {
  state.fr24CacheStatus = payload || null;
  if (!elements.fr24CacheTitle || !elements.fr24CacheSummary) {
    return;
  }
  const size = formatBytes(payload?.size_bytes || 0);
  const count = formatCount(payload?.file_count || 0);
  elements.fr24CacheTitle.textContent = t("query.cacheSummary", { size, count });
  elements.fr24CacheSummary.textContent = payload?.root || t("query.cacheInitial");
}

function formatFR24AccessFlag(value) {
  return value ? t("query.accessConfigured") : t("query.accessMissing");
}

function updateFR24AccessSummary(payload) {
  state.fr24AccessStatus = payload || null;
  if (!elements.fr24AccessSummary) {
    return;
  }
  const synced = Boolean(payload?.cookie_configured || payload?.frpl_configured);
  elements.fr24AccessSummary.textContent = t("query.accessSummary", {
    state: synced ? t("query.accessSyncedState") : t("query.accessUnsyncedState"),
  });
}

function fr24NativeSessionMessage(payload = {}) {
  const rawMessage = cleanErrorMessage(payload.message || "");
  if (payload.error) {
    if (/没有可同步|no fr24 session/i.test(rawMessage)) {
      return t("query.accessSyncMissing");
    }
    return currentLanguage() === "zh-Hans" && rawMessage ? rawMessage : t("error.fr24Session");
  }
  if (/同步|synced/i.test(rawMessage)) {
    return t("query.accessSynced");
  }
  return currentLanguage() === "zh-Hans" && rawMessage ? rawMessage : t("query.accessSaved");
}

function openFR24VerificationBrowser() {
  if (!window.webkit?.messageHandlers?.navplanner) {
    setFR24QueryStatus(t("database.iosOnly"), true);
    setStatus(t("database.iosOnly"), true);
    return;
  }
  postNativeEvent("openFR24Verification");
  setFR24QueryStatus(t("query.accessOpening"));
  setStatus(t("query.accessOpening"));
}

function syncFR24BrowserSession() {
  if (!window.webkit?.messageHandlers?.navplanner) {
    setFR24QueryStatus(t("database.iosOnly"), true);
    setStatus(t("database.iosOnly"), true);
    return;
  }
  postNativeEvent("syncFR24Session");
  setFR24QueryStatus(t("query.accessSyncing"));
  setStatus(t("query.accessSyncing"));
}

function openFR24CacheDirectory() {
  if (!window.webkit?.messageHandlers?.navplanner) {
    setFR24QueryStatus(t("database.iosOnly"), true);
    setStatus(t("database.iosOnly"), true);
    return;
  }
  postNativeEvent("openFR24CacheDirectory");
  setFR24QueryStatus(t("query.cacheDirectoryOpening"));
  setStatus(t("query.cacheDirectoryOpening"));
}

function importFR24GPX() {
  if (!window.webkit?.messageHandlers?.navplanner) {
    setFR24QueryStatus(t("database.iosOnly"), true);
    setStatus(t("database.iosOnly"), true);
    return;
  }
  postNativeEvent("importFR24GPX");
  setFR24QueryStatus(t("query.importGPXOpening"));
  setStatus(t("query.importGPXOpening"));
}

function handleNativeFR24SessionUpdated(payload = {}) {
  updateFR24AccessSummary(payload);
  const message = fr24NativeSessionMessage(payload);
  setFR24QueryStatus(message, Boolean(payload.error));
  setStatus(message, Boolean(payload.error));
}

function handleNativeFR24CacheDirectoryOpened(payload = {}) {
  const rawMessage = cleanErrorMessage(payload.message || "");
  const message = payload.error
    ? (currentLanguage() === "zh-Hans" && rawMessage ? rawMessage : t("query.cacheDirectoryFailed"))
    : (currentLanguage() === "zh-Hans" && rawMessage ? rawMessage : t("query.cacheDirectoryOpened"));
  setFR24QueryStatus(message, Boolean(payload.error));
  setStatus(message, Boolean(payload.error));
}

function handleNativeFR24GPXImported(payload = {}) {
  if (payload.error) {
    const rawMessage = cleanErrorMessage(payload.message || "");
    const message = currentLanguage() === "zh-Hans" && rawMessage ? rawMessage : localizedErrorMessage(rawMessage);
    setFR24QueryStatus(message, true);
    setStatus(message, true);
    return;
  }
  const count = drawFR24TrackPoints(payload.track_points || [], { fitBounds: true });
  const message = t("query.importGPXDrawn", {
    filename: payload.filename || "GPX",
    count: formatCount(count),
  });
  setFR24QueryStatus(message);
  setStatus(message);
}

async function refreshFR24CacheStatus() {
  const payload = await fetchJson("/api/fr24/cache/status");
  updateFR24CacheSummary(payload);
  return payload;
}

async function searchFR24Cache() {
  hideSearchResults();
  const query = elements.fr24CacheSearchInput?.value.trim() || "";
  setFR24QueryBusy(true);
  setFR24QueryStatus(t("query.cacheLoading"));
  try {
    const params = new URLSearchParams({ query, limit: "120" });
    const payload = await fetchJson(`/api/fr24/cache/list?${params.toString()}`);
    const items = payload.items || [];
    renderFR24CacheFlights(items);
    updateFR24CacheSummary(payload.cache || state.fr24CacheStatus || {});
    setFR24QueryStatus(items.length ? t("query.cacheLoaded", { count: items.length }) : t("query.cacheEmpty"), !items.length);
  } catch (error) {
    renderFR24CacheFlights([]);
    const message = localizedErrorMessage(error.message);
    setFR24QueryStatus(message, true);
    setStatus(message, true);
  } finally {
    setFR24QueryBusy(false);
  }
}

async function refreshFR24AccessStatus() {
  const payload = await fetchJson("/api/fr24/access/status");
  updateFR24AccessSummary(payload);
  return payload;
}

function clearFR24AccessInputs() {
  if (elements.fr24CookieInput) {
    elements.fr24CookieInput.value = "";
  }
  if (elements.fr24FrPlInput) {
    elements.fr24FrPlInput.value = "";
  }
}

async function saveFR24Access() {
  const payload = await fetchJson("/api/fr24/access/update", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      web_cookie: elements.fr24CookieInput?.value || "",
      frpl: elements.fr24FrPlInput?.value || "",
    }),
  });
  clearFR24AccessInputs();
  updateFR24AccessSummary(payload);
  setFR24QueryStatus(t("query.accessSaved"));
  setStatus(t("query.accessSaved"));
}

async function clearFR24Access() {
  const payload = await fetchJson("/api/fr24/access/clear", { method: "POST" });
  clearFR24AccessInputs();
  updateFR24AccessSummary(payload);
  setFR24QueryStatus(t("query.accessCleared"));
  setStatus(t("query.accessCleared"));
}

async function searchFR24Flights() {
  hideSearchResults();
  const route = currentQueryRouteInputs();
  if (!route) {
    renderFR24Flights([]);
    return;
  }
  setFR24QueryBusy(true);
  setFR24QueryStatus(t("query.loading"));
  try {
    const payload = await fetchJson(
      `/api/fr24/search?departure=${encodeURIComponent(route.departure)}&arrival=${encodeURIComponent(route.arrival)}&limit=10`,
    );
    const flights = payload.flights || [];
    state.fr24HistoryByKey.clear();
    renderFR24Flights(flights);
    updateFR24CacheSummary(payload.cache || state.fr24CacheStatus || {});
    updateFR24AccessSummary(payload.access || state.fr24AccessStatus || {});
    setFR24QueryStatus(flights.length ? t("query.loaded", { count: flights.length }) : t("query.noFlights"), !flights.length);
  } catch (error) {
    renderFR24Flights([]);
    const message = localizedErrorMessage(error.message);
    setFR24QueryStatus(message, true);
    setStatus(message, true);
  } finally {
    setFR24QueryBusy(false);
  }
}

async function searchFR24ManualHistory() {
  hideSearchResults();
  const query = elements.fr24ManualHistoryInput?.value.trim() || "";
  if (!query) {
    setFR24QueryStatus(t("query.manualHistoryMissing"), true);
    setStatus(t("query.manualHistoryMissing"), true);
    return;
  }
  const route = optionalQueryRouteInputs();
  const params = new URLSearchParams({ query, limit: "0" });
  if (route) {
    params.set("departure", route.departure);
    params.set("arrival", route.arrival);
  }
  setFR24QueryBusy(true);
  setFR24QueryStatus(t("query.manualHistoryLoading"));
  try {
    const payload = await fetchJson(`/api/fr24/manual-history?${params.toString()}`);
    const flights = payload.flights || [];
    state.fr24HistoryByKey.clear();
    renderFR24Flights(flights, { history: true, prefix: "manual" });
    updateFR24CacheSummary(payload.cache || state.fr24CacheStatus || {});
    updateFR24AccessSummary(payload.access || state.fr24AccessStatus || {});
    setFR24QueryStatus(flights.length ? t("query.manualHistoryLoaded", { count: flights.length }) : t("query.noHistory"), !flights.length);
  } catch (error) {
    renderFR24Flights([], { history: true, prefix: "manual" });
    const message = localizedErrorMessage(error.message);
    setFR24QueryStatus(message, true);
    setStatus(message, true);
  } finally {
    setFR24QueryBusy(false);
  }
}

async function loadFR24History(key) {
  const flight = getFR24FlightByKey(key);
  const route = currentQueryRouteInputs();
  if (!flight || !route) {
    return;
  }
  setFR24QueryBusy(true);
  setFR24QueryStatus(t("query.historyLoading"));
  try {
    const payload = await fetchJson(
      `/api/fr24/history?departure=${encodeURIComponent(route.departure)}&arrival=${encodeURIComponent(route.arrival)}&flight=${encodeURIComponent(flight.flight || "")}&callsign=${encodeURIComponent(flight.callsign || "")}`,
    );
    const histories = payload.flights || [];
    state.fr24HistoryByKey.set(key, histories);
    renderFR24Flights(state.fr24SearchFlights, state.fr24SearchRenderOptions);
    updateFR24AccessSummary(payload.access || state.fr24AccessStatus || {});
    setFR24QueryStatus(histories.length ? t("query.historyLoaded", { count: histories.length }) : t("query.noHistory"), !histories.length);
  } catch (error) {
    const message = localizedErrorMessage(error.message);
    setFR24QueryStatus(message, true);
    setStatus(message, true);
  } finally {
    setFR24QueryBusy(false);
  }
}

async function fetchFR24TrackPayload(flight, options = {}) {
  const flightID = flight.fr24_id;
  if (!flightID) {
    throw new Error(t("error.fr24MissingId"));
  }
  return fetchJson("/api/fr24/download", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ flight_id: flightID, flight }),
    signal: options.signal,
  });
}

function finiteFR24Number(...values) {
  for (const value of values) {
    const number = Number(value);
    if (Number.isFinite(number)) {
      return number;
    }
  }
  return null;
}

function normalizedFR24TrackPoints(trackPoints) {
  return withDisplayLongitudes((trackPoints || []).map((point) => {
    const source = point || {};
    const lat = finiteFR24Number(source.lat, source.latitude, source.position?.lat);
    const lon = finiteFR24Number(source.lon, source.lng, source.longitude, source.position?.lng, source.position?.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      return null;
    }
    const output = { lat, lon };
    const timestamp = finiteFR24Number(source.timestamp, source.ts, source.time);
    if (Number.isFinite(timestamp)) {
      output.timestamp = timestamp > 1_000_000_000_000 ? Math.floor(timestamp / 1000) : Math.floor(timestamp);
    }
    const altitude = finiteFR24Number(
      source.altitude_ft,
      source.altitude,
      source.alt,
      source.alt_ft,
      source.altitudeFt,
      source.altitude_feet,
      source.altitude?.feet,
      source.altitude?.ft,
    );
    const altitudeMeters = finiteFR24Number(
      source.altitude_m,
      source.alt_m,
      source.altitudeMeters,
      source.altitude_meter,
      source.altitude?.meters,
      source.altitude?.m,
    );
    if (Number.isFinite(altitude)) {
      output.altitude = altitude;
      output.altitude_ft = altitude;
    } else if (Number.isFinite(altitudeMeters)) {
      output.altitude_m = altitudeMeters;
      output.altitude_ft = altitudeMeters * 3.280839895;
      output.altitude = output.altitude_ft;
    }
    const speed = finiteFR24Number(
      source.speed_kt,
      source.speed_kts,
      source.speed,
      source.spd,
      source.speedKt,
      source.speedKts,
      source.ground_speed,
      source.groundspeed,
      source.groundSpeed,
      source.ground_speed_kt,
      source.gs,
      source.speed?.kts,
      source.speed?.knots,
      source.groundSpeed?.knots,
    );
    if (Number.isFinite(speed)) {
      output.speed = speed;
      output.speed_kt = speed;
    }
    return output;
  }).filter(Boolean));
}

function cloneFR24TrackPayload(payload = state.fr24TrackPayload) {
  if (!payload || !Array.isArray(payload.track_points) || payload.track_points.length < 2) {
    return null;
  }
  return {
    track_points: payload.track_points.map((point) => ({
      lat: Number(point.lat),
      lon: Number(point.lon),
      timestamp: finiteFR24Number(point.timestamp),
      altitude: finiteFR24Number(point.altitude, point.altitude_ft),
      altitude_ft: finiteFR24Number(point.altitude_ft, point.altitude),
      altitude_m: finiteFR24Number(point.altitude_m),
      speed: finiteFR24Number(point.speed, point.speed_kt),
      speed_kt: finiteFR24Number(point.speed_kt, point.speed),
    })).filter((point) => Number.isFinite(point.lat) && Number.isFinite(point.lon)).map((point) => {
      Object.keys(point).forEach((key) => {
        if (point[key] === null || point[key] === undefined || !Number.isFinite(point[key])) {
          delete point[key];
        }
      });
      return point;
    }),
  };
}

function formatFR24Altitude(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return "--";
  }
  return `${Math.round(number).toLocaleString(currentLanguage() === "zh-Hans" ? "zh-CN" : "en-US")} ft`;
}

function formatFR24Speed(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return "--";
  }
  return `${Math.round(number)} kt`;
}

function formatFR24ProfileTime(point, index, total) {
  if (Number.isFinite(point?.timestamp)) {
    return formatFlightTime(point.timestamp);
  }
  const denominator = Math.max(1, total - 1);
  return `${Math.round((index / denominator) * 100)}%`;
}

function formatFR24ProfileAxisTime(value) {
  const timestamp = normalizeFlightTimestamp(value);
  if (!timestamp) {
    return "";
  }
  try {
    return new Intl.DateTimeFormat(currentLanguage() === "zh-Hans" ? "zh-CN" : "en-US", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(new Date(timestamp * 1000));
  } catch (_error) {
    return new Date(timestamp * 1000).toISOString().slice(11, 16);
  }
}

function fr24ProfileDataPoints() {
  const points = state.fr24TrackPayload?.track_points || [];
  return points.map((point, index) => ({
    ...point,
    index,
    timestamp: finiteFR24Number(point.timestamp),
    altitude: finiteFR24Number(point.altitude_ft, point.altitude),
    speed: finiteFR24Number(point.speed_kt, point.speed),
  }));
}

function shouldShowFR24ProfilePanel() {
  return Boolean(state.fr24TrackPayload && isMapOverlayVisible("fr24"));
}

function paddedRange(values, fallbackPadding) {
  if (!values.length) {
    return { min: 0, max: 1 };
  }
  let min = Math.min(...values);
  let max = Math.max(...values);
  if (min === max) {
    min -= fallbackPadding;
    max += fallbackPadding;
  } else {
    const padding = Math.max(fallbackPadding, (max - min) * 0.08);
    min -= padding;
    max += padding;
  }
  return { min, max };
}

function svgPathForProfile(points, yKey) {
  let started = false;
  let path = "";
  points.forEach((point) => {
    const x = point.x;
    const y = point[yKey];
    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      started = false;
      return;
    }
    path += `${started ? "L" : "M"}${x.toFixed(1)} ${y.toFixed(1)} `;
    started = true;
  });
  return path.trim();
}

function drawFR24ProfileChart() {
  const svg = elements.fr24ProfileSvg;
  const profile = state.fr24ProfilePoints;
  if (!svg || profile.length < 2) {
    state.fr24ProfileLayout = null;
    if (svg) {
      svg.innerHTML = "";
    }
    return;
  }

  const chartElement = svg.parentElement || svg;
  const chartRect = chartElement.getBoundingClientRect();
  const width = Math.round(Math.max(320, chartRect.width || svg.clientWidth || 640));
  const height = Math.round(Math.max(120, chartRect.height || svg.clientHeight || 190));
  svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
  const labelFontSize = clampNumber(Math.min(width / 62, height / 15), 10, 12.5);
  const xLabelFontSize = clampNumber(Math.min(width / 72, height / 17), 9.5, 11.5);
  const plot = {
    left: Math.round(clampNumber(width * 0.11, 54, 74)),
    right: Math.round(clampNumber(width * 0.035, 18, 34)),
    top: Math.round(clampNumber(height * 0.1, 16, 26)),
    bottom: Math.round(clampNumber(height * 0.2, 36, 50)),
  };
  const plotWidth = width - plot.left - plot.right;
  const plotHeight = height - plot.top - plot.bottom;
  const timestamps = profile.map((point) => point.timestamp).filter(Number.isFinite);
  const minTime = timestamps.length ? Math.min(...timestamps) : 0;
  const maxTime = timestamps.length ? Math.max(...timestamps) : 0;
  const useTimeAxis = timestamps.length >= 2 && maxTime > minTime;
  const altitudeValues = profile.map((point) => point.altitude).filter(Number.isFinite);
  const speedValues = profile.map((point) => point.speed).filter(Number.isFinite);
  const altitudeRange = paddedRange(altitudeValues, 500);
  const speedRange = paddedRange(speedValues, 20);
  const xForPoint = (point, index) => {
    if (useTimeAxis && Number.isFinite(point.timestamp)) {
      return plot.left + ((point.timestamp - minTime) / Math.max(1, maxTime - minTime)) * plotWidth;
    }
    return plot.left + (index / Math.max(1, profile.length - 1)) * plotWidth;
  };
  const yForAltitude = (altitude) => plot.top + (1 - ((altitude - altitudeRange.min) / Math.max(1, altitudeRange.max - altitudeRange.min))) * plotHeight;
  const yForSpeed = (speed) => plot.top + (1 - ((speed - speedRange.min) / Math.max(1, speedRange.max - speedRange.min))) * plotHeight;
  const plotted = profile.map((point, index) => ({
    ...point,
    x: xForPoint(point, index),
    altitudeY: Number.isFinite(point.altitude) ? yForAltitude(point.altitude) : null,
    speedY: Number.isFinite(point.speed) ? yForSpeed(point.speed) : null,
  }));
  state.fr24ProfileLayout = {
    width,
    height,
    plotLeft: plot.left,
    plotRight: width - plot.right,
    points: plotted,
  };

  const altitudePath = svgPathForProfile(plotted, "altitudeY");
  const speedPath = svgPathForProfile(plotted, "speedY");
  const dayTheme = document.documentElement.dataset.theme === "day";
  const gridStroke = dayTheme ? "rgba(70, 111, 139, 0.22)" : "rgba(148, 188, 218, 0.18)";
  const axisStroke = dayTheme ? "rgba(43, 84, 112, 0.42)" : "rgba(148, 188, 218, 0.32)";
  const labelFill = dayTheme ? "rgba(39, 73, 98, 0.82)" : "rgba(203, 222, 238, 0.84)";
  const noDataFill = dayTheme ? "rgba(50, 80, 104, 0.72)" : "rgba(203, 222, 238, 0.72)";
  const yTickCount = Math.round(clampNumber(plotHeight / 36, 4, 6));
  const yGridLevels = Array.from({ length: yTickCount }, (_, index) => index / Math.max(1, yTickCount - 1));
  const yGrid = yGridLevels.map((level) => {
    const y = plot.top + level * plotHeight;
    const altitude = altitudeRange.max - level * (altitudeRange.max - altitudeRange.min);
    const label = altitudeValues.length ? formatFR24Altitude(altitude) : "";
    return `
      <line x1="${plot.left}" y1="${y.toFixed(1)}" x2="${(width - plot.right).toFixed(1)}" y2="${y.toFixed(1)}" stroke="${gridStroke}" stroke-width="1" />
      <text x="${(plot.left - 8).toFixed(1)}" y="${(y + labelFontSize * 0.32).toFixed(1)}" fill="${labelFill}" font-size="${labelFontSize.toFixed(1)}" font-weight="700" text-anchor="end">${escapeHtml(label)}</text>
    `;
  }).join("");
  const xTickCount = Math.round(clampNumber(plotWidth / 118 + 1, 3, 7));
  const xLabelY = height - Math.max(8, plot.bottom * 0.3);
  const xGrid = Array.from({ length: xTickCount }, (_, index) => {
    const level = index / Math.max(1, xTickCount - 1);
    const x = plot.left + level * plotWidth;
    const label = useTimeAxis
      ? formatFR24ProfileAxisTime(minTime + level * (maxTime - minTime))
      : `${Math.round(level * 100)}%`;
    return `
      <line x1="${x.toFixed(1)}" y1="${plot.top}" x2="${x.toFixed(1)}" y2="${(height - plot.bottom).toFixed(1)}" stroke="${gridStroke}" stroke-width="1" />
      <text x="${x.toFixed(1)}" y="${xLabelY.toFixed(1)}" fill="${labelFill}" font-size="${xLabelFontSize.toFixed(1)}" font-weight="700" text-anchor="middle">${escapeHtml(label)}</text>
    `;
  }).join("");
  const noData = !altitudeValues.length && !speedValues.length
    ? `<text x="${width / 2}" y="${height / 2}" fill="${noDataFill}" font-size="${clampNumber(width / 44, 12, 14).toFixed(1)}" font-weight="700" text-anchor="middle">${escapeHtml(t("query.profileNoData"))}</text>`
    : "";
  const altitudeStrokeWidth = clampNumber(height / 54, 2.8, 3.8);
  const speedStrokeWidth = clampNumber(height / 78, 1.9, 2.8);
  const cursorStrokeWidth = clampNumber(height / 125, 1.2, 1.7);
  const altitudeDotRadius = clampNumber(height / 42, 3.8, 5.2);
  const speedDotRadius = clampNumber(height / 50, 3.4, 4.6);

  svg.innerHTML = `
    <rect x="0" y="0" width="${width}" height="${height}" fill="transparent" />
    ${xGrid}
    ${yGrid}
    <line x1="${plot.left}" y1="${plot.top}" x2="${plot.left}" y2="${height - plot.bottom}" stroke="${axisStroke}" stroke-width="1.2" />
    <line x1="${plot.left}" y1="${height - plot.bottom}" x2="${width - plot.right}" y2="${height - plot.bottom}" stroke="${axisStroke}" stroke-width="1.2" />
    ${altitudePath ? `<path d="${altitudePath}" fill="none" stroke="#2f96ff" stroke-width="${altitudeStrokeWidth.toFixed(1)}" stroke-linecap="round" stroke-linejoin="round" />` : ""}
    ${speedPath ? `<path d="${speedPath}" fill="none" stroke="rgba(255, 198, 86, 0.95)" stroke-width="${speedStrokeWidth.toFixed(1)}" stroke-linecap="round" stroke-linejoin="round" />` : ""}
    ${noData}
    <line id="fr24ProfileCursorLine" x1="0" y1="${plot.top}" x2="0" y2="${height - plot.bottom}" stroke="rgba(237, 244, 255, 0.96)" stroke-width="${cursorStrokeWidth.toFixed(1)}" stroke-dasharray="6 6" />
    <circle id="fr24ProfileCursorAltitude" cx="0" cy="0" r="${altitudeDotRadius.toFixed(1)}" fill="#2f96ff" stroke="white" stroke-width="${cursorStrokeWidth.toFixed(1)}" />
    <circle id="fr24ProfileCursorSpeed" cx="0" cy="0" r="${speedDotRadius.toFixed(1)}" fill="#ffc656" stroke="rgba(20, 28, 38, 0.72)" stroke-width="${Math.max(1, cursorStrokeWidth - 0.2).toFixed(1)}" />
  `;
}

function updateFR24TrackCursorMarker(point) {
  if (!point || !shouldShowFR24ProfilePanel()) {
    if (fr24TrackCursorMarker) {
      fr24TrackLayerGroup.removeLayer(fr24TrackCursorMarker);
    }
    return;
  }
  const latlng = latLngForPoint(point);
  if (!fr24TrackCursorMarker) {
    fr24TrackCursorMarker = L.marker(latlng, {
      pane: "routePane",
      interactive: false,
      keyboard: false,
      icon: L.divIcon({
        className: "fr24-track-position-icon",
        html: "<span></span>",
        iconSize: [18, 18],
        iconAnchor: [9, 9],
      }),
    });
  } else {
    fr24TrackCursorMarker.setLatLng(latlng);
  }
  if (!fr24TrackLayerGroup.hasLayer(fr24TrackCursorMarker)) {
    fr24TrackCursorMarker.addTo(fr24TrackLayerGroup);
  }
}

function updateFR24ProfileCursor(index) {
  const profile = state.fr24ProfilePoints;
  if (!profile.length) {
    updateFR24TrackCursorMarker(null);
    if (elements.fr24ProfileReadout) {
      elements.fr24ProfileReadout.textContent = "--";
    }
    return;
  }
  const clampedIndex = Math.round(clampNumber(index, 0, profile.length - 1));
  state.fr24ProfileCursorIndex = clampedIndex;
  if (elements.fr24ProfileSlider) {
    elements.fr24ProfileSlider.max = String(profile.length - 1);
    elements.fr24ProfileSlider.value = String(clampedIndex);
  }
  const point = profile[clampedIndex];
  if (elements.fr24ProfileReadout) {
    elements.fr24ProfileReadout.textContent = t("query.profileReadout", {
      time: formatFR24ProfileTime(point, clampedIndex, profile.length),
      altitude: formatFR24Altitude(point.altitude),
      speed: formatFR24Speed(point.speed),
    });
  }
  const plotted = state.fr24ProfileLayout?.points?.[clampedIndex];
  if (elements.fr24ProfileSvg && plotted) {
    const line = elements.fr24ProfileSvg.querySelector("#fr24ProfileCursorLine");
    const altitudeDot = elements.fr24ProfileSvg.querySelector("#fr24ProfileCursorAltitude");
    const speedDot = elements.fr24ProfileSvg.querySelector("#fr24ProfileCursorSpeed");
    [line].forEach((element) => {
      if (!element) return;
      element.setAttribute("x1", plotted.x.toFixed(1));
      element.setAttribute("x2", plotted.x.toFixed(1));
    });
    if (altitudeDot) {
      altitudeDot.setAttribute("cx", plotted.x.toFixed(1));
      altitudeDot.setAttribute("cy", Number.isFinite(plotted.altitudeY) ? plotted.altitudeY.toFixed(1) : "0");
      altitudeDot.setAttribute("visibility", Number.isFinite(plotted.altitudeY) ? "visible" : "hidden");
    }
    if (speedDot) {
      speedDot.setAttribute("cx", plotted.x.toFixed(1));
      speedDot.setAttribute("cy", Number.isFinite(plotted.speedY) ? plotted.speedY.toFixed(1) : "0");
      speedDot.setAttribute("visibility", Number.isFinite(plotted.speedY) ? "visible" : "hidden");
    }
  }
  updateFR24TrackCursorMarker(point);
}

function updateFR24ProfilePanel() {
  if (!elements.fr24ProfileCard) {
    return;
  }
  const visible = shouldShowFR24ProfilePanel();
  const points = visible ? fr24ProfileDataPoints() : [];
  state.fr24ProfilePoints = points;
  elements.fr24ProfileCard.classList.toggle("hidden", points.length < 2);
  if (points.length < 2) {
    state.fr24ProfileLayout = null;
    if (elements.fr24ProfileSvg) {
      elements.fr24ProfileSvg.innerHTML = "";
    }
    if (elements.fr24ProfileReadout) {
      elements.fr24ProfileReadout.textContent = "--";
    }
    updateFR24TrackCursorMarker(null);
    return;
  }
  drawFR24ProfileChart();
  updateFR24ProfileCursor(state.fr24ProfileCursorIndex);
}

function scheduleFR24ProfileChartResize(delay = 0) {
  if (delay > 0) {
    window.setTimeout(() => scheduleFR24ProfileChartResize(), delay);
    return;
  }
  if (state.fr24ProfileResizeFrame) {
    window.cancelAnimationFrame(state.fr24ProfileResizeFrame);
  }
  state.fr24ProfileResizeFrame = window.requestAnimationFrame(() => {
    state.fr24ProfileResizeFrame = null;
    if (!state.fr24ProfilePoints.length || elements.fr24ProfileCard?.classList.contains("hidden")) {
      return;
    }
    drawFR24ProfileChart();
    updateFR24ProfileCursor(state.fr24ProfileCursorIndex);
  });
}

function ensureFR24ProfileResizeObserver() {
  if (state.fr24ProfileResizeObserver || !window.ResizeObserver) {
    return;
  }
  const targets = new Set([
    elements.detailPanel,
    elements.fr24ProfileCard,
    elements.fr24ProfileSvg?.parentElement,
  ].filter(Boolean));
  if (!targets.size) {
    return;
  }
  state.fr24ProfileResizeObserver = new ResizeObserver(() => scheduleFR24ProfileChartResize());
  targets.forEach((target) => state.fr24ProfileResizeObserver.observe(target));
}

function fr24ProfileIndexFromEvent(event) {
  const layout = state.fr24ProfileLayout;
  const svg = elements.fr24ProfileSvg;
  if (!layout || !svg) {
    return 0;
  }
  const rect = svg.getBoundingClientRect();
  const x = rect.width > 0
    ? ((event.clientX - rect.left) / rect.width) * layout.width
    : layout.plotLeft;
  let bestIndex = 0;
  let bestDistance = Infinity;
  layout.points.forEach((point, index) => {
    const distance = Math.abs(point.x - x);
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = index;
    }
  });
  return bestIndex;
}

function handleFR24ProfilePointer(event) {
  if (!state.fr24ProfilePoints.length) {
    return;
  }
  event.preventDefault();
  updateFR24ProfileCursor(fr24ProfileIndexFromEvent(event));
}

function renderFR24TrackPayload(payload, { fitBounds = false } = {}) {
  const basePoints = cloneFR24TrackPayload(payload)?.track_points || [];
  fr24TrackLayerGroup.clearLayers();
  if (basePoints.length < 2) {
    state.fr24TrackPayload = null;
    state.fr24ProfileCursorIndex = 0;
    updateFR24ProfilePanel();
    applyMapOverlayVisibility();
    updateTrackHistoryControlState();
    return 0;
  }
  const segments = splitFR24TrackSegments(basePoints);
  ROUTE_WORLD_COPY_OFFSETS.forEach((longitudeOffset) => {
    segments.forEach((segment) => {
      const latlngs = routeWorldCopy(segment.points, longitudeOffset).map(latLngForPoint);
      const layer = L.polyline(latlngs, {
        pane: "routePane",
        color: "#050505",
        weight: routeStrokeWeight(segment.dashed ? 2.8 : 3.4),
        opacity: segment.dashed ? 0.82 : 0.92,
        interactive: false,
        lineCap: "round",
        lineJoin: "round",
        dashArray: segment.dashed ? "7 8" : null,
      }).addTo(fr24TrackLayerGroup);
      layer.bringToFront();
    });
  });
  state.fr24TrackPayload = { track_points: cloneFR24TrackPayload({ track_points: basePoints }).track_points };
  state.fr24ProfileCursorIndex = clampNumber(state.fr24ProfileCursorIndex, 0, basePoints.length - 1);
  if (fitBounds) {
    const bounds = L.polyline(basePoints.map(latLngForPoint), {
      pane: "routePane",
      color: "#000000",
      weight: 0,
      opacity: 0,
      interactive: false,
    }).addTo(fr24TrackLayerGroup).getBounds();
    map.fitBounds(bounds, { padding: [36, 36] });
  }
  updateFR24ProfilePanel();
  applyMapOverlayVisibility();
  updateTrackHistoryControlState();
  return basePoints.length;
}

function drawFR24TrackPoints(trackPoints, { fitBounds = true, recordHistory = true } = {}) {
  const basePoints = normalizedFR24TrackPoints(trackPoints);
  if (recordHistory && (state.fr24TrackPayload || basePoints.length >= 2)) {
    pushDrawingUndoState();
  }
  const count = renderFR24TrackPayload({ track_points: basePoints }, { fitBounds });
  updateTrackHistoryControlState();
  return count;
}

async function downloadAndDrawFR24Track(key) {
  const flight = getFR24FlightByKey(key);
  if (!flight) {
    return;
  }
  setFR24QueryBusy(true);
  setFR24QueryStatus(t("query.downloading"));
  try {
    const payload = await fetchFR24TrackPayload(flight);
    const count = drawFR24TrackPoints(payload.track_points || []);
    updateFR24CacheSummary(payload.cache || state.fr24CacheStatus || {});
    updateFR24AccessSummary(payload.access || state.fr24AccessStatus || {});
    setFR24QueryStatus(t("query.drawn", { count }));
    setStatus(t("query.drawn", { count }));
  } catch (error) {
    const message = localizedErrorMessage(error.message);
    setFR24QueryStatus(message, true);
    setStatus(message, true);
  } finally {
    setFR24QueryBusy(false);
  }
}

async function matchFR24FlightTrack(key) {
  const flight = getFR24FlightByKey(key);
  const route = currentQueryRouteInputs();
  if (!flight || !route) {
    return;
  }
  const controller = beginRouteOperation(t("track.operation"));
  setFR24QueryBusy(true);
  setFR24QueryStatus(t("query.matching"));
  setStatus(t("query.matching"));
  try {
    const download = await fetchFR24TrackPayload(flight, { signal: controller.signal });
    throwIfAborted(controller.signal);
    drawFR24TrackPoints(download.track_points || [], { fitBounds: false });
    updateFR24CacheSummary(download.cache || state.fr24CacheStatus || {});
    updateFR24AccessSummary(download.access || state.fr24AccessStatus || {});
    if (state.currentRoutePayload && !state.preTrackMatchRoutePayload) {
      state.preTrackMatchRoutePayload = cloneJSON(state.currentRoutePayload);
      state.preTrackMatchAirports = cloneJSON(state.currentRouteAirports);
      state.preTrackMatchRouteLayerKind = state.currentRouteLayerKind;
    }
    const payload = await fetchJson("/api/route/track-match", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        departure: route.departure,
        arrival: route.arrival,
        track_points: download.track_points || [],
      }),
      signal: controller.signal,
    });
    throwIfAborted(controller.signal);
    await applyRoutePayload(payload, route.departure, route.arrival, {
      signal: controller.signal,
      routeLayerKind: "route",
    });
    const message = t("query.matched", {
      message: currentLanguage() === "zh-Hans" && payload.message ? payload.message : t("track.importMatchedFallback"),
      distance: Math.round(payload.distance_nm || 0),
    });
    setFR24QueryStatus(message);
    setStatus(message);
  } catch (error) {
    if (isAbortError(error)) {
      setStatus(t("track.stopped"));
    } else {
      const message = localizedErrorMessage(error.message);
      setFR24QueryStatus(message, true);
      setStatus(message, true);
    }
  } finally {
    setFR24QueryBusy(false);
    endRouteOperation(controller);
  }
}

function clearFR24TrackDrawing(options = {}) {
  const eventLike = options && typeof options === "object" && "target" in options;
  const recordHistory = eventLike ? true : options.recordHistory !== false;
  if (!state.fr24TrackPayload) {
    setFR24QueryStatus(t("query.noFR24Track"), true);
    setStatus(t("query.noFR24Track"), true);
    updateTrackHistoryControlState();
    return;
  }
  if (recordHistory) {
    pushDrawingUndoState();
  }
  fr24TrackLayerGroup.clearLayers();
  state.fr24TrackPayload = null;
  state.fr24ProfileCursorIndex = 0;
  updateFR24ProfilePanel();
  applyMapOverlayVisibility();
  updateTrackHistoryControlState();
  setFR24QueryStatus(t("query.fr24TrackCleared"));
  setStatus(t("query.fr24TrackCleared"));
}

async function restoreFR24MatchedRoute() {
  if (!state.preTrackMatchRoutePayload || !state.preTrackMatchAirports) {
    setFR24QueryStatus(t("query.noRestore"), true);
    return;
  }
  const controller = beginRouteOperation(t("query.restoreMatch"));
  try {
    await applyRoutePayload(
      cloneJSON(state.preTrackMatchRoutePayload),
      state.preTrackMatchAirports.departure,
      state.preTrackMatchAirports.arrival,
      { signal: controller.signal, routeLayerKind: state.preTrackMatchRouteLayerKind || inferRouteLayerKind(state.preTrackMatchRoutePayload) },
    );
    state.preTrackMatchRoutePayload = null;
    state.preTrackMatchAirports = null;
    state.preTrackMatchRouteLayerKind = null;
    setFR24QueryStatus(t("query.restored"));
    setStatus(t("query.restored"));
  } catch (error) {
    if (isAbortError(error)) {
      setStatus(t("track.stopped"));
    } else {
      setErrorStatus(error);
    }
  } finally {
    endRouteOperation(controller);
  }
}

async function deleteFR24CachedFlight(key) {
  const flight = state.fr24CacheFlights.get(key);
  const cacheKey = flight?.cache_key || flight?.fr24_id;
  if (!flight || !cacheKey) {
    return;
  }
  const label = flightPrimaryLabel(flight);
  if (!window.confirm(t("query.cacheDeleteConfirm", { flight: label }))) {
    return;
  }
  setFR24QueryBusy(true);
  setFR24QueryStatus(t("query.cacheLoading"));
  try {
    const payload = await fetchJson("/api/fr24/cache/delete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ cache_key: cacheKey }),
    });
    updateFR24CacheSummary(payload.cache || state.fr24CacheStatus || {});
    await searchFR24Cache();
    setFR24QueryStatus(t("query.cacheDeleted"));
    setStatus(t("query.cacheDeleted"));
  } catch (error) {
    const message = localizedErrorMessage(error.message);
    setFR24QueryStatus(message, true);
    setStatus(message, true);
  } finally {
    setFR24QueryBusy(false);
  }
}

async function setFR24CacheFavorite(key, favorite) {
  const flight = state.fr24CacheFlights.get(key);
  const cacheKey = flight?.cache_key || flight?.fr24_id;
  if (!flight || !cacheKey) {
    return;
  }
  setFR24QueryBusy(true);
  setFR24QueryStatus(t("query.cacheLoading"));
  try {
    const payload = await fetchJson("/api/fr24/cache/favorite", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ cache_key: cacheKey, favorite: Boolean(favorite) }),
    });
    updateFR24CacheSummary(payload.cache || state.fr24CacheStatus || {});
    await searchFR24Cache();
    const message = favorite ? t("query.cacheFavorited") : t("query.cacheUnfavorited");
    setFR24QueryStatus(message);
    setStatus(message);
  } catch (error) {
    const message = localizedErrorMessage(error.message);
    setFR24QueryStatus(message, true);
    setStatus(message, true);
  } finally {
    setFR24QueryBusy(false);
  }
}

async function shareFR24CachedFlight(key) {
  const flight = state.fr24CacheFlights.get(key);
  const cacheKey = flight?.cache_key || flight?.fr24_id;
  if (!flight || !cacheKey) {
    return;
  }
  if (!window.webkit?.messageHandlers?.navplanner) {
    setFR24QueryStatus(t("database.iosOnly"), true);
    setStatus(t("database.iosOnly"), true);
    return;
  }
  setFR24QueryBusy(true);
  setFR24QueryStatus(t("query.cacheSharing"));
  try {
    const payload = await fetchJson("/api/fr24/cache/share", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ cache_key: cacheKey }),
    });
    updateFR24CacheSummary(payload.cache || state.fr24CacheStatus || {});
    if (!payload.share_path) {
      throw new Error(t("query.cacheDirectoryFailed"));
    }
    postNativeEvent("shareFile", {
      path: payload.share_path,
      title: payload.filename || flightPrimaryLabel(flight),
    });
    await searchFR24Cache();
    setFR24QueryStatus(t("query.cacheShareReady"));
    setStatus(t("query.cacheShareReady"));
  } catch (error) {
    const message = localizedErrorMessage(error.message);
    setFR24QueryStatus(message, true);
    setStatus(message, true);
  } finally {
    setFR24QueryBusy(false);
  }
}

async function clearFR24Cache() {
  const status = state.fr24CacheStatus || await refreshFR24CacheStatus();
  const size = formatBytes(status.size_bytes || 0);
  const count = formatCount(status.file_count || 0);
  if (!window.confirm(`${t("query.clearCacheConfirm")}\n\n${t("query.cacheSummary", { size, count })}`)) {
    return;
  }
  const payload = await fetchJson("/api/fr24/cache/clear", { method: "POST" });
  updateFR24CacheSummary(payload);
  await searchFR24Cache();
  const favoriteCount = Number(payload.favorite_count || 0);
  const message = favoriteCount > 0
    ? t("query.cacheClearedWithFavorites", { count: formatCount(favoriteCount) })
    : t("query.cacheCleared");
  setFR24QueryStatus(message);
  setStatus(message);
}

function handleFR24FlightAction(event) {
  const button = event.target instanceof Element ? event.target.closest("[data-fr24-action]") : null;
  if (!button) {
    return;
  }
  event.preventDefault();
  const key = button.dataset.fr24Key;
  const action = button.dataset.fr24Action;
  if (action === "history") {
    loadFR24History(key).catch(setErrorStatus);
  } else if (action === "draw") {
    downloadAndDrawFR24Track(key).catch(setErrorStatus);
  } else if (action === "match") {
    matchFR24FlightTrack(key).catch(setErrorStatus);
  } else if (action === "delete-cache") {
    deleteFR24CachedFlight(key).catch(setErrorStatus);
  } else if (action === "favorite-cache") {
    setFR24CacheFavorite(key, button.dataset.fr24Favorite === "true").catch(setErrorStatus);
  } else if (action === "share-cache") {
    shareFR24CachedFlight(key).catch(setErrorStatus);
  }
}

const calculatePage = createCalculatePage({
  state,
  elements,
  t,
  currentLanguage,
  escapeHtml,
  clampNumber,
  withDisplayLongitudes,
  normalizeLongitude,
  greatCircleDistanceNm,
  initialBearingDeg,
  procedureCacheKey,
  formatAltitudeRestriction,
  svgPathForProfile,
});

function syncCalculateControls(options = {}) {
  calculatePage.syncControls(options);
}

function scheduleCalculateRender(delay = 0) {
  calculatePage.scheduleRender(delay);
}

function normalizeCalculateManufacturer(value) {
  return calculatePage.normalizeManufacturer(value);
}

function normalizeCalculateAircraft(value, manufacturer = state.calculateManufacturer) {
  return calculatePage.normalizeAircraft(value, manufacturer);
}

function isCalculateWeatherSource(value) {
  return calculatePage.hasWeatherSource(value);
}

function forEachCalculateLayer(callback) {
  calculatePage.forEachLayer(callback);
}

registerPlanPage({
  elements,
  buildRoute,
  clearAllMapDrawings,
  stopActiveRouteOperation,
});

registerAirportPage({
  elements,
  map,
  airportSlots: AIRPORT_SLOTS,
  airportForSlot,
  setActiveAirportSlot,
});

registerQueryPage({
  elements,
  state,
  t,
  formatBytes,
  formatCount,
  searchFR24Flights,
  importFR24GPX,
  searchFR24ManualHistory,
  handleFR24FlightAction,
  searchFR24Cache,
  clearFR24TrackDrawing,
  restoreFR24MatchedRoute,
  clearFR24Cache,
  refreshFR24CacheStatus,
  setFR24QueryStatus,
  openFR24CacheDirectory,
  openFR24VerificationBrowser,
  syncFR24BrowserSession,
  saveFR24Access,
  clearFR24Access,
  refreshFR24AccessStatus,
  updateFR24ProfileCursor,
  handleFR24ProfilePointer,
  ensureFR24ProfileResizeObserver,
  setErrorStatus,
});

calculatePage.registerEvents();

registerSettingsPage({
  elements,
  t,
  requestDatabaseSelection,
  refreshDatabaseList,
  restoreBundledDatabase,
  handleDatabaseListAction,
  openOfflineMapManagerFromSettings,
  refreshOfflineMapStatus,
  refreshMapCacheStatus,
  clearMapCache,
  resetAllSettingsAndCaches,
  applyThemeMode,
  applyLanguageMode,
  applyAppIconChoice,
  applyMapSourceChoice,
  applyOnlineMapProvider,
  applyMapTileZoomOffset,
  setStatus,
  setErrorStatus,
});

elements.mapExpandButton?.addEventListener("click", () => {
  const expanded = !document.body.classList.contains("map-expanded");
  document.body.classList.toggle("map-expanded", expanded);
  elements.mapExpandButton.classList.toggle("is-expanded", expanded);
  const label = expanded ? t("layout.restoreMap") : t("layout.expandMap");
  elements.mapExpandButton.setAttribute("aria-label", label);
  elements.mapExpandButton.setAttribute("title", label);
  window.setTimeout(() => {
    map.invalidateSize();
    scheduleVectorMapResizeSync();
    scheduleFR24ProfileChartResize();
    scheduleCalculateRender();
    refreshNavOverlay();
  }, 180);
  scheduleFR24ProfileChartResize(260);
  scheduleCalculateRender(260);
});
elements.sidebarExpandButton?.addEventListener("click", () => {
  const expanded = !document.body.classList.contains("left-panel-expanded");
  document.body.classList.toggle("left-panel-expanded", expanded);
  elements.sidebarExpandButton.classList.toggle("is-expanded", expanded);
  const label = expanded ? t("layout.restoreSidebar") : t("layout.expandSidebar");
  elements.sidebarExpandButton.setAttribute("aria-label", label);
  elements.sidebarExpandButton.setAttribute("title", label);
  window.setTimeout(() => {
    map.invalidateSize();
    scheduleVectorMapResizeSync();
    scheduleFR24ProfileChartResize();
    scheduleCalculateRender();
    refreshNavOverlay();
  }, 180);
  scheduleFR24ProfileChartResize(260);
  scheduleCalculateRender(260);
});
elements.detailModeTabButtons.forEach((button) => {
  button.addEventListener("click", () => setDetailTab(button.dataset.detailTab));
});
elements.mobileBottomTabButtons.forEach((button) => {
  button.addEventListener("click", () => setMobileBottomTab(button.dataset.mobileTab));
});
window.addEventListener("resize", () => {
  updateMapTileZoomOffsetControl();
  scheduleFR24ProfileChartResize();
  scheduleCalculateRender();
}, { passive: true });
window.addEventListener("orientationchange", () => {
  window.setTimeout(() => {
    updateMapTileZoomOffsetControl();
    scheduleFR24ProfileChartResize();
    scheduleCalculateRender();
  }, 180);
}, { passive: true });
themeMediaQuery?.addEventListener?.("change", () => {
  if (state.themeMode === "system") {
    applyThemeMode("system", { persist: false });
  }
});
window.addEventListener("languagechange", () => {
  if (state.languageMode === "system") {
    applyLanguageMode("system", { persist: false });
  }
});
window.navplannerNativeDatabaseSelected = handleNativeDatabaseSelected;
window.navplannerNativeAppIconChanged = handleNativeAppIconChanged;
window.navplannerNativeFR24SessionUpdated = handleNativeFR24SessionUpdated;
window.navplannerNativeFR24CacheDirectoryOpened = handleNativeFR24CacheDirectoryOpened;
window.navplannerNativeFR24GPXImported = handleNativeFR24GPXImported;

elements.departureInput.addEventListener(
  "input",
  debounce(() => searchEntities(elements.departureInput, elements.departureResults)),
);
elements.arrivalInput.addEventListener(
  "input",
  debounce(() => searchEntities(elements.arrivalInput, elements.arrivalResults)),
);
elements.manualInput.addEventListener(
  "input",
  debounce(() => searchEntities(elements.manualInput, elements.manualResults)),
);
elements.departureInput.addEventListener("focus", () => {
  elements.arrivalResults.classList.add("hidden");
  elements.manualResults.classList.add("hidden");
});
elements.arrivalInput.addEventListener("focus", () => {
  elements.departureResults.classList.add("hidden");
  elements.manualResults.classList.add("hidden");
});
elements.manualInput.addEventListener("focus", () => {
  elements.departureResults.classList.add("hidden");
  elements.arrivalResults.classList.add("hidden");
});

document.addEventListener("click", (event) => {
  if (!event.target.closest(".search-wrap")) {
    hideSearchResults();
  }
});

function simulatorDebugLaunchConfig() {
  const raw = window.__NAVPLANNER_SIM_DEBUG_JSON;
  if (!raw) {
    return null;
  }
  if (typeof raw === "object") {
    return raw;
  }
  try {
    const parsed = JSON.parse(String(raw));
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch (error) {
    console.warn("NavPlanner simulator debug JSON 解析失败", error);
    return null;
  }
}

async function applySimulatorDebugLaunch() {
  if (window.__NAVPLANNER_SIM_DEBUG_APPLIED) {
    return;
  }
  const config = simulatorDebugLaunchConfig();
  if (!config) {
    return;
  }
  window.__NAVPLANNER_SIM_DEBUG_APPLIED = true;

  if (["system", "zh-Hans", "en"].includes(config.languageMode)) {
    applyLanguageMode(config.languageMode, { persist: false });
  }
  if (["system", "day", "night"].includes(config.themeMode)) {
    applyThemeMode(config.themeMode, { persist: false });
  }
  if (typeof config.departure === "string") {
    elements.departureInput.value = config.departure.trim().toUpperCase();
  }
  if (typeof config.arrival === "string") {
    elements.arrivalInput.value = config.arrival.trim().toUpperCase();
  }
  if (typeof config.route === "string") {
    elements.routeInput.value = config.route.trim().toUpperCase();
  }
  if (typeof config.departureRunway === "string") {
    state.selectedRunways.departure = config.departureRunway.trim().toUpperCase() || "ALL";
  }
  if (typeof config.arrivalRunway === "string") {
    state.selectedRunways.arrival = config.arrivalRunway.trim().toUpperCase() || "ALL";
  }

  let shouldSyncCalculateControls = false;
  if (typeof config.calculateManufacturer === "string") {
    state.calculateManufacturer = normalizeCalculateManufacturer(config.calculateManufacturer);
    shouldSyncCalculateControls = true;
  }
  if (typeof config.calculateAircraft === "string") {
    state.calculateAircraft = normalizeCalculateAircraft(config.calculateAircraft, state.calculateManufacturer);
    shouldSyncCalculateControls = true;
  }
  if (Number.isFinite(Number(config.cruiseAltitudeFt))) {
    state.calculateCruiseAltitudeFt = clampNumber(Number(config.cruiseAltitudeFt), 10000, 60000);
    shouldSyncCalculateControls = true;
  }
  if (Number.isFinite(Number(config.cruiseMach))) {
    state.calculateCruiseMach = Number(config.cruiseMach);
    shouldSyncCalculateControls = true;
  }
  if (Number.isFinite(Number(config.descentRateFpm))) {
    state.calculateDescentRateFpm = clampNumber(Number(config.descentRateFpm), 0, 4000);
    shouldSyncCalculateControls = true;
  }
  if (Number.isFinite(Number(config.profileZoom))) {
    state.calculateProfileZoom = clampNumber(Number(config.profileZoom), 1, 4);
    shouldSyncCalculateControls = true;
  }
  if (isCalculateWeatherSource(config.weatherSource)) {
    state.calculateWeatherSource = config.weatherSource;
    shouldSyncCalculateControls = true;
  }
  if (config.calculateLayerVisibility && typeof config.calculateLayerVisibility === "object") {
    forEachCalculateLayer((key) => {
      if (typeof config.calculateLayerVisibility[key] === "boolean") {
        state.calculateLayerVisibility[key] = config.calculateLayerVisibility[key];
      }
    });
    shouldSyncCalculateControls = true;
  }
  if (shouldSyncCalculateControls) {
    syncCalculateControls();
  }

  if (config.buildRoute) {
    await buildRoute({ forceAuto: config.forceAuto !== false });
  }

  const mobileTab = typeof config.mobileTab === "string" ? config.mobileTab : config.tab;
  if (typeof mobileTab === "string") {
    setMobileBottomTab(mobileTab);
  }
  const detailTab = typeof config.detailTab === "string"
    ? config.detailTab
    : (mobileTab === "calculate" ? "calculate" : "");
  if (detailTab) {
    setDetailTab(detailTab);
  }
  if (mobileTab === "calculate" || detailTab === "calculate") {
    scheduleCalculateRender();
    scheduleCalculateRender(220);
  }
  if (Number.isFinite(Number(config.calculateScrollTop)) && elements.calculateSection) {
    window.setTimeout(() => {
      elements.calculateSection.scrollTop = Math.max(0, Number(config.calculateScrollTop));
      scheduleCalculateRender();
    }, 320);
  }
  console.info("NavPlanner simulator debug launch applied", config.name || "");
}

/**
 * 功能：执行 `init` 对应的业务逻辑。
 * 输入：无。
 * 输出：Promise，解析为函数处理结果。
 */
async function init() {
  applyLanguageMode(state.languageMode, { persist: false, refresh: false });
  applyThemeMode(state.themeMode, { persist: false });
  applyAppIconChoice(state.appIconChoice, { persist: false, notifyNative: false });
  updateMapTypeOptionLabels();
  updateMapTypeOptionState();
  updateMapTileZoomOffsetControl();
  setDetailTab("airport");
  setMobileBottomTab("plan");
  try {
    await refreshHeaderStatus({ announce: false });
    renderRunwayButtons("departure");
    renderRunwayButtons("arrival");
    renderRunwayButtons("manual");
    updateAirportPanelVisibility();
    refreshNavOverlay();
    refreshOfflineMapStatus().catch((error) => console.warn("离线地图状态刷新失败", error));
    refreshMapCacheStatus().catch((error) => console.warn("在线地图缓存状态刷新失败", error));
    await applySimulatorDebugLaunch();
  } catch (error) {
    setErrorStatus(error);
  }
}

init();
