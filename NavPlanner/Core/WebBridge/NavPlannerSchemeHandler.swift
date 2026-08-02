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
    private let workQueue = DispatchQueue(
        label: "com.navplanner.web-bridge",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let lock = NSLock()
    private var stoppedTasks = Set<ObjectIdentifier>()
    private static let transparentTile = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==") ?? Data()

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
            guard !self.consumeStoppedTask(taskID) else { return }
            let response = self.response(for: url, request: urlSchemeTask.request, taskID: taskID)
            self.deliver(response: response, to: urlSchemeTask)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        _ = lock.withLock {
            stoppedTasks.insert(taskID)
        }
    }

    private func response(
        for url: URL,
        request: URLRequest,
        taskID: ObjectIdentifier? = nil
    ) -> SchemeResponse {
        switch url.host {
        case "app":
            if url.path == "/api" || url.path.hasPrefix("/api/") {
                return apiResponse(for: url, request: request, taskID: taskID)
            }
            return appResourceResponse(for: url)
        case "api":
            return apiResponse(for: url, request: request, taskID: taskID)
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

    private func apiResponse(
        for url: URL,
        request: URLRequest,
        taskID: ObjectIdentifier? = nil
    ) -> SchemeResponse {
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
            return onlineTileResponse(pathComponents: pathComponents, taskID: taskID)
        }
        if pathComponents.first == "offline-maps" {
            return offlineMapsResponse(for: url, request: request, path: path, pathComponents: pathComponents)
        }
        if pathComponents.first == "databases" {
            return databasesResponse(for: request, path: path, queryValue: queryValue)
        }
        if pathComponents.first == "fr24" {
            return fr24Response(for: request, path: path, queryValue: queryValue)
        }
        if path == "/weather/open-meteo" {
            return openMeteoWeatherResponse(queryItems: query)
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
        if pathComponents.first == "procedure-preview", pathComponents.count == 3, request.httpMethod == "POST" {
            let type = pathComponents[1]
            let airport = pathComponents[2].removingPercentEncoding ?? pathComponents[2]
            let body = jsonBody(from: request)
            let selections = body["procedures"] as? [[String: Any]] ?? []
            return jsonResponse(plannerService.procedurePreviewPayload(
                type: type,
                airport: airport,
                selections: selections
            ))
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

    private func openMeteoWeatherResponse(queryItems: [URLQueryItem]) -> SchemeResponse {
        let allowedNames = Set([
            "latitude",
            "longitude",
            "hourly",
            "forecast_days",
            "timezone",
            "wind_speed_unit",
            "precipitation_unit",
            "models"
        ])
        let forwarded = queryItems.filter { item in
            guard allowedNames.contains(item.name),
                  let value = item.value,
                  !value.isEmpty,
                  value.count <= 900 else {
                return false
            }
            return true
        }
        guard forwarded.contains(where: { $0.name == "latitude" }),
              forwarded.contains(where: { $0.name == "longitude" }),
              forwarded.contains(where: { $0.name == "hourly" }) else {
            return jsonResponse(["error": "Invalid weather request"], statusCode: 400)
        }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = forwarded
        guard let url = components?.url else {
            return jsonResponse(["error": "Invalid weather URL"], statusCode: 400)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 14
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("NavPlanner iOS weather proxy", forHTTPHeaderField: "User-Agent")

        let semaphore = DispatchSemaphore(value: 0)
        var outputData: Data?
        var outputResponse: HTTPURLResponse?
        var outputError: Error?
        URLSession.shared.dataTask(with: request) { data, response, error in
            outputData = data
            outputResponse = response as? HTTPURLResponse
            outputError = error
            semaphore.signal()
        }.resume()
        if semaphore.wait(timeout: .now() + 16) == .timedOut {
            return jsonResponse(["error": "Weather request timed out"], statusCode: 504)
        }
        if let outputError {
            return jsonResponse(["error": "Weather request failed: \(outputError.localizedDescription)"], statusCode: 502)
        }
        let statusCode = outputResponse?.statusCode ?? 502
        let data = outputData ?? Data()
        let contentType = outputResponse?.value(forHTTPHeaderField: "Content-Type") ?? "application/json"
        var headers = cacheHeaders.merging([
            "Cache-Control": "no-store",
            "X-Weather-Source": "Open-Meteo"
        ]) { _, new in new }
        if let date = outputResponse?.value(forHTTPHeaderField: "Date") {
            headers["Date"] = date
            headers["X-Weather-Updated"] = date
        }
        return SchemeResponse(
            statusCode: statusCode,
            mimeType: contentType,
            data: data,
            headers: headers
        )
    }

    private func onlineTileResponse(
        pathComponents: [String],
        taskID: ObjectIdentifier? = nil
    ) -> SchemeResponse {
        let providerKey: String
        let zText: String
        let xText: String
        let yPath: String
        let coordinateStart: Int

        if pathComponents.first == "map-cache", pathComponents.count >= 5 {
            providerKey = pathComponents[1]
            coordinateStart = versionAdjustedIndex(in: pathComponents, defaultIndex: 2)
            guard pathComponents.count > coordinateStart + 2 else {
                return jsonResponse(["error": "Invalid map tile path"], statusCode: 404)
            }
            zText = pathComponents[coordinateStart]
            xText = pathComponents[coordinateStart + 1]
            yPath = pathComponents[coordinateStart + 2]
        } else if pathComponents.first == "terrain", pathComponents.count >= 5 {
            providerKey = pathComponents[1] == "terrarium" ? "terrain_terrarium" : pathComponents[1]
            coordinateStart = versionAdjustedIndex(in: pathComponents, defaultIndex: 2)
            guard pathComponents.count > coordinateStart + 2 else {
                return jsonResponse(["error": "Invalid terrain tile path"], statusCode: 404)
            }
            zText = pathComponents[coordinateStart]
            xText = pathComponents[coordinateStart + 1]
            yPath = pathComponents[coordinateStart + 2]
        } else {
            return jsonResponse(["error": "Invalid map tile path"], statusCode: 404)
        }

        let yText = (yPath as NSString).deletingPathExtension
        guard let z = Int(zText), let x = Int(xText), let y = Int(yText) else {
            return jsonResponse(["error": "Invalid map tile coordinate"], statusCode: 404)
        }
        let demandGeneration = onlineTileDemandGeneration(
            pathComponents: pathComponents,
            coordinateStart: coordinateStart
        )
        let shouldCancel = { [weak self] in
            guard let self, let taskID else { return false }
            return self.isStoppedTask(taskID)
        }

        let initialState = onlineTileCache.tile(
            providerKey: providerKey,
            z: z,
            x: x,
            y: y,
            waitForDownload: 0,
            demandGeneration: demandGeneration,
            priority: .visible,
            shouldCancel: shouldCancel
        )
        if case let .hit(data, contentType) = initialState {
            return onlineTileHitResponse(data: data, contentType: contentType)
        }

        // 优先复用最多三级的已有祖先瓦片作为低清预览。只下载最近一级父瓦片，
        // 避免为了预览额外放大队列；父瓦片一张仍可覆盖四张当前瓦片。
        let allowsParentFallback = pathComponents.first == "map-cache" && z > 0
        let fallbackCoordinates: [(levels: Int, z: Int, x: Int, y: Int)] = allowsParentFallback
            ? (1...min(3, z)).map { levels in
                (levels, z - levels, x >> levels, y >> levels)
            }
            : []
        for coordinate in fallbackCoordinates {
            if case let .hit(data, contentType) = onlineTileCache.cachedTile(
                providerKey: providerKey,
                z: coordinate.z,
                x: coordinate.x,
                y: coordinate.y
            ) {
                return onlineTileFallbackResponse(
                    data: data,
                    contentType: contentType,
                    sourceZoom: coordinate.z,
                    fallbackLevels: coordinate.levels,
                    targetState: initialState
                )
            }
        }

        let parentCoordinate = fallbackCoordinates.first
        if allowsParentFallback {
            _ = onlineTileCache.tile(
                providerKey: providerKey,
                z: parentCoordinate?.z ?? z - 1,
                x: parentCoordinate?.x ?? x >> 1,
                y: parentCoordinate?.y ?? y >> 1,
                waitForDownload: 0,
                demandGeneration: demandGeneration,
                priority: .preview,
                shouldCancel: shouldCancel
            )
        }

        let finalState: OnlineTileCache.TileState
        switch initialState {
        case .queued, .pending:
            finalState = onlineTileCache.tile(
                providerKey: providerKey,
                z: z,
                x: x,
                y: y,
                waitForDownload: OnlineTileCache.tileResponseWaitTimeout,
                demandGeneration: demandGeneration,
                priority: .visible,
                shouldCancel: shouldCancel
            )
        case .failed:
            finalState = initialState
        case .hit:
            finalState = initialState
        }

        if case let .hit(data, contentType) = finalState {
            return onlineTileHitResponse(data: data, contentType: contentType)
        }
        for coordinate in fallbackCoordinates {
            if case let .hit(data, contentType) = onlineTileCache.cachedTile(
                providerKey: providerKey,
                z: coordinate.z,
                x: coordinate.x,
                y: coordinate.y
            ) {
                return onlineTileFallbackResponse(
                    data: data,
                    contentType: contentType,
                    sourceZoom: coordinate.z,
                    fallbackLevels: coordinate.levels,
                    targetState: finalState
                )
            }
        }

        switch finalState {
        case .queued:
            return placeholderTileResponse(cacheState: "QUEUED")
        case .pending:
            return placeholderTileResponse(cacheState: "PENDING")
        case .failed:
            return placeholderTileResponse(cacheState: "MISS")
        case let .hit(data, contentType):
            return onlineTileHitResponse(data: data, contentType: contentType)
        }
    }

    private func onlineTileHitResponse(data: Data, contentType: String) -> SchemeResponse {
        SchemeResponse(
            statusCode: 200,
            mimeType: contentType,
            data: data,
            headers: cacheHeaders.merging([
                "Cache-Control": "public, max-age=31536000, immutable",
                "X-Map-Cache": "HIT"
            ]) { _, new in new }
        )
    }

    private func onlineTileFallbackResponse(
        data: Data,
        contentType: String,
        sourceZoom: Int,
        fallbackLevels: Int,
        targetState: OnlineTileCache.TileState
    ) -> SchemeResponse {
        SchemeResponse(
            statusCode: 200,
            mimeType: contentType,
            data: data,
            headers: cacheHeaders.merging([
                "Cache-Control": "no-store",
                "X-Map-Cache": "FALLBACK",
                "X-Map-Fallback-Levels": String(fallbackLevels),
                "X-Map-Fallback-Zoom": String(sourceZoom),
                "X-Map-Fallback-Target-State": onlineTileStateName(targetState)
            ]) { _, new in new }
        )
    }

    private func onlineTileStateName(_ state: OnlineTileCache.TileState) -> String {
        switch state {
        case .hit: "HIT"
        case .queued: "QUEUED"
        case .pending: "PENDING"
        case .failed: "MISS"
        }
    }

    private func onlineTileDemandGeneration(
        pathComponents: [String],
        coordinateStart: Int
    ) -> UInt64 {
        let suffixStart = coordinateStart + 3
        guard pathComponents.count > suffixStart + 1,
              pathComponents[suffixStart] == "demand"
        else {
            return 0
        }
        return UInt64(pathComponents[suffixStart + 1]) ?? 0
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

    private func databasesResponse(
        for request: URLRequest,
        path: String,
        queryValue: (String, String) -> String
    ) -> SchemeResponse {
        if path == "/databases/list" {
            let payload = plannerService.databaseListPayload(
                query: queryValue("query", ""),
                limit: Int(queryValue("limit", "200")) ?? 200
            )
            return jsonResponse(payload, statusCode: payload["error"] == nil ? 200 : 500)
        }
        if path == "/databases/select", request.httpMethod == "POST" {
            do {
                let body = jsonBody(from: request)
                return jsonResponse(try plannerService.selectDatabasePayload(name: body["name"] as? String ?? ""))
            } catch {
                return jsonResponse(["error": error.localizedDescription], statusCode: 400)
            }
        }
        if path == "/databases/delete", request.httpMethod == "POST" {
            do {
                let body = jsonBody(from: request)
                return jsonResponse(try plannerService.deleteDatabasePayload(name: body["name"] as? String ?? ""))
            } catch {
                return jsonResponse(["error": error.localizedDescription], statusCode: 400)
            }
        }
        if path == "/databases/restore-bundled", request.httpMethod == "POST" {
            do {
                return jsonResponse(try plannerService.restoreBundledDatabasePayload())
            } catch {
                return jsonResponse(["error": error.localizedDescription], statusCode: 400)
            }
        }
        return jsonResponse(["error": "Database API not found"], statusCode: 404)
    }

    private func fr24Response(
        for request: URLRequest,
        path: String,
        queryValue: (String, String) -> String
    ) -> SchemeResponse {
        if path == "/fr24/cache/status" {
            return jsonResponse(fr24Service.cacheStatusPayload())
        }
        if path == "/fr24/cache/list" {
            return jsonResponse(fr24Service.cacheListPayload(
                query: queryValue("query", ""),
                limit: Int(queryValue("limit", "120")) ?? 120
            ))
        }
        if path == "/fr24/cache/delete", request.httpMethod == "POST" {
            let body = jsonBody(from: request)
            let cacheKey = body["cache_key"] as? String ?? body["cacheKey"] as? String ?? ""
            let payload = fr24Service.deleteCacheItemPayload(cacheKey: cacheKey)
            return jsonResponse(payload, statusCode: payload["error"] == nil ? 200 : 404)
        }
        if path == "/fr24/cache/favorite", request.httpMethod == "POST" {
            let body = jsonBody(from: request)
            let cacheKey = body["cache_key"] as? String ?? body["cacheKey"] as? String ?? ""
            let favorite = (body["favorite"] as? Bool)
                ?? (body["favorite"] as? NSNumber)?.boolValue
                ?? false
            let payload = fr24Service.updateCacheFavoritePayload(cacheKey: cacheKey, favorite: favorite)
            return jsonResponse(payload, statusCode: payload["error"] == nil ? 200 : 404)
        }
        if path == "/fr24/cache/share", request.httpMethod == "POST" {
            let body = jsonBody(from: request)
            let cacheKey = body["cache_key"] as? String ?? body["cacheKey"] as? String ?? ""
            let payload = fr24Service.shareCacheItemPayload(cacheKey: cacheKey)
            return jsonResponse(payload, statusCode: payload["error"] == nil ? 200 : 404)
        }
        if path == "/fr24/cache/clear", request.httpMethod == "POST" {
            let body = jsonBody(from: request)
            let includeFavorites = body["include_favorites"] as? Bool
                ?? body["includeFavorites"] as? Bool
                ?? false
            return jsonResponse(fr24Service.clearCachePayload(includeFavorites: includeFavorites))
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
        if path == "/fr24/manual-history" {
            let departure = queryValue("departure", "")
            let arrival = queryValue("arrival", "")
            var routeAirports: [String: Any] = ["departure": [String: Any](), "arrival": [String: Any]()]
            if !departure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !arrival.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let resolved = plannerService.fr24RouteAirportsPayload(departure: departure, arrival: arrival)
                if resolved["error"] == nil {
                    routeAirports = resolved
                }
            }
            let payload = fr24Service.manualHistoryPayload(
                routeAirports: routeAirports,
                query: queryValue("query", ""),
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
        let coordinateStart = versionAdjustedIndex(in: parts, defaultIndex: 2)
        guard parts.count >= 5,
              parts[0] == "offline-maps",
              parts[1] == "tile",
              parts.count > coordinateStart + 2,
              let z = Int(parts[coordinateStart]),
              let x = Int(parts[coordinateStart + 1]) else {
            return jsonResponse(["error": "Invalid tile path"], statusCode: 404)
        }
        let yText = (parts[coordinateStart + 2] as NSString).deletingPathExtension
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
        let coordinateStart = versionAdjustedIndex(in: parts, defaultIndex: 3)
        guard parts.count >= 6,
              parts[0] == "offline-maps",
              parts[1] == "resource",
              parts.count > coordinateStart + 2,
              let z = Int(parts[coordinateStart]),
              let x = Int(parts[coordinateStart + 1]) else {
            return jsonResponse(["error": "Invalid offline resource tile path"], statusCode: 404)
        }
        let name = parts[2].removingPercentEncoding ?? parts[2]
        let yText = (parts[coordinateStart + 2] as NSString).deletingPathExtension
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
        let filenameIndex = versionAdjustedIndex(in: pathComponents, defaultIndex: 2)
        guard pathComponents.count > filenameIndex,
              pathComponents[0] == "offline-maps",
              pathComponents[1] == "pmtiles" else {
            return jsonResponse(["error": "Invalid PMTiles path"], statusCode: 404)
        }
        let filename = pathComponents[filenameIndex].removingPercentEncoding ?? pathComponents[filenameIndex]
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

    private func versionAdjustedIndex(in parts: [String], defaultIndex: Int) -> Int {
        guard parts.indices.contains(defaultIndex),
              parts[defaultIndex].hasPrefix("_v") else {
            return defaultIndex
        }
        return defaultIndex + 1
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
            guard !self.consumeStoppedTask(taskID) else { return }
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

    private func isStoppedTask(_ taskID: ObjectIdentifier) -> Bool {
        lock.withLock {
            stoppedTasks.contains(taskID)
        }
    }

    @discardableResult
    private func consumeStoppedTask(_ taskID: ObjectIdentifier) -> Bool {
        lock.withLock {
            stoppedTasks.remove(taskID) != nil
        }
    }

    private var cacheHeaders: [String: String] {
        [
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Expose-Headers": [
                "Accept-Ranges",
                "Content-Length",
                "Content-Range",
                "Date",
                "ETag",
                "X-Map-Cache",
                "X-Map-Fallback-Levels",
                "X-Map-Fallback-Target-State",
                "X-Map-Fallback-Zoom",
                "X-Offline-Map",
                "X-Weather-Source",
                "X-Weather-Updated"
            ].joined(separator: ", "),
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
    private var pendingPageWaitsForStableResult = false
    private var pendingPageReadStartedAt: Date?
    private var pendingPageBestText = ""
    private var pendingPageBestScore = -1
    private var pendingPageLastSignature = ""
    private var pendingPageStableReadCount = 0

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
                readDelay: 0.45,
                waitForStableResult: true
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
        waitForStableResult: Bool = false,
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
        pendingPageWaitsForStableResult = waitForStableResult
        pendingPageReadStartedAt = nil
        pendingPageBestText = ""
        pendingPageBestScore = -1
        pendingPageLastSignature = ""
        pendingPageStableReadCount = 0
        let pageTimeout: TimeInterval = waitForStableResult ? 29 : 24
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: pageTimeout
        )
        request.setValue(acceptHeader, forHTTPHeaderField: "Accept")
        request.setValue("https://www.flightradar24.com/", forHTTPHeaderField: "Referer")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        webView.load(request)
        DispatchQueue.main.asyncAfter(deadline: .now() + pageTimeout) { [weak self] in
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
      const collectRows = (nodes) => {
        for (const node of nodes) {
          const text = clean(node.innerText || node.textContent || "");
          if (text.length < 18 || text.length > 1800) {
            continue;
          }
          const hrefs = linksFor(node);
          const dateMatch = text.match(/\b\d{1,2}\s+[A-Za-z]{3}\s+20\d{2}\b/);
          const hasFlightStatus = /\b(STD|ATD|STA|ETA|Landed|Scheduled|Cancelled|Canceled|Diverted|Unknown|KML|CSV|Play)\b/i.test(text);
          const instanceLink = hrefs.find((link) => /(?:flightId=|\/flight\/|\/data\/flights\/[^/#?\s]+#[0-9a-f]{6,12}\b)/i.test(link.href));
          if (!dateMatch || (!hasFlightStatus && !instanceLink)) {
            continue;
          }
          const instanceKey = instanceLink?.href.match(/(?:flightId=|#)([0-9a-f]{6,12})\b/i)?.[1] || "";
          const key = `${dateMatch[0]}|${instanceKey}|${text}`;
          if (seen.has(key)) {
            continue;
          }
          seen.add(key);
          rows.push({ text, hrefs, cells: cellsFor(node), headers: headersFor(node) });
          if (rows.length >= 160) {
            break;
          }
        }
      };
      const tableRows = Array.from(document.querySelectorAll("table tbody tr, table [role='row'], [role='table'] [role='row'], [role='grid'] [role='row']"));
      collectRows(tableRows);
      if (!rows.length) {
        const fallbackRows = Array.from(document.querySelectorAll("tr, [role='row'], li, article, [class*='flight'], [class*='history'], [class*='row']"))
          .filter((node) => !node.querySelector("tr, [role='row']"));
        collectRows(fallbackRows);
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
        guard pendingPageCompletion != nil, pendingPageReadStartedAt == nil else { return }
        pendingPageReadStartedAt = Date()
        readPendingPage(from: webView, after: pendingPageReadDelay)
    }

    private func readPendingPage(from webView: WKWebView, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
            guard let self, self.pendingPageCompletion != nil else { return }
            guard let webView else {
                self.finishPendingPage(.failure(BrowserError(message: "FR24 web request failed.")))
                return
            }
            let script = self.pendingPageReadScript
            webView.evaluateJavaScript(script) { [weak self, weak webView] result, error in
                guard let self, self.pendingPageCompletion != nil else { return }
                if let error {
                    self.finishPendingPage(.failure(BrowserError(message: "FR24 web response could not be read: \(error.localizedDescription)")))
                    return
                }
                let text = result as? String ?? ""
                guard self.pendingPageWaitsForStableResult else {
                    self.finishPendingPage(.success(PageResponse(
                        status: self.pendingPageStatus,
                        contentType: self.pendingPageContentType,
                        text: text
                    )))
                    return
                }

                let metrics = self.historySnapshotMetrics(text)
                if metrics.score > self.pendingPageBestScore {
                    self.pendingPageBestScore = metrics.score
                    self.pendingPageBestText = text
                }
                if metrics.signature == self.pendingPageLastSignature {
                    self.pendingPageStableReadCount += 1
                } else {
                    self.pendingPageLastSignature = metrics.signature
                    self.pendingPageStableReadCount = 0
                }

                let elapsed = Date().timeIntervalSince(self.pendingPageReadStartedAt ?? Date())
                let isStable = elapsed >= 3.0 && self.pendingPageStableReadCount >= 2
                if isStable || elapsed >= 6.0 {
                    self.finishPendingPage(.success(PageResponse(
                        status: self.pendingPageStatus,
                        contentType: self.pendingPageContentType,
                        text: self.pendingPageBestText.isEmpty ? text : self.pendingPageBestText
                    )))
                    return
                }
                guard let webView else {
                    self.finishPendingPage(.failure(BrowserError(message: "FR24 web request failed.")))
                    return
                }
                self.readPendingPage(from: webView, after: 0.45)
            }
        }
    }

    private func historySnapshotMetrics(_ text: String) -> (score: Int, signature: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (text.count, "invalid|\(text.count)|\(text.hashValue)")
        }
        let rows = object["rows"] as? [[String: Any]] ?? []
        let rowText = rows.map { Self.stringValue($0["text"]) }.joined(separator: "|")
        let bodyText = Self.stringValue(object["bodyText"])
        let score = rows.count * 10_000_000 + min(rowText.count, 900_000) * 10 + min(bodyText.count, 999_999)
        return (score, "\(rows.count)|\(bodyText.count)|\(rowText.hashValue)")
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
        pendingPageWaitsForStableResult = false
        pendingPageReadStartedAt = nil
        pendingPageBestText = ""
        pendingPageBestScore = -1
        pendingPageLastSignature = ""
        pendingPageStableReadCount = 0
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

    static func extractFlightNumber(from text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        for pattern in [
            #"/data/flights/([A-Za-z0-9]{2,8})"#,
            #"^([A-Za-z]{1,3}\d{1,4}[A-Za-z]?)$"#
        ] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               let range = Range(match.range(at: 1), in: value) {
                let token = String(value[range]).uppercased().filter { $0.isLetter || $0.isNumber }
                return token.isEmpty ? nil : token
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

    func cacheListPayload(query: String, limit: Int) -> [String: Any] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let loweredQuery = trimmedQuery.lowercased()
        let normalizedQuery = normalizedFlightToken(trimmedQuery).lowercased()
        let clampedLimit = max(1, min(limit, 300))
        let items = cachedFlightItems()
            .filter { item in
                guard !loweredQuery.isEmpty || !normalizedQuery.isEmpty else { return true }
                let searchable = [
                    Self.stringValue(item["cache_key"]),
                    Self.stringValue(item["fr24_id"]),
                    Self.stringValue(item["flight"]),
                    Self.stringValue(item["callsign"]),
                    Self.stringValue(item["airline"]),
                    Self.stringValue(item["aircraft"]),
                    Self.stringValue(item["aircraft_registration"]),
                    Self.stringValue(item["origin_icao"]),
                    Self.stringValue(item["origin_iata"]),
                    Self.stringValue(item["origin_actual_code"]),
                    Self.stringValue(item["dest_icao"]),
                    Self.stringValue(item["dest_iata"]),
                    Self.stringValue(item["dest_actual_code"]),
                    Self.stringValue(item["gpx_filename"])
                ].joined(separator: " ").lowercased()
                let normalizedSearchable = normalizedFlightToken(searchable).lowercased()
                return (!loweredQuery.isEmpty && searchable.contains(loweredQuery))
                    || (!normalizedQuery.isEmpty && normalizedSearchable.contains(normalizedQuery))
            }
            .prefix(clampedLimit)
        return [
            "items": Array(items),
            "cache": cacheStatusPayload(),
            "message": "已读取 FR24 下载缓存。"
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

    func clearCachePayload(includeFavorites: Bool = false) -> [String: Any] {
        let favoriteKeys = Set(cachedFlightItems()
            .filter { ($0["favorite"] as? Bool) == true }
            .map { Self.stringValue($0["cache_key"]) }
            .filter { !$0.isEmpty })
        let favoritePaths = Set(favoriteKeys.flatMap { cacheKey in
            cacheFileURLs(cacheKey: cacheKey).map { $0.standardizedFileURL.path }
        })
        var preservedFavorites = 0
        if let items = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil,
            options: []
        ) {
            for item in items {
                if !includeFavorites && favoritePaths.contains(item.standardizedFileURL.path) {
                    preservedFavorites += 1
                    continue
                }
                try? fileManager.removeItem(at: item)
            }
        }
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        var payload = cacheStatusPayload()
        payload["preserved_favorite_file_count"] = preservedFavorites
        payload["favorite_count"] = includeFavorites ? 0 : favoriteKeys.count
        payload["message"] = includeFavorites ? "已清理全部 FR24 轨迹缓存。" : "已清理 FR24 轨迹缓存。"
        return payload
    }

    func deleteCacheItemPayload(cacheKey: String) -> [String: Any] {
        let normalizedKey = sanitizeCacheKey(cacheKey)
        guard !normalizedKey.isEmpty else {
            return ["error": "FR24 cache key missing.", "cache": cacheStatusPayload()]
        }
        var removed = 0
        for url in cacheFileURLs(cacheKey: normalizedKey) where fileManager.fileExists(atPath: url.path) {
            if (try? fileManager.removeItem(at: url)) != nil {
                removed += 1
            }
        }
        guard removed > 0 else {
            return ["error": "FR24 cache item not found.", "cache": cacheStatusPayload()]
        }
        return [
            "cache_key": normalizedKey,
            "removed_file_count": removed,
            "cache": cacheStatusPayload(),
            "message": "已删除 FR24 缓存文件。"
        ]
    }

    func updateCacheFavoritePayload(cacheKey: String, favorite: Bool) -> [String: Any] {
        let normalizedKey = sanitizeCacheKey(cacheKey)
        guard !normalizedKey.isEmpty else {
            return ["error": "FR24 cache key missing.", "cache": cacheStatusPayload()]
        }
        guard var meta = readCacheMeta(cacheKey: normalizedKey) else {
            return ["error": "FR24 cache item not found.", "cache": cacheStatusPayload()]
        }
        meta["favorite"] = favorite
        writeCacheMeta(meta, cacheKey: normalizedKey)
        guard let item = cacheItem(cacheKey: normalizedKey, meta: meta) else {
            return ["error": "FR24 cache item not found.", "cache": cacheStatusPayload()]
        }
        return [
            "item": item,
            "cache": cacheStatusPayload(),
            "message": favorite ? "已收藏 FR24 缓存文件。" : "已取消收藏 FR24 缓存文件。"
        ]
    }

    func shareCacheItemPayload(cacheKey: String) -> [String: Any] {
        let normalizedKey = sanitizeCacheKey(cacheKey)
        guard !normalizedKey.isEmpty else {
            return ["error": "FR24 cache key missing.", "cache": cacheStatusPayload()]
        }
        guard var meta = readCacheMeta(cacheKey: normalizedKey) else {
            return ["error": "FR24 cache item not found.", "cache": cacheStatusPayload()]
        }
        let trackPoints = meta["track_points"] as? [[String: Any]] ?? []
        var flight = (meta["flight"] as? [String: Any]) ?? [:]
        if Self.stringValue(flight["fr24_id"]).isEmpty {
            flight["fr24_id"] = normalizedKey
        }
        flight["cache_key"] = normalizedKey
        let targetURL: URL
        if trackPoints.count >= 2,
           let gpxURL = try? writeGPXCacheFile(
            cacheKey: normalizedKey,
            flight: flight,
            trackPoints: trackPoints,
            previousMeta: meta
           ) {
            meta["gpx_filename"] = gpxURL.lastPathComponent
            meta["gpx_path"] = gpxURL.path
            meta["flight"] = flight
            writeCacheMeta(meta, cacheKey: normalizedKey)
            targetURL = gpxURL
        } else if let sourceURL = cacheGPXURL(cacheKey: normalizedKey, meta: meta),
                  fileManager.fileExists(atPath: sourceURL.path) {
            let shareDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("NavPlannerFR24Share", isDirectory: true)
            try? fileManager.createDirectory(at: shareDirectory, withIntermediateDirectories: true)
            let filename = displayGPXFilename(cacheKey: normalizedKey, flight: flight, trackPoints: trackPoints)
            let shareURL = shareDirectory.appendingPathComponent(filename)
            try? fileManager.removeItem(at: shareURL)
            do {
                try fileManager.copyItem(at: sourceURL, to: shareURL)
                targetURL = shareURL
            } catch {
                return [
                    "error": "无法准备 FR24 GPX 分享文件：\(error.localizedDescription)",
                    "cache": cacheStatusPayload()
                ]
            }
        } else {
            return ["error": "FR24 cache GPX file not found.", "cache": cacheStatusPayload()]
        }
        return [
            "cache_key": normalizedKey,
            "filename": targetURL.lastPathComponent,
            "share_path": targetURL.path,
            "gpx_path": targetURL.path,
            "cache": cacheStatusPayload(),
            "message": "已准备 FR24 GPX 分享文件。"
        ]
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

    func manualHistoryPayload(
        routeAirports: [String: Any],
        query: String,
        limit: Int
    ) -> [String: Any] {
        let rawQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawQuery.isEmpty else {
            return [
                "error": "FR24 flight number missing.",
                "flights": [],
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload()
            ]
        }
        if let tokenFromURL = Self.extractFlightNumber(from: rawQuery) {
            return historyPayload(routeAirports: routeAirports, flightNumber: tokenFromURL, callsign: "", limit: limit)
        }
        if let flightID = Self.extractFlightID(from: rawQuery),
           normalizedFlightToken(rawQuery).lowercased() == flightID.lowercased() {
            var flight = manualFlightIDPayload(flightID: flightID)
            var message = "已按 FR24 flightId 生成单条历史记录。"
            do {
                let playback = try webGet(path: "/common/v1/flight-playback.json", params: [
                    ("flightId", flightID),
                    ("timestamp", String(Int(Date().timeIntervalSince1970)))
                ])
                let trackPoints = extractPlaybackTrackPoints(playback)
                flight = enrichedFlightPayload(
                    flightID: flightID,
                    flight: flight,
                    playback: playback,
                    trackPoints: trackPoints,
                    routeAirports: routeAirports
                )
                message = "已按 FR24 flightId 读取航班基本信息。"
            } catch {
                flight["metadata_error"] = error.localizedDescription
            }
            return [
                "route": routeAirports,
                "flights": [flight],
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload(),
                "message": message
            ]
        }
        return historyPayload(routeAirports: routeAirports, flightNumber: rawQuery, callsign: "", limit: limit)
    }

    private func manualFlightIDPayload(flightID: String) -> [String: Any] {
        [
            "fr24_id": flightID,
            "flight": "",
            "callsign": "",
            "airline": "",
            "aircraft": "",
            "aircraft_registration": "",
            "origin_icao": "",
            "origin_iata": "",
            "origin_actual_code": "",
            "origin_name": "",
            "dest_icao": "",
            "dest_iata": "",
            "dest_actual_code": "",
            "dest_name": "",
            "status": "flightId",
            "timestamp": 0,
            "scheduled_departure": NSNull(),
            "scheduled_arrival": NSNull(),
            "actual_departure": NSNull(),
            "actual_arrival": NSNull(),
            "estimated_departure": NSNull(),
            "estimated_arrival": NSNull(),
            "duration_seconds": NSNull(),
            "source_provider": "Flightradar24 flightId"
        ]
    }

    private func enrichedFlightPayload(
        flightID: String,
        flight: [String: Any],
        playback: [String: Any],
        trackPoints: [[String: Any]],
        routeAirports: [String: Any] = [:]
    ) -> [String: Any] {
        let departure = routeAirports["departure"] as? [String: Any] ?? [:]
        let arrival = routeAirports["arrival"] as? [String: Any] ?? [:]
        let candidates = playbackFlightInfoCandidates(playback)
        let best = candidates
            .map { normalizeOfficialFlight($0, departure: departure, arrival: arrival) }
            .max { flightInfoScore($0) < flightInfoScore($1) }
        var output = best ?? manualFlightIDPayload(flightID: flightID)
        output["fr24_id"] = Self.stringValue(output["fr24_id"]).isEmpty ? flightID : Self.stringValue(output["fr24_id"])

        for (key, value) in flight where !hasMeaningfulFlightValue(output[key]) && hasMeaningfulFlightValue(value) {
            output[key] = value
        }
        if !hasMeaningfulFlightValue(output["timestamp"]),
           let firstTimestamp = trackPoints.compactMap({ Self.intValue($0["timestamp"]) }).map(normalizedTimestamp).first {
            output["timestamp"] = firstTimestamp
        }
        if !hasMeaningfulFlightValue(output["actual_departure"]),
           let firstTimestamp = trackPoints.compactMap({ Self.intValue($0["timestamp"]) }).map(normalizedTimestamp).first {
            output["actual_departure"] = firstTimestamp
        }
        if Self.stringValue(output["source_provider"]).isEmpty {
            output["source_provider"] = "Flightradar24 playback"
        }
        return output
    }

    private func playbackFlightInfoCandidates(_ payload: [String: Any]) -> [[String: Any]] {
        var candidates: [[String: Any]] = []
        func visit(_ item: Any) {
            guard candidates.count < 300 else { return }
            if let dictionary = item as? [String: Any] {
                candidates.append(dictionary)
                dictionary.values.forEach(visit)
            } else if let array = item as? [Any], array.count < 80 {
                array.forEach(visit)
            }
        }
        visit(payload)
        return candidates
    }

    private func flightInfoScore(_ flight: [String: Any]) -> Int {
        var score = 0
        if !Self.stringValue(flight["flight"]).isEmpty { score += 6 }
        if !Self.stringValue(flight["callsign"]).isEmpty { score += 4 }
        if !Self.stringValue(flight["aircraft_registration"]).isEmpty { score += 5 }
        if !Self.stringValue(flight["aircraft"]).isEmpty { score += 2 }
        if !Self.stringValue(flight["airline"]).isEmpty { score += 2 }
        if !Self.stringValue(flight["origin_icao"]).isEmpty || !Self.stringValue(flight["origin_iata"]).isEmpty { score += 2 }
        if !Self.stringValue(flight["dest_icao"]).isEmpty || !Self.stringValue(flight["dest_iata"]).isEmpty { score += 2 }
        if hasMeaningfulFlightValue(flight["actual_departure"]) || hasMeaningfulFlightValue(flight["scheduled_departure"]) { score += 3 }
        if hasMeaningfulFlightValue(flight["timestamp"]) { score += 2 }
        return score
    }

    private func hasMeaningfulFlightValue(_ value: Any?) -> Bool {
        switch value {
        case let value as String:
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case let value as NSNumber:
            return value.doubleValue != 0
        case let value as Int:
            return value != 0
        case let value as Double:
            return value.isFinite && value != 0
        case is NSNull, nil:
            return false
        default:
            return !Self.stringValue(value).isEmpty
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
                "origin_iata": Self.stringValue(departure["iata"]),
                "origin_name": Self.stringValue(departure["name"]),
                "dest_icao": Self.stringValue(arrival["icao"]),
                "dest_iata": Self.stringValue(arrival["iata"]),
                "dest_name": Self.stringValue(arrival["name"]),
                "status": status,
                "history_url": pageURL,
                "raw_history": text,
                "timestamp": actualDeparture ?? scheduledDeparture ?? dateTimestamp ?? 0,
                "source_provider": "Flightradar24 data page"
            ]
            annotateActualAirports(
                &publicFlight,
                expectedDeparture: departure,
                expectedArrival: arrival,
                parsedOriginCode: originCode,
                parsedDestinationCode: destinationCode
            )
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
        return sortedFlights(flights)
    }

    private func airportCodeSet(_ airport: [String: Any]) -> Set<String> {
        [
            Self.stringValue(airport["icao"]),
            Self.stringValue(airport["iata"]),
            Self.stringValue(airport["schedule_code"])
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
            .reduce(into: Set<String>()) { result, code in result.insert(code) }
    }

    private func annotateActualAirports(
        _ flight: inout [String: Any],
        expectedDeparture: [String: Any],
        expectedArrival: [String: Any],
        parsedOriginCode: String,
        parsedDestinationCode: String
    ) {
        let departureCodes = airportCodeSet(expectedDeparture)
        let arrivalCodes = airportCodeSet(expectedArrival)
        let actualOrigin = parsedOriginCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let actualDestination = parsedDestinationCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var mismatch = false
        if !actualOrigin.isEmpty, !departureCodes.contains(actualOrigin) {
            flight["origin_actual_code"] = actualOrigin
            mismatch = true
        }
        if !actualDestination.isEmpty, !arrivalCodes.contains(actualDestination) {
            flight["dest_actual_code"] = actualDestination
            mismatch = true
        }
        if mismatch {
            flight["actual_route_mismatch"] = true
        }
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
            let enrichedFlight = enrichedFlightPayload(
                flightID: flightID,
                flight: flight,
                playback: playback,
                trackPoints: trackPoints
            )
            return try cacheDownloadResponse(
                flightID: flightID,
                cacheKey: normalizedID,
                flight: enrichedFlight,
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
        let payload: [String: Any] = [
            "flight": flight,
            "track_points": trackPoints,
            "playback": playback
        ]
        if let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
            try? payloadData.write(to: jsonURL, options: [.atomic])
        }
        var publicFlight = flight
        publicFlight["fr24_id"] = flightID
        publicFlight["cache_key"] = cacheKey
        let existingMeta = readCacheMeta(cacheKey: cacheKey)
        let existingFavorite = existingMeta.flatMap { meta -> Bool? in
            (meta["favorite"] as? Bool) ?? (meta["favorite"] as? NSNumber)?.boolValue
        } ?? false
        publicFlight["favorite"] = existingFavorite
        let gpxURL = try writeGPXCacheFile(
            cacheKey: cacheKey,
            flight: publicFlight,
            trackPoints: trackPoints,
            previousMeta: existingMeta
        )
        let meta: [String: Any] = [
            "flight": publicFlight,
            "track_points": trackPoints,
            "gpx_filename": gpxURL.lastPathComponent,
            "gpx_path": gpxURL.path,
            "json_filename": jsonURL.lastPathComponent,
            "downloaded_at": Int(Date().timeIntervalSince1970),
            "favorite": existingFavorite
        ]
        writeCacheMeta(meta, cacheKey: cacheKey)
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
                ["aircraft", "model", "code"],
                ["aircraft", "model", "text"]
            ])),
            "aircraft_registration": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "aircraft", "identification", "registration"],
                ["flight", "aircraft", "registration"],
                ["registration"],
                ["reg"],
                ["aircraft_registration"],
                ["aircraft", "identification", "registration"],
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
            func firstFiniteDouble(_ values: [Any?]) -> Double? {
                for value in values {
                    if let number = Self.doubleValue(value), number.isFinite {
                        return number
                    }
                }
                return nil
            }

            func assignAltitude(_ altitudeFeet: Double?, _ altitudeMeters: Double?, to point: inout [String: Any]) {
                if let altitudeFeet, altitudeFeet.isFinite {
                    point["altitude"] = Int(altitudeFeet.rounded())
                    point["altitude_ft"] = altitudeFeet
                } else if let altitudeMeters, altitudeMeters.isFinite {
                    point["altitude_m"] = altitudeMeters
                    point["altitude_ft"] = altitudeMeters * 3.280839895
                    point["altitude"] = Int((altitudeMeters * 3.280839895).rounded())
                }
            }

            func assignSpeed(_ speedKnots: Double?, to point: inout [String: Any]) {
                if let speedKnots, speedKnots.isFinite {
                    point["speed"] = speedKnots
                    point["speed_kt"] = speedKnots
                }
            }

            func normalizedArrayPoint(_ array: [Any]) -> [String: Any]? {
                let layouts: [(timestamp: Int?, lat: Int, lon: Int, altitude: Int?, speed: Int?)] = [
                    (0, 1, 2, 3, 4),
                    (2, 0, 1, 3, 4),
                    (nil, 0, 1, 2, 3)
                ]
                for layout in layouts {
                    guard array.count > layout.lon,
                          let lat = Self.doubleValue(array[layout.lat]),
                          let lon = Self.doubleValue(array[layout.lon]),
                          lat.isFinite,
                          lon.isFinite,
                          abs(lat) <= 90,
                          abs(lon) <= 360 else {
                        continue
                    }
                    var point: [String: Any] = ["lat": lat, "lon": lon]
                    if let timestampIndex = layout.timestamp,
                       array.count > timestampIndex,
                       let timestamp = Self.timestampValue(array[timestampIndex]) {
                        point["timestamp"] = timestamp
                    }
                    let altitudeFeet = layout.altitude.flatMap { index -> Double? in
                        array.count > index ? Self.doubleValue(array[index]) : nil
                    }
                    let speedKnots = layout.speed.flatMap { index -> Double? in
                        array.count > index ? Self.doubleValue(array[index]) : nil
                    }
                    assignAltitude(altitudeFeet, nil, to: &point)
                    assignSpeed(speedKnots, to: &point)
                    return point
                }
                return nil
            }

            return items.compactMap { item -> [String: Any]? in
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
                    let altitudeFeet = firstFiniteDouble([
                        dictionary["altitude"],
                        dictionary["alt"],
                        dictionary["alt_ft"],
                        dictionary["altitude_ft"],
                        dictionary["altitudeFt"],
                        dictionary["altitude_feet"],
                        Self.deepValue(dictionary, path: ["altitude", "feet"]),
                        Self.deepValue(dictionary, path: ["altitude", "ft"])
                    ])
                    let altitudeMeters = firstFiniteDouble([
                        dictionary["altitude_m"],
                        dictionary["alt_m"],
                        dictionary["altitudeMeters"],
                        dictionary["altitude_meter"],
                        Self.deepValue(dictionary, path: ["altitude", "meters"]),
                        Self.deepValue(dictionary, path: ["altitude", "m"])
                    ])
                    assignAltitude(altitudeFeet, altitudeMeters, to: &point)
                    let speedKnots = firstFiniteDouble([
                        dictionary["speed"],
                        dictionary["spd"],
                        dictionary["speed_kt"],
                        dictionary["speed_kts"],
                        dictionary["speedKt"],
                        dictionary["speedKts"],
                        dictionary["ground_speed"],
                        dictionary["groundspeed"],
                        dictionary["groundSpeed"],
                        dictionary["ground_speed_kt"],
                        dictionary["gs"],
                        Self.deepValue(dictionary, path: ["speed", "kts"]),
                        Self.deepValue(dictionary, path: ["speed", "knots"]),
                        Self.deepValue(dictionary, path: ["groundSpeed", "knots"])
                    ])
                    assignSpeed(speedKnots, to: &point)
                    return point
                }
                if let array = item as? [Any], array.count >= 2 {
                    return normalizedArrayPoint(array)
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

    private func cacheFileURLs(cacheKey: String) -> [URL] {
        var urls = [
            rootDirectory.appendingPathComponent("\(cacheKey).gpx"),
            rootDirectory.appendingPathComponent("\(cacheKey).json"),
            rootDirectory.appendingPathComponent("\(cacheKey).meta.json")
        ]
        if let meta = readCacheMeta(cacheKey: cacheKey),
           let gpxURL = cacheGPXURL(cacheKey: cacheKey, meta: meta) {
            urls.append(gpxURL)
        }
        var seen: Set<String> = []
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }

    private func readCacheMeta(cacheKey: String) -> [String: Any]? {
        let metaURL = rootDirectory.appendingPathComponent("\(cacheKey).meta.json")
        guard let data = try? Data(contentsOf: metaURL),
              let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return meta
    }

    private func writeCacheMeta(_ meta: [String: Any], cacheKey: String) {
        let metaURL = rootDirectory.appendingPathComponent("\(cacheKey).meta.json")
        if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]) {
            try? metaData.write(to: metaURL, options: [.atomic])
        }
    }

    private func cacheGPXURL(cacheKey: String, meta: [String: Any]?) -> URL? {
        if let path = meta.flatMap({ Self.stringValue($0["gpx_path"]) }), !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        if let filename = meta.flatMap({ Self.stringValue($0["gpx_filename"]) }), !filename.isEmpty {
            return rootDirectory.appendingPathComponent(filename)
        }
        return rootDirectory.appendingPathComponent("\(cacheKey).gpx")
    }

    private func displayGPXFilename(
        cacheKey: String,
        flight: [String: Any],
        trackPoints: [[String: Any]]
    ) -> String {
        let timestamp = [
            Self.intValue(flight["actual_departure"]),
            Self.intValue(flight["scheduled_departure"]),
            Self.intValue(flight["timestamp"]),
            trackPoints.compactMap { Self.intValue($0["timestamp"]) }.first
        ].compactMap { $0 }.map(normalizedTimestamp).first ?? Int(Date().timeIntervalSince1970)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HHmmZ"
        let dateToken = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
        let flightToken = normalizedFlightToken(Self.stringValue(flight["flight"])).isEmpty
            ? normalizedFlightToken(Self.stringValue(flight["callsign"]))
            : normalizedFlightToken(Self.stringValue(flight["flight"]))
        let registration = filenameToken(Self.stringValue(flight["aircraft_registration"]), fallback: "REG")
        let identifier = filenameToken(Self.stringValue(flight["fr24_id"]).isEmpty ? cacheKey : Self.stringValue(flight["fr24_id"]), fallback: cacheKey)
        return "\(dateToken)_\(flightToken.isEmpty ? "FR24" : flightToken)_\(registration)_\(identifier).gpx"
    }

    private func filenameToken(_ value: String, fallback: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var output = ""
        for scalar in trimmed.unicodeScalars {
            if allowed.contains(scalar) {
                output += String(scalar)
            }
        }
        return output.isEmpty ? fallback : output
    }

    private func writeGPXCacheFile(
        cacheKey: String,
        flight: [String: Any],
        trackPoints: [[String: Any]],
        previousMeta: [String: Any]? = nil
    ) throws -> URL {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let filename = displayGPXFilename(cacheKey: cacheKey, flight: flight, trackPoints: trackPoints)
        let gpxURL = rootDirectory.appendingPathComponent(filename)
        let gpxText = gpxDocument(
            flightID: Self.stringValue(flight["fr24_id"]).isEmpty ? cacheKey : Self.stringValue(flight["fr24_id"]),
            flight: flight,
            trackPoints: trackPoints
        )
        try gpxText.data(using: .utf8)?.write(to: gpxURL, options: [.atomic])

        let oldURLs = [
            rootDirectory.appendingPathComponent("\(cacheKey).gpx"),
            cacheGPXURL(cacheKey: cacheKey, meta: previousMeta)
        ].compactMap { $0 }
        for oldURL in oldURLs where oldURL.standardizedFileURL.path != gpxURL.standardizedFileURL.path {
            try? fileManager.removeItem(at: oldURL)
        }
        return gpxURL
    }

    private func cachedFlightItems() -> [[String: Any]] {
        guard let metaURLs = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return metaURLs
            .filter { $0.lastPathComponent.hasSuffix(".meta.json") }
            .compactMap { url -> [String: Any]? in
                let cacheKey = url.lastPathComponent.replacingOccurrences(of: ".meta.json", with: "")
                guard let meta = readCacheMeta(cacheKey: cacheKey) else { return nil }
                return cacheItem(cacheKey: cacheKey, meta: meta)
            }
            .sorted { left, right in
                let leftTime = Self.intValue(left["downloaded_at"]) ?? Self.intValue(left["timestamp"]) ?? 0
                let rightTime = Self.intValue(right["downloaded_at"]) ?? Self.intValue(right["timestamp"]) ?? 0
                if leftTime != rightTime {
                    return leftTime > rightTime
                }
                return Self.stringValue(left["cache_key"]) < Self.stringValue(right["cache_key"])
            }
    }

    private func cacheItem(cacheKey: String, meta: [String: Any]) -> [String: Any]? {
        let trackPoints = meta["track_points"] as? [[String: Any]] ?? []
        let gpxURL = cacheGPXURL(cacheKey: cacheKey, meta: meta)
            ?? rootDirectory.appendingPathComponent("\(cacheKey).gpx")
        let jsonURL = rootDirectory.appendingPathComponent("\(cacheKey).json")
        guard fileManager.fileExists(atPath: gpxURL.path) || fileManager.fileExists(atPath: jsonURL.path) || !trackPoints.isEmpty else {
            return nil
        }
        var item = (meta["flight"] as? [String: Any]) ?? [:]
        if Self.stringValue(item["fr24_id"]).isEmpty {
            item["fr24_id"] = cacheKey
        }
        item["cache_key"] = cacheKey
        item["cache_hit"] = true
        item["favorite"] = (meta["favorite"] as? Bool) ?? (meta["favorite"] as? NSNumber)?.boolValue ?? false
        item["downloaded_at"] = Self.intValue(meta["downloaded_at"]) ?? NSNull()
        item["track_point_count"] = trackPoints.count
        item["gpx_filename"] = gpxURL.lastPathComponent
        item["gpx_path"] = gpxURL.path
        item["json_filename"] = Self.stringValue(meta["json_filename"]).isEmpty ? jsonURL.lastPathComponent : Self.stringValue(meta["json_filename"])
        return item
    }

    private func cachedDownloadPayload(cacheKey: String, flight: [String: Any]) -> [String: Any]? {
        guard let meta = readCacheMeta(cacheKey: cacheKey),
              var trackPoints = meta["track_points"] as? [[String: Any]],
              trackPoints.count >= 2 else {
            return nil
        }
        var refreshedMeta = meta
        var cachedFlight = (meta["flight"] as? [String: Any]) ?? flight
        let jsonURL = rootDirectory.appendingPathComponent("\(cacheKey).json")
        if let data = try? Data(contentsOf: jsonURL),
           let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let playback = payload["playback"] as? [String: Any] {
            let extractedPoints = extractPlaybackTrackPoints(playback)
            if extractedPoints.count >= 2 {
                trackPoints = extractedPoints
                refreshedMeta["track_points"] = extractedPoints
                writeCacheMeta(refreshedMeta, cacheKey: cacheKey)
            }
            let flightID = Self.stringValue(cachedFlight["fr24_id"]).isEmpty ? cacheKey : Self.stringValue(cachedFlight["fr24_id"])
            cachedFlight = enrichedFlightPayload(
                flightID: flightID,
                flight: cachedFlight,
                playback: playback,
                trackPoints: trackPoints
            )
        }
        cachedFlight["favorite"] = (meta["favorite"] as? Bool) ?? (meta["favorite"] as? NSNumber)?.boolValue ?? false
        cachedFlight["cache_key"] = cacheKey
        if let gpxURL = try? writeGPXCacheFile(
            cacheKey: cacheKey,
            flight: cachedFlight,
            trackPoints: trackPoints,
            previousMeta: meta
        ) {
            refreshedMeta["gpx_filename"] = gpxURL.lastPathComponent
            refreshedMeta["gpx_path"] = gpxURL.path
            refreshedMeta["track_points"] = trackPoints
            refreshedMeta["flight"] = cachedFlight
            writeCacheMeta(refreshedMeta, cacheKey: cacheKey)
        }
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
        let meta = readCacheMeta(cacheKey: cacheKey)
        let gpxURL = cacheGPXURL(cacheKey: cacheKey, meta: meta)
            ?? rootDirectory.appendingPathComponent("\(cacheKey).gpx")
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
            let altitudeFeet = Self.doubleValue(point["altitude_ft"]) ?? Self.doubleValue(point["altitude"])
            let speedKnots = Self.doubleValue(point["speed_kt"]) ?? Self.doubleValue(point["speed"])
            var children: [String] = []
            if let altitudeFeet, altitudeFeet.isFinite {
                children.append("<ele>\(gpxNumber(altitudeFeet * 0.3048, decimals: 1))</ele>")
            }
            if let time {
                children.append("<time>\(xmlEscape(isoFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(time)))))</time>")
            }
            var extensionChildren: [String] = []
            if let altitudeFeet, altitudeFeet.isFinite {
                extensionChildren.append("<navplanner:altitude_ft>\(gpxNumber(altitudeFeet, decimals: 0))</navplanner:altitude_ft>")
            }
            if let speedKnots, speedKnots.isFinite {
                extensionChildren.append("<navplanner:speed_kt>\(gpxNumber(speedKnots, decimals: 1))</navplanner:speed_kt>")
                extensionChildren.append("<navplanner:speed_mps>\(gpxNumber(speedKnots * 0.514444, decimals: 2))</navplanner:speed_mps>")
            }
            if !extensionChildren.isEmpty {
                children.append("""
                <extensions>
                  \(extensionChildren.joined(separator: "\n          "))
                </extensions>
                """)
            }
            let content = children.isEmpty ? "" : "\n        \(children.joined(separator: "\n        "))\n      "
            return """
            <trkpt lat="\(lat)" lon="\(lon)">\(content)</trkpt>
            """
        }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="NavPlanner" xmlns="http://www.topografix.com/GPX/1/1" xmlns:navplanner="https://navplanner.app/gpx/1/0">
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

    private func gpxNumber(_ value: Double, decimals: Int) -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        switch decimals {
        case 0:
            return String(format: "%.0f", locale: locale, value)
        case 1:
            return String(format: "%.1f", locale: locale, value)
        case 2:
            return String(format: "%.2f", locale: locale, value)
        default:
            return String(format: "%.3f", locale: locale, value)
        }
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

    enum RequestPriority: Int {
        case visible = 1
        case preview = 2

        var operationQueuePriority: Operation.QueuePriority {
            switch self {
            case .visible: .high
            case .preview: .veryHigh
            }
        }
    }

    private final class TileDownloadJob {
        let key: String
        let operation = BlockOperation()
        let sequence: UInt64
        var demandGeneration: UInt64
        var priority: RequestPriority

        private let taskLock = NSLock()
        private var activeTask: URLSessionTask?

        init(
            key: String,
            sequence: UInt64,
            demandGeneration: UInt64,
            priority: RequestPriority
        ) {
            self.key = key
            self.sequence = sequence
            self.demandGeneration = demandGeneration
            self.priority = priority
            operation.queuePriority = priority.operationQueuePriority
        }

        func promote(to newPriority: RequestPriority) {
            guard newPriority.rawValue > priority.rawValue else { return }
            priority = newPriority
            operation.queuePriority = newPriority.operationQueuePriority
        }

        func installActiveTask(_ task: URLSessionTask) -> Bool {
            taskLock.withLock {
                guard !operation.isCancelled else { return false }
                activeTask = task
                return true
            }
        }

        func clearActiveTask(_ task: URLSessionTask) {
            taskLock.withLock {
                if activeTask === task {
                    activeTask = nil
                }
            }
        }

        func cancel() {
            operation.cancel()
            let task = taskLock.withLock { () -> URLSessionTask? in
                let task = activeTask
                activeTask = nil
                return task
            }
            task?.cancel()
        }
    }

    static let tileResponseWaitTimeout: TimeInterval = 2.4
    private static let tileDownloadRequestTimeout: TimeInterval = 8
    private static let tileDownloadResourceTimeout: TimeInterval = 14
    private static let tileDownloadWorkers = 8
    private static let tileDownloadRetries = 1
    private static let tileDownloadRetryDelay: TimeInterval = 0.35
    private static let maxPendingDownloads = 512
    // Network.framework reports child-endpoint identifier wrapping after a
    // long burst on one session. Rotate well before the observed threshold,
    // while allowing already running tasks from the previous session to drain.
    private static let maxDownloadTasksPerSession = 48

    private struct TilePayload {
        let data: Data
        let contentType: String
    }

    private final class TileDownloadResult: @unchecked Sendable {
        private let lock = NSLock()
        private var data: Data?
        private var response: HTTPURLResponse?

        func store(data: Data?, response: URLResponse?) {
            lock.withLock {
                self.data = data
                self.response = response as? HTTPURLResponse
            }
        }

        func value() -> (Data?, HTTPURLResponse?) {
            lock.withLock { (data, response) }
        }
    }

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let previousRootDirectory: URL
    private let legacyRootDirectory: URL
    private var session: URLSession
    private let sessionLock = NSLock()
    private var sessionTaskCount = 0
    private var sessionRotationCount = 0
    private let downloadQueue: OperationQueue
    private let lock = NSLock()
    private var pendingJobs: [String: TileDownloadJob] = [:]
    private var activeJobIDs = Set<ObjectIdentifier>()
    private var failedAtByKey: [String: Date] = [:]
    private var latestDemandGeneration: UInt64 = 0
    private var nextJobSequence: UInt64 = 0
    private var peakPendingCount = 0
    private var cancelledStaleCount = 0
    private var cancelledOverflowCount = 0
    private var successfulDownloadCount = 0
    private let failureCooldown: TimeInterval = 8

    private let providers: [String: OnlineTileProvider] = [
        "arcgis": OnlineTileProvider(
            key: "arcgis",
            format: "jpg",
            contentType: "image/jpeg",
            templates: [
                "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}",
                "https://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}"
            ],
            maxZoom: 20
        ),
        "openstreetmap": OnlineTileProvider(
            key: "openstreetmap",
            format: "png",
            contentType: "image/png",
            templates: [
                "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
            ],
            maxZoom: 19
        ),
        "opentopomap": OnlineTileProvider(
            key: "opentopomap",
            format: "png",
            contentType: "image/png",
            templates: [
                "https://a.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://b.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://c.tile.opentopomap.org/{z}/{x}/{y}.png"
            ],
            maxZoom: 17
        ),
        "google": OnlineTileProvider(
            key: "google",
            format: "jpg",
            contentType: "image/jpeg",
            templates: [
                "https://mt0.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://mt2.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://mt3.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US"
            ],
            maxZoom: 20
        ),
        "google_terrain": OnlineTileProvider(
            key: "google_terrain",
            format: "jpg",
            contentType: "image/jpeg",
            templates: [
                "https://mt0.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}",
                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                "https://a.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://b.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://c.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://mt2.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://mt3.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US"
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
        self.legacyRootDirectory = cacheRoot
            .appendingPathComponent("NavPlanner", isDirectory: true)
            .appendingPathComponent("MapCache", isDirectory: true)
        self.previousRootDirectory = cacheRoot
            .appendingPathComponent("NavPlanner", isDirectory: true)
            .appendingPathComponent("MapCacheV2", isDirectory: true)
        self.rootDirectory = cacheRoot
            .appendingPathComponent("NavPlanner", isDirectory: true)
            .appendingPathComponent("MapCacheV3", isDirectory: true)

        self.session = URLSession(configuration: Self.tileSessionConfiguration())

        let downloadQueue = OperationQueue()
        downloadQueue.name = "com.navplanner.online-map-cache"
        downloadQueue.qualityOfService = .userInitiated
        downloadQueue.maxConcurrentOperationCount = Self.tileDownloadWorkers
        self.downloadQueue = downloadQueue

        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    func tile(
        providerKey: String,
        z: Int,
        x: Int,
        y: Int,
        waitForDownload: TimeInterval = 0,
        demandGeneration: UInt64 = 0,
        priority: RequestPriority = .visible,
        shouldCancel: () -> Bool = { false }
    ) -> TileState {
        guard let provider = providers[providerKey],
              z >= 0, z <= provider.maxZoom, x >= 0, y >= 0 else {
            return .failed
        }
        let remoteURLs = provider.requestURLs(z: z, x: x, y: y)
        guard !remoteURLs.isEmpty else {
            return .failed
        }

        let localURL = tileFileURL(provider: provider, z: z, x: x, y: y)
        if let payload = cachedTilePayload(provider: provider, localURL: localURL, z: z, x: x, y: y) {
            return .hit(data: payload.data, contentType: payload.contentType)
        }

        let key = cacheKey(provider: provider, z: z, x: x, y: y)
        var jobsToCancel: [TileDownloadJob] = []
        var jobToEnqueue: TileDownloadJob?
        let state = lock.withLock { () -> TileState? in
            if demandGeneration > 0 {
                guard demandGeneration >= latestDemandGeneration else {
                    // A late response from a viewport that has already been replaced
                    // must not re-enter the queue ahead of the current visible region.
                    return .failed
                }
                if demandGeneration > latestDemandGeneration {
                    latestDemandGeneration = demandGeneration
                    let staleJobs = pendingJobs.values.filter {
                        $0.demandGeneration > 0 && $0.demandGeneration < demandGeneration
                    }
                    for job in staleJobs where pendingJobs[job.key] === job {
                        pendingJobs.removeValue(forKey: job.key)
                    }
                    cancelledStaleCount += staleJobs.count
                    jobsToCancel.append(contentsOf: staleJobs)
                }
            }

            if let pendingJob = pendingJobs[key] {
                pendingJob.demandGeneration = max(pendingJob.demandGeneration, demandGeneration)
                pendingJob.promote(to: priority)
                return .pending
            }
            if let failedAt = failedAtByKey[key] {
                if Date().timeIntervalSince(failedAt) < failureCooldown {
                    return .failed
                }
                failedAtByKey.removeValue(forKey: key)
            }

            nextJobSequence &+= 1
            let job = TileDownloadJob(
                key: key,
                sequence: nextJobSequence,
                demandGeneration: demandGeneration,
                priority: priority
            )
            pendingJobs[key] = job
            jobToEnqueue = job
            peakPendingCount = max(peakPendingCount, pendingJobs.count)

            let overflow = max(0, pendingJobs.count - Self.maxPendingDownloads)
            if overflow > 0 {
                let overflowJobs = pendingJobs.values
                    .filter { $0 !== job && !$0.operation.isExecuting }
                    .sorted {
                        if $0.priority.rawValue != $1.priority.rawValue {
                            return $0.priority.rawValue < $1.priority.rawValue
                        }
                        return $0.sequence < $1.sequence
                    }
                    .prefix(overflow)
                for overflowJob in overflowJobs where pendingJobs[overflowJob.key] === overflowJob {
                    pendingJobs.removeValue(forKey: overflowJob.key)
                    jobsToCancel.append(overflowJob)
                    cancelledOverflowCount += 1
                }
            }
            return nil
        }
        jobsToCancel.forEach { $0.cancel() }

        if let state {
            if case .pending = state,
               waitForDownload > 0,
               let payload = waitForCachedTile(
                provider: provider,
                localURL: localURL,
                timeout: waitForDownload,
                shouldCancel: shouldCancel
               ) {
                return .hit(data: payload.data, contentType: payload.contentType)
            }
            return state
        }

        if let jobToEnqueue {
            downloadTile(
                provider: provider,
                remoteURLs: remoteURLs,
                localURL: localURL,
                job: jobToEnqueue
            )
        }
        if waitForDownload > 0,
           let payload = waitForCachedTile(
            provider: provider,
            localURL: localURL,
            timeout: waitForDownload,
            shouldCancel: shouldCancel
           ) {
            return .hit(data: payload.data, contentType: payload.contentType)
        }
        return .queued
    }

    func cachedTile(providerKey: String, z: Int, x: Int, y: Int) -> TileState {
        guard let provider = providers[providerKey],
              z >= 0, z <= provider.maxZoom, x >= 0, y >= 0 else {
            return .failed
        }
        let localURL = tileFileURL(provider: provider, z: z, x: x, y: y)
        guard let payload = cachedTilePayload(provider: provider, localURL: localURL, z: z, x: x, y: y) else {
            return .failed
        }
        return .hit(data: payload.data, contentType: payload.contentType)
    }

    func statusPayload() -> [String: Any] {
        let usage = diskUsage()
        let sessionRuntime = sessionLock.withLock {
            (
                taskCount: sessionTaskCount,
                rotationCount: sessionRotationCount
            )
        }
        let runtime = lock.withLock { () -> [String: Any] in
            let activeCount = pendingJobs.values.reduce(into: 0) { count, job in
                if activeJobIDs.contains(ObjectIdentifier(job)) {
                    count += 1
                }
            }
            return [
                "pending_count": pendingJobs.count,
                "active_count": activeCount,
                "queued_count": max(0, pendingJobs.count - activeCount),
                "failed_count": failedAtByKey.count,
                "latest_demand_generation": latestDemandGeneration,
                "peak_pending_count": peakPendingCount,
                "cancelled_stale_count": cancelledStaleCount,
                "cancelled_overflow_count": cancelledOverflowCount,
                "successful_download_count": successfulDownloadCount
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
            "active_count": runtime["active_count"] ?? 0,
            "queued_count": runtime["queued_count"] ?? 0,
            "failed_count": runtime["failed_count"] ?? 0,
            "latest_demand_generation": runtime["latest_demand_generation"] ?? 0,
            "peak_pending_count": runtime["peak_pending_count"] ?? 0,
            "cancelled_stale_count": runtime["cancelled_stale_count"] ?? 0,
            "cancelled_overflow_count": runtime["cancelled_overflow_count"] ?? 0,
            "successful_download_count": runtime["successful_download_count"] ?? 0,
            "queue_capacity": Self.maxPendingDownloads,
            "session_task_count": sessionRuntime.taskCount,
            "session_rotation_count": sessionRuntime.rotationCount,
            "session_task_capacity": Self.maxDownloadTasksPerSession,
            "message": "在线底图缓存状态已读取。"
        ]
    }

    func clearPayload() -> [String: Any] {
        let jobs = lock.withLock { () -> [TileDownloadJob] in
            let jobs = Array(pendingJobs.values)
            pendingJobs.removeAll()
            failedAtByKey.removeAll()
            activeJobIDs.removeAll()
            latestDemandGeneration = 0
            peakPendingCount = 0
            cancelledStaleCount = 0
            cancelledOverflowCount = 0
            successfulDownloadCount = 0
            return jobs
        }
        jobs.forEach { $0.cancel() }
        downloadQueue.cancelAllOperations()
        for directory in [rootDirectory, previousRootDirectory, legacyRootDirectory] {
            if let items = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            ) {
                for item in items {
                    try? fileManager.removeItem(at: item)
                }
            }
        }
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        var payload = statusPayload()
        payload["message"] = "已清理在线地图缓存。"
        return payload
    }

    private func cachedTilePayload(provider: OnlineTileProvider, localURL: URL) -> TilePayload? {
        guard let data = try? Data(contentsOf: localURL), !data.isEmpty else {
            return nil
        }
        guard let payload = cacheTilePayload(from: data, provider: provider) else {
            try? fileManager.removeItem(at: localURL)
            return nil
        }
        return payload
    }

    private func cachedTilePayload(provider: OnlineTileProvider, localURL: URL, z: Int, x: Int, y: Int) -> TilePayload? {
        if let payload = cachedTilePayload(provider: provider, localURL: localURL) {
            return payload
        }
        guard let legacyURL = legacyNormalizedTileFileURL(provider: provider, z: z, x: x, y: y),
              legacyURL != localURL else {
            return nil
        }
        return cachedTilePayload(provider: provider, localURL: legacyURL)
    }

    private func waitForCachedTile(
        provider: OnlineTileProvider,
        localURL: URL,
        timeout: TimeInterval,
        shouldCancel: () -> Bool
    ) -> TilePayload? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if shouldCancel() {
                return nil
            }
            Thread.sleep(forTimeInterval: 0.08)
            if let payload = cachedTilePayload(provider: provider, localURL: localURL) {
                return payload
            }
        }
        return nil
    }

    private func downloadTile(
        provider: OnlineTileProvider,
        remoteURLs: [URL],
        localURL: URL,
        job: TileDownloadJob
    ) {
        job.operation.addExecutionBlock { [weak self, weak job] in
            guard let self, let job, !job.operation.isCancelled else { return }
            let jobID = ObjectIdentifier(job)
            self.lock.withLock {
                _ = self.activeJobIDs.insert(jobID)
            }
            defer {
                self.lock.withLock {
                    self.activeJobIDs.remove(jobID)
                    if self.pendingJobs[job.key] === job {
                        self.pendingJobs.removeValue(forKey: job.key)
                    }
                }
            }

            for retry in 0...Self.tileDownloadRetries {
                guard !job.operation.isCancelled else { return }
                for remoteURL in remoteURLs {
                    guard !job.operation.isCancelled else { return }
                    guard let payload = self.downloadTilePayload(
                        provider: provider,
                        remoteURL: remoteURL,
                        job: job
                    ) else {
                        continue
                    }
                    guard !job.operation.isCancelled else { return }
                    if self.writeCacheData(payload.data, to: localURL) {
                        self.lock.withLock {
                            _ = self.failedAtByKey.removeValue(forKey: job.key)
                            self.successfulDownloadCount += 1
                        }
                        return
                    }
                }
                if retry < Self.tileDownloadRetries {
                    Thread.sleep(forTimeInterval: Self.tileDownloadRetryDelay * Double(retry + 1))
                }
            }

            guard !job.operation.isCancelled else { return }
            self.markFailure(key: job.key)
        }
        downloadQueue.addOperation(job.operation)
    }

    private func downloadTilePayload(
        provider: OnlineTileProvider,
        remoteURL: URL,
        job: TileDownloadJob
    ) -> TilePayload? {
        guard !job.operation.isCancelled else { return nil }
        let request = tileRequest(for: remoteURL)
        let semaphore = DispatchSemaphore(value: 0)
        let result = TileDownloadResult()

        let task = makeDownloadTask(for: request) { data, response, _ in
            result.store(data: data, response: response)
            semaphore.signal()
        }
        task.priority = URLSessionTask.highPriority
        guard job.installActiveTask(task) else {
            task.cancel()
            return nil
        }
        task.resume()

        guard semaphore.wait(timeout: .now() + Self.tileDownloadResourceTimeout + 1) == .success else {
            task.cancel()
            job.clearActiveTask(task)
            return nil
        }
        job.clearActiveTask(task)
        guard !job.operation.isCancelled else { return nil }
        let value = result.value()
        guard let response = value.1,
              (200..<300).contains(response.statusCode),
              let data = value.0 else {
            return nil
        }
        return cacheTilePayload(from: data, provider: provider)
    }

    private static func tileSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = tileDownloadRequestTimeout
        configuration.timeoutIntervalForResource = tileDownloadResourceTimeout
        configuration.httpMaximumConnectionsPerHost = tileDownloadWorkers
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return configuration
    }

    private func makeDownloadTask(
        for request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        var previousSession: URLSession?
        let task = sessionLock.withLock { () -> URLSessionDataTask in
            if sessionTaskCount >= Self.maxDownloadTasksPerSession {
                previousSession = session
                session = URLSession(configuration: Self.tileSessionConfiguration())
                sessionTaskCount = 0
                sessionRotationCount += 1
            }
            sessionTaskCount += 1
            // Create the task while sessionLock is held so another worker cannot
            // finish/invalidate this session between selecting it and registering
            // the task with Foundation.
            return session.dataTask(with: request, completionHandler: completionHandler)
        }
        // Do not invalidate while holding sessionLock: completion callbacks from
        // the old session are allowed to drain independently.
        previousSession?.finishTasksAndInvalidate()
        return task
    }

    private func tileRequest(for remoteURL: URL) -> URLRequest {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = Self.tileDownloadRequestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 NavPlanner/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("image/jpeg,image/png,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")
        return request
    }

    private func writeCacheData(_ data: Data, to localURL: URL) -> Bool {
        do {
            try fileManager.createDirectory(
                at: localURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let temporaryURL = localURL
                .deletingLastPathComponent()
                .appendingPathComponent(".\(localURL.lastPathComponent).\(UUID().uuidString).tmp")
            try data.write(to: temporaryURL, options: [.atomic])
            _ = try? fileManager.removeItem(at: localURL)
            try fileManager.moveItem(at: temporaryURL, to: localURL)
            return true
        } catch {
            return false
        }
    }

    private func markFailure(key: String) {
        lock.withLock {
            failedAtByKey[key] = Date()
        }
    }

    private func cacheTilePayload(from data: Data, provider: OnlineTileProvider) -> TilePayload? {
        guard isValidTileData(data, provider: provider) else { return nil }
        return TilePayload(data: data, contentType: contentType(for: data) ?? provider.contentType)
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
        guard data.count >= 4,
              data.prefix(2).elementsEqual([0xff, 0xd8]) else {
            return false
        }
        var index = data.count - 1
        while index > 2 {
            let byte = data[index]
            if byte != 0x00, byte != 0x0a, byte != 0x0d, byte != 0x20 {
                break
            }
            index -= 1
        }
        return index >= 3 && data[index - 1] == 0xff && data[index] == 0xd9
    }

    private func isPNG(_ data: Data) -> Bool {
        let signature: [UInt8] = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
        let iendChunk: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82]
        return data.count >= 20
            && data.prefix(signature.count).elementsEqual(signature)
            && data.suffix(iendChunk.count).elementsEqual(iendChunk)
    }

    private func cacheKey(provider: OnlineTileProvider, z: Int, x: Int, y: Int) -> String {
        "\(provider.key)|\(z)|\(x)|\(y)"
    }

    private func tileFileURL(provider: OnlineTileProvider, z: Int, x: Int, y: Int) -> URL {
        rootDirectory
            .appendingPathComponent(provider.key, isDirectory: true)
            .appendingPathComponent(String(format: "z%02d", z), isDirectory: true)
            .appendingPathComponent(String(format: "%04x", x >> 8), isDirectory: true)
            .appendingPathComponent("\(String(format: "%08x", x))_\(String(format: "%08x", y)).\(cacheFileExtension(for: provider))")
    }

    private func cacheFileExtension(for provider: OnlineTileProvider) -> String {
        provider.format
    }

    private func legacyNormalizedTileFileURL(provider: OnlineTileProvider, z: Int, x: Int, y: Int) -> URL? {
        guard ["jpg", "jpeg"].contains(provider.format) else { return nil }
        return rootDirectory
            .appendingPathComponent(provider.key, isDirectory: true)
            .appendingPathComponent(String(format: "z%02d", z), isDirectory: true)
            .appendingPathComponent(String(format: "%04x", x >> 8), isDirectory: true)
            .appendingPathComponent("\(String(format: "%08x", x))_\(String(format: "%08x", y)).png")
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
