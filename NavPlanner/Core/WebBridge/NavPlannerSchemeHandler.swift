import Foundation
import WebKit

enum FR24SessionStore {
    static let webCookieKey = "navplanner.fr24.webCookie"
    static let frPlKey = "navplanner.fr24.frPl"

    static func accessStatusPayload(userDefaults: UserDefaults = .standard) -> [String: Any] {
        [
            "cookie_configured": !storedWebCookie(userDefaults: userDefaults).isEmpty,
            "frpl_configured": !storedFRPl(userDefaults: userDefaults).isEmpty,
            "message": "FR24 网络访问状态已读取。"
        ]
    }

    static func updateAccessPayload(
        webCookie: String?,
        frPl: String?,
        userDefaults: UserDefaults = .standard
    ) -> [String: Any] {
        let cookie = sanitizedHeaderSecret(webCookie)
        let token = sanitizedHeaderSecret(frPl)
        setSecret(cookie, forKey: webCookieKey, userDefaults: userDefaults)
        if !token.isEmpty {
            setSecret(token, forKey: frPlKey, userDefaults: userDefaults)
        } else if let embedded = cookieValue(named: "_frPl", in: cookie), !embedded.isEmpty {
            setSecret(embedded, forKey: frPlKey, userDefaults: userDefaults)
        }
        var payload = accessStatusPayload(userDefaults: userDefaults)
        payload["message"] = "已保存 FR24 Web 会话配置。"
        return payload
    }

    static func clearAccessPayload(userDefaults: UserDefaults = .standard) -> [String: Any] {
        userDefaults.removeObject(forKey: webCookieKey)
        userDefaults.removeObject(forKey: frPlKey)
        var payload = accessStatusPayload(userDefaults: userDefaults)
        payload["message"] = "已清除 FR24 Web 会话配置。"
        return payload
    }

    static func storedWebCookie(userDefaults: UserDefaults = .standard) -> String {
        sanitizedHeaderSecret(userDefaults.string(forKey: webCookieKey))
    }

    static func storedFRPl(userDefaults: UserDefaults = .standard) -> String {
        sanitizedHeaderSecret(userDefaults.string(forKey: frPlKey))
    }

    static func requestCookieHeader(userDefaults: UserDefaults = .standard) -> String? {
        let cookie = storedWebCookie(userDefaults: userDefaults)
        let frPl = storedFRPl(userDefaults: userDefaults)
        if cookie.isEmpty {
            return frPl.isEmpty ? nil : "_frPl=\(frPl)"
        }
        if !frPl.isEmpty, cookieValue(named: "_frPl", in: cookie) == nil {
            return "\(cookie); _frPl=\(frPl)"
        }
        return cookie
    }

    static func cookieValue(named name: String, in cookie: String) -> String? {
        let parts = cookie.split(separator: ";")
        for part in parts {
            let item = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let equals = item.firstIndex(of: "=") else { continue }
            let key = item[..<equals].trimmingCharacters(in: .whitespacesAndNewlines)
            if key == name {
                let value = item[item.index(after: equals)...].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : String(value)
            }
        }
        return nil
    }

