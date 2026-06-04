import Foundation
import WebKit

final class NavPlannerSchemeHandler: NSObject, WKURLSchemeHandler {
    private struct SchemeResponse {
        let statusCode: Int
        let mimeType: String
        let data: Data
        let headers: [String: String]
    }

    private let plannerService: PlannerService
    private let mapStore: MapStore
    private let onlineTileCache = OnlineTileCache()
    private let workQueue = DispatchQueue(label: "com.navplanner.web-bridge", qos: .userInitiated)
    private let lock = NSLock()
    private var stoppedTasks = Set<ObjectIdentifier>()
    private static let transparentTile = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=") ?? Data()

    init(plannerService: PlannerService, mapStore: MapStore) {
        self.plannerService = plannerService
        self.mapStore = mapStore
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        _ = lock.withLock {
            stoppedTasks.remove(taskID)
        }

        guard let url = urlSchemeTask.request.url else {
            deliver(response: jsonResponse(["error": "Invalid URL"], statusCode: 400), to: urlSchemeTask)
            return
        }

        workQueue.async { [weak self] in
            guard let self else { return }
            let response = self.response(for: url, request: urlSchemeTask.request)
            self.deliver(response: response, to: urlSchemeTask)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        _ = lock.withLock {
            stoppedTasks.insert(taskID)
        }
    }

    private func response(for url: URL, request: URLRequest) -> SchemeResponse {
        switch url.host {
        case "app":
            if url.path == "/api" || url.path.hasPrefix("/api/") {
                return apiResponse(for: url, request: request)
            }
            return appResourceResponse(for: url)
        case "api":
            return apiResponse(for: url, request: request)
        case "tiles":
            return tileResponse(for: url)
        default:
            return jsonResponse(["error": "Unknown navplanner host"], statusCode: 404)
        }
    }

    private func appResourceResponse(for url: URL) -> SchemeResponse {
        guard let resource = webResourceURL(for: url.path),
              let data = try? Data(contentsOf: resource) else {
            return jsonResponse(["error": "Web resource not found"], statusCode: 404)
        }
        return SchemeResponse(
            statusCode: 200,
            mimeType: mimeType(forExtension: resource.pathExtension),
            data: data,
            headers: cacheHeaders
        )
    }

    private func apiResponse(for url: URL, request: URLRequest) -> SchemeResponse {
        let path = normalizedAPIPath(url.path)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let queryValue: (String, String) -> String = { name, fallback in
            query.first(where: { $0.name == name })?.value ?? fallback
        }

        let pathComponents = path.split(separator: "/").map(String.init)
        if path == "/map-cache/status" {
            return jsonResponse(onlineTileCache.statusPayload())
        }
        if path == "/map-cache/clear", request.httpMethod == "POST" {
            return jsonResponse(onlineTileCache.clearPayload())
        }
        if pathComponents.first == "map-cache" || pathComponents.first == "terrain" {
            return onlineTileResponse(pathComponents: pathComponents)
        }
        if pathComponents.first == "offline-maps" {
            return offlineMapsResponse(for: url, request: request, path: path, pathComponents: pathComponents)
        }
        if path == "/header" {
            return jsonResponse(plannerService.headerPayload())
        }
        if path == "/search" {
            return jsonResponse(plannerService.searchPayload(query: queryValue("q", "")))
        }
        if pathComponents.first == "airport", pathComponents.count == 2 {
            let ident = pathComponents[1].removingPercentEncoding ?? pathComponents[1]
            guard let payload = plannerService.airportPayload(ident: ident) else {
                return jsonResponse(["error": "Airport not found"], statusCode: 404)
            }
            return jsonResponse(payload)
        }
        if pathComponents.first == "procedure", pathComponents.count >= 5 {
            let type = pathComponents[1]
            let airport = pathComponents[2].removingPercentEncoding ?? pathComponents[2]
            let procedure = pathComponents[3].removingPercentEncoding ?? pathComponents[3]
            let transition = pathComponents[4].removingPercentEncoding ?? pathComponents[4]
            return jsonResponse(plannerService.procedurePayload(type: type, airport: airport, procedure: procedure, transition: transition))
        }
        if pathComponents.first == "airway", pathComponents.count == 2 {
            let airway = pathComponents[1].removingPercentEncoding ?? pathComponents[1]
            return jsonResponse(plannerService.airwayPayload(airway: airway))
        }
        if path == "/nav-overlay" {
            return jsonResponse(plannerService.navOverlayPayload(
                south: Double(queryValue("south", "0")) ?? 0,
                west: Double(queryValue("west", "0")) ?? 0,
                north: Double(queryValue("north", "0")) ?? 0,
                east: Double(queryValue("east", "0")) ?? 0,
                zoom: Int(Double(queryValue("zoom", "4")) ?? 4)
            ))
        }
        if path == "/route/resolve" {
            let payload = plannerService.routeResolvePayload(
                departure: queryValue("departure", ""),
                arrival: queryValue("arrival", ""),
                route: queryValue("route", ""),
                departureRunway: queryValue("departure_runway", "ALL"),
                arrivalRunway: queryValue("arrival_runway", "ALL")
            )
            return jsonResponse(payload, statusCode: payload["error"] == nil ? 200 : 400)
        }
        if path == "/route/fr24-match" {
            return jsonResponse(plannerService.fr24UnavailablePayload(), statusCode: 503)
        }
        if path == "/route/track-match" {
            guard request.httpMethod == "POST" else {
                return jsonResponse(["error": "Track match requires POST."], statusCode: 405)
            }
            let body = jsonBody(from: request)
            let rawTrackPoints = body["track_points"] as? [Any] ?? []
            let trackPoints = rawTrackPoints.compactMap { $0 as? [String: Any] }
            let payload = plannerService.trackMatchPayload(
                departure: body["departure"] as? String ?? "",
                arrival: body["arrival"] as? String ?? "",
                trackPoints: trackPoints
            )
            return jsonResponse(payload, statusCode: payload["error"] == nil ? 200 : 400)
        }
        return jsonResponse(["error": "API not found"], statusCode: 404)
    }

    private func onlineTileResponse(pathComponents: [String]) -> SchemeResponse {
        let providerKey: String
        let zText: String
        let xText: String
        let yPath: String

        if pathComponents.first == "map-cache", pathComponents.count >= 5 {
            providerKey = pathComponents[1]
            zText = pathComponents[2]
            xText = pathComponents[3]
            yPath = pathComponents[4]
        } else if pathComponents.first == "terrain", pathComponents.count >= 5 {
            providerKey = pathComponents[1] == "terrarium" ? "terrain_terrarium" : pathComponents[1]
            zText = pathComponents[2]
            xText = pathComponents[3]
            yPath = pathComponents[4]
        } else {
            return jsonResponse(["error": "Invalid map tile path"], statusCode: 404)
        }

        let yText = (yPath as NSString).deletingPathExtension
        guard let z = Int(zText), let x = Int(xText), let y = Int(yText) else {
            return jsonResponse(["error": "Invalid map tile coordinate"], statusCode: 404)
        }

        switch onlineTileCache.tile(providerKey: providerKey, z: z, x: x, y: y) {
        case let .hit(data, contentType):
            return SchemeResponse(
                statusCode: 200,
                mimeType: contentType,
                data: data,
                headers: cacheHeaders.merging([
                    "Cache-Control": "public, max-age=31536000, immutable",
                    "X-Map-Cache": "HIT"
                ]) { _, new in new }
            )
        case .queued:
            return placeholderTileResponse(cacheState: "QUEUED")
        case .pending:
            return placeholderTileResponse(cacheState: "PENDING")
        case .failed:
            return placeholderTileResponse(cacheState: "MISS")
        }
    }

    private func offlineMapsResponse(
        for url: URL,
        request: URLRequest,
        path: String,
        pathComponents: [String]
    ) -> SchemeResponse {
        if path == "/offline-maps" {
            return jsonResponse(mapStore.statusPayload())
        }
        if path == "/offline-maps/select", request.httpMethod == "POST" {
            let body = jsonBody(from: request)
            return jsonResponse(mapStore.selectResource(name: body["name"] as? String ?? ""))
        }
        if path == "/offline-maps/delete", request.httpMethod == "POST" {
            let body = jsonBody(from: request)
            return jsonResponse(mapStore.deleteResource(name: body["name"] as? String ?? ""))
        }
        if path == "/offline-maps/compact", request.httpMethod == "POST" {
            let body = jsonBody(from: request)
            return jsonResponse(mapStore.compactResource(name: body["name"] as? String ?? ""))
        }
        if path == "/offline-maps/download", request.httpMethod == "POST" {
            let body = jsonBody(from: request)
            return jsonResponse(["download_job": mapStore.startDownload(payload: body)])
        }
        if path == "/offline-maps/cancel", request.httpMethod == "POST" {
            return jsonResponse(["download_job": mapStore.cancelDownload()])
        }
        if pathComponents.count >= 4, pathComponents[1] == "tile" {
            return tileResponse(for: url)
        }
        if pathComponents.count >= 6, pathComponents[1] == "resource" {
            return namedTileResponse(for: url)
        }
        if pathComponents.count >= 3, pathComponents[1] == "pmtiles" {
            return pmtilesResponse(for: request, pathComponents: pathComponents)
        }
        return jsonResponse(["error": "Offline maps API not found"], statusCode: 404)
    }

    private func tileResponse(for url: URL) -> SchemeResponse {
        let parts = normalizedAPIPath(url.path).split(separator: "/").map(String.init)
        guard parts.count >= 5,
              parts[0] == "offline-maps",
              parts[1] == "tile",
              let z = Int(parts[2]),
              let x = Int(parts[3]) else {
            return jsonResponse(["error": "Invalid tile path"], statusCode: 404)
        }
        let yText = (parts[4] as NSString).deletingPathExtension
        guard let y = Int(yText),
              let tile = mapStore.activeTile(z: z, x: x, y: y) else {
            return placeholderTileResponse(cacheState: "MISS")
        }
        return SchemeResponse(
            statusCode: 200,
            mimeType: tile.contentType,
            data: tile.data,
            headers: cacheHeaders.merging(tile.headers) { _, new in new }
        )
    }

    private func namedTileResponse(for url: URL) -> SchemeResponse {
        let parts = normalizedAPIPath(url.path).split(separator: "/").map(String.init)
        guard parts.count >= 6,
              parts[0] == "offline-maps",
              parts[1] == "resource",
              let z = Int(parts[3]),
              let x = Int(parts[4]) else {
            return jsonResponse(["error": "Invalid offline resource tile path"], statusCode: 404)
        }
        let name = parts[2].removingPercentEncoding ?? parts[2]
        let yText = (parts[5] as NSString).deletingPathExtension
        guard let y = Int(yText),
              let tile = mapStore.resourceTile(name: name, z: z, x: x, y: y) else {
            return placeholderTileResponse(cacheState: "MISS")
        }
        return SchemeResponse(
            statusCode: 200,
            mimeType: tile.contentType,
            data: tile.data,
            headers: cacheHeaders.merging(tile.headers) { _, new in new }
        )
    }

    private func pmtilesResponse(for request: URLRequest, pathComponents: [String]) -> SchemeResponse {
        guard pathComponents.count == 3,
              pathComponents[0] == "offline-maps",
              pathComponents[1] == "pmtiles" else {
            return jsonResponse(["error": "Invalid PMTiles path"], statusCode: 404)
        }
        let filename = pathComponents[2].removingPercentEncoding ?? pathComponents[2]
        guard filename.hasSuffix(".pmtiles") else {
            return jsonResponse(["error": "Invalid PMTiles filename"], statusCode: 404)
        }
        let name = String(filename.dropLast(".pmtiles".count))
        guard let result = mapStore.pmtilesFileResponse(
            name: name,
            rangeHeader: request.value(forHTTPHeaderField: "Range")
        ) else {
            return jsonResponse(["error": "PMTiles resource not found"], statusCode: 404)
        }
        return SchemeResponse(
            statusCode: result.statusCode,
            mimeType: result.contentType,
            data: result.data,
            headers: cacheHeaders.merging(result.headers) { _, new in new }
        )
    }

    private func jsonResponse(_ object: Any, statusCode: Int = 200) -> SchemeResponse {
        let sanitized = sanitizeJSON(object)
        let data = (try? JSONSerialization.data(withJSONObject: sanitized, options: [])) ?? Data("{}".utf8)
        return SchemeResponse(statusCode: statusCode, mimeType: "application/json", data: data, headers: cacheHeaders)
    }

    private func placeholderTileResponse(cacheState: String) -> SchemeResponse {
        SchemeResponse(
            statusCode: 200,
            mimeType: "image/png",
            data: Self.transparentTile,
            headers: cacheHeaders.merging(["X-Map-Cache": cacheState, "X-Offline-Map": cacheState]) { _, new in new }
        )
    }

    private func sanitizeJSON(_ value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            return dictionary.mapValues(sanitizeJSON)
        case let array as [Any]:
            return array.map(sanitizeJSON)
        case is NSNull, is String, is Int, is Double, is Bool:
            return value
        case let number as NSNumber:
            return number
        default:
            return NSNull()
        }
    }

