import Foundation

public struct RuntimeRouteDescriptor: Hashable, Sendable {
    public let method: String
    public let path: String

    public init(method: String, path: String) {
        self.method = method
        self.path = path
    }
}

public final class SimNavRuntimeRouter: @unchecked Sendable {
    public static let coreRoutes = [
        RuntimeRouteDescriptor(method: "GET", path: "/header"),
        RuntimeRouteDescriptor(method: "GET", path: "/search"),
        RuntimeRouteDescriptor(method: "GET", path: "/airport/{ident}"),
        RuntimeRouteDescriptor(method: "GET", path: "/procedure/{type}/{airport}/{procedure}/{transition}"),
        RuntimeRouteDescriptor(method: "POST", path: "/procedure-preview/{type}/{airport}"),
        RuntimeRouteDescriptor(method: "GET", path: "/airway/{airway}"),
        RuntimeRouteDescriptor(method: "GET", path: "/nav-overlay"),
        RuntimeRouteDescriptor(method: "GET", path: "/route/resolve"),
        RuntimeRouteDescriptor(method: "POST", path: "/route/track-match"),
        RuntimeRouteDescriptor(method: "GET", path: "/route/fr24-match"),
        RuntimeRouteDescriptor(method: "GET", path: "/databases/list"),
        RuntimeRouteDescriptor(method: "POST", path: "/databases/import"),
        RuntimeRouteDescriptor(method: "POST", path: "/databases/select"),
        RuntimeRouteDescriptor(method: "POST", path: "/databases/delete"),
        RuntimeRouteDescriptor(method: "POST", path: "/databases/restore-bundled"),
        RuntimeRouteDescriptor(method: "GET", path: "/offline-maps"),
        RuntimeRouteDescriptor(method: "POST", path: "/offline-maps/import"),
        RuntimeRouteDescriptor(method: "POST", path: "/offline-maps/select"),
        RuntimeRouteDescriptor(method: "POST", path: "/offline-maps/delete"),
        RuntimeRouteDescriptor(method: "POST", path: "/offline-maps/compact"),
        RuntimeRouteDescriptor(method: "POST", path: "/offline-maps/download"),
        RuntimeRouteDescriptor(method: "POST", path: "/offline-maps/cancel"),
        RuntimeRouteDescriptor(method: "GET", path: "/offline-maps/tile/{z}/{x}/{y}"),
        RuntimeRouteDescriptor(method: "GET", path: "/offline-maps/resource/{name}/{z}/{x}/{y}"),
        RuntimeRouteDescriptor(method: "GET", path: "/offline-maps/pmtiles/{name}.pmtiles"),
        RuntimeRouteDescriptor(method: "GET", path: "/map-cache/status"),
        RuntimeRouteDescriptor(method: "POST", path: "/map-cache/clear"),
        RuntimeRouteDescriptor(method: "GET", path: "/map-cache/{provider}/{z}/{x}/{y}"),
        RuntimeRouteDescriptor(method: "GET", path: "/terrain/terrarium/{z}/{x}/{y}.png"),
        RuntimeRouteDescriptor(method: "GET", path: "/weather/open-meteo"),
        RuntimeRouteDescriptor(method: "GET", path: "/fr24/cache/status"),
        RuntimeRouteDescriptor(method: "GET", path: "/fr24/cache/list"),
        RuntimeRouteDescriptor(method: "GET", path: "/fr24/cache/file/{cacheKey}"),
        RuntimeRouteDescriptor(method: "POST", path: "/fr24/cache/delete"),
        RuntimeRouteDescriptor(method: "POST", path: "/fr24/cache/favorite"),
        RuntimeRouteDescriptor(method: "POST", path: "/fr24/cache/share"),
        RuntimeRouteDescriptor(method: "POST", path: "/fr24/cache/clear"),
        RuntimeRouteDescriptor(method: "GET", path: "/fr24/access/status"),
        RuntimeRouteDescriptor(method: "POST", path: "/fr24/access/probe"),
        RuntimeRouteDescriptor(method: "POST", path: "/fr24/access/update"),
        RuntimeRouteDescriptor(method: "POST", path: "/fr24/access/clear"),
        RuntimeRouteDescriptor(method: "POST", path: "/fr24/browser/open"),
        RuntimeRouteDescriptor(method: "POST", path: "/fr24/browser/sync"),
        RuntimeRouteDescriptor(method: "GET", path: "/fr24/browser/status"),
        RuntimeRouteDescriptor(method: "GET", path: "/fr24/search"),
        RuntimeRouteDescriptor(method: "GET", path: "/fr24/history"),
        RuntimeRouteDescriptor(method: "GET", path: "/fr24/manual-history"),
        RuntimeRouteDescriptor(method: "POST", path: "/fr24/download")
    ]