    static func sanitizedHeaderSecret(_ value: String?) -> String {
        var text = (value ?? "")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("cookie:") {
            text = String(text.dropFirst("cookie:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func setSecret(_ value: String?, forKey key: String, userDefaults: UserDefaults) {
        let secret = sanitizedHeaderSecret(value)
        if secret.isEmpty {
            userDefaults.removeObject(forKey: key)
        } else {
            userDefaults.set(secret, forKey: key)
        }
    }
}

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
    private let fr24Service = FR24Service()
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
        if pathComponents.first == "fr24" {
            return fr24Response(for: request, path: path, queryValue: queryValue)
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
            let departure = queryValue("departure", "")
            let arrival = queryValue("arrival", "")
            let routeAirports = plannerService.fr24RouteAirportsPayload(departure: departure, arrival: arrival)
            if routeAirports["error"] != nil {
                return jsonResponse(routeAirports, statusCode: 400)
            }
            let flightHint = queryValue("flight_id", "")
            let downloadPayload: [String: Any]
            if let hintedFlightID = FR24Service.extractFlightID(from: flightHint) {
                downloadPayload = fr24Service.downloadPayload(flightID: hintedFlightID, flight: ["fr24_id": hintedFlightID])
            } else {
                let searchPayload = fr24Service.searchPayload(routeAirports: routeAirports, limit: 1)
                guard (searchPayload["error"] as? String) == nil,
                      let flights = searchPayload["flights"] as? [[String: Any]],
                      let firstFlight = flights.first,
                      let flightID = firstFlight["fr24_id"] as? String,
                      !flightID.isEmpty else {
                    return jsonResponse(searchPayload, statusCode: 503)
                }
                downloadPayload = fr24Service.downloadPayload(flightID: flightID, flight: firstFlight)
            }
            guard (downloadPayload["error"] as? String) == nil,
                  let trackPoints = downloadPayload["track_points"] as? [[String: Any]] else {
                return jsonResponse(downloadPayload, statusCode: 503)
            }
            var payload = plannerService.trackMatchPayload(
                departure: departure,
                arrival: arrival,
                trackPoints: trackPoints
            )
            if payload["error"] != nil {
                return jsonResponse(payload, statusCode: 400)
            }
            payload["message"] = "已从 FR24 Web 轨迹匹配本地航路。"
            payload["source"] = [
                "provider": "Flightradar24 web",
                "flight": downloadPayload["flight"] ?? [:],
                "track_points": trackPoints,
                "cache": downloadPayload["cache"] ?? [:]
            ]
            return jsonResponse(payload)
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

    private func fr24Response(
        for request: URLRequest,
        path: String,
        queryValue: (String, String) -> String
    ) -> SchemeResponse {
        if path == "/fr24/cache/status" {
            return jsonResponse(fr24Service.cacheStatusPayload())
        }
        if path == "/fr24/cache/clear", request.httpMethod == "POST" {
            return jsonResponse(fr24Service.clearCachePayload())
        }
        if path == "/fr24/access/status" {
            return jsonResponse(fr24Service.accessStatusPayload())
        }
        if path == "/fr24/access/update", request.httpMethod == "POST" {
            let body = jsonBody(from: request)
            return jsonResponse(fr24Service.updateAccessPayload(
                webCookie: body["web_cookie"] as? String,
                frPl: body["frpl"] as? String
            ))
        }
        if path == "/fr24/access/clear", request.httpMethod == "POST" {
            return jsonResponse(fr24Service.clearAccessPayload())
        }
        if path == "/fr24/search" {
            let routeAirports = plannerService.fr24RouteAirportsPayload(
                departure: queryValue("departure", ""),
                arrival: queryValue("arrival", "")
            )
            if routeAirports["error"] != nil {
                return jsonResponse(routeAirports, statusCode: 400)
            }
            let payload = fr24Service.searchPayload(
                routeAirports: routeAirports,
                limit: Int(queryValue("limit", "10")) ?? 10
            )
            return jsonResponse(payload, statusCode: payload["error"] == nil ? 200 : 503)
        }
        if path == "/fr24/history" {
            let routeAirports = plannerService.fr24RouteAirportsPayload(
                departure: queryValue("departure", ""),
                arrival: queryValue("arrival", "")
            )
            if routeAirports["error"] != nil {
                return jsonResponse(routeAirports, statusCode: 400)
            }
            let payload = fr24Service.historyPayload(
                routeAirports: routeAirports,
                flightNumber: queryValue("flight", ""),
                callsign: queryValue("callsign", ""),
                limit: Int(queryValue("limit", "0")) ?? 0
            )
            return jsonResponse(payload, statusCode: payload["error"] == nil ? 200 : 503)
        }
        if path == "/fr24/download", request.httpMethod == "POST" {
            let body = jsonBody(from: request)
            let rawFlight = body["flight"] as? [String: Any] ?? [:]
            let flightID = FR24Service.extractFlightID(from: body["flight_id"] as? String ?? "")
                ?? FR24Service.extractFlightID(from: rawFlight["fr24_id"] as? String ?? "")
            guard let flightID, !flightID.isEmpty else {
                return jsonResponse(["error": "FR24 flightId missing."], statusCode: 400)
            }
            let payload = fr24Service.downloadPayload(flightID: flightID, flight: rawFlight)
            return jsonResponse(payload, statusCode: payload["error"] == nil ? 200 : 503)
        }
        return jsonResponse(["error": "FR24 API not found"], statusCode: 404)
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

private final class FR24BrowserFetch: NSObject, WKNavigationDelegate {
    private struct BrowserError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static let shared = FR24BrowserFetch()
    private var webView: WKWebView?
    private struct PageResponse {
        let status: Int
        let contentType: String
        let text: String
    }
    private var pendingPageCompletion: ((Result<PageResponse, Error>) -> Void)?
    private var pendingPageURL: URL?
    private var pendingPageStatus = 0
    private var pendingPageContentType = ""
    private var pendingPageReadScript = ""
    private var pendingPageReadDelay: TimeInterval = 0

    func performJSONRequest(path: String, params: [(String, String)]) throws -> [String: Any] {
        guard var components = URLComponents(string: "https://api.flightradar24.com\(path)") else {
            throw BrowserError(message: "FR24 web request failed.")
        }
        components.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components.url else {
            throw BrowserError(message: "FR24 web request failed.")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var output: Result<[String: Any], Error>?
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                output = .failure(BrowserError(message: "FR24 web request failed."))
                semaphore.signal()
                return
            }
            self.loadJSONPage(url: url) { result in
                output = result.flatMap { page in
                    Self.decodePageResponse(page, requestURL: url)
                }
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .now() + 28) == .timedOut {
            throw BrowserError(message: "FR24 web request timed out.")
        }
        switch output {
        case let .success(payload):
            return payload
        case let .failure(error):
            throw error
        case .none:
            throw BrowserError(message: "FR24 web request failed.")
        }
    }

    func performFlightHistoryPageRequest(flightToken: String) throws -> [String: Any] {
        let token = flightToken.lowercased().filter { $0.isLetter || $0.isNumber }
        guard !token.isEmpty,
              let url = URL(string: "https://www.flightradar24.com/data/flights/\(token)") else {
            throw BrowserError(message: "FR24 flight number missing.")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var output: Result<[String: Any], Error>?
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                output = .failure(BrowserError(message: "FR24 web request failed."))
                semaphore.signal()
                return
            }
            self.loadPage(
                url: url,
                acceptHeader: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                readScript: Self.flightHistoryExtractionScript,
                readDelay: 1.2
            ) { result in
                output = result.flatMap { page in
                    Self.decodeFlightHistoryPageResponse(page, requestURL: url)
                }
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .now() + 30) == .timedOut {
            throw BrowserError(message: "FR24 web request timed out.")
        }
        switch output {
        case let .success(payload):
            return payload
        case let .failure(error):
            throw error
        case .none:
            throw BrowserError(message: "FR24 web request failed.")
        }
    }

    private func loadJSONPage(url: URL, completion: @escaping (Result<PageResponse, Error>) -> Void) {
        loadPage(
            url: url,
            acceptHeader: "application/json, text/plain, */*",
            readScript: "document.body ? (document.body.innerText || document.body.textContent || '') : (document.documentElement ? document.documentElement.innerText || document.documentElement.textContent || '' : '')",
            readDelay: 0,
            completion: completion
        )
    }

    private func loadPage(
        url: URL,
        acceptHeader: String,
        readScript: String,
        readDelay: TimeInterval,
        completion: @escaping (Result<PageResponse, Error>) -> Void
    ) {
        guard pendingPageCompletion == nil else {
            completion(.failure(BrowserError(message: "FR24 browser is already handling a web request.")))
            return
        }
        let webView = ensureWebView()
        pendingPageCompletion = completion
        pendingPageURL = url
        pendingPageStatus = 0
        pendingPageContentType = ""
        pendingPageReadScript = readScript
        pendingPageReadDelay = readDelay
        var request = URLRequest(url: url)
        request.setValue(acceptHeader, forHTTPHeaderField: "Accept")
        request.setValue("https://www.flightradar24.com/", forHTTPHeaderField: "Referer")
        webView.load(request)
        DispatchQueue.main.asyncAfter(deadline: .now() + 24) { [weak self] in
            guard let self,
                  self.pendingPageCompletion != nil,
                  self.pendingPageURL == url else {
                return
            }
            self.finishPendingPage(.failure(BrowserError(message: "FR24 web request timed out.")))
        }
    }

    private func ensureWebView() -> WKWebView {
        if let webView {
            return webView
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        self.webView = webView
        return webView
    }

    private static func decodePageResponse(_ page: PageResponse, requestURL: URL) -> Result<[String: Any], Error> {
        NSLog(
            "NavPlanner FR24 browser load path=%@ status=%d type=%@ body=%@",
            requestURL.path,
            page.status,
            page.contentType,
            bodyKind(page.text)
        )
        if page.status == 401 || page.status == 403 {
            return .failure(BrowserError(message: "FR24 web access was blocked. Open FR24 verification in Query, complete verification, then sync the session."))
        }
        guard page.status == 0 || (200..<300).contains(page.status) else {
            return .failure(BrowserError(message: "FR24 web returned HTTP \(page.status)."))
        }
        if page.text.localizedCaseInsensitiveContains("cloudflare")
            || page.text.localizedCaseInsensitiveContains("challenge-platform")
            || page.text.localizedCaseInsensitiveContains("just a moment")
            || page.text.localizedCaseInsensitiveContains("<html") {
            return .failure(BrowserError(message: "FR24 web returned an HTML response."))
        }
        guard let bodyData = page.text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return .failure(BrowserError(message: "FR24 web response was not valid JSON."))
        }
        return .success(object)
    }

    private static func bodyKind(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "empty"
        }
        if trimmed.localizedCaseInsensitiveContains("cloudflare")
            || trimmed.localizedCaseInsensitiveContains("challenge-platform")
            || trimmed.localizedCaseInsensitiveContains("just a moment") {
            return "cloudflare"
        }
        if trimmed.localizedCaseInsensitiveContains("<html") {
            return "html"
        }
        if trimmed.hasPrefix("{") {
            return "json-object"
        }
        if trimmed.hasPrefix("[") {
            return "json-array"
        }
        return "text"
    }

    private static func decodeFlightHistoryPageResponse(_ page: PageResponse, requestURL: URL) -> Result<[String: Any], Error> {
        NSLog(
            "NavPlanner FR24 browser history path=%@ status=%d type=%@ body=%@",
            requestURL.path,
            page.status,
            page.contentType,
            bodyKind(page.text)
        )
        if page.status == 401 || page.status == 403 {
            return .failure(BrowserError(message: "FR24 web access was blocked. Open FR24 verification in Query, complete verification, then sync the session."))
        }
        guard page.status == 0 || (200..<300).contains(page.status) else {
            return .failure(BrowserError(message: "FR24 web returned HTTP \(page.status)."))
        }
        guard let bodyData = page.text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return .failure(BrowserError(message: "FR24 web response was not valid JSON."))
        }
        let bodyText = Self.stringValue(object["bodyText"])
        let combined = "\(page.text)\n\(bodyText)"
        if combined.localizedCaseInsensitiveContains("cloudflare")
            || combined.localizedCaseInsensitiveContains("challenge-platform")
            || combined.localizedCaseInsensitiveContains("just a moment") {
            return .failure(BrowserError(message: "FR24 web returned an HTML response."))
        }
        return .success(object)
    }

    private static func stringValue(_ value: Any?) -> String {
        switch value {
        case let value as String:
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        case let value as NSNumber:
            return value.stringValue
        case is NSNull, nil:
            return ""
        default:
            return String(describing: value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static let flightHistoryExtractionScript = #"""
    (() => {
      const clean = (value) => String(value || "").replace(/\s+/g, " ").trim();
      const hrefValue = (anchor) => anchor.href || anchor.getAttribute("href") || "";
      const linksFor = (node) => Array.from(node.querySelectorAll("a"))
        .map((anchor) => ({
          text: clean(anchor.textContent),
          title: clean(anchor.getAttribute("title") || anchor.getAttribute("aria-label") || ""),
          href: hrefValue(anchor),
        }))
        .filter((item) => item.href || item.text || item.title);
      const cellsFor = (node) => {
        const direct = Array.from(node.querySelectorAll(":scope > td, :scope > th, :scope > [role='cell'], :scope > [role='gridcell'], :scope > [role='columnheader']"));
        const nested = direct.length ? direct : Array.from(node.querySelectorAll("td, th, [role='cell'], [role='gridcell'], [role='columnheader'], [class*='cell'], [class*='Cell']"));
        return nested
          .map((cell) => clean(cell.innerText || cell.textContent || ""))
          .filter(Boolean);
      };
      const headersFor = (node) => {
        const table = node.closest("table, [role='table'], [role='grid']");
        return Array.from(table?.querySelectorAll("thead th, thead [role='columnheader'], [role='rowgroup']:first-child [role='columnheader']") || [])
          .map((cell) => clean(cell.innerText || cell.textContent || ""))
          .filter(Boolean);
      };
      const rows = [];
      const seen = new Set();
      const rowNodes = Array.from(document.querySelectorAll("tr, [role='row'], li, article, [class*='flight'], [class*='history'], [class*='row']"));
      for (const node of rowNodes) {
        const text = clean(node.innerText || node.textContent || "");
        if (text.length < 18 || text.length > 1800) {
          continue;
        }
        const hrefs = linksFor(node);
        const hasDate = /\b\d{1,2}\s+[A-Za-z]{3}\s+20\d{2}\b/.test(text);
        const hasFlightStatus = /\b(STD|ATD|STA|ETA|Landed|Scheduled|Cancelled|Canceled|Diverted|Unknown|KML|CSV|Play)\b/i.test(text);
        const hasFlightLink = hrefs.some((link) => /(?:flightId=|\/flight\/|\/data\/flights\/|#[0-9a-f]{6,12}\b)/i.test(link.href));
        if (!hasDate && !hasFlightLink) {
          continue;
        }
        if (!hasFlightStatus && !hasFlightLink) {
          continue;
        }
        const key = text.slice(0, 240);
        if (seen.has(key)) {
          continue;
        }
        seen.add(key);
        rows.push({ text, hrefs, cells: cellsFor(node), headers: headersFor(node) });
        if (rows.length >= 120) {
          break;
        }
      }
      const links = Array.from(document.querySelectorAll("a"))
        .map((anchor) => ({
          text: clean(anchor.textContent),
          title: clean(anchor.getAttribute("title") || anchor.getAttribute("aria-label") || ""),
          href: hrefValue(anchor),
          rowText: clean((anchor.closest("tr, [role='row'], li, article, [class*='flight'], [class*='history'], [class*='row']") || anchor.parentElement || anchor).innerText || ""),
        }))
        .filter((item) => item.href || item.text || item.title)
        .slice(0, 240);
      return JSON.stringify({
        title: clean(document.title),
        url: window.location.href,
        bodyText: clean(document.body ? document.body.innerText : ""),
        rows,
        links,
      });
    })()
    """#

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if pendingPageCompletion != nil,
           let response = navigationResponse.response as? HTTPURLResponse {
            pendingPageStatus = response.statusCode
            pendingPageContentType = response.mimeType ?? response.value(forHTTPHeaderField: "Content-Type") ?? ""
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if pendingPageCompletion != nil {
            let script = pendingPageReadScript
            let delay = pendingPageReadDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
                guard let self else { return }
                guard let webView else {
                    self.finishPendingPage(.failure(BrowserError(message: "FR24 web request failed.")))
                    return
                }
                webView.evaluateJavaScript(script) { [weak self] result, error in
                    guard let self else { return }
                    if let error {
                        self.finishPendingPage(.failure(BrowserError(message: "FR24 web response could not be read: \(error.localizedDescription)")))
                        return
                    }
                    self.finishPendingPage(.success(PageResponse(
                        status: self.pendingPageStatus,
                        contentType: self.pendingPageContentType,
                        text: result as? String ?? ""
                    )))
                }
            }
            return
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if pendingPageCompletion != nil {
            finishPendingPage(.failure(BrowserError(message: "FR24 web request failed: \(error.localizedDescription)")))
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if pendingPageCompletion != nil {
            finishPendingPage(.failure(BrowserError(message: "FR24 web request failed: \(error.localizedDescription)")))
        }
    }

    private func finishPendingPage(_ result: Result<PageResponse, Error>) {
        let completion = pendingPageCompletion
        pendingPageCompletion = nil
        pendingPageURL = nil
        pendingPageStatus = 0
        pendingPageContentType = ""
        pendingPageReadScript = ""
        pendingPageReadDelay = 0
        completion?(result)
    }
}

private final class FR24Service {
    private struct ServiceError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let rootDirectory: URL
    private let session: URLSession
    private let apiBaseURL = "https://api.flightradar24.com"
    private let isoFormatter = ISO8601DateFormatter()

    init(fileManager: FileManager = .default, userDefaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.rootDirectory = cacheRoot
            .appendingPathComponent("NavPlanner", isDirectory: true)
            .appendingPathComponent("FR24", isDirectory: true)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 16
        configuration.timeoutIntervalForResource = 22
        configuration.httpMaximumConnectionsPerHost = 2
        self.session = URLSession(configuration: configuration)

        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    static func extractFlightID(from text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        for pattern in [
            #"flightId=([0-9a-fA-F]{6,12})"#,
            #"/data/flights/[^/#?\s]+#([0-9a-fA-F]{6,12})"#,
            #"/flight/[^/#?\s]+#([0-9a-fA-F]{6,12})"#,
            #"FR24[:\s]+([0-9a-fA-F]{6,12})"#,
            #"#([0-9a-fA-F]{6,12})(?:$|[?&\s])"#,
            #"^([0-9a-fA-F]{6,12})$"#
        ] {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               let range = Range(match.range(at: 1), in: value) {
                return (String(value[range]).removingPercentEncoding ?? String(value[range])).lowercased()
            }
        }
        return nil
    }

    func cacheStatusPayload() -> [String: Any] {
        let usage = diskUsage()
        return [
            "root": rootDirectory.path,
            "file_count": usage.files,
            "size_bytes": usage.bytes,
            "message": "FR24 轨迹缓存状态已读取。"
        ]
    }

    func accessStatusPayload() -> [String: Any] {
        FR24SessionStore.accessStatusPayload(userDefaults: userDefaults)
    }

    func updateAccessPayload(webCookie: String?, frPl: String?) -> [String: Any] {
        FR24SessionStore.updateAccessPayload(
            webCookie: webCookie,
            frPl: frPl,
            userDefaults: userDefaults
        )
    }

    func clearAccessPayload() -> [String: Any] {
        FR24SessionStore.clearAccessPayload(userDefaults: userDefaults)
    }

    func clearCachePayload() -> [String: Any] {
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
        var payload = cacheStatusPayload()
        payload["message"] = "已清理 FR24 轨迹缓存。"
        return payload
    }

    func searchPayload(routeAirports: [String: Any], limit: Int) -> [String: Any] {
        let clampedLimit = max(1, min(limit, 10))
        do {
            let flights = try routeFlights(
                routeAirports: routeAirports,
                limit: clampedLimit,
                flightNumber: "",
                callsign: "",
                lookbackHours: 720
            )
            if flights.isEmpty {
                return [
                    "error": "FR24 web did not find recent flights for this route.",
                    "flights": [],
                    "cache": cacheStatusPayload(),
                    "access": accessStatusPayload()
                ]
            }
            return [
                "route": routeAirports,
                "flights": flights,
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload(),
                "message": "已读取 FR24 航线查询结果。"
            ]
        } catch {
            return [
                "error": error.localizedDescription,
                "flights": [],
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload()
            ]
        }
    }

    func historyPayload(
        routeAirports: [String: Any],
        flightNumber: String,
        callsign: String,
        limit: Int
    ) -> [String: Any] {
        let token = normalizedFlightToken(flightNumber).isEmpty
            ? normalizedFlightToken(callsign)
            : normalizedFlightToken(flightNumber)
        guard !token.isEmpty else {
            return [
                "error": "FR24 flight number missing.",
                "flights": [],
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload()
            ]
        }
        let clampedLimit = limit <= 0 ? 0 : max(1, min(limit, 100))
        do {
            let page = try FR24BrowserFetch.shared.performFlightHistoryPageRequest(flightToken: token)
            let flights = parseFlightHistoryPage(
                page,
                flightToken: token,
                routeAirports: routeAirports,
                limit: clampedLimit
            )
            return [
                "route": routeAirports,
                "flights": flights,
                "history_url": "https://www.flightradar24.com/data/flights/\(token.lowercased())",
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload(),
                "message": flights.isEmpty ? "未找到该航班号的 FR24 历史记录。" : "已读取 FR24 航班历史。"
            ]
        } catch {
            return [
                "error": error.localizedDescription,
                "flights": [],
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload()
            ]
        }
    }

    private func parseFlightHistoryPage(
        _ payload: [String: Any],
        flightToken: String,
        routeAirports: [String: Any],
        limit: Int
    ) -> [[String: Any]] {
        let departure = routeAirports["departure"] as? [String: Any] ?? [:]
        let arrival = routeAirports["arrival"] as? [String: Any] ?? [:]
        let pageTitle = Self.stringValue(payload["title"])
        let pageURL = Self.stringValue(payload["url"]).isEmpty
            ? "https://www.flightradar24.com/data/flights/\(flightToken.lowercased())"
            : Self.stringValue(payload["url"])
        let airline = airlineName(from: pageTitle, flightToken: flightToken)
        let rows = historyRows(from: payload)
        var flights: [[String: Any]] = []
        var seen = Set<String>()

        for row in rows {
            let text = row.text
            if !historyRowLooksLikeFlight(text, hrefs: row.hrefs, flightToken: flightToken) {
                continue
            }
            let flightID = row.hrefs.compactMap(Self.extractFlightID(from:)).first
                ?? Self.extractFlightID(from: text)
            let fieldMap = historyFieldMap(headers: row.headers, cells: row.cells)
            let dateTimestamp = firstHistoryDate(in: Self.stringValue(fieldMap["date"])) ?? firstHistoryDate(in: text)
            let scheduledDeparture = timeFromHistoryCell(Self.stringValue(fieldMap["std"]), preferredDate: dateTimestamp)
                ?? labeledTime("STD", in: text, preferredDate: dateTimestamp)
            let actualDeparture = timeFromHistoryCell(Self.stringValue(fieldMap["atd"]), preferredDate: dateTimestamp)
                ?? labeledTime("ATD", in: text, preferredDate: dateTimestamp)
                ?? labeledTime("DEP", in: text, preferredDate: dateTimestamp)
                ?? statusTimeFromHistoryCell(Self.stringValue(fieldMap["status"]), statusWords: ["Departed"], preferredDate: dateTimestamp)
                ?? statusTimeFromHistoryCell(text, statusWords: ["Departed"], preferredDate: dateTimestamp)
            let scheduledArrival = timeFromHistoryCell(
                Self.stringValue(fieldMap["sta"]),
                preferredDate: dateTimestamp,
                rollAfter: scheduledDeparture ?? actualDeparture
            ) ?? labeledTime("STA", in: text, preferredDate: dateTimestamp, rollAfter: scheduledDeparture ?? actualDeparture)
            let actualArrival = statusTimeFromHistoryCell(
                Self.stringValue(fieldMap["status"]),
                statusWords: ["Landed", "Arrived"],
                preferredDate: dateTimestamp,
                rollAfter: actualDeparture ?? scheduledDeparture
            ) ?? labeledTime("ATA", in: text, preferredDate: dateTimestamp, rollAfter: actualDeparture ?? scheduledDeparture)
                ?? statusTimeFromHistoryCell(text, statusWords: ["Landed", "Arrived"], preferredDate: dateTimestamp, rollAfter: actualDeparture ?? scheduledDeparture)
            let estimatedArrival = timeFromHistoryCell(
                Self.stringValue(fieldMap["eta"]),
                preferredDate: dateTimestamp,
                rollAfter: scheduledDeparture ?? actualDeparture
            ) ?? statusTimeFromHistoryCell(
                Self.stringValue(fieldMap["status"]),
                statusWords: ["Estimated", "ETA"],
                preferredDate: dateTimestamp,
                rollAfter: actualDeparture ?? scheduledDeparture
            ) ?? labeledTime("ETA", in: text, preferredDate: dateTimestamp, rollAfter: scheduledDeparture ?? actualDeparture)
            let duration = durationFromHistoryCell(Self.stringValue(fieldMap["flight_time"]))
                ?? durationFromHistoryText(text)
                ?? positiveDuration(departure: actualDeparture ?? scheduledDeparture, arrival: actualArrival ?? estimatedArrival ?? scheduledArrival)
            let aircraftInfo = aircraftFromHistoryText(Self.stringValue(fieldMap["aircraft"]))
                ?? aircraftFromHistoryText(text)
                ?? ("", "")
            let originCode = airportCodeFromHistoryCell(Self.stringValue(fieldMap["from"]))
            let destinationCode = airportCodeFromHistoryCell(Self.stringValue(fieldMap["to"]))
            let statusFromCell = statusFromHistoryText(Self.stringValue(fieldMap["status"]))
            let status = statusFromCell.isEmpty ? statusFromHistoryText(text) : statusFromCell
            var publicFlight: [String: Any] = [
                "fr24_id": flightID ?? "",
                "flight": flightToken,
                "callsign": flightToken,
                "airline": airline,
                "aircraft": aircraftInfo.type,
                "aircraft_registration": aircraftInfo.registration,
                "origin_icao": Self.stringValue(departure["icao"]),
                "origin_iata": originCode.isEmpty ? Self.stringValue(departure["iata"]) : originCode,
                "origin_name": Self.stringValue(departure["name"]),
                "dest_icao": Self.stringValue(arrival["icao"]),
                "dest_iata": destinationCode.isEmpty ? Self.stringValue(arrival["iata"]) : destinationCode,
                "dest_name": Self.stringValue(arrival["name"]),
                "status": status,
                "history_url": pageURL,
                "raw_history": text,
                "timestamp": actualDeparture ?? scheduledDeparture ?? dateTimestamp ?? 0,
                "source_provider": "Flightradar24 data page"
            ]
            publicFlight["scheduled_departure"] = scheduledDeparture ?? NSNull()
            publicFlight["scheduled_arrival"] = scheduledArrival ?? NSNull()
            publicFlight["actual_departure"] = actualDeparture ?? NSNull()
            publicFlight["actual_arrival"] = actualArrival ?? NSNull()
            publicFlight["estimated_departure"] = NSNull()
            publicFlight["estimated_arrival"] = estimatedArrival ?? NSNull()
            publicFlight["duration_seconds"] = duration ?? NSNull()

            let dedupeKey = (flightID?.isEmpty == false ? flightID! : "\(flightToken)|\(Self.stringValue(publicFlight["timestamp"]))|\(text.prefix(160))").lowercased()
            if seen.contains(dedupeKey) {
                continue
            }
            seen.insert(dedupeKey)
            flights.append(publicFlight)
            if limit > 0, flights.count >= limit {
                break
            }
        }
        return limitScheduledHistory(sortedFlights(flights))
    }

    private func historyRows(from payload: [String: Any]) -> [(text: String, hrefs: [String], cells: [String], headers: [String])] {
        var rows: [(text: String, hrefs: [String], cells: [String], headers: [String])] = []
        if let rawRows = payload["rows"] as? [[String: Any]] {
            for rawRow in rawRows {
                let text = Self.stringValue(rawRow["text"])
                let hrefs = hrefs(from: rawRow["hrefs"])
                let cells = Self.stringArray(rawRow["cells"])
                let headers = Self.stringArray(rawRow["headers"])
                if !text.isEmpty {
                    rows.append((text, hrefs, cells, headers))
                }
            }
        }
        if rows.isEmpty, let links = payload["links"] as? [[String: Any]] {
            for link in links {
                let rowText = Self.stringValue(link["rowText"])
                let href = Self.stringValue(link["href"])
                if !rowText.isEmpty {
                    rows.append((rowText, href.isEmpty ? [] : [href], [], []))
                }
            }
        }
        return rows
    }

    private func historyFieldMap(headers: [String], cells: [String]) -> [String: String] {
        var fields: [String: String] = [:]

        func normalizedHeader(_ value: String) -> String {
            let lowercased = value.lowercased()
            if lowercased.contains("date") { return "date" }
            if lowercased == "flight" || lowercased.contains("flight no") || lowercased.contains("flight number") { return "flight" }
            if lowercased == "from" || lowercased.contains("origin") || lowercased.contains("from") { return "from" }
            if lowercased == "to" || lowercased.contains("destination") || lowercased.contains("arrival airport") { return "to" }
            if lowercased.contains("aircraft") { return "aircraft" }
            if lowercased.contains("flight time") || lowercased.contains("duration") { return "flight_time" }
            if lowercased.contains("std") { return "std" }
            if lowercased.contains("atd") { return "atd" }
            if lowercased.contains("sta") { return "sta" }
            if lowercased.contains("ata") { return "ata" }
            if lowercased.contains("eta") { return "eta" }
            if lowercased.contains("status") { return "status" }
            return ""
        }

        func assign(_ key: String, _ value: String) {
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !cleaned.isEmpty, fields[key, default: ""].isEmpty {
                fields[key] = cleaned
            }
        }

        func labeledCell(_ cell: String) -> (String, String)? {
            let labels: [(String, String)] = [
                ("flight time", "flight_time"),
                ("duration", "flight_time"),
                ("aircraft", "aircraft"),
                ("status", "status"),
                ("date", "date"),
                ("from", "from"),
                ("origin", "from"),
                ("to", "to"),
                ("destination", "to"),
                ("std", "std"),
                ("atd", "atd"),
                ("sta", "sta"),
                ("ata", "ata"),
                ("eta", "eta")
            ]
            let cleaned = cell
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = cleaned.lowercased()
            for (label, key) in labels {
                if lowercased == label {
                    return nil
                }
                if lowercased.hasPrefix(label) {
                    let suffix = lowercased.dropFirst(label.count)
                    if let first = suffix.first,
                       !first.isWhitespace,
                       first != ":",
                       first != "-",
                       first != "–" {
                        continue
                    }
                    var value = String(cleaned.dropFirst(label.count))
                        .trimmingCharacters(in: CharacterSet(charactersIn: " :\n\t-"))
                    if value.isEmpty,
                       let range = cleaned.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: label) + #"\b\s*[:\-]?\s*(.+)$"#, options: [.regularExpression, .caseInsensitive]) {
                        value = String(cleaned[range]).replacingOccurrences(
                            of: #"\b"# + NSRegularExpression.escapedPattern(for: label) + #"\b\s*[:\-]?\s*"#,
                            with: "",
                            options: [.regularExpression, .caseInsensitive]
                        )
                    }
                    return value.isEmpty ? nil : (key, value)
                }
            }
            return nil
        }

        func cellLooksLikeFlightNumber(_ cell: String) -> Bool {
            let cleaned = cell
                .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
                .uppercased()
            guard let regex = try? NSRegularExpression(pattern: #"^[A-Z]{1,3}\d{1,4}[A-Z]?$"#) else {
                return false
            }
            return regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) != nil
        }

        func cellLooksLikeDate(_ cell: String) -> Bool {
            firstHistoryDate(in: cell) != nil
        }

        for (index, header) in headers.enumerated() where index < cells.count {
            let key = normalizedHeader(header)
            assign(key, cells[index])
        }

        for cell in cells {
            if let (key, value) = labeledCell(cell) {
                assign(key, value)
            }
        }

        if cells.count >= 8 {
            let fallbackKeys = ["date", "from", "to", "aircraft", "flight_time", "std", "atd", "sta", "status"]
            let fallbackWithFlightKeys = ["date", "flight", "from", "to", "aircraft", "flight_time", "std", "atd", "sta", "status"]
            let startIndex = cells.firstIndex(where: cellLooksLikeDate) ?? 0
            let remaining = Array(cells.dropFirst(startIndex))
            let keys = remaining.count >= fallbackWithFlightKeys.count || (remaining.count >= 9 && remaining.indices.contains(1) && cellLooksLikeFlightNumber(remaining[1]))
                ? fallbackWithFlightKeys
                : fallbackKeys
            for (index, key) in keys.enumerated() where index < remaining.count {
                assign(key, remaining[index])
            }
        }
        return fields
    }

    private func limitScheduledHistory(_ flights: [[String: Any]]) -> [[String: Any]] {
        var didKeepScheduled = false
        var output: [[String: Any]] = []
        for flight in flights {
            let isScheduled = Self.stringValue(flight["status"]).localizedCaseInsensitiveContains("scheduled")
            if isScheduled {
                if didKeepScheduled {
                    continue
                }
                didKeepScheduled = true
            }
            output.append(flight)
        }
        return output
    }

    private func hrefs(from value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings.filter { !$0.isEmpty }
        }
        guard let items = value as? [[String: Any]] else {
            return []
        }
        return items.flatMap { item in
            [Self.stringValue(item["href"]), Self.stringValue(item["text"]), Self.stringValue(item["title"])]
        }.filter { !$0.isEmpty }
    }

    private func historyRowLooksLikeFlight(_ text: String, hrefs: [String], flightToken: String) -> Bool {
        let lowercased = text.lowercased()
        let hasDate = firstHistoryDate(in: text) != nil
        let hasFlightID = hrefs.contains { Self.extractFlightID(from: $0) != nil }
        let statusTerms = [
            "std", "atd", "sta", "eta", "landed", "scheduled", "cancelled", "canceled",
            "diverted", "unknown", "kml", "csv", "play"
        ]
        let hasStatus = statusTerms.contains { lowercased.contains($0) }
        let hasToken = normalizedFlightToken(text).contains(flightToken)
        return (hasDate || hasFlightID) && (hasStatus || hasFlightID || hasToken)
    }

    private func airlineName(from pageTitle: String, flightToken: String) -> String {
        let cleaned = pageTitle
            .replacingOccurrences(of: "| Flightradar24", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "Flightradar24", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "Flight Tracker", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: flightToken, with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: " - ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "" : cleaned
    }

    private func firstHistoryDate(in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d{1,2})\s+([A-Za-z]{3})\s+(20\d{2})\b"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let dayRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let yearRange = Range(match.range(at: 3), in: text) else {
            return nil
        }
        let dateText = "\(text[dayRange]) \(text[monthRange]) \(text[yearRange])"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "d MMM yyyy"
        guard let date = formatter.date(from: dateText) else {
            return nil
        }
        return Int(date.timeIntervalSince1970)
    }

    private func timeFromHistoryCell(_ text: String, preferredDate: Int?, rollAfter: Int? = nil) -> Int? {
        guard let dateStart = preferredDate,
              let regex = try? NSRegularExpression(pattern: #"\b([0-2]?\d):([0-5]\d)\b"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hours = Int(text[hourRange]),
              let minutes = Int(text[minuteRange]) else {
            return nil
        }
        var timestamp = dateStart + hours * 3600 + minutes * 60
        if let rollAfter, timestamp + 6 * 3600 < rollAfter {
            timestamp += 24 * 3600
        }
        return timestamp
    }

    private func labeledTime(_ label: String, in text: String, preferredDate: Int?, rollAfter: Int? = nil) -> Int? {
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: label) + #"\s+([0-2]?\d:[0-5]\d)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let timeRange = Range(match.range(at: 1), in: text),
              let dateStart = preferredDate else {
            return nil
        }
        let parts = text[timeRange].split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else {
            return nil
        }
        var timestamp = dateStart + parts[0] * 3600 + parts[1] * 60
        if let rollAfter, timestamp + 6 * 3600 < rollAfter {
            timestamp += 24 * 3600
        }
        return timestamp
    }

    private func statusTimeFromHistoryCell(
        _ text: String,
        statusWords: [String],
        preferredDate: Int?,
        rollAfter: Int? = nil
    ) -> Int? {
        guard let preferredDate,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let words = statusWords
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        let pattern = #"\b(?:"# + words + #")\b[^\d]{0,24}([0-2]?\d:[0-5]\d)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let timeRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return timeFromHistoryCell(String(text[timeRange]), preferredDate: preferredDate, rollAfter: rollAfter)
    }

    private func durationFromHistoryText(_ text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"\b(?:Landed|Arrived|Flight time|Duration)\s+(\d{1,2}):([0-5]\d)\b"#, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hours = Int(text[hourRange]),
              let minutes = Int(text[minuteRange]) else {
            return nil
        }
        return hours * 3600 + minutes * 60
    }

    private func durationFromHistoryCell(_ text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"^\s*(\d{1,2}):([0-5]\d)\s*$"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hours = Int(text[hourRange]),
              let minutes = Int(text[minuteRange]) else {
            return nil
        }
        return hours * 3600 + minutes * 60
    }

    private func aircraftFromHistoryText(_ text: String) -> (type: String, registration: String)? {
        if let regex = try? NSRegularExpression(pattern: #"\b([A-Z0-9]{3,5})\s*\(([A-Z0-9-]{3,12})\)"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let typeRange = Range(match.range(at: 1), in: text),
           let registrationRange = Range(match.range(at: 2), in: text) {
            return (String(text[typeRange]), String(text[registrationRange]))
        }
        if let regex = try? NSRegularExpression(pattern: #"\b(A[0-9][A-Z0-9]{2}|B[0-9][A-Z0-9]{2}|E[0-9]{3}|CRJ[0-9]{1,3}|AT[0-9]{2}|DH[0-9A-Z]{2}|C[0-9]{3})\b"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let typeRange = Range(match.range(at: 1), in: text) {
            return (String(text[typeRange]), "")
        }
        return nil
    }

    private func airportCodeFromHistoryCell(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\(([A-Z0-9]{3,4})\)"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return ""
        }
        return String(text[range]).uppercased()
    }

    private func statusFromHistoryText(_ text: String) -> String {
        for status in ["Landed", "Scheduled", "Cancelled", "Canceled", "Diverted", "Unknown", "Estimated"] {
            if text.range(of: status, options: [.caseInsensitive]) != nil {
                return status
            }
        }
        return ""
    }

    func downloadPayload(flightID: String, flight: [String: Any]) -> [String: Any] {
        let normalizedID = sanitizeCacheKey(flightID)
        guard !normalizedID.isEmpty else {
            return ["error": "FR24 flightId missing.", "cache": cacheStatusPayload()]
        }
        if let cached = cachedDownloadPayload(cacheKey: normalizedID, flight: flight) {
            return cached
        }
        do {
            let playback = try webGet(path: "/common/v1/flight-playback.json", params: [
                ("flightId", flightID),
                ("timestamp", String(Int(Date().timeIntervalSince1970)))
            ])
            let trackPoints = extractPlaybackTrackPoints(playback)
            guard trackPoints.count >= 2 else {
                return [
                    "error": "FR24 web playback did not return enough trajectory points.",
                    "cache": cacheStatusPayload(),
                    "access": accessStatusPayload()
                ]
            }
            return try cacheDownloadResponse(
                flightID: flightID,
                cacheKey: normalizedID,
                flight: flight,
                playback: playback,
                trackPoints: trackPoints,
                cacheHit: false
            )
        } catch {
            return [
                "error": error.localizedDescription,
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload()
            ]
        }
    }

    private func cacheDownloadResponse(
        flightID: String,
        cacheKey: String,
        flight: [String: Any],
        playback: [String: Any],
        trackPoints: [[String: Any]],
        cacheHit: Bool
    ) throws -> [String: Any] {
        let jsonURL = rootDirectory.appendingPathComponent("\(cacheKey).json")
        let metaURL = rootDirectory.appendingPathComponent("\(cacheKey).meta.json")
        let gpxURL = rootDirectory.appendingPathComponent("\(cacheKey).gpx")
        let payload: [String: Any] = [
            "flight": flight,
            "track_points": trackPoints,
            "playback": playback
        ]
        if let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
            try? payloadData.write(to: jsonURL, options: [.atomic])
        }
        let gpxText = gpxDocument(
            flightID: flightID,
            flight: flight,
            trackPoints: trackPoints
        )
        try gpxText.data(using: .utf8)?.write(to: gpxURL, options: [.atomic])
        var publicFlight = flight
        publicFlight["fr24_id"] = flightID
        let meta: [String: Any] = [
            "flight": publicFlight,
            "track_points": trackPoints,
            "gpx_filename": gpxURL.lastPathComponent,
            "gpx_path": gpxURL.path,
            "json_filename": jsonURL.lastPathComponent,
            "downloaded_at": Int(Date().timeIntervalSince1970)
        ]
        if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]) {
            try? metaData.write(to: metaURL, options: [.atomic])
        }
        return downloadResponse(
            cacheKey: cacheKey,
            flight: publicFlight,
            trackPoints: trackPoints,
            cacheHit: cacheHit
        )
    }

    private func routeFlights(
        routeAirports: [String: Any],
        limit: Int,
        flightNumber: String,
        callsign: String,
        lookbackHours: Int
    ) throws -> [[String: Any]] {
        guard let departure = routeAirports["departure"] as? [String: Any],
              let arrival = routeAirports["arrival"] as? [String: Any] else {
            throw serviceError("Departure or arrival could not be resolved.")
        }
        let departureCodes = Set(Self.stringArray(departure["codes"]).map { $0.uppercased() })
        let arrivalCodes = Set(Self.stringArray(arrival["codes"]).map { $0.uppercased() })
        let flightFilter = normalizedFlightToken(flightNumber)
        let callsignFilter = normalizedFlightToken(callsign)
        let departureScheduleCode = scheduleCode(for: departure)
        let arrivalScheduleCode = scheduleCode(for: arrival)
        let now = Date()
        let stepHours = 24
        var flights: [[String: Any]] = []
        var seen = Set<String>()

        for offsetHours in stride(from: 0, through: max(1, lookbackHours), by: stepHours) {
            let timestamp = Int(now.addingTimeInterval(TimeInterval(-offsetHours * 3600)).timeIntervalSince1970)
            var offsetHadSuccess = false
            var offsetHadHTTP400 = false
            for modeInfo in [
                (mode: "departures", airportCode: departureScheduleCode),
                (mode: "arrivals", airportCode: arrivalScheduleCode)
            ] {
                var params = [
                    ("code", modeInfo.airportCode),
                    ("plugin[]", "schedule"),
                    ("plugin-setting[schedule][mode]", modeInfo.mode)
                ]
                if offsetHours == 0 {
                    params.append(("page", "1"))
                    params.append(("limit", "100"))
                } else {
                    params.append(("plugin-setting[schedule][timestamp]", String(timestamp)))
                }
                let payload: [String: Any]
                do {
                    payload = try webGet(path: "/common/v1/airport.json", params: params)
                    offsetHadSuccess = true
                } catch {
                    if error.localizedDescription.contains("HTTP 400") {
                        offsetHadHTTP400 = true
                    }
                    if offsetHours == 0, flights.isEmpty {
                        throw error
                    }
                    continue
                }
                let rawFlights = extractScheduleFlights(payload)
                var appendedFromPayload = 0
                for rawFlight in rawFlights {
                    var flight = normalizeOfficialFlight(rawFlight, departure: departure, arrival: arrival)
                    if modeInfo.mode == "departures" {
                        if Self.stringValue(flight["origin_icao"]).isEmpty {
                            flight["origin_icao"] = Self.stringValue(departure["icao"])
                        }
                        if Self.stringValue(flight["origin_iata"]).isEmpty {
                            flight["origin_iata"] = Self.stringValue(departure["iata"])
                        }
                    } else {
                        if Self.stringValue(flight["dest_icao"]).isEmpty {
                            flight["dest_icao"] = Self.stringValue(arrival["icao"])
                        }
                        if Self.stringValue(flight["dest_iata"]).isEmpty {
                            flight["dest_iata"] = Self.stringValue(arrival["iata"])
                        }
                    }
                    guard flightMatchesRoute(flight, departureCodes: departureCodes, arrivalCodes: arrivalCodes) else {
                        continue
                    }
                    if !flightFilter.isEmpty || !callsignFilter.isEmpty {
                        let number = normalizedFlightToken(Self.stringValue(flight["flight"]))
                        let call = normalizedFlightToken(Self.stringValue(flight["callsign"]))
                        if !flightFilter.isEmpty, number != flightFilter {
                            continue
                        }
                        if flightFilter.isEmpty, !callsignFilter.isEmpty, call != callsignFilter {
                            continue
                        }
                    }
                    let identifier = Self.stringValue(flight["fr24_id"])
                    let dedupeKey = identifier.isEmpty
                        ? "\(Self.stringValue(flight["flight"]))|\(Self.stringValue(flight["callsign"]))|\(Self.intValue(flight["timestamp"]) ?? flights.count)"
                        : identifier
                    if seen.contains(dedupeKey) {
                        continue
                    }
                    seen.insert(dedupeKey)
                    flights.append(flight)
                    appendedFromPayload += 1
                    if flights.count >= limit {
                        NSLog(
                            "NavPlanner FR24 schedule code=%@ mode=%@ offset=%d raw=%d appended=%d total=%d",
                            modeInfo.airportCode,
                            modeInfo.mode,
                            offsetHours,
                            rawFlights.count,
                            appendedFromPayload,
                            flights.count
                        )
                        return sortedFlights(flights)
                    }
                }
                NSLog(
                    "NavPlanner FR24 schedule code=%@ mode=%@ offset=%d raw=%d appended=%d total=%d",
                    modeInfo.airportCode,
                    modeInfo.mode,
                    offsetHours,
                    rawFlights.count,
                    appendedFromPayload,
                    flights.count
                )
            }
            if offsetHours > 0, !offsetHadSuccess, offsetHadHTTP400 {
                NSLog(
                    "NavPlanner FR24 schedule stop offset=%d reason=http400 total=%d",
                    offsetHours,
                    flights.count
                )
                break
            }
        }
        return sortedFlights(flights)
    }

    private func scheduleCode(for airport: [String: Any]) -> String {
        let schedule = Self.stringValue(airport["schedule_code"])
        if !schedule.isEmpty {
            return schedule
        }
        let iata = Self.stringValue(airport["iata"])
        if !iata.isEmpty {
            return iata
        }
        let ident = Self.stringValue(airport["ident"])
        if !ident.isEmpty {
            return ident
        }
        return Self.stringValue(airport["icao"])
    }

    private func extractScheduleFlights(_ payload: [String: Any]) -> [[String: Any]] {
        var flights: [[String: Any]] = []

        func visit(_ item: Any) {
            if let dictionary = item as? [String: Any] {
                let flightID = Self.stringValue(Self.firstDeepValue(dictionary, paths: [
                    ["flight", "identification", "id"],
                    ["identification", "id"]
                ]))
                if !flightID.isEmpty {
                    flights.append(dictionary)
                }
                dictionary.values.forEach(visit)
            } else if let array = item as? [Any] {
                array.forEach(visit)
            }
        }

        visit(payload)
        return flights
    }

    private func normalizeOfficialFlight(
        _ rawFlight: [String: Any],
        departure: [String: Any],
        arrival: [String: Any]
    ) -> [String: Any] {
        let scheduledDeparture = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "scheduled", "departure"],
            ["scheduled_out"],
            ["scheduled_departure"],
            ["scheduled_departure_time"],
            ["datetime_scheduled_departure"],
            ["time", "scheduled", "departure"]
        ]))
        let scheduledArrival = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "scheduled", "arrival"],
            ["scheduled_in"],
            ["scheduled_arrival"],
            ["scheduled_arrival_time"],
            ["datetime_scheduled_arrival"],
            ["time", "scheduled", "arrival"]
        ]))
        let actualDeparture = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "real", "departure"],
            ["actual_out"],
            ["actual_off"],
            ["actual_departure"],
            ["actual_departure_time"],
            ["datetime_takeoff"],
            ["datetime_real_departure"],
            ["time", "real", "departure"],
            ["time", "actual", "departure"]
        ]))
        let actualArrival = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "real", "arrival"],
            ["actual_on"],
            ["actual_in"],
            ["actual_arrival"],
            ["actual_arrival_time"],
            ["datetime_landed"],
            ["datetime_real_arrival"],
            ["time", "real", "arrival"],
            ["time", "actual", "arrival"]
        ]))
        let estimatedDeparture = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "estimated", "departure"],
            ["estimated_out"],
            ["estimated_off"],
            ["estimated_departure"],
            ["estimated_departure_time"],
            ["datetime_estimated_departure"],
            ["time", "estimated", "departure"]
        ]))
        let estimatedArrival = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "estimated", "arrival"],
            ["estimated_on"],
            ["estimated_in"],
            ["estimated_arrival"],
            ["estimated_arrival_time"],
            ["datetime_estimated_arrival"],
            ["time", "estimated", "arrival"]
        ]))
        let originICAO = Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "airport", "origin", "code", "icao"],
            ["origin", "code"],
            ["origin", "icao"],
            ["orig_icao"],
            ["origin_icao"],
            ["departure_icao"],
            ["airport", "origin", "code", "icao"]
        ]))
        let originIATA = Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "airport", "origin", "code", "iata"],
            ["origin", "alternate_ident"],
            ["origin", "iata"],
            ["orig_iata"],
            ["origin_iata"],
            ["departure_iata"],
            ["airport", "origin", "code", "iata"]
        ]))
        let destICAO = Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "airport", "destination", "code", "icao"],
            ["destination", "code"],
            ["destination", "icao"],
            ["dest_icao"],
            ["destination_icao"],
            ["arrival_icao"],
            ["airport", "destination", "code", "icao"]
        ]))
        let destIATA = Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "airport", "destination", "code", "iata"],
            ["destination", "alternate_ident"],
            ["destination", "iata"],
            ["dest_iata"],
            ["destination_iata"],
            ["arrival_iata"],
            ["airport", "destination", "code", "iata"]
        ]))
        let duration = positiveDuration(
            departure: actualDeparture ?? scheduledDeparture,
            arrival: actualArrival ?? scheduledArrival
        )
        var publicFlight: [String: Any] = [
            "fr24_id": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "identification", "id"],
                ["identification", "id"],
                ["fr24_id"],
                ["flight_id"],
                ["id"],
                ["ident"]
            ])),
            "flight": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "identification", "number", "default"],
                ["ident"],
                ["flight"],
                ["flight_number"],
                ["number"],
                ["identification", "number", "default"]
            ])),
            "callsign": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "identification", "callsign"],
                ["ident"],
                ["callsign"],
                ["identification", "callsign"]
            ])),
            "airline": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "airline", "name"],
                ["airline", "name"],
                ["operator"],
                ["operator_icao"],
                ["operator_iata"],
                ["airline"],
                ["airline_name"],
                ["flight", "airline", "name"]
            ])),
            "aircraft": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "aircraft", "model", "code"],
                ["flight", "aircraft", "model", "text"],
                ["aircraft_type"],
                ["aircraft"],
                ["aircraft_code"],
                ["type"],
                ["model"],
                ["aircraft", "model", "code"]
            ])),
            "aircraft_registration": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "aircraft", "identification", "registration"],
                ["flight", "aircraft", "registration"],
                ["registration"],
                ["reg"],
                ["aircraft_registration"],
                ["aircraft", "registration"]
            ])),
            "origin_icao": originICAO.isEmpty ? Self.stringValue(departure["icao"]) : originICAO,
            "origin_iata": originIATA.isEmpty ? Self.stringValue(departure["iata"]) : originIATA,
            "origin_name": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "airport", "origin", "name"],
                ["origin", "name"],
                ["origin_name"],
                ["departure_name"],
                ["airport", "origin", "name"]
            ])),
            "dest_icao": destICAO.isEmpty ? Self.stringValue(arrival["icao"]) : destICAO,
            "dest_iata": destIATA.isEmpty ? Self.stringValue(arrival["iata"]) : destIATA,
            "dest_name": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "airport", "destination", "name"],
                ["destination", "name"],
                ["dest_name"],
                ["destination_name"],
                ["arrival_name"],
                ["airport", "destination", "name"]
            ])),
            "timestamp": actualDeparture ?? scheduledDeparture ?? actualArrival ?? scheduledArrival ?? 0,
            "source_provider": "Flightradar24 web"
        ]
        publicFlight["scheduled_departure"] = scheduledDeparture ?? NSNull()
        publicFlight["scheduled_arrival"] = scheduledArrival ?? NSNull()
        publicFlight["actual_departure"] = actualDeparture ?? NSNull()
        publicFlight["actual_arrival"] = actualArrival ?? NSNull()
        publicFlight["estimated_departure"] = estimatedDeparture ?? NSNull()
        publicFlight["estimated_arrival"] = estimatedArrival ?? NSNull()
        publicFlight["duration_seconds"] = duration ?? NSNull()
        return publicFlight
    }

    private func sortedFlights(_ flights: [[String: Any]]) -> [[String: Any]] {
        flights.sorted {
            (Self.intValue($0["timestamp"]) ?? 0) > (Self.intValue($1["timestamp"]) ?? 0)
        }
    }

    private func serviceError(_ message: String) -> ServiceError {
        ServiceError(message: message)
    }

    private func flightMatchesRoute(
        _ flight: [String: Any],
        departureCodes: Set<String>,
        arrivalCodes: Set<String>
    ) -> Bool {
        let originCodes = [
            Self.stringValue(flight["origin_icao"]).uppercased(),
            Self.stringValue(flight["origin_iata"]).uppercased()
        ].filter { !$0.isEmpty }
        let destCodes = [
            Self.stringValue(flight["dest_icao"]).uppercased(),
            Self.stringValue(flight["dest_iata"]).uppercased()
        ].filter { !$0.isEmpty }
        return !departureCodes.intersection(originCodes).isEmpty
            && !arrivalCodes.intersection(destCodes).isEmpty
    }

    private func webGet(path: String, params: [(String, String)]) throws -> [String: Any] {
        do {
            return try FR24BrowserFetch.shared.performJSONRequest(path: path, params: params)
        } catch {
            NSLog("NavPlanner FR24 browser request error path=%@ error=%@", path, error.localizedDescription)
            if Self.shouldSurfaceBrowserRequestError(error.localizedDescription) {
                throw serviceError(error.localizedDescription)
            }
        }

        guard var components = URLComponents(string: "\(apiBaseURL)\(path)") else {
            throw serviceError("FR24 web request failed.")
        }
        components.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components.url else {
            throw serviceError("FR24 web request failed.")
        }
        var request = URLRequest(url: url)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.flightradar24.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.flightradar24.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        if let cookie = FR24SessionStore.requestCookieHeader(userDefaults: userDefaults), !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        return try performJSONRequest(request)
    }

    private static func shouldSurfaceBrowserRequestError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("blocked")
            || lowercased.contains("cloudflare")
            || lowercased.contains("html response")
            || lowercased.contains("returned http")
            || lowercased.contains("not valid json")
    }

    private func performJSONRequest(_ request: URLRequest) throws -> [String: Any] {
        let semaphore = DispatchSemaphore(value: 0)
        var outputData: Data?
        var outputResponse: URLResponse?
        var outputError: Error?
        let task = session.dataTask(with: request) { data, response, error in
            outputData = data
            outputResponse = response
            outputError = error
            semaphore.signal()
        }
        task.resume()
        if semaphore.wait(timeout: .now() + 22) == .timedOut {
            task.cancel()
            throw serviceError("FR24 web request timed out.")
        }
        if let outputError {
            throw serviceError("FR24 web request failed: \(outputError.localizedDescription)")
        }
        let httpResponse = outputResponse as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 0
        let data = outputData ?? Data()
        if Self.isCloudflareChallenge(data: data, response: httpResponse) {
            throw serviceError("FR24 web access was blocked by Cloudflare verification.")
        }
        if statusCode == 401 || statusCode == 403 {
            throw serviceError(Self.fr24HTTPErrorMessage(statusCode: statusCode, data: data))
        }
        guard (200..<300).contains(statusCode) else {
            throw serviceError(Self.fr24HTTPErrorMessage(statusCode: statusCode, data: data))
        }
        if let text = String(data: data.prefix(400), encoding: .utf8),
           text.localizedCaseInsensitiveContains("just a moment")
            || text.localizedCaseInsensitiveContains("cloudflare")
            || text.localizedCaseInsensitiveContains("<html") {
            throw serviceError("FR24 web returned an HTML response.")
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw serviceError("FR24 web response was not valid JSON.")
        }
        return object
    }

    private static func fr24HTTPErrorMessage(statusCode: Int, data: Data) -> String {
        if statusCode == 401 || statusCode == 403 {
            return "FR24 web access was blocked. Open FR24 verification in Query, complete verification, then sync the session."
        }
        let summary: String
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            summary = stringValue(object["message"]).isEmpty
                ? (stringValue(object["error"]).isEmpty ? stringValue(object["detail"]) : stringValue(object["error"]))
                : stringValue(object["message"])
        } else {
            summary = String(data: data, encoding: .utf8)?
                .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        if summary.isEmpty {
            return "FR24 web returned HTTP \(statusCode)."
        }
        return "FR24 web returned HTTP \(statusCode): \(String(summary.prefix(180)))."
    }

    private static func isCloudflareChallenge(data: Data, response: HTTPURLResponse?) -> Bool {
        let mitigated = response?.value(forHTTPHeaderField: "cf-mitigated")?.lowercased() == "challenge"
        guard let text = String(data: data.prefix(1200), encoding: .utf8) else {
            return mitigated
        }
        return mitigated
            || text.localizedCaseInsensitiveContains("cloudflare")
            || text.localizedCaseInsensitiveContains("challenge-platform")
            || text.localizedCaseInsensitiveContains("just a moment")
    }

    private func extractPlaybackTrackPoints(_ payload: [String: Any]) -> [[String: Any]] {
        var candidateTracks: [[[String: Any]]] = []

        func normalizedTrack(_ items: [Any]) -> [[String: Any]] {
            items.compactMap { item in
                if let dictionary = item as? [String: Any] {
                    let lat = Self.doubleValue(dictionary["lat"])
                        ?? Self.doubleValue(dictionary["latitude"])
                        ?? Self.doubleValue(Self.deepValue(dictionary, path: ["position", "lat"]))
                    let lon = Self.doubleValue(dictionary["lon"])
                        ?? Self.doubleValue(dictionary["lng"])
                        ?? Self.doubleValue(dictionary["longitude"])
                        ?? Self.doubleValue(Self.deepValue(dictionary, path: ["position", "lng"]))
                        ?? Self.doubleValue(Self.deepValue(dictionary, path: ["position", "lon"]))
                    guard let lat, let lon, lat.isFinite, lon.isFinite else {
                        return nil
                    }
                    var point: [String: Any] = [
                        "lat": lat,
                        "lon": lon
                    ]
                    if let timestamp = Self.timestampValue(dictionary["timestamp"])
                        ?? Self.timestampValue(dictionary["ts"])
                        ?? Self.timestampValue(dictionary["time"]) {
                        point["timestamp"] = timestamp
                    }
                    if let altitude = Self.intValue(dictionary["altitude"])
                        ?? Self.intValue(dictionary["alt"])
                        ?? Self.intValue(Self.deepValue(dictionary, path: ["altitude", "feet"]))
                        ?? Self.intValue(Self.deepValue(dictionary, path: ["altitude", "meters"])) {
                        point["altitude"] = altitude
                    }
                    return point
                }
                if let array = item as? [Any], array.count >= 3 {
                    let timestamp = Self.intValue(array[0])
                    let lat = Self.doubleValue(array[1])
                    let lon = Self.doubleValue(array[2])
                    guard let lat, let lon, lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 360 else {
                        return nil
                    }
                    var point: [String: Any] = ["lat": lat, "lon": lon]
                    if let timestamp {
                        point["timestamp"] = timestamp
                    }
                    return point
                }
                return nil
            }
        }

        func visit(_ item: Any) {
            if let array = item as? [Any] {
                let points = normalizedTrack(array)
                if points.count >= 2 {
                    candidateTracks.append(points)
                }
                array.forEach(visit)
            } else if let dictionary = item as? [String: Any] {
                dictionary.values.forEach(visit)
            }
        }

        visit(payload)
        return candidateTracks.max { $0.count < $1.count } ?? []
    }

    private func cachedDownloadPayload(cacheKey: String, flight: [String: Any]) -> [String: Any]? {
        let metaURL = rootDirectory.appendingPathComponent("\(cacheKey).meta.json")
        guard let data = try? Data(contentsOf: metaURL),
              let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let trackPoints = meta["track_points"] as? [[String: Any]],
              trackPoints.count >= 2 else {
            return nil
        }
        let cachedFlight = (meta["flight"] as? [String: Any]) ?? flight
        return downloadResponse(
            cacheKey: cacheKey,
            flight: cachedFlight,
            trackPoints: trackPoints,
            cacheHit: true
        )
    }

    private func downloadResponse(
        cacheKey: String,
        flight: [String: Any],
        trackPoints: [[String: Any]],
        cacheHit: Bool
    ) -> [String: Any] {
        let gpxURL = rootDirectory.appendingPathComponent("\(cacheKey).gpx")
        return [
            "flight": flight,
            "track_points": trackPoints,
            "track_point_count": trackPoints.count,
            "cache_key": cacheKey,
            "gpx_filename": gpxURL.lastPathComponent,
            "gpx_path": gpxURL.path,
            "cache_hit": cacheHit,
            "cache": cacheStatusPayload(),
            "access": accessStatusPayload(),
            "message": cacheHit ? "已读取缓存的 FR24 GPX 轨迹。" : "已下载并缓存 FR24 GPX 轨迹。"
        ]
    }

    private func gpxDocument(
        flightID: String,
        flight: [String: Any],
        trackPoints: [[String: Any]]
    ) -> String {
        let title = [
            Self.stringValue(flight["flight"]),
            Self.stringValue(flight["origin_icao"]).isEmpty ? Self.stringValue(flight["origin_iata"]) : Self.stringValue(flight["origin_icao"]),
            Self.stringValue(flight["dest_icao"]).isEmpty ? Self.stringValue(flight["dest_iata"]) : Self.stringValue(flight["dest_icao"])
        ].filter { !$0.isEmpty }.joined(separator: " ")
        let name = title.isEmpty ? "FR24 \(flightID)" : title
        let body = trackPoints.map { point -> String in
            let lat = Self.doubleValue(point["lat"]) ?? 0
            let lon = Self.doubleValue(point["lon"]) ?? 0
            let time = Self.intValue(point["timestamp"]).map { normalizedTimestamp($0) }
            return """
            <trkpt lat="\(lat)" lon="\(lon)">\(time.map { "<time>\(xmlEscape(isoFormatter.string(from: Date(timeIntervalSince1970: TimeInterval($0)))))</time>" } ?? "")</trkpt>
            """
        }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="NavPlanner" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <name>\(xmlEscape(name))</name>
            <trkseg>
        \(body)
            </trkseg>
          </trk>
        </gpx>
        """
    }

    private func diskUsage() -> (files: Int, bytes: Int64) {
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }
        var files = 0
        var bytes: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            files += 1
            bytes += Int64(values?.fileSize ?? 0)
        }
        return (files, bytes)
    }

    private func sanitizeCacheKey(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var output = ""
        for scalar in value.lowercased().unicodeScalars {
            output += allowed.contains(scalar) ? String(scalar) : "-"
        }
        return output
    }

    private func normalizedFlightToken(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private func positiveDuration(departure: Int?, arrival: Int?) -> Int? {
        guard let departure, let arrival else { return nil }
        let normalizedDeparture = normalizedTimestamp(departure)
        let normalizedArrival = normalizedTimestamp(arrival)
        let duration = normalizedArrival - normalizedDeparture
        return duration > 0 && duration < 172800 ? duration : nil
    }

    private func normalizedTimestamp(_ value: Int) -> Int {
        value > 1_000_000_000_000 ? value / 1000 : value
    }

    private func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func firstDeepValue(_ dictionary: [String: Any], paths: [[String]]) -> Any? {
        for path in paths {
            if let value = deepValue(dictionary, path: path),
               !stringValue(value).isEmpty || intValue(value) != nil || doubleValue(value) != nil {
                return value
            }
        }
        return nil
    }

    private static func deepValue(_ dictionary: [String: Any], path: [String]) -> Any? {
        var cursor: Any? = dictionary
        for key in path {
            guard let object = cursor as? [String: Any], object.keys.contains(key) else {
                return nil
            }
            cursor = object[key]
        }
        return cursor
    }

    private static func stringArray(_ value: Any?) -> [String] {
        if let array = value as? [String] {
            return array.filter { !$0.isEmpty }
        }
        if let array = value as? [Any] {
            return array.map(stringValue).filter { !$0.isEmpty }
        }
        let single = stringValue(value)
        return single.isEmpty ? [] : [single]
    }

    private static func urlPathComponent(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func stringValue(_ value: Any?) -> String {
        switch value {
        case let value as String:
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        case let value as NSNumber:
            return value.stringValue
        case let value as Int:
            return String(value)
        case let value as Double:
            return String(value)
        case is NSNull, nil:
            return ""
        default:
            return String(describing: value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func timestampValue(_ value: Any?) -> Int? {
        if let number = intValue(value) {
            return number > 1_000_000_000_000 ? number / 1000 : number
        }
        let text = stringValue(value)
        guard !text.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: text) {
            return Int(date.timeIntervalSince1970)
        }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        for pattern in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"] {
            fallback.dateFormat = pattern
            if let date = fallback.date(from: text) {
                return Int(date.timeIntervalSince1970)
            }
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as Double where value.isFinite:
            return Int(value)
        case let value as String:
            guard let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)),
                  number.isFinite else {
                return nil
            }
            return Int(number)
        default:
            return nil
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
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