    private func jsonBody(from request: URLRequest) -> [String: Any] {
        if let body = request.httpBody,
           let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            return object
        }
        guard let stream = request.httpBodyStream else {
            return [:]
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 {
                break
            }
            data.append(buffer, count: read)
        }
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private func webResourceURL(for path: String) -> URL? {
        let resourcePath = path == "/" ? "/map.html" : path
        let components = resourcePath.split(separator: "/").map(String.init)
        guard !components.isEmpty, !components.contains(where: { $0 == ".." }) else {
            return nil
        }
        guard let webRoot = Bundle.main.url(forResource: "Web", withExtension: nil) else {
            return nil
        }
        let candidate = webRoot.appendingPathComponent(components.joined(separator: "/"))
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            return nil
        }
        return candidate
    }

    private func normalizedAPIPath(_ path: String) -> String {
        if path == "/api" {
            return "/"
        }
        if path.hasPrefix("/api/") {
            return String(path.dropFirst(4))
        }
        return path
    }

    private func deliver(response: SchemeResponse, to task: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(task as AnyObject)
        DispatchQueue.main.async {
            guard !self.lock.withLock({ self.stoppedTasks.contains(taskID) }) else { return }
            guard let url = task.request.url,
                  let httpResponse = HTTPURLResponse(
                    url: url,
                    statusCode: response.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: response.headers.merging(["Content-Type": response.mimeType]) { _, new in new }
                  ) else {
                return
            }
            task.didReceive(httpResponse)
            if !response.data.isEmpty {
                task.didReceive(response.data)
            }
            task.didFinish()
        }
    }

    private var cacheHeaders: [String: String] {
        [
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-store"
        ]
    }

    private func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "html": "text/html; charset=utf-8"
        case "css": "text/css; charset=utf-8"
        case "js": "application/javascript; charset=utf-8"
        case "json": "application/json"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "svg": "image/svg+xml"
        case "pbf", "mvt": "application/x-protobuf"
        case "pmtiles", "mbtiles", "sqlite", "sqlite3": "application/octet-stream"
        default: "application/octet-stream"
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

