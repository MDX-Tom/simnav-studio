import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(SQLite3)
import SQLite3
#elseif canImport(CSQLite)
import CSQLite
#else
#error("SQLite3 or CSQLite is required to build SimNavCore")
#endif

struct OfflineTileResult {
    let data: Data
    let contentType: String
    let headers: [String: String]
}

struct OfflineFileRangeResult {
    let statusCode: Int
    let data: Data
    let contentType: String
    let headers: [String: String]
}

private final class CachedOfflineTile {
    let result: OfflineTileResult

    init(result: OfflineTileResult) {
        self.result = result
    }
}

struct OfflineMapResource: Identifiable {
    let name: String
    let url: URL
    let isDirectory: Bool
    let kind: String
    let storageLayout: String
    let format: String
    let contentType: String
    let size: Int64
    let tileCount: Int
    let bounds: [String: Any]?
    let minZoom: Int
    let maxZoom: Int
    let sourceMaxZoom: Int

    var id: String { name }

    func payload(active: Bool) -> [String: Any] {
        [
            "name": name,
            "label": name,
            "provider": "local_import",
            "provider_label": "本地导入",
            "kind": kind,
            "storage_layout": storageLayout,
            "format": format,
            "content_type": contentType,
            "active": active,
            "size_bytes": size,
            "tile_count": tileCount,
            "bounds": bounds ?? NSNull(),
            "min_zoom": minZoom,
            "max_zoom": maxZoom,
            "source_max_zoom": sourceMaxZoom
        ]
    }
}

private struct OfflineDownloadProvider {
    let key: String
    let label: String
    let kind: String
    let format: String
    let contentType: String
    let templates: [String]
    let maxZoom: Int
    let recommendedSourceMaxZoom: Int
    let estimatedTileBytes: Int
    let description: String

    func payload() -> [String: Any] {
        [
            "key": key,
            "label": label,
            "kind": kind,
            "format": format,
            "max_zoom": maxZoom,
            "recommended_source_max_zoom": recommendedSourceMaxZoom,
            "estimated_tile_bytes": estimatedTileBytes,
            "description": description
        ]
    }

    func requestURL(z: Int, x: Int, y: Int) -> URL? {
        requestURLs(z: z, x: x, y: y).first
    }

    func requestURLs(z: Int, x: Int, y: Int) -> [URL] {
        guard !templates.isEmpty else { return [] }
        let startIndex = abs(z + x + y) % templates.count
        return (0..<templates.count).compactMap { offset in
            let template = templates[(startIndex + offset) % templates.count]
            let text = template
                .replacingOccurrences(of: "{z}", with: String(z))
                .replacingOccurrences(of: "{x}", with: String(x))
                .replacingOccurrences(of: "{y}", with: String(y))
            return URL(string: text)
        }
    }
}

private struct OfflineTileRange {
    let zoom: Int
    let xStart: Int
    let xEnd: Int
    let yStart: Int
    let yEnd: Int

    var tileCount: Int {
        max(0, xEnd - xStart + 1) * max(0, yEnd - yStart + 1)
    }
}

private struct OfflineTileCoordinate {
    let z: Int
    let x: Int
    let y: Int
}

private struct OfflineTileFetchOutcome {
    let coordinate: OfflineTileCoordinate
    let result: Result<Data, Error>
}

private final class OfflineTileOutcomeBuffer: @unchecked Sendable {
    private let condition = NSCondition()
    private var outcomes: [OfflineTileFetchOutcome] = []

    func append(_ outcome: OfflineTileFetchOutcome) {
        condition.lock()
        outcomes.append(outcome)
        condition.signal()
        condition.unlock()
    }

    func drain(waitingUntil deadline: Date) -> [OfflineTileFetchOutcome] {
        condition.lock()
        if outcomes.isEmpty {
            _ = condition.wait(until: deadline)
        }
        let drained = outcomes
        outcomes.removeAll(keepingCapacity: true)
        condition.unlock()
        return drained
    }
}

private final class OfflineTileRequestResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Data, Error>?

    func store(_ result: Result<Data, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func snapshot() -> Result<Data, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}

private struct OfflineTileHTTPError: LocalizedError {
    let statusCode: Int

    var errorDescription: String? {
        "HTTP \(statusCode)"
    }
}

private struct OfflineMapImportError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private final class OfflineDownloadJobState {
    private let lock = NSLock()
    private var payload: [String: Any]
    private var cancelled = false

    init(payload: [String: Any]) {
        self.payload = payload
    }

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    func snapshot() -> [String: Any] {
        lock.withLock { payload }
    }

    func update(_ body: (inout [String: Any]) -> Void) {
        lock.withLock {
            body(&payload)
        }
    }

    func requestCancel() -> [String: Any] {
        lock.withLock {
            cancelled = true
            payload["aborted"] = true
            payload["message"] = "用户已请求取消下载，正在停止当前瓦片请求。"
            payload["cancel_requested_at"] = Self.timestamp()
            return payload
        }
    }

    static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}

final class MapStore {
    private let fileManager: FileManager
    private let rootDirectory: URL
    private let queue = DispatchQueue(label: "com.navplanner.map-store", qos: .utility)
    private let downloadQueue = DispatchQueue(label: "com.navplanner.map-store.download", qos: .utility)
    private let downloadLock = NSLock()
    private let tileCache = NSCache<NSString, CachedOfflineTile>()
    private var downloadJob: OfflineDownloadJobState?

    private let maxDownloadTiles = 5_000_000
    private let downloadWorkers = 12
    private let downloadInflightFactor = 2
    private let tileTimeoutSeconds: TimeInterval = 12
    private let tileRetries = 1

    private var downloadInflightLimit: Int {
        max(downloadWorkers, downloadWorkers * downloadInflightFactor)
    }

    private let downloadProviders: [String: OfflineDownloadProvider] = [
        "opentopomap": OfflineDownloadProvider(
            key: "opentopomap",
            label: "OpenTopoMap Terrain",
            kind: "raster",
            format: "png",
            contentType: "image/png",
            templates: [
                "https://a.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://b.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://c.tile.opentopomap.org/{z}/{x}/{y}.png"
            ],
            maxZoom: 17,
            recommendedSourceMaxZoom: 10,
            estimatedTileBytes: 42_000,
            description: "全球地形栅格瓦片；iOS 本地下载后写入 SQLite 瓦片库。"
        ),
        "esri_topo": OfflineDownloadProvider(
            key: "esri_topo",
            label: "Esri World Topographic",
            kind: "raster",
            format: "jpg",
            contentType: "image/jpeg",
            templates: [
                "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}"
            ],
            maxZoom: 19,
            recommendedSourceMaxZoom: 10,
            estimatedTileBytes: 8_500,
            description: "全球地形/地理信息栅格瓦片，适合离线地形浏览。"
        ),
        "osm_standard": OfflineDownloadProvider(
            key: "osm_standard",
            label: "OpenStreetMap Standard",
            kind: "raster",
            format: "png",
            contentType: "image/png",
            templates: [
                "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
            ],
            maxZoom: 19,
            recommendedSourceMaxZoom: 10,
            estimatedTileBytes: 18_000,
            description: "全球通用栅格瓦片，地形表达较弱但覆盖稳定。"
        ),
        "openfreemap_vector": OfflineDownloadProvider(
            key: "openfreemap_vector",
            label: "OpenFreeMap Vector",
            kind: "vector",
            format: "pbf",
            contentType: "application/vnd.mapbox-vector-tile",
            templates: [
                "https://tiles.openfreemap.org/planet/20260520_001001_pt/{z}/{x}/{y}.pbf"
            ],
            maxZoom: 14,
            recommendedSourceMaxZoom: 10,
            estimatedTileBytes: 6_500,
            description: "全球矢量瓦片资源；下载为 SQLite 瓦片库后可作为离线地形矢量底图。"
        )
    ]

    private struct OfflineDownloadRequest {
        let provider: OfflineDownloadProvider
        let name: String
        let bounds: [String: Double]
        let baseBounds: [String: Double]
        let tiered: Bool
        let baseMaxZoom: Int
        let minZoom: Int
        let maxZoom: Int
        let sourceMaxZoom: Int
        let ranges: [OfflineTileRange]
        let total: Int
        let estimatedBytes: Int
    }