    private let plannerService: PlannerService
    private let mapStore: MapStore?
    private let onlineTileCache: SimNavOnlineTileCache?
    private let fr24Service: FR24Service
    private let exposesLocalFilePaths: Bool
    private let weatherProxy = SimNavWeatherProxy()
    private static let transparentTile = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="
    ) ?? Data()

    public convenience init(
        configuration: RuntimeConfiguration,
        fileManager: FileManager = .default,
        fr24BrowserFetcher: FR24BrowserFetching? = nil,
        fr24APIBaseURL: URL = URL(string: "https://api.flightradar24.com")!
    ) {
        let dataStore = LocalDataStore(
            fileManager: fileManager,
            rootDirectory: configuration.dataRoot,
            bundledDatabaseURL: configuration.bundledDatabaseURL
        )
        let plannerService = PlannerService(
            dataStore: dataStore,
            performanceSubsystem: configuration.performanceSubsystem
        )
        let mapStore = MapStore(
            fileManager: fileManager,
            rootDirectory: configuration.dataRoot.appendingPathComponent("MapOffline", isDirectory: true)
        )
        let onlineTileCache = SimNavOnlineTileCache(
            fileManager: fileManager,
            rootDirectory: configuration.dataRoot.appendingPathComponent("MapCacheV3", isDirectory: true)
        )
        let fr24Service = FR24Service(
            fileManager: fileManager,
            rootDirectory: configuration.dataRoot.appendingPathComponent("FR24", isDirectory: true),
            sessionFileURL: configuration.dataRoot
                .appendingPathComponent("Config", isDirectory: true)
                .appendingPathComponent("fr24-session.json"),
            browserFetcher: fr24BrowserFetcher,
            apiBaseURL: fr24APIBaseURL
        )
        self.init(
            plannerService: plannerService,
            mapStore: mapStore,
            onlineTileCache: onlineTileCache,
            fr24Service: fr24Service,
            exposesLocalFilePaths: false
        )
    }

    init(
        plannerService: PlannerService,
        mapStore: MapStore? = nil,
        onlineTileCache: SimNavOnlineTileCache? = nil,
        fr24Service: FR24Service = FR24Service(),
        exposesLocalFilePaths: Bool = true
    ) {
        self.plannerService = plannerService
        self.mapStore = mapStore
        self.onlineTileCache = onlineTileCache
        self.fr24Service = fr24Service
        self.exposesLocalFilePaths = exposesLocalFilePaths
    }

    public func canHandle(_ request: RuntimeRequest) -> Bool {
        let path = normalizedAPIPath(request.path)
        let components = path.split(separator: "/").map(String.init)
        if ["/header", "/search", "/nav-overlay", "/route/resolve", "/route/track-match", "/route/fr24-match"].contains(path) {
            return true
        }
        if components.first == "airport", components.count == 2 {
            return true
        }
        if components.first == "procedure", components.count >= 5 {
            return true
        }
        if components.first == "procedure-preview", components.count == 3 {
            return true
        }
        if components.first == "databases", components.count == 2 {
            return true
        }
        if components.first == "offline-maps" {
            return true
        }
        if components.first == "map-cache" || components.first == "terrain" {
            return true
        }
        if path == "/weather/open-meteo" {
            return true
        }
        if components.first == "fr24" {
            return true
        }
        return components.first == "airway" && components.count == 2
    }

    public func handle(
        _ request: RuntimeRequest,
        shouldCancel: @escaping () -> Bool = { false }
    ) -> RuntimeResponse {
        let path = normalizedAPIPath(request.path)
        let pathComponents = path.split(separator: "/").map(String.init)
        let queryValue: (String, String) -> String = { name, fallback in
            request.queryValue(name, default: fallback)
        }

        if path == "/header" {
            return jsonResponse(plannerService.headerPayload())
        }
        if path == "/search" {
            return jsonResponse(plannerService.searchPayload(query: queryValue("q", "")))
        }
        if pathComponents.first == "airport", pathComponents.count == 2 {
            let ident = decoded(pathComponents[1])
            guard let payload = plannerService.airportPayload(ident: ident) else {
                return jsonResponse(["error": "Airport not found"], status: 404)
            }
            return jsonResponse(payload)
        }
        if pathComponents.first == "procedure", pathComponents.count >= 5 {
            return jsonResponse(plannerService.procedurePayload(
                type: pathComponents[1],
                airport: decoded(pathComponents[2]),
                procedure: decoded(pathComponents[3]),
                transition: decoded(pathComponents[4])
            ))
        }
        if pathComponents.first == "procedure-preview", pathComponents.count == 3 {
            guard request.method == "POST" else {
                return jsonResponse(["error": "API not found"], status: 404)
            }
            let body = jsonBody(request.body)
            return jsonResponse(plannerService.procedurePreviewPayload(
                type: pathComponents[1],
                airport: decoded(pathComponents[2]),
                selections: body["procedures"] as? [[String: Any]] ?? []
            ))
        }
        if pathComponents.first == "airway", pathComponents.count == 2 {
            return jsonResponse(plannerService.airwayPayload(airway: decoded(pathComponents[1])))
        }
        if path == "/nav-overlay" {
            let generation = Int(queryValue("generation", "0")) ?? 0
            if shouldCancel() {
                return jsonResponse(["cancelled": true, "generation": generation])
            }
            var payload = plannerService.navOverlayPayload(
                south: Double(queryValue("south", "0")) ?? 0,
                west: Double(queryValue("west", "0")) ?? 0,
                north: Double(queryValue("north", "0")) ?? 0,
                east: Double(queryValue("east", "0")) ?? 0,
                zoom: Int(Double(queryValue("zoom", "4")) ?? 4),
                shouldCancel: shouldCancel
            )
            if shouldCancel() {
                return jsonResponse(["cancelled": true, "generation": generation])
            }
            payload["generation"] = generation
            return jsonResponse(payload)
        }
        if path == "/route/resolve" {
            let payload = plannerService.routeResolvePayload(
                departure: queryValue("departure", ""),
                arrival: queryValue("arrival", ""),
                route: queryValue("route", ""),
                departureRunway: queryValue("departure_runway", "ALL"),
                arrivalRunway: queryValue("arrival_runway", "ALL")
            )
            return jsonResponse(payload, status: payload["error"] == nil ? 200 : 400)
        }
        if path == "/route/track-match" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Track match requires POST."], status: 405)
            }
            let body = jsonBody(request.body)
            let rawTrackPoints = body["track_points"] as? [Any] ?? []
            let payload = plannerService.trackMatchPayload(
                departure: body["departure"] as? String ?? "",
                arrival: body["arrival"] as? String ?? "",
                trackPoints: rawTrackPoints.compactMap { $0 as? [String: Any] }
            )
            return jsonResponse(payload, status: payload["error"] == nil ? 200 : 400)
        }
        if path == "/route/fr24-match" {
            return fr24RouteMatchResponse(request: request)
        }
        if pathComponents.first == "fr24" {
            return fr24Response(
                request: request,
                path: path,
                pathComponents: pathComponents
            )
        }
        if path == "/databases/list" {
            guard request.method == "GET" else {
                return jsonResponse(["error": "Database list requires GET."], status: 405)
            }
            let payload = plannerService.databaseListPayload(
                query: queryValue("query", ""),
                limit: Int(queryValue("limit", "200")) ?? 200
            )
            return jsonResponse(payload, status: payload["error"] == nil ? 200 : 500)
        }
        if path == "/databases/import" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Database import requires POST."], status: 405)
            }
            guard let source = request.bodyFileURL else {
                return jsonResponse(["error": "Database upload body is missing."], status: 400)
            }
            do {
                return jsonResponse(try plannerService.importDatabasePayload(from: source))
            } catch {
                return jsonResponse(["error": error.localizedDescription], status: 400)
            }
        }
        if path == "/databases/select" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Database selection requires POST."], status: 405)
            }
            do {
                let body = jsonBody(request.body)
                return jsonResponse(try plannerService.selectDatabasePayload(
                    name: body["name"] as? String ?? ""
                ))
            } catch {
                return jsonResponse(["error": error.localizedDescription], status: 400)
            }
        }
        if path == "/databases/delete" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Database deletion requires POST."], status: 405)
            }
            do {
                let body = jsonBody(request.body)
                return jsonResponse(try plannerService.deleteDatabasePayload(
                    name: body["name"] as? String ?? ""
                ))
            } catch {
                return jsonResponse(["error": error.localizedDescription], status: 400)
            }
        }
        if path == "/databases/restore-bundled" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Database restore requires POST."], status: 405)
            }
            do {
                return jsonResponse(try plannerService.restoreBundledDatabasePayload())
            } catch {
                return jsonResponse(["error": error.localizedDescription], status: 400)
            }
        }
        if pathComponents.first == "offline-maps" {
            return offlineMapsResponse(
                request: request,
                path: path,
                pathComponents: pathComponents
            )
        }
        if path == "/map-cache/status" {
            guard let onlineTileCache else {
                return jsonResponse(["error": "Online tile cache is unavailable."], status: 503)
            }
            return jsonResponse(onlineTileCache.statusPayload())
        }
        if path == "/map-cache/clear" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Map cache clear requires POST."], status: 405)
            }
            guard let onlineTileCache else {
                return jsonResponse(["error": "Online tile cache is unavailable."], status: 503)
            }
            return jsonResponse(onlineTileCache.clearPayload())
        }
        if pathComponents.first == "map-cache" || pathComponents.first == "terrain" {
            return onlineTileResponse(request: request, pathComponents: pathComponents)
        }
        if path == "/weather/open-meteo" {
            return weatherProxy.response(for: request)
        }
        return jsonResponse(["error": "API not found"], status: 404)
    }

    private func fr24RouteMatchResponse(request: RuntimeRequest) -> RuntimeResponse {
        guard request.method == "GET" else {
            return jsonResponse(["error": "FR24 route matching requires GET."], status: 405)
        }
        let departure = request.queryValue("departure")
        let arrival = request.queryValue("arrival")
        let routeAirports = plannerService.fr24RouteAirportsPayload(
            departure: departure,
            arrival: arrival
        )
        if routeAirports["error"] != nil {
            return jsonResponse(routeAirports, status: 400)
        }
        let flightHint = request.queryValue("flight_id")
        let downloadPayload: [String: Any]
        if let hintedFlightID = FR24Service.extractFlightID(from: flightHint) {
            downloadPayload = fr24Service.downloadPayload(
                flightID: hintedFlightID,
                flight: ["fr24_id": hintedFlightID]
            )
        } else {
            let searchPayload = fr24Service.searchPayload(routeAirports: routeAirports, limit: 1)
            guard searchPayload["error"] == nil,
                  let flights = searchPayload["flights"] as? [[String: Any]],
                  let firstFlight = flights.first,
                  let flightID = firstFlight["fr24_id"] as? String,
                  !flightID.isEmpty else {
                return fr24JSONResponse(searchPayload, status: 503)
            }
            downloadPayload = fr24Service.downloadPayload(flightID: flightID, flight: firstFlight)
        }
        guard downloadPayload["error"] == nil,
              let trackPoints = downloadPayload["track_points"] as? [[String: Any]] else {
            return fr24JSONResponse(downloadPayload, status: 503)
        }
        var payload = plannerService.trackMatchPayload(
            departure: departure,
            arrival: arrival,
            trackPoints: trackPoints
        )
        if payload["error"] != nil {
            return jsonResponse(payload, status: 400)
        }
        payload["message"] = "已从 FR24 Web 轨迹匹配本地航路。"
        payload["source"] = [
            "provider": "Flightradar24 web",
            "flight": downloadPayload["flight"] ?? [:],
            "track_points": trackPoints,
            "cache": downloadPayload["cache"] ?? [:]
        ]
        return fr24JSONResponse(payload)
    }

    private func fr24Response(
        request: RuntimeRequest,
        path: String,
        pathComponents: [String]
    ) -> RuntimeResponse {
        if path == "/fr24/cache/status" {
            guard request.method == "GET" else {
                return jsonResponse(["error": "FR24 cache status requires GET."], status: 405)
            }
            return fr24JSONResponse(fr24Service.cacheStatusPayload())
        }
        if path == "/fr24/cache/list" {
            guard request.method == "GET" else {
                return jsonResponse(["error": "FR24 cache list requires GET."], status: 405)
            }
            return fr24JSONResponse(fr24Service.cacheListPayload(
                query: request.queryValue("query"),
                limit: Int(request.queryValue("limit", default: "120")) ?? 120
            ))
        }
        if pathComponents.count == 4,
           pathComponents[1] == "cache",
           pathComponents[2] == "file" {
            guard request.method == "GET" else {
                return jsonResponse(["error": "FR24 cache download requires GET."], status: 405)
            }
            let cacheKey = decoded(pathComponents[3])
            guard let export = fr24Service.cacheExport(cacheKey: cacheKey) else {
                return jsonResponse(["error": "FR24 cache GPX file not found."], status: 404)
            }
            let asciiFilename = export.filename.unicodeScalars
                .map { $0.isASCII && $0.value >= 32 && $0.value < 127 ? Character(String($0)) : "_" }
                .map(String.init)
                .joined()
                .replacingOccurrences(of: "\"", with: "_")
            return RuntimeResponse(
                status: 200,
                headers: [
                    "Cache-Control": "private, no-store",
                    "Content-Disposition": "attachment; filename=\"\(asciiFilename)\"",
                    "Content-Type": "application/gpx+xml; charset=utf-8"
                ],
                body: export.data
            )
        }
        if path == "/fr24/cache/delete" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "FR24 cache deletion requires POST."], status: 405)
            }
            let body = jsonBody(request.body)
            let payload = fr24Service.deleteCacheItemPayload(
                cacheKey: body["cache_key"] as? String ?? body["cacheKey"] as? String ?? ""
            )
            return fr24JSONResponse(payload, status: payload["error"] == nil ? 200 : 404)
        }
        if path == "/fr24/cache/favorite" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "FR24 favorite update requires POST."], status: 405)
            }
            let body = jsonBody(request.body)
            let favorite = body["favorite"] as? Bool
                ?? (body["favorite"] as? NSNumber)?.boolValue
                ?? false
            let payload = fr24Service.updateCacheFavoritePayload(
                cacheKey: body["cache_key"] as? String ?? body["cacheKey"] as? String ?? "",
                favorite: favorite
            )
            return fr24JSONResponse(payload, status: payload["error"] == nil ? 200 : 404)
        }
        if path == "/fr24/cache/share" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "FR24 cache sharing requires POST."], status: 405)
            }
            let body = jsonBody(request.body)
            let cacheKey = body["cache_key"] as? String ?? body["cacheKey"] as? String ?? ""
            var payload = fr24Service.shareCacheItemPayload(cacheKey: cacheKey)
            if payload["error"] == nil {
                payload["download_url"] = "/api/fr24/cache/file/\(encodedPathComponent(cacheKey))"
            }
            return fr24JSONResponse(payload, status: payload["error"] == nil ? 200 : 404)
        }
        if path == "/fr24/cache/clear" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "FR24 cache clear requires POST."], status: 405)
            }
            let body = jsonBody(request.body)
            let includeFavorites = body["include_favorites"] as? Bool
                ?? body["includeFavorites"] as? Bool
                ?? false
            return fr24JSONResponse(fr24Service.clearCachePayload(includeFavorites: includeFavorites))
        }
        if path == "/fr24/access/status" {
            guard request.method == "GET" else {
                return jsonResponse(["error": "FR24 access status requires GET."], status: 405)
            }
            return jsonResponse(fr24Service.accessStatusPayload())
        }
        if path == "/fr24/access/probe" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "FR24 access probe requires POST."], status: 405)
            }
            return jsonResponse(fr24Service.probeAccessPayload())
        }
        if path == "/fr24/access/update" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "FR24 access update requires POST."], status: 405)
            }
            let body = jsonBody(request.body)
            return jsonResponse(fr24Service.updateAccessPayload(
                webCookie: body["web_cookie"] as? String,
                frPl: body["frpl"] as? String
            ))
        }
        if path == "/fr24/access/clear" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "FR24 access clear requires POST."], status: 405)
            }
            return jsonResponse(fr24Service.clearAccessPayload())
        }
        if path == "/fr24/browser/open" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "FR24 browser open requires POST."], status: 405)
            }
            let payload = fr24Service.openBrowserVerificationPayload()
            return jsonResponse(payload, status: payload["error"] == nil ? 200 : 503)
        }
        if path == "/fr24/browser/sync" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "FR24 browser sync requires POST."], status: 405)
            }
            let payload = fr24Service.syncBrowserSessionPayload()
            return jsonResponse(payload, status: payload["error"] == nil ? 200 : 503)
        }
        if path == "/fr24/browser/status" {
            guard request.method == "GET" else {
                return jsonResponse(["error": "FR24 browser status requires GET."], status: 405)
            }
            return jsonResponse(fr24Service.accessStatusPayload())
        }
        if path == "/fr24/search" || path == "/fr24/history" {
            guard request.method == "GET" else {
                return jsonResponse(["error": "FR24 query requires GET."], status: 405)
            }
            let routeAirports = plannerService.fr24RouteAirportsPayload(
                departure: request.queryValue("departure"),
                arrival: request.queryValue("arrival")
            )
            if routeAirports["error"] != nil {
                return jsonResponse(routeAirports, status: 400)
            }
            let payload: [String: Any]
            if path == "/fr24/search" {
                payload = fr24Service.searchPayload(
                    routeAirports: routeAirports,
                    limit: Int(request.queryValue("limit", default: "10")) ?? 10
                )
            } else {
                payload = fr24Service.historyPayload(
                    routeAirports: routeAirports,
                    flightNumber: request.queryValue("flight"),
                    callsign: request.queryValue("callsign"),
                    limit: Int(request.queryValue("limit", default: "0")) ?? 0
                )
            }
            return fr24JSONResponse(payload, status: payload["error"] == nil ? 200 : 503)
        }
        if path == "/fr24/manual-history" {
            guard request.method == "GET" else {
                return jsonResponse(["error": "FR24 manual history requires GET."], status: 405)
            }
            let departure = request.queryValue("departure")
            let arrival = request.queryValue("arrival")
            var routeAirports: [String: Any] = [
                "departure": [String: Any](),
                "arrival": [String: Any]()
            ]
            if !departure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !arrival.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let resolved = plannerService.fr24RouteAirportsPayload(
                    departure: departure,
                    arrival: arrival
                )
                if resolved["error"] == nil {
                    routeAirports = resolved
                }
            }
            let payload = fr24Service.manualHistoryPayload(
                routeAirports: routeAirports,
                query: request.queryValue("query"),
                limit: Int(request.queryValue("limit", default: "0")) ?? 0
            )
            return fr24JSONResponse(payload, status: payload["error"] == nil ? 200 : 503)
        }
        if path == "/fr24/download" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "FR24 download requires POST."], status: 405)
            }
            let body = jsonBody(request.body)
            let rawFlight = plannerService.canonicalizedFR24FlightAirports(
                body["flight"] as? [String: Any] ?? [:]
            )
            let flightID = FR24Service.extractFlightID(from: body["flight_id"] as? String ?? "")
                ?? FR24Service.extractFlightID(from: rawFlight["fr24_id"] as? String ?? "")
            guard let flightID, !flightID.isEmpty else {
                return jsonResponse(["error": "FR24 flightId missing."], status: 400)
            }
            let payload = fr24Service.downloadPayload(flightID: flightID, flight: rawFlight)
            return fr24JSONResponse(payload, status: payload["error"] == nil ? 200 : 503)
        }
        return jsonResponse(["error": "FR24 API not found"], status: 404)
    }

    private func onlineTileResponse(
        request: RuntimeRequest,
        pathComponents: [String]
    ) -> RuntimeResponse {
        guard request.method == "GET" else {
            return jsonResponse(["error": "Map tile requests require GET."], status: 405)
        }
        guard let onlineTileCache else {
            return jsonResponse(["error": "Online tile cache is unavailable."], status: 503)
        }
        let providerKey: String
        let coordinateStart: Int
        if pathComponents.first == "map-cache", pathComponents.count >= 5 {
            providerKey = pathComponents[1]
            coordinateStart = versionAdjustedIndex(in: pathComponents, defaultIndex: 2)
        } else if pathComponents.first == "terrain", pathComponents.count >= 5 {
            providerKey = pathComponents[1] == "terrarium" ? "terrain_terrarium" : pathComponents[1]
            coordinateStart = versionAdjustedIndex(in: pathComponents, defaultIndex: 2)
        } else {
            return jsonResponse(["error": "Invalid map tile path"], status: 404)
        }
        guard pathComponents.count > coordinateStart + 2,
              let z = Int(pathComponents[coordinateStart]),
              let x = Int(pathComponents[coordinateStart + 1]),
              let y = Int((pathComponents[coordinateStart + 2] as NSString).deletingPathExtension) else {
            return jsonResponse(["error": "Invalid map tile coordinate"], status: 404)
        }
        let suffixStart = coordinateStart + 3
        let demandGeneration: UInt64 = pathComponents.count > suffixStart + 1
            && pathComponents[suffixStart] == "demand"
            ? UInt64(pathComponents[suffixStart + 1]) ?? 0
            : 0

        let initialState = onlineTileCache.tile(
            providerKey: providerKey,
            z: z,
            x: x,
            y: y,
            waitForDownload: 0,
            demandGeneration: demandGeneration,
            priority: .visible
        )
        if case let .hit(data, contentType) = initialState {
            return onlineTileHitResponse(data: data, contentType: contentType)
        }

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
        if let parent = fallbackCoordinates.first {
            _ = onlineTileCache.tile(
                providerKey: providerKey,
                z: parent.z,
                x: parent.x,
                y: parent.y,
                waitForDownload: 0,
                demandGeneration: demandGeneration,
                priority: .preview
            )
        }

        let finalState: SimNavOnlineTileCache.TileState
        switch initialState {
        case .queued, .pending:
            finalState = onlineTileCache.tile(
                providerKey: providerKey,
                z: z,
                x: x,
                y: y,
                waitForDownload: SimNavOnlineTileCache.tileResponseWaitTimeout,
                demandGeneration: demandGeneration,
                priority: .visible
            )
        case .failed, .hit:
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
        return placeholderTileResponse(cacheState: onlineTileStateName(finalState))
    }

    private func onlineTileHitResponse(data: Data, contentType: String) -> RuntimeResponse {
        RuntimeResponse(
            status: 200,
            headers: [
                "Cache-Control": "public, max-age=31536000, immutable",
                "Content-Type": contentType,
                "X-Map-Cache": "HIT"
            ],
            body: data
        )
    }

    private func onlineTileFallbackResponse(
        data: Data,
        contentType: String,
        sourceZoom: Int,
        fallbackLevels: Int,
        targetState: SimNavOnlineTileCache.TileState
    ) -> RuntimeResponse {
        RuntimeResponse(
            status: 200,
            headers: [
                "Cache-Control": "no-store",
                "Content-Type": contentType,
                "X-Map-Cache": "FALLBACK",
                "X-Map-Fallback-Levels": String(fallbackLevels),
                "X-Map-Fallback-Zoom": String(sourceZoom),
                "X-Map-Fallback-Target-State": onlineTileStateName(targetState)
            ],
            body: data
        )
    }

    private func onlineTileStateName(_ state: SimNavOnlineTileCache.TileState) -> String {
        switch state {
        case .hit: "HIT"
        case .queued: "QUEUED"
        case .pending: "PENDING"
        case .failed: "MISS"
        }
    }

    private func offlineMapsResponse(
        request: RuntimeRequest,
        path: String,
        pathComponents: [String]
    ) -> RuntimeResponse {
        guard let mapStore else {
            return jsonResponse(["error": "Offline map storage is unavailable."], status: 503)
        }
        if path == "/offline-maps" {
            guard request.method == "GET" else {
                return jsonResponse(["error": "Offline map status requires GET."], status: 405)
            }
            return jsonResponse(mapStore.statusPayload())
        }
        if path == "/offline-maps/select" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Offline map selection requires POST."], status: 405)
            }
            let body = jsonBody(request.body)
            return jsonResponse(mapStore.selectResource(name: body["name"] as? String ?? ""))
        }
        if path == "/offline-maps/import" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Offline map import requires POST."], status: 405)
            }
            guard let source = request.bodyFileURL else {
                return jsonResponse(["error": "Offline map upload body is missing."], status: 400)
            }
            do {
                return jsonResponse(try mapStore.importResource(from: source))
            } catch {
                return jsonResponse(["error": error.localizedDescription], status: 400)
            }
        }
        if path == "/offline-maps/delete" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Offline map deletion requires POST."], status: 405)
            }
            let body = jsonBody(request.body)
            return jsonResponse(mapStore.deleteResource(name: body["name"] as? String ?? ""))
        }
        if path == "/offline-maps/compact" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Offline map compaction requires POST."], status: 405)
            }
            let body = jsonBody(request.body)
            return jsonResponse(mapStore.compactResource(name: body["name"] as? String ?? ""))
        }
        if path == "/offline-maps/download" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Offline map download requires POST."], status: 405)
            }
            return jsonResponse(["download_job": mapStore.startDownload(payload: jsonBody(request.body))])
        }
        if path == "/offline-maps/cancel" {
            guard request.method == "POST" else {
                return jsonResponse(["error": "Offline map cancellation requires POST."], status: 405)
            }
            return jsonResponse(["download_job": mapStore.cancelDownload()])
        }
        if pathComponents.count >= 4, pathComponents[1] == "tile" {
            let coordinateStart = versionAdjustedIndex(in: pathComponents, defaultIndex: 2)
            guard pathComponents.count > coordinateStart + 2,
                  let z = Int(pathComponents[coordinateStart]),
                  let x = Int(pathComponents[coordinateStart + 1]),
                  let y = Int((pathComponents[coordinateStart + 2] as NSString).deletingPathExtension),
                  let tile = mapStore.activeTile(z: z, x: x, y: y) else {
                return placeholderTileResponse()
            }
            return RuntimeResponse(
                status: 200,
                headers: [
                    "Cache-Control": "no-store",
                    "Content-Type": tile.contentType
                ].merging(tile.headers) { _, new in new },
                body: tile.data
            )
        }
        if pathComponents.count >= 6, pathComponents[1] == "resource" {
            let coordinateStart = versionAdjustedIndex(in: pathComponents, defaultIndex: 3)
            guard pathComponents.count > coordinateStart + 2,
                  let z = Int(pathComponents[coordinateStart]),
                  let x = Int(pathComponents[coordinateStart + 1]),
                  let y = Int((pathComponents[coordinateStart + 2] as NSString).deletingPathExtension),
                  let tile = mapStore.resourceTile(
                    name: decoded(pathComponents[2]),
                    z: z,
                    x: x,
                    y: y
                  ) else {
                return placeholderTileResponse()
            }
            return RuntimeResponse(
                status: 200,
                headers: [
                    "Cache-Control": "no-store",
                    "Content-Type": tile.contentType
                ].merging(tile.headers) { _, new in new },
                body: tile.data
            )
        }
        if pathComponents.count >= 3, pathComponents[1] == "pmtiles" {
            let filenameIndex = versionAdjustedIndex(in: pathComponents, defaultIndex: 2)
            guard pathComponents.count > filenameIndex else {
                return jsonResponse(["error": "Invalid PMTiles path"], status: 404)
            }
            let filename = decoded(pathComponents[filenameIndex])
            guard filename.lowercased().hasSuffix(".pmtiles") else {
                return jsonResponse(["error": "Invalid PMTiles filename"], status: 404)
            }
            let name = String(filename.dropLast(".pmtiles".count))
            guard let result = mapStore.pmtilesFileResponse(
                name: name,
                rangeHeader: request.headerValue("Range")
            ) else {
                return jsonResponse(["error": "PMTiles resource not found"], status: 404)
            }
            return RuntimeResponse(
                status: result.statusCode,
                headers: ["Content-Type": result.contentType]
                    .merging(result.headers) { _, new in new },
                body: result.data
            )
        }
        return jsonResponse(["error": "Offline maps API not found"], status: 404)
    }

    private func placeholderTileResponse(cacheState: String = "MISS") -> RuntimeResponse {
        RuntimeResponse(
            status: 200,
            headers: [
                "Cache-Control": "no-store",
                "Content-Type": "image/png",
                "X-Map-Cache": cacheState,
                "X-Offline-Map": cacheState
            ],
            body: Self.transparentTile
        )
    }

    private func versionAdjustedIndex(in parts: [String], defaultIndex: Int) -> Int {
        guard parts.indices.contains(defaultIndex), parts[defaultIndex].hasPrefix("_v") else {
            return defaultIndex
        }
        return defaultIndex + 1
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

    private func decoded(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }

    private func encodedPathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func jsonBody(_ data: Data) -> [String: Any] {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private func fr24JSONResponse(_ object: Any, status: Int = 200) -> RuntimeResponse {
        let canonicalized = canonicalizedFR24AirportObject(object)
        return jsonResponse(
            exposesLocalFilePaths ? canonicalized : redactFR24LocalFilePaths(canonicalized),
            status: status
        )
    }

    private func canonicalizedFR24AirportObject(_ value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            var output = dictionary.reduce(into: [String: Any]()) { result, entry in
                result[entry.key] = canonicalizedFR24AirportObject(entry.value)
            }
            let keys = Set(output.keys)
            if !keys.isDisjoint(with: [
                "origin_icao", "origin_iata", "origin_actual_code",
                "dest_icao", "dest_iata", "dest_actual_code"
            ]) {
                output = plannerService.canonicalizedFR24FlightAirports(output)
            }
            return output
        case let array as [Any]:
            return array.map(canonicalizedFR24AirportObject)
        default:
            return value
        }
    }

    private func redactFR24LocalFilePaths(_ value: Any) -> Any {
        let privateKeys = Set(["root", "path", "gpx_path", "json_path", "share_path"])
        switch value {
        case let dictionary as [String: Any]:
            return dictionary.reduce(into: [String: Any]()) { output, entry in
                guard !privateKeys.contains(entry.key.lowercased()) else { return }
                output[entry.key] = redactFR24LocalFilePaths(entry.value)
            }
        case let array as [Any]:
            return array.map(redactFR24LocalFilePaths)
        default:
            return value
        }
    }

    private func jsonResponse(_ object: Any, status: Int = 200) -> RuntimeResponse {
        let sanitized = sanitizeJSON(object)
        let data = (try? JSONSerialization.data(
            withJSONObject: sanitized,
            options: [.sortedKeys]
        )) ?? Data("{}".utf8)
        return RuntimeResponse(
            status: status,
            headers: [
                "Cache-Control": "no-store",
                "Content-Type": "application/json"
            ],
            body: data
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
}