private struct OnlineTileProvider {
    let key: String
    let format: String
    let contentType: String
    let templates: [String]
    let maxZoom: Int

    func requestURLs(z: Int, x: Int, y: Int) -> [URL] {
        guard !templates.isEmpty else { return [] }
        return templates.compactMap { template in
            let text = template
                .replacingOccurrences(of: "{z}", with: String(z))
                .replacingOccurrences(of: "{x}", with: String(x))
                .replacingOccurrences(of: "{y}", with: String(y))
            return URL(string: text)
        }
    }
}

private final class OnlineTileCache {
    enum TileState {
        case hit(data: Data, contentType: String)
        case queued
        case pending
        case failed
    }

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let session: URLSession
    private let lock = NSLock()
    private var pendingKeys = Set<String>()
    private var failedAtByKey: [String: Date] = [:]
    private let failureCooldown: TimeInterval = 30

    private let providers: [String: OnlineTileProvider] = [
        "google_terrain": OnlineTileProvider(
            key: "google_terrain",
            format: "jpg",
            contentType: "image/jpeg",
            templates: [
                "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}",
                "https://a.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://b.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://c.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://mt0.google.com/vt/lyrs=p&x={x}&y={y}&z={z}",
                "https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}",
                "https://mt2.google.com/vt/lyrs=p&x={x}&y={y}&z={z}",
                "https://mt3.google.com/vt/lyrs=p&x={x}&y={y}&z={z}"
            ],
            maxZoom: 20
        ),
        "terrain_terrarium": OnlineTileProvider(
            key: "terrain_terrarium",
            format: "png",
            contentType: "image/png",
            templates: [
                "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png",
                "https://elevation-tiles-prod.s3.amazonaws.com/terrarium/{z}/{x}/{y}.png"
            ],
            maxZoom: 13
        )
    ]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.rootDirectory = cacheRoot
            .appendingPathComponent("NavPlanner", isDirectory: true)
            .appendingPathComponent("MapCache", isDirectory: true)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        configuration.httpMaximumConnectionsPerHost = 6
        self.session = URLSession(configuration: configuration)

        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    func tile(providerKey: String, z: Int, x: Int, y: Int) -> TileState {
        guard let provider = providers[providerKey],
              z >= 0, z <= provider.maxZoom, x >= 0, y >= 0 else {
            return .failed
        }
        let remoteURLs = provider.requestURLs(z: z, x: x, y: y)
        guard !remoteURLs.isEmpty else {
            return .failed
        }

        let localURL = tileFileURL(provider: provider, z: z, x: x, y: y)
        if let data = try? Data(contentsOf: localURL), !data.isEmpty {
            return .hit(data: data, contentType: contentType(for: data) ?? provider.contentType)
        }

        let key = cacheKey(provider: provider, z: z, x: x, y: y)
        let state = lock.withLock { () -> TileState? in
            if pendingKeys.contains(key) {
                return .pending
            }
            if let failedAt = failedAtByKey[key] {
                if Date().timeIntervalSince(failedAt) < failureCooldown {
                    return .failed
                }
                failedAtByKey.removeValue(forKey: key)
            }
            pendingKeys.insert(key)
            return nil
        }
        if let state {
            return state
        }

        downloadTile(provider: provider, remoteURLs: remoteURLs, localURL: localURL, key: key)
        return .queued
    }