    init(fileManager: FileManager = .default, rootDirectory: URL? = nil) {
        self.fileManager = fileManager
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let supportRoot = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("NavPlanner", isDirectory: true)
            self.rootDirectory = supportRoot.appendingPathComponent("MapOffline", isDirectory: true)
        }
        tileCache.countLimit = 512
        try? fileManager.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true)
    }

    func statusPayload() -> [String: Any] {
        queue.sync {
            statusPayloadLocked(resources: scanResources())
        }
    }

    func importResource(from sourceURL: URL) throws -> [String: Any] {
        try queue.sync {
            let supportedExtensions = Set(["pmtiles", "mbtiles", "sqlite", "sqlite3"])
            let source = sourceURL.standardizedFileURL
            let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            let fileSize = Int64(values.fileSize ?? 0)
            guard values.isRegularFile == true else {
                throw OfflineMapImportError(message: "离线地图导入源不是普通文件。")
            }
            guard fileSize > 0 else {
                throw OfflineMapImportError(message: "离线地图文件为空。")
            }
            guard fileSize <= 64 * 1_024 * 1_024 * 1_024 else {
                throw OfflineMapImportError(message: "离线地图文件超过 64 GiB 上限。")
            }
            let pathExtension = source.pathExtension.lowercased()
            guard supportedExtensions.contains(pathExtension) else {
                throw OfflineMapImportError(message: "仅支持 PMTiles、MBTiles、SQLite 或 SQLite3 地图包。")
            }

            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            let stagingRoot = rootDirectory.appendingPathComponent(
                ".import-\(UUID().uuidString)",
                isDirectory: true
            )
            try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: stagingRoot) }

            let baseName = safeResourceName(source.deletingPathExtension().lastPathComponent)
            var targetName = "\(baseName).\(pathExtension)"
            var suffix = 2
            while fileManager.fileExists(atPath: rootDirectory.appendingPathComponent(targetName).path) {
                targetName = "\(baseName)-\(suffix).\(pathExtension)"
                suffix += 1
            }
            let stagedURL = stagingRoot.appendingPathComponent(targetName)
            try fileManager.copyItem(at: source, to: stagedURL)
            try validateImportedMap(at: stagedURL, pathExtension: pathExtension)

            let targetURL = rootDirectory.appendingPathComponent(targetName)
            try fileManager.moveItem(at: stagedURL, to: targetURL)
            tileCache.removeAllObjects()
            let resources = scanResources()
            guard let imported = resources.first(where: { $0.url.standardizedFileURL == targetURL.standardizedFileURL }) else {
                try? fileManager.removeItem(at: targetURL)
                throw OfflineMapImportError(message: "地图包已复制，但无法识别其瓦片布局。")
            }
            writeActiveResourceName(imported.name)
            var payload = statusPayloadLocked(resources: resources)
            payload["imported"] = imported.payload(active: true)
            payload["message"] = "已导入并启用离线地图：\(imported.name)"
            return payload
        }
    }

    func activeTile(z: Int, x: Int, y: Int) -> OfflineTileResult? {
        queue.sync {
            let resources = scanResources()
            guard let active = activeResourceName(resources: resources),
                  let resource = resources.first(where: { $0.name == active }) else {
                return nil
            }
            return tile(resource: resource, z: z, x: x, y: y)
        }
    }

    func resourceTile(name: String, z: Int, x: Int, y: Int) -> OfflineTileResult? {
        queue.sync {
            let normalized = safeResourceName(name)
            guard let resource = scanResources().first(where: { $0.name == normalized || $0.name == name }) else {
                return nil
            }
            return tile(resource: resource, z: z, x: x, y: y)
        }
    }

    func pmtilesFileResponse(name: String, rangeHeader: String?) -> OfflineFileRangeResult? {
        queue.sync {
            let normalized = safeResourceName(name)
            guard let resource = scanResources().first(where: { $0.name == normalized || $0.name == name }),
                  let url = pmtilesURL(for: resource) else {
                return nil
            }
            return fileRangeResponse(url: url, contentType: "application/octet-stream", rangeHeader: rangeHeader)
        }
    }

    func selectResource(name: String) -> [String: Any] {
        queue.sync {
            let normalized = safeResourceName(name)
            let resources = scanResources()
            guard resources.contains(where: { $0.name == normalized || $0.name == name }) else {
                var payload = statusPayloadLocked(resources: resources)
                payload["message"] = "未找到离线地图资源：\(name)"
                return payload
            }
            writeActiveResourceName(normalized)
            return statusPayloadLocked(resources: resources)
        }
    }

    func deleteResource(name: String) -> [String: Any] {
        queue.sync {
            let normalized = safeResourceName(name)
            let resources = scanResources()
            if let resource = resources.first(where: { $0.name == normalized || $0.name == name }) {
                try? fileManager.removeItem(at: resource.url)
                tileCache.removeAllObjects()
                if activeResourceName(resources: resources) == resource.name {
                    try? fileManager.removeItem(at: activeFileURL)
                }
            }
            return statusPayloadLocked(resources: scanResources())
        }
    }

    func compactResource(name: String) -> [String: Any] {
        queue.sync {
            var payload = statusPayloadLocked(resources: scanResources())
            payload["message"] = "iOS 已支持读取 SQLite / MBTiles / 文件布局离线瓦片；旧目录压缩迁移将在下载器接入阶段补齐。"
            return payload
        }
    }

    func startDownload(payload: [String: Any]) -> [String: Any] {
        let existing = downloadLock.withLock { downloadJob }
        if let existing, existing.snapshot()["running"] as? Bool == true {
            return failedDownloadJob(message: "已有离线地图下载任务正在运行。", name: stringValue(payload["name"]) ?? "离线地图资源")
        }

        guard let request = makeDownloadRequest(payload: payload) else {
            return failedDownloadJob(message: "离线地图下载参数无效。", name: stringValue(payload["name"]) ?? "离线地图资源")
        }
        if request.total <= 0 {
            return failedDownloadJob(message: "下载范围内没有可用瓦片。", name: request.name)
        }
        if request.total > maxDownloadTiles {
            return failedDownloadJob(message: "下载将包含 \(request.total) 个瓦片，超过上限 \(maxDownloadTiles)。", name: request.name)
        }
        do {
            try probeDownloadProvider(request: request)
        } catch {
            return failedDownloadJob(
                message: "\(request.provider.label) 当前无法访问，已取消下载任务。请换用 Esri World Topographic 或稍后重试。原因：\(cleanTileError(error))",
                name: request.name
            )
        }

        let job = OfflineDownloadJobState(payload: initialDownloadJobPayload(request: request))
        downloadLock.withLock {
            downloadJob = job
        }
        downloadQueue.async { [weak self, job] in
            self?.runDownload(request: request, job: job)
        }
        return job.snapshot()
    }

    func cancelDownload() -> [String: Any] {
        guard let job = downloadLock.withLock({ downloadJob }),
              job.snapshot()["running"] as? Bool == true else {
            return failedDownloadJob(message: "当前没有正在运行的离线地图下载任务。", name: "离线地图资源")
        }
        return job.requestCancel()
    }

    private func scanResources() -> [OfflineMapResource] {
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        guard let items = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return items.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isDirectory == true {
                return directoryResource(url: url)
            }
            if values?.isRegularFile == true {
                return fileResource(url: url)
            }
            return nil
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func directoryResource(url: URL) -> OfflineMapResource? {
        let metadata = loadMetadata(directory: url)
        let tilesSQLiteURL = url.appendingPathComponent("tiles.sqlite")
        let pmtilesURL = url.appendingPathComponent("resource.pmtiles")
        let tilesDirectoryURL = url.appendingPathComponent("tiles", isDirectory: true)
        let hasKnownStorage = fileManager.fileExists(atPath: tilesSQLiteURL.path)
            || fileManager.fileExists(atPath: pmtilesURL.path)
            || fileManager.fileExists(atPath: tilesDirectoryURL.path)
        guard metadata != nil || hasKnownStorage else {
            return nil
        }

        let rawName = stringValue(metadata?["name"]) ?? url.lastPathComponent
        let name = safeResourceName(rawName)
        let format = stringValue(metadata?["format"]) ?? (fileManager.fileExists(atPath: pmtilesURL.path) ? "pbf" : "png")
        let contentType = stringValue(metadata?["content_type"]) ?? contentType(forFormat: format)
        let storageLayout = stringValue(metadata?["storage_layout"])
            ?? (fileManager.fileExists(atPath: pmtilesURL.path) ? "pmtiles_v1" : (fileManager.fileExists(atPath: tilesSQLiteURL.path) ? "sqlite_v1" : "files_legacy"))
        let kind = stringValue(metadata?["kind"]) ?? kindForContentType(contentType, format: format, storageLayout: storageLayout)
        let tileCount = intValue(metadata?["tile_count"]) ?? sqliteTileCount(url: tilesSQLiteURL, layout: "sqlite_v1") ?? 0
        let minZoom = intValue(metadata?["min_zoom"]) ?? sqliteZoomRange(url: tilesSQLiteURL, layout: "sqlite_v1")?.min ?? 0
        let maxZoom = intValue(metadata?["max_zoom"]) ?? sqliteZoomRange(url: tilesSQLiteURL, layout: "sqlite_v1")?.max ?? 14
        return OfflineMapResource(
            name: name,
            url: url,
            isDirectory: true,
            kind: kind,
            storageLayout: storageLayout,
            format: format,
            contentType: contentType,
            size: directorySize(url),
            tileCount: tileCount,
            bounds: metadata?["bounds"] as? [String: Any],
            minZoom: minZoom,
            maxZoom: maxZoom,
            sourceMaxZoom: intValue(metadata?["source_max_zoom"]) ?? maxZoom
        )
    }

    private func fileResource(url: URL) -> OfflineMapResource? {
        let ext = url.pathExtension.lowercased()
        guard ["pmtiles", "mbtiles", "sqlite", "sqlite3"].contains(ext) else {
            return nil
        }
        if ext == "pmtiles" {
            return OfflineMapResource(
                name: safeResourceName(url.deletingPathExtension().lastPathComponent),
                url: url,
                isDirectory: false,
                kind: "vector",
                storageLayout: "pmtiles_v1",
                format: "pbf",
                contentType: "application/vnd.mapbox-vector-tile",
                size: fileSize(url),
                tileCount: 0,
                bounds: nil,
                minZoom: 0,
                maxZoom: 14,
                sourceMaxZoom: 14
            )
        }
        return sqliteFileResource(url: url)
    }

    private func sqliteFileResource(url: URL) -> OfflineMapResource? {
        guard let db = openSQLiteReadOnly(url) else {
            return nil
        }
        defer { sqlite3_close(db) }

        let metadata = sqliteMetadata(db)
        let layout = sqliteLayout(db) ?? (url.pathExtension.lowercased() == "mbtiles" ? "mbtiles" : "sqlite_v1")
        let format = metadata["format"]?.lowercased() ?? "png"
        let contentType = contentType(forFormat: format)
        let zoomRange = sqliteZoomRange(db: db, layout: layout)
        return OfflineMapResource(
            name: safeResourceName(metadata["name"] ?? url.deletingPathExtension().lastPathComponent),
            url: url,
            isDirectory: false,
            kind: kindForContentType(contentType, format: format, storageLayout: layout),
            storageLayout: layout,
            format: format,
            contentType: contentType,
            size: fileSize(url),
            tileCount: sqliteTileCount(db: db, layout: layout) ?? 0,
            bounds: parseBounds(metadata["bounds"]),
            minZoom: intFromString(metadata["minzoom"]) ?? zoomRange?.min ?? 0,
            maxZoom: intFromString(metadata["maxzoom"]) ?? zoomRange?.max ?? 14,
            sourceMaxZoom: intFromString(metadata["maxzoom"]) ?? zoomRange?.max ?? 14
        )
    }

    private func tile(resource: OfflineMapResource, z: Int, x: Int, y: Int) -> OfflineTileResult? {
        guard z >= 0, x >= 0, y >= 0 else { return nil }
        let cacheKey = "\(resource.url.path)|\(z)|\(x)|\(y)" as NSString
        if let cached = tileCache.object(forKey: cacheKey) {
            return cached.result
        }

        let data: Data?
        switch resource.storageLayout {
        case "sqlite_v1":
            data = readSQLiteV1Tile(resource: resource, z: z, x: x, y: y)
                ?? readFileLayoutTile(resource: resource, z: z, x: x, y: y)
        case "mbtiles":
            data = readMBTilesTile(resource: resource, z: z, x: x, y: y)
        case "files_legacy":
            data = readFileLayoutTile(resource: resource, z: z, x: x, y: y)
        default:
            data = nil
        }

        guard let data else {
            return nil
        }
        let result = OfflineTileResult(
            data: data,
            contentType: resource.contentType,
            headers: vectorTileHeaders(data: data, resource: resource)
        )
        tileCache.setObject(CachedOfflineTile(result: result), forKey: cacheKey)
        return result
    }

    private func readSQLiteV1Tile(resource: OfflineMapResource, z: Int, x: Int, y: Int) -> Data? {
        let sqliteURL = resource.isDirectory ? resource.url.appendingPathComponent("tiles.sqlite") : resource.url
        guard fileManager.fileExists(atPath: sqliteURL.path),
              let db = openSQLiteReadOnly(sqliteURL) else {
            return nil
        }
        defer { sqlite3_close(db) }
        return sqliteBlob(db: db, sql: "SELECT data FROM tiles WHERE z=? AND x=? AND y=?", arguments: [z, x, y])
    }

    private func readMBTilesTile(resource: OfflineMapResource, z: Int, x: Int, y: Int) -> Data? {
        guard let db = openSQLiteReadOnly(resource.url) else {
            return nil
        }
        defer { sqlite3_close(db) }
        let tmsY = (1 << z) - 1 - y
        return sqliteBlob(
            db: db,
            sql: "SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=?",
            arguments: [z, x, tmsY]
        )
    }

    private func readFileLayoutTile(resource: OfflineMapResource, z: Int, x: Int, y: Int) -> Data? {
        guard resource.isDirectory else { return nil }
        let extensions = candidateExtensions(format: resource.format)
        for ext in extensions {
            let modern = modernTileURL(resourceDir: resource.url, z: z, x: x, y: y, ext: ext)
            if let data = try? Data(contentsOf: modern) {
                return data
            }
            let legacy = legacyTileURL(resourceDir: resource.url, z: z, x: x, y: y, ext: ext)
            if let data = try? Data(contentsOf: legacy) {
                return data
            }
        }
        return nil
    }

    private func activeResourceName(resources: [OfflineMapResource]) -> String? {
        guard !resources.isEmpty else { return nil }
        guard let data = try? Data(contentsOf: activeFileURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return resources.first?.name
        }
        let active = safeResourceName((object["name"] as? String) ?? (object["active"] as? String) ?? "")
        guard !active.isEmpty,
              resources.contains(where: { $0.name == active }) else {
            return resources.first?.name
        }
        return active
    }

    private var activeFileURL: URL {
        rootDirectory.appendingPathComponent("active.json")
    }

    private func writeActiveResourceName(_ name: String) {
        let payload = ["name": safeResourceName(name)]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
            return
        }
        try? data.write(to: activeFileURL, options: [.atomic])
    }

    private func statusPayloadLocked(resources: [OfflineMapResource]) -> [String: Any] {
        let active = activeResourceName(resources: resources)
        return [
            "active": active as Any,
            "resources": resources.map { $0.payload(active: $0.name == active) },
            "providers": ["opentopomap", "esri_topo", "osm_standard", "openfreemap_vector"]
                .compactMap { downloadProviders[$0]?.payload() },
            "download_job": currentDownloadJobPayload() as Any,
            "max_download_tiles": maxDownloadTiles,
            "download_workers": downloadWorkers,
            "download_inflight_factor": downloadInflightFactor,
            "tile_timeout_seconds": Int(tileTimeoutSeconds),
            "tile_retries": tileRetries,
            "message": "已支持读取本地 PMTiles Range、MBTiles、SQLite 瓦片库和 Web map_offline 文件布局；下载标签可直接在 iOS 本地创建 SQLite 离线瓦片库。"
        ]
    }

    private func currentDownloadJobPayload() -> Any? {
        guard let job = downloadLock.withLock({ downloadJob }) else {
            return NSNull()
        }
        return job.snapshot()
    }

    private func failedDownloadJob(message: String, name: String) -> [String: Any] {
        [
            "name": safeResourceName(name),
            "running": false,
            "aborted": true,
            "downloaded": 0,
            "skipped": 0,
            "total": 0,
            "failed": 0,
            "bytes_downloaded": 0,
            "bytes_per_second": 0,
            "tiles_per_second": 0,
            "download_workers": downloadWorkers,
            "inflight_limit": downloadInflightLimit,
            "active_downloads": 0,
            "message": message,
            "finished_at": OfflineDownloadJobState.timestamp()
        ]
    }

    private func makeDownloadRequest(payload: [String: Any]) -> OfflineDownloadRequest? {
        let providerKey = stringValue(payload["provider"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let provider = downloadProviders[providerKey] else {
            return nil
        }

        let minZoom = clampInt(intValue(payload["min_zoom"]) ?? 0, min: 0, max: provider.maxZoom)
        let maxZoom = clampInt(intValue(payload["max_zoom"]) ?? min(14, provider.maxZoom), min: minZoom, max: provider.maxZoom)
        let sourceMaxZoom = clampInt(
            intValue(payload["source_max_zoom"]) ?? min(maxZoom, provider.recommendedSourceMaxZoom),
            min: minZoom,
            max: maxZoom
        )
        let baseMaxZoom = clampInt(
            intValue(payload["base_max_zoom"]) ?? min(sourceMaxZoom, 5),
            min: minZoom,
            max: sourceMaxZoom
        )
        let bounds = normalizedBounds(
            west: doubleValue(payload["west"]) ?? -180,
            south: doubleValue(payload["south"]) ?? -85,
            east: doubleValue(payload["east"]) ?? 180,
            north: doubleValue(payload["north"]) ?? 85
        )
        let baseBounds = normalizedBounds(
            west: doubleValue(payload["base_west"]) ?? -180,
            south: doubleValue(payload["base_south"]) ?? -85,
            east: doubleValue(payload["base_east"]) ?? 180,
            north: doubleValue(payload["base_north"]) ?? 85
        )
        let tiered = boolValue(payload["tiered"])
        let ranges = downloadTileRanges(
            baseBounds: baseBounds,
            detailBounds: bounds,
            minZoom: minZoom,
            maxZoom: sourceMaxZoom,
            baseMaxZoom: baseMaxZoom,
            tiered: tiered
        )
        let total = ranges.reduce(0) { $0 + $1.tileCount }
        let defaultName = "\(provider.key)_z\(minZoom)_\(maxZoom)_src\(sourceMaxZoom)"
        let name = safeResourceName(stringValue(payload["name"]) ?? defaultName)
        return OfflineDownloadRequest(
            provider: provider,
            name: name,
            bounds: bounds,
            baseBounds: baseBounds,
            tiered: tiered,
            baseMaxZoom: baseMaxZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
            sourceMaxZoom: sourceMaxZoom,
            ranges: ranges,
            total: total,
            estimatedBytes: total * provider.estimatedTileBytes
        )
    }

    private func initialDownloadJobPayload(request: OfflineDownloadRequest) -> [String: Any] {
        [
            "id": "job_\(Int(Date().timeIntervalSince1970))",
            "running": true,
            "name": request.name,
            "provider": request.provider.key,
            "provider_label": request.provider.label,
            "kind": request.provider.kind,
            "format": request.provider.format,
            "bounds": request.bounds,
            "base_bounds": request.baseBounds,
            "tiered": request.tiered,
            "base_max_zoom": request.baseMaxZoom,
            "min_zoom": request.minZoom,
            "max_zoom": request.maxZoom,
            "source_max_zoom": request.sourceMaxZoom,
            "total": request.total,
            "downloaded": 0,
            "skipped": 0,
            "failed": 0,
            "bytes_downloaded": 0,
            "estimated_tile_bytes": request.provider.estimatedTileBytes,
            "estimated_bytes": request.estimatedBytes,
            "download_workers": downloadWorkers,
            "inflight_limit": downloadInflightLimit,
            "active_downloads": 0,
            "tile_timeout_seconds": Int(tileTimeoutSeconds),
            "tile_retries": tileRetries,
            "bytes_per_second": 0,
            "tiles_per_second": 0,
            "message": "准备使用 \(downloadWorkers) 个线程下载离线地图资源，单瓦片超时 \(Int(tileTimeoutSeconds)) 秒。",
            "started_at": OfflineDownloadJobState.timestamp()
        ]
    }

    private func runDownload(request: OfflineDownloadRequest, job: OfflineDownloadJobState) {
        let resourceDirectory = rootDirectory.appendingPathComponent(request.name, isDirectory: true)
        let sqliteURL = resourceDirectory.appendingPathComponent("tiles.sqlite")
        var db: OpaquePointer?
        var session: URLSession?
        var fetchQueue: OperationQueue?
        var processedAtLastSample = 0
        var bytesAtLastSample = 0
        var sampleDate = Date()
        var pendingWrites = 0

        func finish(running: Bool = false, aborted: Bool = false, message: String? = nil) {
            fetchQueue?.cancelAllOperations()
            session?.invalidateAndCancel()
            if let db {
                sqlite3_exec(db, "COMMIT", nil, nil, nil)
                sqlite3_exec(db, "PRAGMA optimize", nil, nil, nil)
                sqlite3_close(db)
            }
            job.update { payload in
                payload["running"] = running
                payload["active_downloads"] = 0
                payload["aborted"] = aborted || (payload["aborted"] as? Bool == true)
                payload["finished_at"] = OfflineDownloadJobState.timestamp()
                if let message {
                    payload["message"] = message
                }
            }
            tileCache.removeAllObjects()
        }

        do {
            try fileManager.createDirectory(at: resourceDirectory, withIntermediateDirectories: true)
            db = try openSQLiteWritable(sqliteURL)
            guard let db else {
                finish(aborted: true, message: "无法创建离线地图 SQLite 瓦片库。")
                return
            }
            try createTileStoreIfNeeded(db)
            sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil)

            session = URLSession(configuration: tileSessionConfiguration(timeout: tileTimeoutSeconds, maxConnections: downloadWorkers))
            fetchQueue = OperationQueue()
            fetchQueue?.name = "com.navplanner.map-store.offline-tile"
            fetchQueue?.qualityOfService = .utility
            fetchQueue?.maxConcurrentOperationCount = max(1, downloadWorkers)

            var consecutiveFailures = 0
            let abortThreshold = min(50, max(12, downloadWorkers * 2, request.total / 100))
            let maxInflight = downloadInflightLimit
            let completed = OfflineTileOutcomeBuffer()
            var pendingCount = 0
            var shouldAbort = false
            var rangeIndex = 0
            var nextX: Int?
            var nextY: Int?
            var lastWaitNotice = Date()

            func nextCoordinate() -> OfflineTileCoordinate? {
                while rangeIndex < request.ranges.count {
                    let range = request.ranges[rangeIndex]
                    guard range.xStart <= range.xEnd, range.yStart <= range.yEnd else {
                        rangeIndex += 1
                        nextX = nil
                        nextY = nil
                        continue
                    }
                    let x = nextX ?? range.xStart
                    let y = nextY ?? range.yStart
                    let coordinate = OfflineTileCoordinate(z: range.zoom, x: x, y: y)
                    if y < range.yEnd {
                        nextX = x
                        nextY = y + 1
                    } else if x < range.xEnd {
                        nextX = x + 1
                        nextY = range.yStart
                    } else {
                        rangeIndex += 1
                        nextX = nil
                        nextY = nil
                    }
                    return coordinate
                }
                return nil
            }

            func commitIfNeeded(force: Bool = false) {
                guard pendingWrites > 0, force || pendingWrites >= 250 else { return }
                sqlite3_exec(db, "COMMIT", nil, nil, nil)
                sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil)
                pendingWrites = 0
            }

            func markAcceptedTile(coordinate: OfflineTileCoordinate, data: Data?, size: Int) throws {
                if let data {
                    try writeTileStoreTile(db, z: coordinate.z, x: coordinate.x, y: coordinate.y, data: data)
                    pendingWrites += 1
                }
                let byteCount = data?.count ?? size
                consecutiveFailures = 0
                job.update { payload in
                    payload["downloaded"] = (intValue(payload["downloaded"]) ?? 0) + 1
                    payload["skipped"] = (intValue(payload["skipped"]) ?? 0) + 1
                    payload["bytes_downloaded"] = (intValue(payload["bytes_downloaded"]) ?? 0) + byteCount
                }
                commitIfNeeded()
                updateDownloadSpeed(job: job, processedAtLastSample: &processedAtLastSample, bytesAtLastSample: &bytesAtLastSample, sampleDate: &sampleDate)
            }

            func queueRemoteTiles() throws -> Bool {
                while !job.isCancelled && !shouldAbort && pendingCount < maxInflight {
                    guard let coordinate = nextCoordinate() else {
                        return true
                    }
                    if let existingSize = tileStoreTileSize(db, z: coordinate.z, x: coordinate.x, y: coordinate.y), existingSize > 0 {
                        try markAcceptedTile(coordinate: coordinate, data: nil, size: existingSize)
                        continue
                    }
                    if let existingData = existingDownloadFileTile(resourceDirectory: resourceDirectory, provider: request.provider, coordinate: coordinate) {
                        try markAcceptedTile(coordinate: coordinate, data: existingData, size: existingData.count)
                        continue
                    }
                    guard let session, let fetchQueue else {
                        throw NSError(domain: "NavPlannerOfflineMap", code: -20, userInfo: [NSLocalizedDescriptionKey: "下载队列尚未初始化"])
                    }
                    pendingCount += 1
                    job.update { payload in
                        payload["active_downloads"] = pendingCount
                    }
                    fetchQueue.addOperation { [provider = request.provider, coordinate, session] in
                        let result: Result<Data, Error>
                        do {
                            let data = try self.fetchOfflineTile(provider: provider, coordinate: coordinate, session: session, timeout: self.tileTimeoutSeconds)
                            result = .success(data)
                        } catch {
                            result = .failure(error)
                        }
                        completed.append(OfflineTileFetchOutcome(coordinate: coordinate, result: result))
                    }
                }
                return false
            }

            var exhausted = try queueRemoteTiles()
            while pendingCount > 0 && !job.isCancelled && !shouldAbort {
                let outcomes = completed.drain(waitingUntil: Date(timeIntervalSinceNow: 0.25))

                guard !outcomes.isEmpty else {
                    let now = Date()
                    if now.timeIntervalSince(sampleDate) >= 3 {
                        job.update { payload in
                            payload["bytes_per_second"] = 0
                            payload["tiles_per_second"] = 0.0
                        }
                    }
                    if now.timeIntervalSince(lastWaitNotice) >= 3 {
                        job.update { payload in
                            payload["message"] = "等待 \(pendingCount) 个慢请求返回，单瓦片超时 \(Int(tileTimeoutSeconds)) 秒；如长期为 0 KB/s，可稍后重试或减少下载范围。"
                        }
                        lastWaitNotice = now
                    }
                    continue
                }

                for outcome in outcomes {
                    pendingCount = max(0, pendingCount - 1)
                    job.update { payload in
                        payload["active_downloads"] = pendingCount
                    }
                    switch outcome.result {
                    case let .success(data):
                        try writeTileStoreTile(db, z: outcome.coordinate.z, x: outcome.coordinate.x, y: outcome.coordinate.y, data: data)
                        pendingWrites += 1
                        consecutiveFailures = 0
                        job.update { payload in
                            payload["downloaded"] = (intValue(payload["downloaded"]) ?? 0) + 1
                            payload["bytes_downloaded"] = (intValue(payload["bytes_downloaded"]) ?? 0) + data.count
                        }
                        commitIfNeeded()
                    case let .failure(error):
                        consecutiveFailures += 1
                        job.update { payload in
                            payload["failed"] = (intValue(payload["failed"]) ?? 0) + 1
                            payload["message"] = "下载 \(outcome.coordinate.z)/\(outcome.coordinate.x)/\(outcome.coordinate.y) 失败：\(cleanTileError(error))"
                        }
                        if consecutiveFailures >= abortThreshold {
                            shouldAbort = true
                            job.update { payload in
                                payload["aborted"] = true
                                payload["message"] = "连续 \(consecutiveFailures) 个瓦片下载失败，已自动中止。建议换用 Esri World Topographic 或缩小范围后重试。"
                            }
                            break
                        }
                    }
                    updateDownloadSpeed(job: job, processedAtLastSample: &processedAtLastSample, bytesAtLastSample: &bytesAtLastSample, sampleDate: &sampleDate)
                }

                if !exhausted && !job.isCancelled && !shouldAbort {
                    exhausted = try queueRemoteTiles()
                }
            }

            if job.isCancelled {
                finish(aborted: true, message: "离线地图下载已取消。")
                return
            }
            if shouldAbort || (job.snapshot()["aborted"] as? Bool == true) {
                finish(aborted: true)
                return
            }

            commitIfNeeded(force: true)
            try writeDownloadMetadata(request: request, job: job, directory: resourceDirectory)
            writeActiveResourceName(request.name)
            finish(message: "离线地图下载完成。")
        } catch {
            finish(aborted: true, message: "离线地图下载失败：\(error.localizedDescription)")
        }
    }

    private func probeDownloadProvider(request: OfflineDownloadRequest) throws {
        guard let coordinate = firstCoordinate(in: request.ranges) else {
            throw NSError(domain: "NavPlannerOfflineMap", code: -21, userInfo: [NSLocalizedDescriptionKey: "下载范围内没有可探测的瓦片"])
        }
        let session = URLSession(configuration: tileSessionConfiguration(timeout: 8, maxConnections: 1))
        defer { session.invalidateAndCancel() }
        _ = try fetchOfflineTile(provider: request.provider, coordinate: coordinate, session: session, timeout: 8)
    }

    private func firstCoordinate(in ranges: [OfflineTileRange]) -> OfflineTileCoordinate? {
        for range in ranges where range.xStart <= range.xEnd && range.yStart <= range.yEnd {
            return OfflineTileCoordinate(z: range.zoom, x: range.xStart, y: range.yStart)
        }
        return nil
    }

    private func tileSessionConfiguration(timeout: TimeInterval, maxConnections: Int) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.httpMaximumConnectionsPerHost = max(1, maxConnections)
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return configuration
    }

    private func existingDownloadFileTile(
        resourceDirectory: URL,
        provider: OfflineDownloadProvider,
        coordinate: OfflineTileCoordinate
    ) -> Data? {
        for ext in candidateExtensions(format: provider.format) {
            let modern = modernTileURL(resourceDir: resourceDirectory, z: coordinate.z, x: coordinate.x, y: coordinate.y, ext: ext)
            if let data = try? Data(contentsOf: modern), isValidDownloadedTile(data, provider: provider) {
                return data
            }
            let legacy = legacyTileURL(resourceDir: resourceDirectory, z: coordinate.z, x: coordinate.x, y: coordinate.y, ext: ext)
            if let data = try? Data(contentsOf: legacy), isValidDownloadedTile(data, provider: provider) {
                return data
            }
        }
        return nil
    }

    private func cleanTileError(_ error: Error) -> String {
        let text = error.localizedDescription
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .joined(separator: " ")
        return String((text.isEmpty ? String(describing: type(of: error)) : text).prefix(220))
    }

    private func formatBytesPerSecond(_ bytesPerSecond: Int) -> String {
        let value = max(0, bytesPerSecond)
        if value >= 1024 * 1024 {
            return String(format: "%.1f MB/s", Double(value) / Double(1024 * 1024))
        }
        return "\(value / 1024) KB/s"
    }

    private func updateDownloadSpeed(
        job: OfflineDownloadJobState,
        processedAtLastSample: inout Int,
        bytesAtLastSample: inout Int,
        sampleDate: inout Date
    ) {
        let now = Date()
        let elapsed = now.timeIntervalSince(sampleDate)
        guard elapsed >= 1 else { return }
        let snapshot = job.snapshot()
        let downloaded = intValue(snapshot["downloaded"]) ?? 0
        let failed = intValue(snapshot["failed"]) ?? 0
        let processed = downloaded + failed
        let bytes = intValue(snapshot["bytes_downloaded"]) ?? 0
        let bytesPerSecond = max(0, Int(Double(bytes - bytesAtLastSample) / elapsed))
        let tilesPerSecond = max(0, Double(processed - processedAtLastSample) / elapsed)
        job.update { payload in
            payload["bytes_per_second"] = bytesPerSecond
            payload["tiles_per_second"] = (tilesPerSecond * 100).rounded() / 100
            let active = intValue(payload["active_downloads"]) ?? 0
            let inflight = intValue(payload["inflight_limit"]) ?? downloadInflightLimit
            payload["message"] = "已处理 \(processed) / \(intValue(payload["total"]) ?? 0) 个瓦片，在途 \(active) / \(inflight)，速度 \(formatBytesPerSecond(bytesPerSecond))。"
        }
        processedAtLastSample = processed
        bytesAtLastSample = bytes
        sampleDate = now
    }

    private func fetchOfflineTile(
        provider: OfflineDownloadProvider,
        coordinate: OfflineTileCoordinate,
        session: URLSession,
        timeout: TimeInterval
    ) throws -> Data {
        let urls = provider.requestURLs(z: coordinate.z, x: coordinate.x, y: coordinate.y)
        guard !urls.isEmpty else {
            throw NSError(domain: "NavPlannerOfflineMap", code: -2, userInfo: [NSLocalizedDescriptionKey: "供应商没有可用瓦片 URL"])
        }

        var lastError: Error?
        for attempt in 0...tileRetries {
            for url in urls {
                do {
                    return try fetchSingleOfflineTile(url: url, provider: provider, session: session, timeout: timeout)
                } catch let error as OfflineTileHTTPError where error.statusCode == 404 {
                    lastError = error
                    break
                } catch {
                    lastError = error
                }
            }
            guard attempt < tileRetries else { break }
            Thread.sleep(forTimeInterval: min(1.5, 0.25 * pow(2.0, Double(attempt))))
        }
        throw lastError ?? NSError(domain: "NavPlannerOfflineMap", code: -5, userInfo: [NSLocalizedDescriptionKey: "瓦片请求失败"])
    }

    private func fetchSingleOfflineTile(
        url: URL,
        provider: OfflineDownloadProvider,
        session: URLSession,
        timeout: TimeInterval
    ) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = OfflineTileRequestResultBox()
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 NavPlanner/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("image/png,image/jpeg,application/x-protobuf,application/octet-stream,*/*;q=0.5", forHTTPHeaderField: "Accept")
        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                resultBox.store(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                resultBox.store(.failure(NSError(domain: "NavPlannerOfflineMap", code: -3, userInfo: [NSLocalizedDescriptionKey: "瓦片响应无效"])))
                return
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                resultBox.store(.failure(OfflineTileHTTPError(statusCode: httpResponse.statusCode)))
                return
            }
            guard let data,
                  !data.isEmpty,
                  self.isValidDownloadedTile(data, provider: provider) else {
                resultBox.store(.failure(NSError(domain: "NavPlannerOfflineMap", code: -3, userInfo: [NSLocalizedDescriptionKey: "瓦片响应无效"])))
                return
            }
            resultBox.store(.success(data))
        }
        task.resume()

        if semaphore.wait(timeout: .now() + timeout + 3) == .timedOut {
            task.cancel()
            throw NSError(domain: "NavPlannerOfflineMap", code: -4, userInfo: [NSLocalizedDescriptionKey: "瓦片请求超时"])
        }
        switch resultBox.snapshot() {
        case let .success(data):
            return data
        case let .failure(error):
            throw error
        case .none:
            throw NSError(domain: "NavPlannerOfflineMap", code: -4, userInfo: [NSLocalizedDescriptionKey: "瓦片请求超时"])
        }
    }

    private func isValidDownloadedTile(_ data: Data, provider: OfflineDownloadProvider) -> Bool {
        guard !data.isEmpty else { return false }
        switch provider.format {
        case "jpg", "jpeg":
            return isJPEG(data) || isPNG(data)
        case "png":
            return isPNG(data)
        default:
            return true
        }
    }

    private func isJPEG(_ data: Data) -> Bool {
        data.count >= 2 && data[data.startIndex] == 0xff && data[data.index(after: data.startIndex)] == 0xd8
    }

    private func isPNG(_ data: Data) -> Bool {
        let signature: [UInt8] = [0x89, 0x50, 0x4e, 0x47]
        return data.starts(with: signature)
    }

    private func openSQLiteWritable(_ url: URL) throws -> OpaquePointer {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            if let db {
                sqlite3_close(db)
            }
            throw NSError(domain: "NavPlannerOfflineMap", code: -10, userInfo: [NSLocalizedDescriptionKey: "SQLite 打开失败"])
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA temp_store=MEMORY", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA busy_timeout=3000", nil, nil, nil)
        return db
    }

    private func createTileStoreIfNeeded(_ db: OpaquePointer) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS tiles (
            z INTEGER NOT NULL,
            x INTEGER NOT NULL,
            y INTEGER NOT NULL,
            data BLOB NOT NULL,
            PRIMARY KEY (z, x, y)
        );
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "NavPlannerOfflineMap", code: -11, userInfo: [NSLocalizedDescriptionKey: "SQLite 瓦片表创建失败"])
        }
    }

    private func tileStoreTileSize(_ db: OpaquePointer, z: Int, x: Int, y: Int) -> Int? {
        sqliteIntRow(db: db, sql: "SELECT length(data) FROM tiles WHERE z=? AND x=? AND y=?", arguments: [z, x, y]).first
    }

    private func writeTileStoreTile(_ db: OpaquePointer, z: Int, x: Int, y: Int, data: Data) throws {
        var statement: OpaquePointer?
        let sql = "INSERT OR REPLACE INTO tiles (z, x, y, data) VALUES (?, ?, ?, ?)"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw NSError(domain: "NavPlannerOfflineMap", code: -12, userInfo: [NSLocalizedDescriptionKey: "SQLite 写入语句创建失败"])
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, sqlite3_int64(z))
        sqlite3_bind_int64(statement, 2, sqlite3_int64(x))
        sqlite3_bind_int64(statement, 3, sqlite3_int64(y))
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        try data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw NSError(domain: "NavPlannerOfflineMap", code: -13, userInfo: [NSLocalizedDescriptionKey: "瓦片数据为空"])
            }
            sqlite3_bind_blob(statement, 4, baseAddress, Int32(data.count), transient)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw NSError(domain: "NavPlannerOfflineMap", code: -14, userInfo: [NSLocalizedDescriptionKey: "SQLite 瓦片写入失败"])
            }
        }
    }

    private func writeDownloadMetadata(request: OfflineDownloadRequest, job: OfflineDownloadJobState, directory: URL) throws {
        let snapshot = job.snapshot()
        let downloaded = intValue(snapshot["downloaded"]) ?? 0
        let bytes = intValue(snapshot["bytes_downloaded"]) ?? 0
        let metadata: [String: Any] = [
            "name": request.name,
            "provider": request.provider.key,
            "provider_label": request.provider.label,
            "kind": request.provider.kind,
            "format": request.provider.format,
            "content_type": request.provider.contentType,
            "bounds": request.bounds,
            "base_bounds": request.baseBounds,
            "tiered": request.tiered,
            "base_max_zoom": request.baseMaxZoom,
            "min_zoom": request.minZoom,
            "max_zoom": request.maxZoom,
            "source_max_zoom": request.sourceMaxZoom,
            "tile_count": request.total,
            "failed": intValue(snapshot["failed"]) ?? 0,
            "storage_layout": "sqlite_v1",
            "estimated_tile_bytes": request.provider.estimatedTileBytes,
            "estimated_bytes": request.estimatedBytes,
            "download_workers": downloadWorkers,
            "inflight_limit": downloadInflightLimit,
            "tile_timeout_seconds": Int(tileTimeoutSeconds),
            "tile_retries": tileRetries,
            "downloaded_bytes": bytes,
            "average_tile_bytes": bytes / max(1, downloaded),
            "created_at": snapshot["started_at"] ?? OfflineDownloadJobState.timestamp(),
            "updated_at": OfflineDownloadJobState.timestamp()
        ]
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("metadata.json"), options: [.atomic])
    }

    private func normalizedBounds(west: Double, south: Double, east: Double, north: Double) -> [String: Double] {
        var normalizedSouth = clampDouble(south, min: -85.05112878, max: 85.05112878)
        var normalizedNorth = clampDouble(north, min: -85.05112878, max: 85.05112878)
        if normalizedSouth > normalizedNorth {
            swap(&normalizedSouth, &normalizedNorth)
        }
        return [
            "west": clampDouble(west, min: -180, max: 180),
            "south": normalizedSouth,
            "east": clampDouble(east, min: -180, max: 180),
            "north": normalizedNorth
        ]
    }

    private func downloadTileRanges(
        baseBounds: [String: Double],
        detailBounds: [String: Double],
        minZoom: Int,
        maxZoom: Int,
        baseMaxZoom: Int,
        tiered: Bool
    ) -> [OfflineTileRange] {
        if !tiered {
            return tileRanges(bounds: detailBounds, minZoom: minZoom, maxZoom: maxZoom)
        }
        let baseZoomEnd = min(maxZoom, max(minZoom, baseMaxZoom))
        var ranges = tileRanges(bounds: baseBounds, minZoom: minZoom, maxZoom: baseZoomEnd)
        if baseZoomEnd < maxZoom {
            ranges.append(contentsOf: tileRanges(bounds: detailBounds, minZoom: baseZoomEnd + 1, maxZoom: maxZoom))
        }
        return mergeTileRanges(ranges)
    }

    private func tileRanges(bounds: [String: Double], minZoom: Int, maxZoom: Int) -> [OfflineTileRange] {
        let west = bounds["west"] ?? -180
        let east = bounds["east"] ?? 180
        let south = bounds["south"] ?? -85
        let north = bounds["north"] ?? 85
        var ranges: [OfflineTileRange] = []
        for zoom in minZoom...maxZoom {
            let maxIndex = (1 << zoom) - 1
            let xRanges: [(Int, Int)]
            if west > east {
                xRanges = [
                    (lonToTileX(west, zoom: zoom), maxIndex),
                    (0, lonToTileX(east, zoom: zoom))
                ]
            } else {
                let x1 = lonToTileX(west, zoom: zoom)
                let x2 = lonToTileX(east, zoom: zoom)
                xRanges = [(min(x1, x2), max(x1, x2))]
            }
            let y1 = latToTileY(north, zoom: zoom)
            let y2 = latToTileY(south, zoom: zoom)
            for (xStart, xEnd) in xRanges {
                ranges.append(OfflineTileRange(
                    zoom: zoom,
                    xStart: xStart,
                    xEnd: xEnd,
                    yStart: min(y1, y2),
                    yEnd: max(y1, y2)
                ))
            }
        }
        return ranges
    }

    private func mergeTileRanges(_ ranges: [OfflineTileRange]) -> [OfflineTileRange] {
        let grouped = Dictionary(grouping: ranges) { "\($0.zoom)|\($0.yStart)|\($0.yEnd)" }
        return grouped.values.flatMap { group -> [OfflineTileRange] in
            let sorted = group.sorted { lhs, rhs in
                lhs.xStart == rhs.xStart ? lhs.xEnd < rhs.xEnd : lhs.xStart < rhs.xStart
            }
            var merged: [OfflineTileRange] = []
            for range in sorted {
                guard let last = merged.last else {
                    merged.append(range)
                    continue
                }
                if range.xStart <= last.xEnd {
                    merged[merged.count - 1] = OfflineTileRange(
                        zoom: last.zoom,
                        xStart: last.xStart,
                        xEnd: max(last.xEnd, range.xEnd),
                        yStart: last.yStart,
                        yEnd: last.yEnd
                    )
                } else {
                    merged.append(range)
                }
            }
            return merged
        }
        .sorted {
            if $0.zoom != $1.zoom { return $0.zoom < $1.zoom }
            if $0.xStart != $1.xStart { return $0.xStart < $1.xStart }
            return $0.yStart < $1.yStart
        }
    }

    private func lonToTileX(_ lon: Double, zoom: Int) -> Int {
        let n = Double(1 << zoom)
        let value = Int(((lon + 180.0) / 360.0) * n)
        return clampInt(value, min: 0, max: Int(n) - 1)
    }

    private func latToTileY(_ lat: Double, zoom: Int) -> Int {
        let clamped = clampDouble(lat, min: -85.05112878, max: 85.05112878)
        let latRad = clamped * .pi / 180
        let n = Double(1 << zoom)
        let value = Int((1.0 - asinh(tan(latRad)) / .pi) / 2.0 * n)
        return clampInt(value, min: 0, max: Int(n) - 1)
    }

    private func clampInt(_ value: Int, min minValue: Int, max maxValue: Int) -> Int {
        Swift.max(minValue, Swift.min(maxValue, value))
    }

    private func clampDouble(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.max(minValue, Swift.min(maxValue, value))
    }

    private func pmtilesURL(for resource: OfflineMapResource) -> URL? {
        let url = resource.isDirectory
            ? resource.url.appendingPathComponent("resource.pmtiles")
            : resource.url
        guard url.pathExtension.lowercased() == "pmtiles",
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private enum FileRange {
        case full
        case partial(start: Int64, end: Int64)
        case unsatisfiable
    }

    private func fileRangeResponse(url: URL, contentType: String, rangeHeader: String?) -> OfflineFileRangeResult? {
        let size = fileSize(url)
        let range = parseRange(rangeHeader, fileSize: size)
        if case .unsatisfiable = range {
            return OfflineFileRangeResult(
                statusCode: 416,
                data: Data(),
                contentType: contentType,
                headers: [
                    "Accept-Ranges": "bytes",
                    "Content-Length": "0",
                    "Content-Range": "bytes */\(max(0, size))",
                    "Cache-Control": "public, max-age=31536000, immutable"
                ]
            )
        }

        let start: Int64
        let end: Int64
        let statusCode: Int
        switch range {
        case .full:
            start = 0
            end = max(0, size - 1)
            statusCode = 200
        case let .partial(rangeStart, rangeEnd):
            start = rangeStart
            end = rangeEnd
            statusCode = 206
        case .unsatisfiable:
            return nil
        }

        guard size >= 0, start >= 0, end >= start else {
            return OfflineFileRangeResult(
                statusCode: statusCode,
                data: Data(),
                contentType: contentType,
                headers: [
                    "Accept-Ranges": "bytes",
                    "Content-Length": "0",
                    "Cache-Control": "public, max-age=31536000, immutable"
                ]
            )
        }

        let length = end - start + 1
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: UInt64(start))
        } catch {
            return nil
        }
        let data = handle.readData(ofLength: Int(length))
        var headers = [
            "Accept-Ranges": "bytes",
            "Content-Length": "\(data.count)",
            "Cache-Control": "public, max-age=31536000, immutable"
        ]
        if statusCode == 206 {
            headers["Content-Range"] = "bytes \(start)-\(end)/\(size)"
        }
        return OfflineFileRangeResult(statusCode: statusCode, data: data, contentType: contentType, headers: headers)
    }

    private func parseRange(_ rangeHeader: String?, fileSize size: Int64) -> FileRange {
        guard let rangeHeader,
              !rangeHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .full
        }
        let header = rangeHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        guard header.lowercased().hasPrefix("bytes=") else {
            return .full
        }
        guard size > 0 else {
            return .unsatisfiable
        }

        let rangeText = String(header.dropFirst(6)).split(separator: ",", maxSplits: 1).first.map(String.init) ?? ""
        let parts = rangeText.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else {
            return .unsatisfiable
        }
        let rawStart = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let rawEnd = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        let start: Int64
        let end: Int64
        if rawStart.isEmpty {
            guard let suffix = Int64(rawEnd), suffix > 0 else {
                return .unsatisfiable
            }
            start = max(0, size - suffix)
            end = size - 1
        } else {
            guard let parsedStart = Int64(rawStart), parsedStart >= 0 else {
                return .unsatisfiable
            }
            start = parsedStart
            if rawEnd.isEmpty {
                end = size - 1
            } else {
                guard let parsedEnd = Int64(rawEnd), parsedEnd >= 0 else {
                    return .unsatisfiable
                }
                end = min(size - 1, parsedEnd)
            }
        }

        guard start < size, start <= end else {
            return .unsatisfiable
        }
        return .partial(start: start, end: end)
    }

    private func loadMetadata(directory: URL) -> [String: Any]? {
        let url = directory.appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private func openSQLiteReadOnly(_ url: URL) -> OpaquePointer? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            if let db {
                sqlite3_close(db)
            }
            return nil
        }
        sqlite3_exec(db, "PRAGMA query_only=ON", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA temp_store=MEMORY", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size=-32768", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA busy_timeout=1000", nil, nil, nil)
        return db
    }

    private func validateImportedMap(at url: URL, pathExtension: String) throws {
        if pathExtension == "pmtiles" {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let header = try handle.read(upToCount: 8) ?? Data()
            guard header.count == 8,
                  header.starts(with: Data("PMTiles".utf8)),
                  header[header.index(header.startIndex, offsetBy: 7)] > 0 else {
                throw OfflineMapImportError(message: "PMTiles 文件头无效。")
            }
            return
        }

        guard let db = openSQLiteReadOnly(url) else {
            throw OfflineMapImportError(message: "SQLite 地图包无法打开。")
        }
        defer { sqlite3_close(db) }
        guard sqliteQuickCheck(db), sqliteLayout(db) != nil else {
            throw OfflineMapImportError(
                message: "SQLite 地图包校验失败，必须包含 MBTiles 或 SimNav tiles 表结构。"
            )
        }
    }

    private func sqliteQuickCheck(_ db: OpaquePointer) -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA quick_check(1)", -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return false
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0) else {
            return false
        }
        return String(cString: text).lowercased() == "ok"
    }

    private func sqliteLayout(_ db: OpaquePointer) -> String? {
        let columns = Set(sqliteColumnNames(db: db, table: "tiles"))
        if columns.isSuperset(of: ["z", "x", "y", "data"]) {
            return "sqlite_v1"
        }
        if columns.isSuperset(of: ["zoom_level", "tile_column", "tile_row", "tile_data"]) {
            return "mbtiles"
        }
        return nil
    }

    private func sqliteColumnNames(db: OpaquePointer, table: String) -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &statement, nil) == SQLITE_OK, let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        var columns: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 1) {
                columns.append(String(cString: text))
            }
        }
        return columns
    }

    private func sqliteMetadata(_ db: OpaquePointer) -> [String: String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT name, value FROM metadata", -1, &statement, nil) == SQLITE_OK, let statement else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        var metadata: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let nameText = sqlite3_column_text(statement, 0),
                  let valueText = sqlite3_column_text(statement, 1) else {
                continue
            }
            metadata[String(cString: nameText).lowercased()] = String(cString: valueText)
        }
        return metadata
    }

    private func sqliteTileCount(url: URL, layout: String) -> Int? {
        guard let db = openSQLiteReadOnly(url) else { return nil }
        defer { sqlite3_close(db) }
        return sqliteTileCount(db: db, layout: layout)
    }

    private func sqliteTileCount(db: OpaquePointer, layout: String) -> Int? {
        let sql = layout == "mbtiles" ? "SELECT COUNT(1) FROM tiles" : "SELECT COUNT(1) FROM tiles"
        return sqliteIntRow(db: db, sql: sql, arguments: []).first
    }

    private func sqliteZoomRange(url: URL, layout: String) -> (min: Int, max: Int)? {
        guard let db = openSQLiteReadOnly(url) else { return nil }
        defer { sqlite3_close(db) }
        return sqliteZoomRange(db: db, layout: layout)
    }

    private func sqliteZoomRange(db: OpaquePointer, layout: String) -> (min: Int, max: Int)? {
        let column = layout == "mbtiles" ? "zoom_level" : "z"
        let values = sqliteIntRow(db: db, sql: "SELECT MIN(\(column)), MAX(\(column)) FROM tiles", arguments: [])
        guard values.count == 2 else { return nil }
        return (values[0], values[1])
    }

    private func sqliteIntRow(db: OpaquePointer, sql: String, arguments: [Int]) -> [Int] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in arguments.enumerated() {
            sqlite3_bind_int64(statement, Int32(index + 1), sqlite3_int64(value))
        }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return []
        }
        return (0..<sqlite3_column_count(statement)).map { index in
            Int(sqlite3_column_int64(statement, index))
        }
    }

    private func sqliteBlob(db: OpaquePointer, sql: String, arguments: [Int]) -> Data? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in arguments.enumerated() {
            sqlite3_bind_int64(statement, Int32(index + 1), sqlite3_int64(value))
        }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let bytes = sqlite3_column_blob(statement, 0) else {
            return nil
        }
        let count = Int(sqlite3_column_bytes(statement, 0))
        return Data(bytes: bytes, count: count)
    }

    private func modernTileURL(resourceDir: URL, z: Int, x: Int, y: Int, ext: String) -> URL {
        resourceDir
            .appendingPathComponent("tiles", isDirectory: true)
            .appendingPathComponent(String(format: "z%02d", z), isDirectory: true)
            .appendingPathComponent(String(format: "%04x", x >> 8), isDirectory: true)
            .appendingPathComponent("\(String(format: "%08x", x))_\(String(format: "%08x", y)).\(ext)")
    }

    private func legacyTileURL(resourceDir: URL, z: Int, x: Int, y: Int, ext: String) -> URL {
        resourceDir
            .appendingPathComponent("tiles", isDirectory: true)
            .appendingPathComponent(String(z), isDirectory: true)
            .appendingPathComponent(String(x), isDirectory: true)
            .appendingPathComponent("\(y).\(ext)")
    }

    private func vectorTileHeaders(data: Data, resource: OfflineMapResource) -> [String: String] {
        guard resource.kind == "vector",
              data.count >= 2,
              data[data.startIndex] == 0x1f,
              data[data.index(after: data.startIndex)] == 0x8b else {
            return [:]
        }
        return ["Content-Encoding": "gzip"]
    }

    private func parseBounds(_ text: String?) -> [String: Any]? {
        guard let text else { return nil }
        let parts = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard parts.count == 4 else { return nil }
        return [
            "west": parts[0],
            "south": parts[1],
            "east": parts[2],
            "north": parts[3]
        ]
    }

    private func candidateExtensions(format: String) -> [String] {
        var values = [format.lowercased()]
        if values[0] == "jpeg" {
            values.append("jpg")
        }
        if values[0] == "jpg" {
            values.append("jpeg")
        }
        for fallback in ["png", "jpg", "jpeg", "pbf", "mvt"] where !values.contains(fallback) {
            values.append(fallback)
        }
        return values
    }

    private func contentType(forFormat format: String) -> String {
        switch format.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "pbf", "mvt":
            return "application/vnd.mapbox-vector-tile"
        case "webp":
            return "image/webp"
        default:
            return "image/png"
        }
    }

    private func kindForContentType(_ contentType: String, format: String, storageLayout: String) -> String {
        let normalized = "\(contentType) \(format) \(storageLayout)".lowercased()
        return normalized.contains("vector") || normalized.contains("pbf") || normalized.contains("mvt") || normalized.contains("pmtiles")
            ? "vector"
            : "raster"
    }

    private func fileSize(_ url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    private func safeResourceName(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).map { character -> Character in
            if character.isLetter || character.isNumber || character == "-" || character == "_" || character == "." {
                return character
            }
            return "_"
        }
        let text = String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
        return text.isEmpty ? "offline_resource" : String(text.prefix(80))
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let integer = value as? Int {
            return integer
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let integer = value as? Int {
            return Double(integer)
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            return ["1", "true", "yes"].contains(string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
        return false
    }

    private func intFromString(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