    func statusPayload() -> [String: Any] {
        let usage = diskUsage()
        let runtime = lock.withLock {
            [
                "pending_count": pendingKeys.count,
                "failed_count": failedAtByKey.count
            ]
        }
        return [
            "root": rootDirectory.path,
            "size_bytes": usage.bytes,
            "file_count": usage.files,
            "providers": providers.values
                .sorted { $0.key < $1.key }
                .map { ["key": $0.key, "format": $0.format, "max_zoom": $0.maxZoom] },
            "pending_count": runtime["pending_count"] ?? 0,
            "failed_count": runtime["failed_count"] ?? 0,
            "message": "在线底图缓存状态已读取。"
        ]
    }

    func clearPayload() -> [String: Any] {
        lock.withLock {
            pendingKeys.removeAll()
            failedAtByKey.removeAll()
        }
        if let items = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil,
            options: []
        ) {
            for item in items {
                try? fileManager.removeItem(at: item)
            }
        }
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        var payload = statusPayload()
        payload["message"] = "已清理在线地图缓存。"
        return payload
    }

    private func downloadTile(provider: OnlineTileProvider, remoteURLs: [URL], localURL: URL, key: String) {
        func finishPending() {
            lock.withLock {
                _ = pendingKeys.remove(key)
            }
        }

        func attemptDownload(at index: Int) {
            guard index < remoteURLs.count else {
                markFailure(key: key)
                finishPending()
                return
            }

            let remoteURL = remoteURLs[index]
            var request = URLRequest(url: remoteURL)
            request.timeoutInterval = 12
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 NavPlanner/1.0",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue("image/jpeg,image/png,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")

            session.dataTask(with: request) { [weak self] data, response, _ in
                guard let self else { return }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      let data,
                      self.isValidTileData(data, provider: provider) else {
                    attemptDownload(at: index + 1)
                    return
                }

                do {
                    try self.fileManager.createDirectory(
                        at: localURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    let temporaryURL = localURL
                        .deletingLastPathComponent()
                        .appendingPathComponent(".\(localURL.lastPathComponent).\(UUID().uuidString).tmp")
                    try data.write(to: temporaryURL, options: [.atomic])
                    _ = try? self.fileManager.removeItem(at: localURL)
                    try self.fileManager.moveItem(at: temporaryURL, to: localURL)
                    self.lock.withLock {
                        _ = self.failedAtByKey.removeValue(forKey: key)
                    }
                    finishPending()
                } catch {
                    attemptDownload(at: index + 1)
                }
            }.resume()
        }

        attemptDownload(at: 0)
    }

    private func markFailure(key: String) {
        lock.withLock {
            failedAtByKey[key] = Date()
        }
    }

    private func isValidTileData(_ data: Data, provider: OnlineTileProvider) -> Bool {
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

    private func contentType(for data: Data) -> String? {
        if isJPEG(data) {
            return "image/jpeg"
        }
        if isPNG(data) {
            return "image/png"
        }
        return nil
    }

    private func isJPEG(_ data: Data) -> Bool {
        data.count >= 2 && data[data.startIndex] == 0xff && data[data.index(after: data.startIndex)] == 0xd8
    }

    private func isPNG(_ data: Data) -> Bool {
        let signature: [UInt8] = [0x89, 0x50, 0x4e, 0x47]
        return data.starts(with: signature)
    }

    private func cacheKey(provider: OnlineTileProvider, z: Int, x: Int, y: Int) -> String {
        "\(provider.key)|\(z)|\(x)|\(y)"
    }

    private func tileFileURL(provider: OnlineTileProvider, z: Int, x: Int, y: Int) -> URL {
        rootDirectory
            .appendingPathComponent(provider.key, isDirectory: true)
            .appendingPathComponent(String(format: "z%02d", z), isDirectory: true)
            .appendingPathComponent(String(format: "%04x", x >> 8), isDirectory: true)
            .appendingPathComponent("\(String(format: "%08x", x))_\(String(format: "%08x", y)).\(provider.format)")
    }

    private func diskUsage() -> (bytes: Int64, files: Int) {
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }
        var totalBytes: Int64 = 0
        var totalFiles = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                continue
            }
            totalFiles += 1
            totalBytes += Int64(values.fileSize ?? 0)
        }
        return (totalBytes, totalFiles)
    }
}
