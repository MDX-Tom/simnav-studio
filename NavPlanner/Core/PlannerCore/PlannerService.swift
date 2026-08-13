import Foundation
#if canImport(os.signpost)
import os.signpost
#endif

#if canImport(os.signpost)
private typealias PlannerPerformanceSignpostID = OSSignpostID
#else
private struct PlannerPerformanceSignpostID {}
#endif

final class PlannerService: @unchecked Sendable {
#if canImport(os.signpost)
    private let performanceLog: OSLog
#endif
    private let dataStore: LocalDataStore
    private let planningCacheLock = NSLock()
    private var planningCacheDatabaseKey: String?
    private var airwayGraphCache: AirwayGraph?
    private var routeBetweenCache: [RouteBetweenCacheKey: RoutePath] = [:]
    private var navOverlayCacheDatabaseKey: String?
    private var navOverlayCache: [String: [[String: Any]]]?
    private static let localizedAirportAliases: [String: [String]] = [
        "上海": ["ZSPD", "ZSSS"],
        "上海浦东": ["ZSPD"],
        "浦东": ["ZSPD"],
        "上海虹桥": ["ZSSS"],
        "虹桥": ["ZSSS"],
        "香港": ["VHHH"],
        "香港国际": ["VHHH"],
        "赤鱲角": ["VHHH"],
        "北京": ["ZBAA", "ZBAD"],
        "北京首都": ["ZBAA"],
        "首都": ["ZBAA"],
        "拉萨": ["ZULS"],
        "拉萨贡嘎": ["ZULS"],
        "贡嘎": ["ZULS"]
    ]

    init(
        dataStore: LocalDataStore,
        performanceSubsystem: String = Bundle.main.bundleIdentifier ?? "com.mdxtom.simnavstudio"
    ) {
        self.dataStore = dataStore
#if canImport(os.signpost)
        self.performanceLog = OSLog(
            subsystem: performanceSubsystem,
            category: "PlannerPerformance"
        )
#endif
    }

    private func beginPerformanceSignpost(_ name: StaticString) -> PlannerPerformanceSignpostID {
#if canImport(os.signpost)
        let signpostID = OSSignpostID(log: performanceLog)
        os_signpost(.begin, log: performanceLog, name: name, signpostID: signpostID)
        return signpostID
#else
        return PlannerPerformanceSignpostID()
#endif
    }

    private func endPerformanceSignpost(_ name: StaticString, signpostID: PlannerPerformanceSignpostID) {
#if canImport(os.signpost)
        os_signpost(.end, log: performanceLog, name: name, signpostID: signpostID)
#endif
    }

    /// 在用户首次输入前以低优先级打开 SQLite 并触碰机场主索引。
    /// 查询固定为少量行，不构建航路图或 nav-overlay 全量缓存。
    func prewarmAirportIndex() {
        let signpostID = beginPerformanceSignpost("AirportIndexPrewarm")
        defer { endPerformanceSignpost("AirportIndexPrewarm", signpostID: signpostID) }
        _ = dataStore.read(fallback: false) { database in
            _ = try database.rows(
                sql: """
                select airport_identifier, iata_ata_designator,
                       airport_ref_latitude, airport_ref_longitude
                from tbl_airports
                where airport_identifier >= 'A'
                order by airport_identifier
                limit 32
                """
            )
            return true
        }
    }

    private struct ProcedureGroupKey: Hashable, Comparable {
        let routeType: String
        let seqno: Int

        static func < (lhs: ProcedureGroupKey, rhs: ProcedureGroupKey) -> Bool {
            if lhs.routeType != rhs.routeType {
                return lhs.routeType < rhs.routeType
            }
            return lhs.seqno < rhs.seqno
        }
    }

    private struct ProcedureRowScore: Comparable {
        let hasArcRadius: Int
        let usesFreshWaypoint: Int
        let hasRealWaypoint: Int
        let hasDrawablePath: Int
        let hasRealCenter: Int
        let waypoint: String

        static func < (lhs: ProcedureRowScore, rhs: ProcedureRowScore) -> Bool {
            let lhsParts = [
                lhs.hasArcRadius,
                lhs.usesFreshWaypoint,
                lhs.hasRealWaypoint,
                lhs.hasDrawablePath,
                lhs.hasRealCenter
            ]
            let rhsParts = [
                rhs.hasArcRadius,
                rhs.usesFreshWaypoint,
                rhs.hasRealWaypoint,
                rhs.hasDrawablePath,
                rhs.hasRealCenter
            ]
            for index in lhsParts.indices where lhsParts[index] != rhsParts[index] {
                return lhsParts[index] < rhsParts[index]
            }
            return lhs.waypoint < rhs.waypoint
        }
    }

    func invalidatePlanningCaches() {
        planningCacheLock.lock()
        resetPlanningCachesLocked(databaseKey: nil)
        planningCacheLock.unlock()
    }

    func databaseListPayload(query: String = "", limit: Int = 200) -> [String: Any] {
        dataStore.databaseListPayload(query: query, limit: limit)
    }

    func selectDatabasePayload(name: String) throws -> [String: Any] {
        let payload = try dataStore.selectDatabase(named: name)
        invalidatePlanningCaches()
        return payload
    }

    func importDatabasePayload(from source: URL) throws -> [String: Any] {
        let payload = try dataStore.importDatabase(from: source)
        invalidatePlanningCaches()
        return payload
    }

    func deleteDatabasePayload(name: String) throws -> [String: Any] {
        try dataStore.deleteDatabase(named: name)
    }

    func restoreBundledDatabasePayload() throws -> [String: Any] {
        let payload = try dataStore.restoreBundledDatabase()
        invalidatePlanningCaches()
        return payload
    }

    func headerPayload() -> [String: Any] {
        dataStore.read(fallback: dataStore.statusPayload()) { database in
            var header = try database.first(sql: "select * from tbl_header limit 1") ?? [:]
            header["local_status"] = "ready"
            header["database_path"] = self.dataStore.databaseURL?.path ?? ""
            header["database_name"] = self.dataStore.databaseURL?.lastPathComponent ?? "navdata.sqlite"
            header["message"] = "本地导航数据库已就绪"
            return header
        }
    }

    func search(query: String, limit: Int = 8) -> [SearchResult] {
        let signpostID = beginPerformanceSignpost("Search")
        defer { endPerformanceSignpost("Search", signpostID: signpostID) }
        let token = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !token.isEmpty else { return [] }
        let clampedLimit = max(1, min(limit, 50))
        let aliasIdentifiers = Self.airportAliasIdentifiers(for: query)
        let pattern = "\(token)%"
        let contains = "%\(token)%"

        let rows = dataStore.read(fallback: [[String: Any]]()) { database in
            var combinedRows: [[String: Any]] = []
            for identifier in aliasIdentifiers {
                if let row = try database.first(
                    sql: """
                    select airport_identifier as ident,
                           coalesce(airport_name, airport_identifier) as name,
                           airport_ref_latitude as lat,
                           airport_ref_longitude as lon,
                           'airport' as kind
                    from tbl_airports
                    where airport_identifier = ?
                      and airport_ref_latitude is not null
                      and airport_ref_longitude is not null
                    limit 1
                    """,
                    arguments: [.text(identifier)]
                ) {
                    combinedRows.append(row)
                }
            }
            combinedRows.append(contentsOf: try database.rows(
                sql: """
                select * from (
                    select airport_identifier as ident,
                           coalesce(airport_name, airport_identifier) as name,
                           airport_ref_latitude as lat,
                           airport_ref_longitude as lon,
                           'airport' as kind
                    from tbl_airports
                    where airport_identifier like ? or iata_ata_designator like ? or airport_name like ?
                    union all
                    select waypoint_identifier as ident,
                           coalesce(waypoint_name, waypoint_identifier) as name,
                           waypoint_latitude as lat,
                           waypoint_longitude as lon,
                           'waypoint' as kind
                    from tbl_enroute_waypoints
                    where waypoint_identifier like ? or waypoint_name like ?
                    union all
                    select vor_identifier as ident,
                           coalesce(vor_name, vor_identifier) as name,
                           vor_latitude as lat,
                           vor_longitude as lon,
                           'vor' as kind
                    from tbl_vhfnavaids
                    where vor_identifier like ? or vor_name like ?
                    union all
                    select ndb_identifier as ident,
                           coalesce(ndb_name, ndb_identifier) as name,
                           ndb_latitude as lat,
                           ndb_longitude as lon,
                           'ndb' as kind
                    from tbl_enroute_ndbnavaids
                    where ndb_identifier like ? or ndb_name like ?
                )
                where lat is not null and lon is not null
                order by
                    case when ident = ? then 0 else 1 end,
                    case kind when 'airport' then 0 when 'waypoint' then 1 else 2 end,
                    ident
                limit ?
                """,
                arguments: [
                    .text(pattern), .text(pattern), .text(contains),
                    .text(pattern), .text(contains),
                    .text(pattern), .text(contains),
                    .text(pattern), .text(contains),
                    .text(token), .int(clampedLimit)
                ]
            ))
            var seen = Set<String>()
            return combinedRows.filter { row in
                let key = "\(navString(row["kind"])):\(navString(row["ident"]))"
                return seen.insert(key).inserted
            }.prefix(clampedLimit).map { $0 }
        }
        return rows.compactMap(SearchResult.init(row:))
    }

    private static func airportAliasIdentifiers(for query: String) -> [String] {
        var normalized = query
            .folding(options: [.widthInsensitive, .caseInsensitive], locale: Locale(identifier: "zh_Hans_CN"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[\s·・\-]+"#, with: "", options: .regularExpression)
        for suffix in ["国际机场", "机场", "市"] where normalized.hasSuffix(suffix) {
            normalized.removeLast(suffix.count)
            break
        }
        guard normalized.count >= 2 else { return [] }
        let exact = localizedAirportAliases[normalized] ?? []
        let prefixMatches = localizedAirportAliases
            .filter { key, _ in key.hasPrefix(normalized) || normalized.hasPrefix(key) }
            .sorted { lhs, rhs in lhs.key.count < rhs.key.count }
            .flatMap { $0.value }
        var seen = Set<String>()
        return (exact + prefixMatches).filter { seen.insert($0).inserted }
    }

    func searchPayload(query: String) -> [String: Any] {
        ["results": search(query: query).map(\.dictionary)]
    }

    func airportPayload(ident: String) -> [String: Any]? {
        let signpostID = beginPerformanceSignpost("AirportPayload")
        defer { endPerformanceSignpost("AirportPayload", signpostID: signpostID) }
        return dataStore.read(fallback: nil as [String: Any]?) { database in
            guard let airportIdent = try resolveAirportIdentifier(ident, database: database),
                  let airport = try database.first(
                    sql: """
                    select *
                    from tbl_airports
                    where airport_identifier = ?
                    limit 1
                    """,
                    arguments: [.text(airportIdent)]
                  ) else {
                return nil
            }

            let runways = try database.rows(
                sql: """
                select runway_identifier, runway_length, runway_width,
                       runway_magnetic_bearing, runway_true_bearing,
                       landing_threshold_elevation, displaced_threshold_distance,
                       threshold_crossing_height, runway_gradient,
                       llz_identifier, llz_mls_gls_category,
                       surface_code, runway_latitude, runway_longitude
                from tbl_runways
                where airport_identifier = ?
                order by runway_identifier
                """,
                arguments: [.text(airportIdent)]
            )

            let communications = try database.rows(
                sql: """
                select communication_type, communication_frequency, callsign
                from tbl_airport_communication
                where airport_identifier = ?
                order by communication_type, communication_frequency
                """,
                arguments: [.text(airportIdent)]
            )

            return [
                "airport": airport,
                "runways": runways,
                "communications": communications,
                "procedures": [
                    "sid": try procedureSummaries(table: "tbl_sids", airport: airportIdent, database: database),
                    "star": try procedureSummaries(table: "tbl_stars", airport: airportIdent, database: database),
                    "approach": try procedureSummaries(table: "tbl_iaps", airport: airportIdent, database: database)
                ]
            ]
        }
    }

    func procedurePayload(type: String, airport: String, procedure: String, transition: String) -> [String: Any] {
        guard let table = procedureTable(for: type) else {
            return ["error": "未知 Procedure 类型"]
        }

        return dataStore.read(fallback: ["items": [], "path": [], "primary_path": [], "missed_path": []]) { database in
            let items = try procedureDetails(
                airport: airport.uppercased(),
                table: table,
                procedure: procedure.uppercased(),
                transition: transition.uppercased(),
                database: database
            )
            return buildProcedureGeometry(items: items)
        }
    }

    func procedurePreviewPayload(
        type: String,
        airport: String,
        selections: [[String: Any]]
    ) -> [String: Any] {
        guard let table = procedureTable(for: type) else {
            return ["error": "未知 Procedure 类型"]
        }

        let normalizedAirport = airport.uppercased()
        var normalizedSelections: [[String: String]] = []
        var seenSelections = Set<String>()
        for selection in selections {
            let procedure = navString(selection["procedure_identifier"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            guard !procedure.isEmpty else { continue }
            let transition = normalizedProcedureTransition(selection["transition_identifier"])
            let key = "\(procedure)\u{0}\(transition)"
            guard !seenSelections.contains(key) else { continue }
            seenSelections.insert(key)
            normalizedSelections.append([
                "procedure_identifier": procedure,
                "transition_identifier": transition,
                "group_identifier": navString(selection["group_identifier"])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
            ])
        }

        guard !normalizedSelections.isEmpty else {
            return [
                "airport": normalizedAirport,
                "type": type.lowercased(),
                "procedures": []
            ]
        }

        let fallback: [String: Any] = [
            "airport": normalizedAirport,
            "type": type.lowercased(),
            "procedures": []
        ]
        return dataStore.read(fallback: fallback) { database in
            let procedures = Array(Set(normalizedSelections.compactMap { $0["procedure_identifier"] })).sorted()
            var rows: [[String: Any]] = []
            // 分块只用于避开不同 SQLite 构建的绑定变量上限；对当前机场通常仍只执行一块。
            for start in stride(from: 0, to: procedures.count, by: 400) {
                let end = min(start + 400, procedures.count)
                let chunk = Array(procedures[start..<end])
                let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
                rows.append(contentsOf: try database.rows(
                    sql: """
                    select procedure_identifier, transition_identifier,
                           seqno, waypoint_identifier, waypoint_latitude, waypoint_longitude,
                           waypoint_description_code, turn_direction, rnp,
                           path_termination, route_type, magnetic_course, route_distance_holding_distance_time,
                           distance_time, altitude_description, altitude1, altitude2,
                           transition_altitude, speed_limit_description, speed_limit, vertical_angle,
                           arc_radius, theta, rho, center_waypoint,
                           center_waypoint_latitude, center_waypoint_longitude
                    from \(table)
                    where airport_identifier = ?
                      and upper(procedure_identifier) in (\(placeholders))
                    order by procedure_identifier, transition_identifier, seqno
                    """,
                    arguments: [.text(normalizedAirport)] + chunk.map { .text($0) }
                ))
            }

            var rowsByVariant: [String: [[String: Any]]] = [:]
            for row in rows {
                let procedure = navString(row["procedure_identifier"]).uppercased()
                let transition = normalizedProcedureTransition(row["transition_identifier"])
                rowsByVariant["\(procedure)\u{0}\(transition)", default: []].append(row)
            }

            let previews = normalizedSelections.compactMap { selection -> [String: Any]? in
                guard let procedure = selection["procedure_identifier"],
                      let transition = selection["transition_identifier"] else {
                    return nil
                }
                let commonRows = normalizeProcedureRows(rowsByVariant["\(procedure)\u{0}ALL"] ?? [])
                let transitionRows = transition == "ALL"
                    ? []
                    : normalizeProcedureRows(rowsByVariant["\(procedure)\u{0}\(transition)"] ?? [])
                let items: [[String: Any]]
                if transition == "ALL" {
                    items = commonRows
                } else if table == "tbl_stars" {
                    items = commonRows + transitionRows
                } else {
                    items = transitionRows + commonRows
                }
                guard items.contains(where: { procedureItemPoint($0) != nil }) else {
                    return nil
                }

                let geometry = buildProcedureGeometry(items: items)
                let waypoints = items.compactMap { item -> [String: Any]? in
                    guard let point = procedureItemPoint(item) else { return nil }
                    return [
                        "identifier": navString(item["waypoint_identifier"]).uppercased(),
                        "lat": point["lat"] ?? 0,
                        "lon": point["lon"] ?? 0
                    ]
                }
                return [
                    "procedure_identifier": procedure,
                    "transition_identifier": transition,
                    "group_identifier": selection["group_identifier"] ?? "",
                    "path": geometry["path"] ?? [],
                    "primary_path": geometry["primary_path"] ?? [],
                    "missed_path": geometry["missed_path"] ?? [],
                    "waypoints": waypoints
                ]
            }

            return [
                "airport": normalizedAirport,
                "type": type.lowercased(),
                "procedures": previews
            ]
        }
    }

    func navOverlayPayload(
        south: Double,
        west: Double,
        north: Double,
        east: Double,
        zoom: Int,
        shouldCancel: () -> Bool = { false }
    ) -> [String: Any] {
        let signpostID = beginPerformanceSignpost("NavOverlayPayload")
        defer { endPerformanceSignpost("NavOverlayPayload", signpostID: signpostID) }
        if shouldCancel() {
            return emptyOverlayPayload()
        }
        let southBound = min(south, north)
        let northBound = max(south, north)
        var westBound = west
        var eastBound = east
        if westBound > eastBound {
            eastBound += 360
        }
        let margin = zoom >= 8 ? 0.12 : zoom >= 6 ? 0.35 : 0.9
        westBound -= margin
        eastBound += margin
        let requestSouth = southBound - margin
        let requestNorth = northBound + margin
        let worldOffsets = worldCopyOffsetsForBounds(west: westBound, east: eastBound)

        return dataStore.read(fallback: emptyOverlayPayload()) { database in
            if shouldCancel() {
                return emptyOverlayPayload()
            }
            let cache = try navOverlayData(database: database)
            if shouldCancel() {
                return emptyOverlayPayload()
            }

            let airports: [[String: Any]]
            if zoom >= 7 {
                let maxAirports = zoom >= 8 ? 2400 : 800
                airports = Array(cache["airports", default: []]
                    .filter { pointInBounds($0, south: requestSouth, west: westBound, north: requestNorth, east: eastBound, worldOffsets: worldOffsets) }
                    .sorted { lhs, rhs in
                        let lhsRank = navString(lhs["iata"]).isEmpty ? 1 : 0
                        let rhsRank = navString(rhs["iata"]).isEmpty ? 1 : 0
                        if lhsRank != rhsRank { return lhsRank < rhsRank }
                        return navString(lhs["ident"]) < navString(rhs["ident"])
                    }
                    .prefix(maxAirports))
            } else {
                airports = []
            }

            var airwayCandidates = cache["airways", default: []]
                .filter { segmentIntersectsBounds($0, south: requestSouth, west: westBound, north: requestNorth, east: eastBound, worldOffsets: worldOffsets) }
            if shouldCancel() {
                return emptyOverlayPayload()
            }
            if let maxAirways = zoom >= 8 ? 18000 : zoom >= 6 ? 9000 : nil,
               airwayCandidates.count > maxAirways {
                airwayCandidates = spatiallyDistributeSegments(
                    airwayCandidates,
                    maxCount: maxAirways,
                    south: requestSouth,
                    west: westBound,
                    north: requestNorth,
                    east: eastBound,
                    worldOffsets: worldOffsets
                )
            }

            let airwayLabelBudget = zoom >= 8 ? 100_000 : zoom >= 7 ? 12 : 4
            let airwayLabelRepeat = zoom >= 9 ? 1 : zoom >= 8 ? 4 : zoom >= 7 ? 8 : 20
            var airwayLabelCounts: [String: Int] = [:]
            let airways = airwayCandidates.map { segment -> [String: Any] in
                let name = navString(segment["name"])
                let routeLabelCount = airwayLabelCounts[name, default: 0]
                let label = zoom >= 6
                    && routeLabelCount < airwayLabelBudget
                    && (routeLabelCount == 0 || routeLabelCount.isMultiple(of: airwayLabelRepeat))
                airwayLabelCounts[name] = routeLabelCount + 1
                var output: [String: Any] = [
                    "name": name,
                    "from": navString(segment["from"]),
                    "to": navString(segment["to"]),
                    "path": segment["path"] ?? [],
                    "direction": navString(segment["direction"]),
                    "area_code": navString(segment["area_code"]),
                    "label": label
                ]
                if label {
                    output["label_at"] = segmentLabelPoint(segment)
                }
                return output
            }

            var waypoints: [[String: Any]] = []
            if zoom >= 7 {
                let maxWaypoints = zoom >= 8 ? 1400 : 420
                waypoints = Array(cache["waypoints", default: []]
                    .filter { pointInBounds($0, south: requestSouth, west: westBound, north: requestNorth, east: eastBound, worldOffsets: worldOffsets) }
                    .prefix(maxWaypoints))
            }
            if zoom >= 9 {
                let terminalWaypoints = cache["terminal_waypoints", default: []]
                    .filter { pointInBounds($0, south: requestSouth, west: westBound, north: requestNorth, east: eastBound, worldOffsets: worldOffsets) }
                    .prefix(2400)
                waypoints.append(contentsOf: terminalWaypoints)
            }

            if shouldCancel() {
                return emptyOverlayPayload()
            }

            var navaids: [[String: Any]] = []
            if zoom >= 5 {
                let maxNavaids = zoom >= 8 ? 700 : 260
                navaids = Array(cache["navaids", default: []]
                    .filter { pointInBounds($0, south: requestSouth, west: westBound, north: requestNorth, east: eastBound, worldOffsets: worldOffsets) }
                    .prefix(maxNavaids))
            }
            if zoom >= 9 {
                let terminalNavaids = cache["terminal_navaids", default: []]
                    .filter { pointInBounds($0, south: requestSouth, west: westBound, north: requestNorth, east: eastBound, worldOffsets: worldOffsets) }
                    .prefix(500)
                navaids.append(contentsOf: terminalNavaids)
            }

            let runways = zoom >= 9 ? Array(cache["runways", default: []]
                .filter { segmentIntersectsBounds($0, south: requestSouth, west: westBound, north: requestNorth, east: eastBound, worldOffsets: worldOffsets) }
                .prefix(1200)) : []

            let ils = zoom >= 9 ? Array(cache["ils", default: []]
                .filter { segmentIntersectsBounds($0, south: requestSouth, west: westBound, north: requestNorth, east: eastBound, worldOffsets: worldOffsets) }
                .prefix(400)) : []

            return [
                "airports": airports,
                "airways": airways,
                "waypoints": waypoints,
                "navaids": navaids,
                "runways": runways,
                "ils": ils
            ]
        }
    }

    func routeResolvePayload(
        departure: String,
        arrival: String,
        route: String,
        departureRunway: String = "ALL",
        arrivalRunway: String = "ALL"
    ) -> [String: Any] {
        let signpostID = beginPerformanceSignpost("RouteResolvePayload")
        defer { endPerformanceSignpost("RouteResolvePayload", signpostID: signpostID) }
        let departureToken = departure.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let arrivalToken = arrival.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let routeText = route.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDepartureRunway = normalizedRunwayChoice(departureRunway)
        let normalizedArrivalRunway = normalizedRunwayChoice(arrivalRunway)
        return dataStore.read(fallback: routeErrorPayload("本地导航数据库不可用。")) { database in
            guard let departurePoint = try lookupDepartureArrivalPoint(departureToken, database: database),
                  let arrivalPoint = try lookupDepartureArrivalPoint(arrivalToken, database: database) else {
                return routeErrorPayload("Departure or arrival could not be resolved.")
            }

            if routeText.isEmpty,
               let guidedRoute = try procedureGuidedRoutePayload(
                departurePoint: departurePoint,
                arrivalPoint: arrivalPoint,
                departureRunway: normalizedDepartureRunway,
                arrivalRunway: normalizedArrivalRunway,
                database: database
               ) {
                return guidedRoute
            }
            if routeText.isEmpty {
                let autoRoute = try ifrrRouteBetween(departurePoint, arrivalPoint, database: database)
                let points = dedupeRoutePoints(autoRoute.points)
                let hasAirwayLeg = autoRoute.legs.contains { navString($0["type"]) == "airway" }
                return [
                    "departure": departurePoint,
                    "arrival": arrivalPoint,
                    "legs": autoRoute.legs,
                    "points": points,
                    "segments": buildBasicSegments(points),
                    "generated": true,
                    "route_display": autoRoute.routeDisplay,
                    "distance_nm": pathLengthNM(points),
                    "selected_procedures": [:],
                    "selected_runways": [
                        "departure": normalizedDepartureRunway,
                        "arrival": normalizedArrivalRunway
                    ],
                    "message": hasAirwayLeg
                        ? "已按本地 IFR 航路网络自动规划。"
                        : "未找到连续航路网络，已使用直飞航路。"
                ]
            }

            var points = [departurePoint]
            var legs: [[String: Any]] = []
            let routeTokens = routeText
                .uppercased()
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
            var index = 0
            var hasExpandedRouteContext = false

            while index < routeTokens.count {
                let token = routeTokens[index]
                if token == "DCT" {
                    if index == 0 {
                        return routeErrorPayload("DCT must follow a known fix or airport.")
                    }
                    if index + 1 >= routeTokens.count {
                        return routeErrorPayload("DCT is missing the target fix.")
                    }
                    let targetToken = routeTokens[index + 1]
                    guard let target = try lookupPoint(targetToken, database: database) else {
                        return routeErrorPayload("DCT target \(targetToken) not found.")
                    }
                    appendRoutePoint(target, to: &points, legs: &legs, preferredType: "direct")
                    hasExpandedRouteContext = true
                    index += 2
                    continue
                }
                if token == "***" {
                    if index == 0 {
                        return routeErrorPayload("*** must be between two fixes.")
                    }
                    if index + 1 >= routeTokens.count {
                        return routeErrorPayload("*** is missing the target fix.")
                    }
                    let sourceToken = routeTokens[index - 1]
                    let source = (points.last.map { navString($0["ident"]) } == sourceToken)
                        ? points.last
                        : (try lookupPoint(sourceToken, database: database))
                    guard let source else {
                        return routeErrorPayload("*** source \(sourceToken) not found.")
                    }
                    let nextAirway: String?
                    if index + 2 < routeTokens.count,
                       try airwayExists(routeTokens[index + 2], database: database) {
                        nextAirway = routeTokens[index + 2]
                    } else {
                        nextAirway = nil
                    }
                    let targetToken = routeTokens[index + 1]
                    guard let target = try resolveRouteBoundaryPoint(
                        targetToken,
                        airway: nextAirway,
                        neighbor: source,
                        database: database
                    ) else {
                        return routeErrorPayload("*** target \(targetToken) not found.")
                    }
                    let segment = try ifrrRouteBetween(source, target, database: database)
                    if let first = segment.points.first,
                       navString(first["ident"]) == navString(source["ident"]) {
                        points[points.count - 1] = first
                    }
                    points.append(contentsOf: segment.points.dropFirst())
                    legs.append(contentsOf: segment.legs)
                    hasExpandedRouteContext = true
                    index += 2
                    continue
                }
                if try airwayExists(token, database: database) {
                    if !hasExpandedRouteContext {
                        return routeErrorPayload("Airway \(token) must follow a fix.")
                    }
                    if index + 1 >= routeTokens.count {
                        return routeErrorPayload("Airway \(token) is missing an exit fix.")
                    }
                    let exitToken = routeTokens[index + 1]
                    guard let entry = points.last,
                          let exitPoint = try resolveRouteBoundaryPoint(exitToken, airway: token, neighbor: entry, database: database) else {
                        return routeErrorPayload("Exit fix \(exitToken) not found.")
                    }
                    guard let airway = try expandAirway(
                        token,
                        entry: navString(entry["ident"]),
                        exit: navString(exitPoint["ident"]),
                        database: database
                    ), let first = airway.points.first else {
                        return routeErrorPayload("Airway \(token) does not connect \(navString(entry["ident"])) to \(navString(exitPoint["ident"])).")
                    }
                    if navString(first["ident"]) == navString(entry["ident"]) {
                        points[points.count - 1] = first
                    }
                    for point in airway.points.dropFirst() {
                        appendRoutePoint(point, to: &points, legs: &legs, preferredType: nil)
                    }
                    legs.append([
                        "type": "airway",
                        "name": token,
                        "entry": airway.entry,
                        "exit": airway.exit,
                        "count": airway.points.count,
                        "distance_nm": pathLengthNM(airway.points)
                    ])
                    hasExpandedRouteContext = true
                    index += 2
                    continue
                }
                guard let point = try lookupPoint(token, database: database) else {
                    return routeErrorPayload("Waypoint \(token) not found.")
                }
                appendRoutePoint(point, to: &points, legs: &legs, preferredType: "fix")
                hasExpandedRouteContext = true
                index += 1
            }

            points.append(arrivalPoint)
            let deduped = dedupeRoutePoints(points)
            let distance = pathLengthNM(deduped)
            let routeDisplay = routeDisplayFromExpandedLegs(legs)

            return [
                "departure": departurePoint,
                "arrival": arrivalPoint,
                "legs": legs,
                "points": deduped,
                "segments": buildBasicSegments(deduped),
                "generated": routeText.isEmpty,
                "route_display": routeDisplay,
                "distance_nm": distance
            ]
        }
    }

    func airwayPayload(airway: String) -> [String: Any] {
        let token = airway.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !token.isEmpty else {
            return ["items": []]
        }
        let items = dataStore.read(fallback: [[String: Any]]()) { database in
            try database.rows(
                sql: """
                select route_identifier, seqno, waypoint_identifier, waypoint_latitude, waypoint_longitude,
                       waypoint_description_code, route_type, minimum_altitude1, maximum_altitude,
                       outbound_course, inbound_distance
                from tbl_enroute_airways
                where route_identifier = ?
                order by cast(seqno as integer), area_code, icao_code, route_type
                """,
                arguments: [.text(token)]
            )
        }
        return ["items": items]
    }

    func fr24RouteAirportsPayload(departure: String, arrival: String) -> [String: Any] {
        let departureToken = departure.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let arrivalToken = arrival.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        return dataStore.read(fallback: ["error": "本地导航数据库不可用。"]) { database in
            guard let departurePoint = try lookupDepartureArrivalPoint(departureToken, database: database),
                  let arrivalPoint = try lookupDepartureArrivalPoint(arrivalToken, database: database) else {
                return ["error": "Departure or arrival could not be resolved."]
            }
            return [
                "departure": try fr24AirportInfo(point: departurePoint, database: database),
                "arrival": try fr24AirportInfo(point: arrivalPoint, database: database)
            ]
        }
    }

    func trackMatchPayload(departure: String, arrival: String, trackPoints: [[String: Any]]) -> [String: Any] {
        let departureToken = departure.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let arrivalToken = arrival.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        return dataStore.read(fallback: ["error": "本地导航数据库不可用。"]) { database in
            do {
                guard let departurePoint = try lookupDepartureArrivalPoint(departureToken, database: database),
                      let arrivalPoint = try lookupDepartureArrivalPoint(arrivalToken, database: database) else {
                    return ["error": "Departure or arrival could not be resolved."]
                }

                let normalizedTrackPoints = normalizeImportedTrackPoints(trackPoints)
                guard normalizedTrackPoints.count >= 2 else {
                    return ["error": "Imported track needs at least two lat/lon points."]
                }

                let procedureMatch = try matchProceduresForTrack(
                    departurePoint: departurePoint,
                    arrivalPoint: arrivalPoint,
                    departureRunway: "ALL",
                    arrivalRunway: "ALL",
                    trackPoints: normalizedTrackPoints,
                    database: database
                )
                let airwayTrackPoints = procedureMatch.usesProcedureFirst
                    ? procedureMatch.enrouteTrackPoints
                    : normalizedTrackPoints
                let matched = try matchTrackPointsToAirways(
                    airwayTrackPoints,
                    database: database
                )
                let matchedRoute: RoutePath
                let selectedProcedures: [String: Any]
                let selectedRunways: [String: String]
                if procedureMatch.usesProcedureFirst {
                    matchedRoute = try applyProcedureBoundaries(
                        matched: matched,
                        sid: procedureMatch.sid?.candidate,
                        star: procedureMatch.star?.candidate,
                        database: database
                    )
                    selectedProcedures = procedureMatch.selectedProcedures
                    selectedRunways = procedureMatch.selectedRunways
                } else {
                    let legacyMatch = try matchProceduresAfterEnroute(
                        departurePoint: departurePoint,
                        arrivalPoint: arrivalPoint,
                        matched: matched,
                        departureRunway: "ALL",
                        arrivalRunway: "ALL",
                        trackPoints: normalizedTrackPoints,
                        database: database
                    )
                    matchedRoute = legacyMatch.matched
                    selectedProcedures = legacyMatch.selectedProcedures
                    selectedRunways = legacyMatch.selectedRunways
                }
                let points = dedupeRoutePoints([departurePoint] + matchedRoute.points + [arrivalPoint])
                return [
                    "departure": departurePoint,
                    "arrival": arrivalPoint,
                    "legs": matchedRoute.legs,
                    "points": points,
                    "segments": buildBasicSegments(points),
                    "generated": true,
                    "message": "已从 \(normalizedTrackPoints.count) 个导入轨迹点匹配本地航路。",
                    "route_display": matchedRoute.routeDisplay,
                    "selected_procedures": selectedProcedures,
                    "selected_runways": selectedRunways,
                    "distance_nm": pathLengthNM(points),
                    "source": [
                        "provider": "Imported track",
                        "track_points": normalizedTrackPoints.map(\.dictionary)
                    ]
                ]
            } catch {
                return ["error": error.localizedDescription]
            }
        }
    }

    private func routeErrorPayload(_ message: String) -> [String: Any] {
        ["error": message]
    }

    private struct ProcedureRouteCandidate {
        let procedure: String
        let transition: String
        let runway: String
        let points: [[String: Any]]
        let endpoint: [String: Any]
        let distanceNM: Double
    }

    private struct RoutePath {
        let points: [[String: Any]]
        let legs: [[String: Any]]
        let routeDisplay: String
    }

    private struct ProcedureTrackAlignment {
        let candidate: ProcedureRouteCandidate
        let candidateStartIndex: Int
        let candidateEndIndex: Int
        let trackStartIndex: Int
        let trackEndIndex: Int
        let matchedFitNM: Double
        let fullFitNM: Double
        let coverageScore: Double
        let meanPointDistanceNM: Double
    }

    private struct ProcedureMatch {
        let sid: ProcedureTrackAlignment?
        let star: ProcedureTrackAlignment?
        let approach: ProcedureTrackAlignment?
        let enrouteTrackPoints: [TrackPoint]
        let selectedProcedures: [String: Any]
        let selectedRunways: [String: String]
        let usesProcedureFirst: Bool
    }

    private struct LegacyProcedureMatch {
        let matched: RoutePath
        let selectedProcedures: [String: Any]
        let selectedRunways: [String: String]
    }

    private struct RouteBetweenCacheKey: Hashable {
        let departureIdent: String
        let departureLat: Int
        let departureLon: Int
        let arrivalIdent: String
        let arrivalLat: Int
        let arrivalLon: Int

        init(departurePoint: [String: Any], arrivalPoint: [String: Any]) {
            self.departureIdent = navString(departurePoint["ident"]).uppercased()
            self.departureLat = Self.coordinateCacheKey(navDouble(departurePoint["lat"]) ?? 0)
            self.departureLon = Self.coordinateCacheKey(navDouble(departurePoint["lon"]) ?? 0)
            self.arrivalIdent = navString(arrivalPoint["ident"]).uppercased()
            self.arrivalLat = Self.coordinateCacheKey(navDouble(arrivalPoint["lat"]) ?? 0)
            self.arrivalLon = Self.coordinateCacheKey(navDouble(arrivalPoint["lon"]) ?? 0)
        }

        private static func coordinateCacheKey(_ value: Double) -> Int {
            Int((value * 100_000).rounded())
        }
    }

    private struct TrackPoint {
        let lat: Double
        let lon: Double

        var dictionary: [String: Any] {
            ["lat": lat, "lon": lon]
        }
    }

    private struct GraphEdge {
        let to: String
        let distanceNM: Double
        let airway: String
    }

    private struct AirwayGraph {
        var nodes: [String: [String: Any]]
        var adjacency: [String: [GraphEdge]]
        var nodeAirways: [String: Set<String>]
        var nodesByIdent: [String: [String]]
        var spatialBuckets: [GraphSpatialKey: [String]]
    }

    private struct GraphSpatialKey: Hashable {
        let latitude: Int
        let longitude: Int
    }

    private struct RouteHeap {
        private var values: [(cost: Double, key: String)] = []

        var isEmpty: Bool { values.isEmpty }

        mutating func push(cost: Double, key: String) {
            values.append((cost, key))
            siftUp(values.count - 1)
        }

        mutating func popMin() -> (cost: Double, key: String)? {
            guard !values.isEmpty else { return nil }
            if values.count == 1 {
                return values.removeLast()
            }
            let output = values[0]
            values[0] = values.removeLast()
            siftDown(0)
            return output
        }

        private mutating func siftUp(_ index: Int) {
            var child = index
            while child > 0 {
                let parent = (child - 1) / 2
                guard isLess(values[child], than: values[parent]) else { break }
                values.swapAt(child, parent)
                child = parent
            }
        }

        private mutating func siftDown(_ index: Int) {
            var parent = index
            while true {
                let left = parent * 2 + 1
                let right = left + 1
                var candidate = parent
                if left < values.count, isLess(values[left], than: values[candidate]) {
                    candidate = left
                }
                if right < values.count, isLess(values[right], than: values[candidate]) {
                    candidate = right
                }
                guard candidate != parent else { break }
                values.swapAt(parent, candidate)
                parent = candidate
            }
        }

        private func isLess(_ lhs: (cost: Double, key: String), than rhs: (cost: Double, key: String)) -> Bool {
            if lhs.cost != rhs.cost {
                return lhs.cost < rhs.cost
            }
            return lhs.key < rhs.key
        }
    }

    private func procedureGuidedRoutePayload(
        departurePoint: [String: Any],
        arrivalPoint: [String: Any],
        departureRunway: String,
        arrivalRunway: String,
        database: SQLiteDatabase
    ) throws -> [String: Any]? {
        let departureIdent = navString(departurePoint["ident"]).uppercased()
        let arrivalIdent = navString(arrivalPoint["ident"]).uppercased()
        let sidCandidates = try procedureRouteCandidates(
            table: "tbl_sids",
            airport: departureIdent,
            mode: "sid",
            runway: departureRunway,
            database: database
        )
        let starCandidates = try procedureRouteCandidates(
            table: "tbl_stars",
            airport: arrivalIdent,
            mode: "star",
            runway: arrivalRunway,
            database: database
        )
        guard !sidCandidates.isEmpty, !starCandidates.isEmpty else {
            return nil
        }

        let sidShortlist = sidCandidates.sorted {
            procedureDistanceSortKey($0, reference: arrivalPoint) < procedureDistanceSortKey($1, reference: arrivalPoint)
        }.prefix(8)
        let starShortlist = starCandidates.sorted {
            procedureDistanceSortKey($0, reference: departurePoint) < procedureDistanceSortKey($1, reference: departurePoint)
        }.prefix(8)

        var bestSID: ProcedureRouteCandidate?
        var bestSTAR: ProcedureRouteCandidate?
        var bestEnroute: RoutePath?
        var bestPoints: [[String: Any]] = []
        var bestDistance = Double.greatestFiniteMagnitude

        for sid in sidShortlist {
            for star in starShortlist {
                let enroute = try ifrrRouteBetween(sid.endpoint, star.endpoint, database: database)
                let candidatePoints = dedupeRoutePoints([departurePoint] + sid.points + enroute.points + star.points + [arrivalPoint])
                let runwayPenalty =
                    runwayPenalty(candidate: sid.runway, selected: departureRunway)
                    + runwayPenalty(candidate: star.runway, selected: arrivalRunway)
                let score = pathLengthNM(candidatePoints) + runwayPenalty
                if score < bestDistance {
                    bestSID = sid
                    bestSTAR = star
                    bestEnroute = enroute
                    bestPoints = candidatePoints
                    bestDistance = score
                }
            }
        }

        guard let sid = bestSID, let star = bestSTAR, let enroute = bestEnroute else {
            return nil
        }

        var legs: [[String: Any]] = [
            ["type": "sid", "name": sid.procedure, "transition": sid.transition]
        ]
        legs.append(contentsOf: enroute.legs)
        legs.append(["type": "star", "name": star.procedure, "transition": star.transition])

        var selectedProcedures: [String: Any] = [
            "sid": [
                "airport": departureIdent,
                "procedure": sid.procedure,
                "transition": sid.transition
            ],
            "star": [
                "airport": arrivalIdent,
                "procedure": star.procedure,
                "transition": star.transition
            ]
        ]
        if let approach = try selectApproachCandidate(
            airport: arrivalIdent,
            runway: arrivalRunway,
            database: database
        ) {
            selectedProcedures["approach"] = [
                "airport": arrivalIdent,
                "procedure": approach["procedure_identifier"] ?? "",
                "transition": approach["transition_identifier"] ?? "ALL"
            ]
        }

        let distance = pathLengthNM(bestPoints)
        let hasAirwayLeg = enroute.legs.contains { navString($0["type"]) == "airway" }
        return [
            "departure": departurePoint,
            "arrival": arrivalPoint,
            "legs": legs,
            "points": bestPoints,
            "segments": [
                "departure": dedupeRoutePoints([departurePoint] + sid.points),
                "enroute": enroute.points,
                "arrival": dedupeRoutePoints(star.points + [arrivalPoint])
            ],
            "generated": true,
            "message": hasAirwayLeg
                ? "已按 SID / STAR 和本地 IFR 航路网络自动接入。"
                : "已按 SID / STAR 自动接入本地离线航路。",
            "route_display": enroute.routeDisplay,
            "selected_procedures": selectedProcedures,
            "selected_runways": [
                "departure": departureRunway,
                "arrival": arrivalRunway
            ],
            "distance_nm": distance
        ]
    }

    private func procedureRouteCandidates(
        table: String,
        airport: String,
        mode: String,
        runway: String,
        database: SQLiteDatabase
    ) throws -> [ProcedureRouteCandidate] {
        let rows = try database.rows(
            sql: """
            select procedure_identifier, transition_identifier, seqno, waypoint_identifier,
                   waypoint_latitude, waypoint_longitude, path_termination
            from \(table)
            where airport_identifier = ?
            order by procedure_identifier, transition_identifier, seqno
            """,
            arguments: [.text(airport.uppercased())]
        )

        var grouped: [(procedure: String, transition: String, rows: [[String: Any]])] = []
        for row in rows {
            let procedure = navString(row["procedure_identifier"]).uppercased()
            let transition = normalizedProcedureTransition(row["transition_identifier"])
            if grouped.indices.last.map({
                grouped[$0].procedure == procedure && grouped[$0].transition == transition
            }) == true {
                grouped[grouped.count - 1].rows.append(row)
            } else {
                grouped.append((procedure: procedure, transition: transition, rows: [row]))
            }
        }

        var candidates: [ProcedureRouteCandidate] = []
        for group in grouped {
            let procedure = group.procedure
            let transition = group.transition
            let candidateRunway = inferProcedureRunway(
                mode: mode,
                procedure: procedure,
                transition: transition
            )
            if candidateRunway != "ALL",
               !runwayMatches(candidate: candidateRunway, selected: runway) {
                continue
            }
            let points = group.rows.compactMap { procedureRoutePoint(from: $0, kind: mode) }
            guard !points.isEmpty else { continue }
            let endpoint = mode == "sid" ? points[points.count - 1] : points[0]
            candidates.append(ProcedureRouteCandidate(
                procedure: procedure,
                transition: transition,
                runway: candidateRunway,
                points: points,
                endpoint: endpoint,
                distanceNM: pathLengthNM(points)
            ))
        }
        return candidates
    }

    /// Track matching needs the complete flyable path, not only the named
    /// runway/transition branch. ARINC SID and approach branches run into the
    /// common route; STAR runway branches run out of it. Keeping the selected
    /// transition while joining the common rows lets a partial flown prefix
    /// identify the complete procedure without shortening what is drawn.
    private func trackProcedureRouteCandidates(
        table: String,
        airport: String,
        mode: String,
        runway: String,
        database: SQLiteDatabase
    ) throws -> [ProcedureRouteCandidate] {
        // Read every transition first. Filtering to one runway leaves the
        // common STAR row behind even when that procedure only has branches
        // for a different runway, which makes the common row look universal.
        let allCandidates = try procedureRouteCandidates(
            table: table,
            airport: airport,
            mode: mode,
            runway: "ALL",
            database: database
        )
        let normalizedMode = mode.lowercased()
        let selectedRunway = normalizedRunwayChoice(runway)
        let grouped = Dictionary(grouping: allCandidates, by: \.procedure)
        var output: [ProcedureRouteCandidate] = []

        for procedure in grouped.keys.sorted() {
            guard let candidates = grouped[procedure] else { continue }
            let common = candidates.first { $0.transition == "ALL" }
            let branches = candidates.filter { $0.transition != "ALL" }
            let explicitRunwayBranches = branches.filter { $0.runway != "ALL" }
            let compatibleRunwayBranches = explicitRunwayBranches.filter {
                selectedRunway == "ALL" || runwayMatches(candidate: $0.runway, selected: selectedRunway)
            }

            // A common route is eligible only if at least one of the
            // procedure's explicit runway branches serves the selected runway.
            if selectedRunway != "ALL",
               !explicitRunwayBranches.isEmpty,
               compatibleRunwayBranches.isEmpty {
                continue
            }

            if let common {
                output.append(common)
            }

            let eligibleBranches = branches.filter {
                $0.runway == "ALL"
                    || selectedRunway == "ALL"
                    || runwayMatches(candidate: $0.runway, selected: selectedRunway)
            }
            for candidate in eligibleBranches {
                guard let common else {
                    output.append(candidate)
                    continue
                }
                let joinedPoints: [[String: Any]]
                if normalizedMode == "star" {
                    joinedPoints = dedupeRoutePoints(common.points + candidate.points)
                } else {
                    joinedPoints = dedupeRoutePoints(candidate.points + common.points)
                }
                guard !joinedPoints.isEmpty else {
                    output.append(candidate)
                    continue
                }
                let endpoint = normalizedMode == "sid"
                    ? joinedPoints[joinedPoints.count - 1]
                    : joinedPoints[0]
                output.append(ProcedureRouteCandidate(
                    procedure: candidate.procedure,
                    transition: candidate.transition,
                    runway: candidate.runway,
                    points: joinedPoints,
                    endpoint: endpoint,
                    distanceNM: pathLengthNM(joinedPoints)
                ))
            }
        }

        return output
    }

    private func procedureDistanceSortKey(_ candidate: ProcedureRouteCandidate, reference: [String: Any]) -> String {
        [
            String(format: "%012.6f", routeDistanceNM(candidate.endpoint, reference)),
            candidate.procedure,
            candidate.transition
        ].joined(separator: "\u{0}")
    }

    private func procedureRoutePoint(from row: [String: Any], kind: String) -> [String: Any]? {
        let ident = navString(row["waypoint_identifier"]).uppercased()
        guard !ident.isEmpty,
              let lat = navDouble(row["waypoint_latitude"]),
              let lon = navDouble(row["waypoint_longitude"]) else {
            return nil
        }
        return [
            "ident": ident,
            "name": ident,
            "label": ident,
            "kind": kind,
            "lat": lat,
            "lon": lon,
            "seqno": navInt(row["seqno"]) ?? 0,
            "path_termination": navString(row["path_termination"])
        ]
    }

    private func selectApproachCandidate(
        airport: String,
        runway: String,
        database: SQLiteDatabase
    ) throws -> [String: Any]? {
        let items = try procedureSummaries(table: "tbl_iaps", airport: airport, database: database)
        let candidates = items.compactMap { item -> [String: Any]? in
            let procedure = navString(item["procedure_identifier"]).uppercased()
            let transition = normalizedProcedureTransition(item["transition_identifier"])
            let candidateRunway = inferRunwayIdentifier(procedure: procedure, transition: transition)
            guard runwayMatches(candidate: candidateRunway, selected: runway) else {
                return nil
            }
            return [
                "procedure_identifier": procedure,
                "transition_identifier": transition,
                "runway": candidateRunway
            ]
        }
        return candidates.min { lhs, rhs in
            approachSortKey(lhs, selectedRunway: runway) < approachSortKey(rhs, selectedRunway: runway)
        }
    }

    private func matchProceduresAfterEnroute(
        departurePoint: [String: Any],
        arrivalPoint: [String: Any],
        matched: RoutePath,
        departureRunway: String = "ALL",
        arrivalRunway: String = "ALL",
        trackPoints: [TrackPoint] = [],
        database: SQLiteDatabase
    ) throws -> LegacyProcedureMatch {
        let departureIdent = navString(departurePoint["ident"]).uppercased()
        let arrivalIdent = navString(arrivalPoint["ident"]).uppercased()
        var matchedRoute = matched
        var selectedProcedures: [String: Any] = [:]
        let trackDepartureRunway = try inferTrackRunway(
            airport: departureIdent,
            mode: "departure",
            trackPoints: trackPoints,
            database: database
        )
        let trackArrivalRunway = try inferTrackRunway(
            airport: arrivalIdent,
            mode: "arrival",
            trackPoints: trackPoints,
            database: database
        )
        let resolvedDepartureRunway = normalizedRunwayChoice(departureRunway) == "ALL"
            ? trackDepartureRunway
            : normalizedRunwayChoice(departureRunway)
        let resolvedArrivalRunway = normalizedRunwayChoice(arrivalRunway) == "ALL"
            ? trackArrivalRunway
            : normalizedRunwayChoice(arrivalRunway)
        var selectedRunways = [
            "departure": resolvedDepartureRunway,
            "arrival": resolvedArrivalRunway
        ]

        let sidCandidates = try procedureRouteCandidates(
            table: "tbl_sids",
            airport: departureIdent,
            mode: "sid",
            runway: resolvedDepartureRunway,
            database: database
        )
        let trackSID = trackDepartureRunway == "ALL"
            ? nil
            : legacyBestProcedureCandidateForTrack(
                candidates: sidCandidates,
                mode: "sid",
                trackPoints: trackPoints
            )
        let airwaySID = try trackSID == nil
            ? selectSIDCandidateForFirstAirway(
                candidates: sidCandidates,
                legs: matchedRoute.legs,
                database: database
            )
            : nil
        let sid = trackSID ?? airwaySID ?? nearestProcedureToRoute(
            candidates: sidCandidates,
            routePoints: matchedRoute.points,
            maxDistanceNM: 15.0
        )
        if let sid {
            selectedProcedures["sid"] = [
                "airport": departureIdent,
                "procedure": sid.procedure,
                "transition": sid.transition
            ]
            if sid.runway != "ALL" {
                selectedRunways["departure"] = sid.runway
            }
            matchedRoute = try extendMatchedRouteFromSID(
                matched: matchedRoute,
                endpoint: sid.endpoint,
                database: database
            )
        }

        let starCandidates = try procedureRouteCandidates(
            table: "tbl_stars",
            airport: arrivalIdent,
            mode: "star",
            runway: resolvedArrivalRunway,
            database: database
        )
        matchedRoute = try replaceTerminalDirectWithSTARAirway(
            matched: matchedRoute,
            starCandidates: starCandidates,
            graph: buildAirwayGraph(database: database),
            database: database
        )
        let trackSTAR = trackArrivalRunway == "ALL"
            ? nil
            : legacyBestProcedureCandidateForTrack(
                candidates: starCandidates,
                mode: "star",
                trackPoints: trackPoints
            )
        let airwaySTAR = try trackSTAR == nil
            ? selectSTARCandidateForRouteAirway(
                candidates: starCandidates,
                legs: matchedRoute.legs,
                database: database
            )
            : nil
        let star = trackSTAR ?? airwaySTAR ?? nearestProcedureToRoute(
            candidates: starCandidates,
            routePoints: matchedRoute.points,
            maxDistanceNM: 10.0
        )
        if let star {
            selectedProcedures["star"] = [
                "airport": arrivalIdent,
                "procedure": star.procedure,
                "transition": star.transition
            ]
            if star.runway != "ALL" {
                selectedRunways["arrival"] = star.runway
            }
            matchedRoute = try trimMatchedRouteAtFix(
                matched: matchedRoute,
                endpoint: star.endpoint,
                database: database
            )
        }

        if let approach = try selectApproachCandidate(
            airport: arrivalIdent,
            runway: selectedRunways["arrival"] ?? "ALL",
            database: database
        ) {
            selectedProcedures["approach"] = [
                "airport": arrivalIdent,
                "procedure": navString(approach["procedure_identifier"]),
                "transition": navString(approach["transition_identifier"])
            ]
            selectedRunways["arrival"] = navString(approach["runway"])
        }

        return LegacyProcedureMatch(
            matched: matchedRoute,
            selectedProcedures: selectedProcedures,
            selectedRunways: selectedRunways
        )
    }

    private func legacyBestProcedureCandidateForTrack(
        candidates: [ProcedureRouteCandidate],
        mode: String,
        trackPoints: [TrackPoint]
    ) -> ProcedureRouteCandidate? {
        guard trackPoints.count >= 2 else { return nil }
        let normalizedMode = mode.lowercased()
        let commonSTARs = normalizedMode == "star"
            ? candidates.filter { $0.transition == "ALL" }
            : []
        let eligible = commonSTARs.isEmpty ? candidates : commonSTARs
        var best: (fitNM: Double, procedureDistanceNM: Double, candidate: ProcedureRouteCandidate)?

        for candidate in eligible {
            let fit = legacyProcedureTrackFitNM(
                candidate: candidate,
                trackPoints: trackPoints
            )
            guard fit.isFinite, fit <= 18.0 else { continue }
            let score = (fit, candidate.distanceNM, candidate)
            if best == nil
                || score.0 < best!.fitNM
                || (score.0 == best!.fitNM && score.1 < best!.procedureDistanceNM)
                || (score.0 == best!.fitNM && score.1 == best!.procedureDistanceNM && candidate.procedure < best!.candidate.procedure)
                || (score.0 == best!.fitNM && score.1 == best!.procedureDistanceNM && candidate.procedure == best!.candidate.procedure && candidate.transition < best!.candidate.transition) {
                best = score
            }
        }
        return best?.candidate
    }

    private func legacyProcedureTrackFitNM(
        candidate: ProcedureRouteCandidate,
        trackPoints: [TrackPoint]
    ) -> Double {
        guard candidate.points.count >= 2, trackPoints.count >= 2,
              let firstProcedurePoint = candidate.points.first,
              let lastProcedurePoint = candidate.points.last else {
            return .greatestFiniteMagnitude
        }

        let firstIndex = legacyNearestTrackIndex(to: firstProcedurePoint, trackPoints: trackPoints)
        let lastIndex = legacyNearestTrackIndex(to: lastProcedurePoint, trackPoints: trackPoints)
        let lower = min(firstIndex, lastIndex)
        let upper = max(firstIndex, lastIndex)
        guard upper > lower else { return .greatestFiniteMagnitude }

        let count = upper - lower + 1
        let step = max(1, count / 64)
        var distances: [Double] = []
        var index = lower
        while index <= upper {
            let point = trackPoints[index]
            distances.append(distanceToPolylineNM(
                lat: point.lat,
                lon: point.lon,
                routePoints: candidate.points
            ))
            index += step
        }
        if (upper - lower) % step != 0 {
            let point = trackPoints[upper]
            distances.append(distanceToPolylineNM(
                lat: point.lat,
                lon: point.lon,
                routePoints: candidate.points
            ))
        }
        distances = distances.filter(\.isFinite).sorted()
        guard !distances.isEmpty else { return .greatestFiniteMagnitude }
        let retainedCount = max(1, Int(ceil(Double(distances.count) * 0.9)))
        return distances.prefix(retainedCount).reduce(0, +) / Double(retainedCount)
    }

    private func legacyNearestTrackIndex(to point: [String: Any], trackPoints: [TrackPoint]) -> Int {
        guard let lat = navDouble(point["lat"]),
              let lon = navDouble(point["lon"]),
              !trackPoints.isEmpty else {
            return 0
        }
        return trackPoints.indices.min { lhs, rhs in
            greatCircleNM(lat1: trackPoints[lhs].lat, lon1: trackPoints[lhs].lon, lat2: lat, lon2: lon)
                < greatCircleNM(lat1: trackPoints[rhs].lat, lon1: trackPoints[rhs].lon, lat2: lat, lon2: lon)
        } ?? 0
    }

    private func matchProceduresForTrack(
        departurePoint: [String: Any],
        arrivalPoint: [String: Any],
        departureRunway: String = "ALL",
        arrivalRunway: String = "ALL",
        trackPoints: [TrackPoint] = [],
        database: SQLiteDatabase
    ) throws -> ProcedureMatch {
        let departureIdent = navString(departurePoint["ident"]).uppercased()
        let arrivalIdent = navString(arrivalPoint["ident"]).uppercased()
        var selectedProcedures: [String: Any] = [:]
        let trackDepartureRunway = try inferTrackRunway(
            airport: departureIdent,
            mode: "departure",
            trackPoints: trackPoints,
            database: database
        )
        let trackArrivalRunway = try inferTrackRunway(
            airport: arrivalIdent,
            mode: "arrival",
            trackPoints: trackPoints,
            database: database
        )
        let resolvedDepartureRunway = normalizedRunwayChoice(departureRunway) == "ALL"
            ? trackDepartureRunway
            : normalizedRunwayChoice(departureRunway)
        let resolvedArrivalRunway = normalizedRunwayChoice(arrivalRunway) == "ALL"
            ? trackArrivalRunway
            : normalizedRunwayChoice(arrivalRunway)
        var selectedRunways = [
            "departure": resolvedDepartureRunway,
            "arrival": resolvedArrivalRunway
        ]
        // Procedure-first matching needs enough samples at both terminal ends.
        // Short route sketches do not contain enough evidence to distinguish
        // adjacent procedures, so they keep the established airway-first path.
        let usesProcedureFirst = trackPoints.count >= 64
            && trackDepartureRunway != "ALL"
            && trackArrivalRunway != "ALL"
        guard usesProcedureFirst else {
            return ProcedureMatch(
                sid: nil,
                star: nil,
                approach: nil,
                enrouteTrackPoints: trackPoints,
                selectedProcedures: [:],
                selectedRunways: selectedRunways,
                usesProcedureFirst: false
            )
        }

        let sidCandidates = try trackProcedureRouteCandidates(
            table: "tbl_sids",
            airport: departureIdent,
            mode: "sid",
            runway: resolvedDepartureRunway,
            database: database
        )
        let runwaySIDCandidates = sidCandidates.filter { $0.runway != "ALL" }
        let sidPool = resolvedDepartureRunway != "ALL" && !runwaySIDCandidates.isEmpty
            ? runwaySIDCandidates
            : sidCandidates
        let sid = bestProcedureAlignment(
            candidates: sidPool,
            mode: "sid",
            trackPoints: trackPoints
        )
        if let sidCandidate = sid?.candidate {
            selectedProcedures["sid"] = [
                "airport": departureIdent,
                "procedure": sidCandidate.procedure,
                "transition": sidCandidate.transition
            ]
            if sidCandidate.runway != "ALL" {
                selectedRunways["departure"] = sidCandidate.runway
            }
        }

        let starCandidates = try trackProcedureRouteCandidates(
            table: "tbl_stars",
            airport: arrivalIdent,
            mode: "star",
            runway: resolvedArrivalRunway,
            database: database
        )
        let star = bestProcedureAlignment(
            candidates: starCandidates,
            mode: "star",
            trackPoints: trackPoints
        )
        if let starCandidate = star?.candidate {
            selectedProcedures["star"] = [
                "airport": arrivalIdent,
                "procedure": starCandidate.procedure,
                "transition": starCandidate.transition
            ]
            if starCandidate.runway != "ALL" {
                selectedRunways["arrival"] = starCandidate.runway
            }
        }

        let approachCandidates = try trackProcedureRouteCandidates(
            table: "tbl_iaps",
            airport: arrivalIdent,
            mode: "approach",
            runway: resolvedArrivalRunway,
            database: database
        )
        let approach = bestApproachAlignment(
            candidates: approachCandidates,
            star: star,
            trackPoints: trackPoints
        )
        if let approachCandidate = approach?.candidate {
            selectedProcedures["approach"] = [
                "airport": arrivalIdent,
                "procedure": approachCandidate.procedure,
                "transition": approachCandidate.transition
            ]
            if approachCandidate.runway != "ALL" {
                selectedRunways["arrival"] = approachCandidate.runway
            }
        } else if let fallbackApproach = try selectApproachCandidate(
            airport: arrivalIdent,
            runway: selectedRunways["arrival"] ?? resolvedArrivalRunway,
            database: database
        ) {
            selectedProcedures["approach"] = [
                "airport": arrivalIdent,
                "procedure": navString(fallbackApproach["procedure_identifier"]),
                "transition": navString(fallbackApproach["transition_identifier"])
            ]
            selectedRunways["arrival"] = navString(fallbackApproach["runway"])
        }

        var enrouteStartIndex = 0
        var enrouteEndIndex = max(0, trackPoints.count - 1)
        if let sid {
            enrouteStartIndex = min(max(0, sid.trackEndIndex), max(0, trackPoints.count - 2))
            let endpointProjection = nearestTrackSegment(
                to: sid.candidate.endpoint,
                trackPoints: trackPoints
            )
            if endpointProjection.distanceNM <= 5.0,
               endpointProjection.index >= enrouteStartIndex {
                enrouteStartIndex = min(endpointProjection.index, max(0, trackPoints.count - 2))
            }
        }
        if let star {
            enrouteEndIndex = min(
                max(1, star.trackStartIndex + 1),
                max(1, trackPoints.count - 1)
            )
        }
        let enrouteTrackPoints: [TrackPoint]
        if trackPoints.count >= 2, enrouteEndIndex > enrouteStartIndex {
            enrouteTrackPoints = Array(trackPoints[enrouteStartIndex...enrouteEndIndex])
        } else {
            enrouteTrackPoints = trackPoints
        }

        return ProcedureMatch(
            sid: sid,
            star: star,
            approach: approach,
            enrouteTrackPoints: enrouteTrackPoints,
            selectedProcedures: selectedProcedures,
            selectedRunways: selectedRunways,
            usesProcedureFirst: true
        )
    }

    private func bestProcedureAlignment(
        candidates: [ProcedureRouteCandidate],
        mode: String,
        trackPoints: [TrackPoint]
    ) -> ProcedureTrackAlignment? {
        guard trackPoints.count >= 2 else { return nil }
        func bestMatch(in pool: [ProcedureRouteCandidate]) -> ProcedureTrackAlignment? {
            var best: ProcedureTrackAlignment?
            for candidate in pool {
                guard let alignment = procedureTrackAlignment(
                    candidate: candidate,
                    mode: mode,
                    trackPoints: trackPoints
                ) else { continue }
                if best == nil || procedureAlignmentIsBetter(alignment, than: best!) {
                    best = alignment
                }
            }
            return best
        }

        let best = bestMatch(in: candidates)
        if mode.lowercased() == "star",
           let best,
           let common = bestMatch(in: candidates.filter { $0.transition == "ALL" }),
           floor(common.matchedFitNM) <= floor(best.matchedFitNM) + 1,
           common.coverageScore >= best.coverageScore * 0.7 {
            return common
        }
        return best
    }

    private func bestApproachAlignment(
        candidates: [ProcedureRouteCandidate],
        star: ProcedureTrackAlignment?,
        trackPoints: [TrackPoint]
    ) -> ProcedureTrackAlignment? {
        guard !candidates.isEmpty else { return nil }
        let bestPriority = candidates.map { approachPriority($0.procedure) }.min() ?? 5
        let preferredType = candidates.filter { approachPriority($0.procedure) == bestPriority }
        let starExitIdent = star?.candidate.points.last.map { navString($0["ident"]).uppercased() } ?? ""
        if !starExitIdent.isEmpty {
            let connected = preferredType.filter {
                navString($0.points.first?["ident"]).uppercased() == starExitIdent
            }
            if let match = bestProcedureAlignment(
                candidates: connected,
                mode: "approach",
                trackPoints: trackPoints
            ) {
                return match
            }
        }
        let common = preferredType.filter { $0.transition == "ALL" }
        if let match = bestProcedureAlignment(
            candidates: common,
            mode: "approach",
            trackPoints: trackPoints
        ) {
            return match
        }
        return bestProcedureAlignment(
            candidates: preferredType,
            mode: "approach",
            trackPoints: trackPoints
        )
    }

    private func procedureTrackAlignment(
        candidate: ProcedureRouteCandidate,
        mode: String,
        trackPoints: [TrackPoint]
    ) -> ProcedureTrackAlignment? {
        guard trackPoints.count >= 2 else { return nil }
        let procedurePoints = primaryProcedureTrackPoints(candidate.points, mode: mode)
        guard procedurePoints.count >= 2 else { return nil }
        let projections = procedurePoints.map {
            nearestTrackSegment(to: $0, trackPoints: trackPoints)
        }
        let maximumPointDistanceNM = 3.0
        var best: ProcedureTrackAlignment?

        for startIndex in procedurePoints.indices {
            guard projections[startIndex].distanceNM <= maximumPointDistanceNM else { continue }
            var lastTrackIndex = projections[startIndex].index
            for endIndex in startIndex..<procedurePoints.count {
                let projection = projections[endIndex]
                guard projection.distanceNM <= maximumPointDistanceNM,
                      projection.index >= lastTrackIndex else {
                    break
                }
                lastTrackIndex = projection.index
                let matchedPoints = Array(procedurePoints[startIndex...endIndex])
                guard matchedPoints.count >= 2 else { continue }
                let matchedFit = matchedProcedureTrackFitNM(
                    procedurePoints: matchedPoints,
                    trackStartIndex: projections[startIndex].index,
                    trackEndIndex: projection.index,
                    trackPoints: trackPoints
                )
                guard matchedFit.isFinite else { continue }
                let distances = projections[startIndex...endIndex].map(\.distanceNM)
                let coverage = pathLengthNM(matchedPoints) + Double(matchedPoints.count) * 4.0
                let continuationFit = procedureContinuationFitNM(
                    candidate: candidate,
                    mode: mode,
                    candidateEndIndex: endIndex,
                    trackEndIndex: projection.index,
                    trackPoints: trackPoints
                )
                let alignment = ProcedureTrackAlignment(
                    candidate: candidate,
                    candidateStartIndex: startIndex,
                    candidateEndIndex: endIndex,
                    trackStartIndex: projections[startIndex].index,
                    trackEndIndex: projection.index,
                    matchedFitNM: matchedFit,
                    fullFitNM: continuationFit,
                    coverageScore: coverage,
                    meanPointDistanceNM: distances.reduce(0, +) / Double(distances.count)
                )
                if best == nil || procedureAlignmentIsBetter(alignment, than: best!) {
                    best = alignment
                }
            }
        }
        return best
    }

    private func procedureContinuationFitNM(
        candidate: ProcedureRouteCandidate,
        mode: String,
        candidateEndIndex: Int,
        trackEndIndex: Int,
        trackPoints: [TrackPoint]
    ) -> Double {
        if mode.lowercased() == "approach" {
            return 0
        }
        guard mode.lowercased() == "sid",
              candidateEndIndex < candidate.points.count - 1,
              trackEndIndex < trackPoints.count - 1,
              let endpoint = candidate.points.last,
              let lat = navDouble(endpoint["lat"]),
              let lon = navDouble(endpoint["lon"]) else {
            return procedureTrackFitNM(candidate: candidate, trackPoints: trackPoints)
        }
        var best = Double.greatestFiniteMagnitude
        for index in trackEndIndex..<(trackPoints.count - 1) {
            best = min(
                best,
                distanceToTrackSegmentNM(
                    lat: lat,
                    lon: lon,
                    start: trackPoints[index],
                    end: trackPoints[index + 1]
                )
            )
        }
        return best
    }

    private func primaryProcedureTrackPoints(
        _ points: [[String: Any]],
        mode: String
    ) -> [[String: Any]] {
        guard mode.lowercased() == "approach",
              let runwayIndex = points.firstIndex(where: {
                  navString($0["ident"]).uppercased().hasPrefix("RW")
              }) else {
            return points
        }
        return Array(points[...runwayIndex])
    }

    private func procedureAlignmentIsBetter(
        _ lhs: ProcedureTrackAlignment,
        than rhs: ProcedureTrackAlignment
    ) -> Bool {
        let lhsFitBand = floor(lhs.matchedFitNM)
        let rhsFitBand = floor(rhs.matchedFitNM)
        if lhsFitBand != rhsFitBand { return lhsFitBand < rhsFitBand }
        let lhsMatchedPointCount = lhs.candidateEndIndex - lhs.candidateStartIndex + 1
        let rhsMatchedPointCount = rhs.candidateEndIndex - rhs.candidateStartIndex + 1
        if lhsMatchedPointCount != rhsMatchedPointCount {
            return lhsMatchedPointCount > rhsMatchedPointCount
        }
        let lhsFullFitBand = floor(lhs.fullFitNM)
        let rhsFullFitBand = floor(rhs.fullFitNM)
        if lhsFullFitBand != rhsFullFitBand { return lhsFullFitBand < rhsFullFitBand }
        if lhs.coverageScore != rhs.coverageScore { return lhs.coverageScore > rhs.coverageScore }
        if lhs.fullFitNM != rhs.fullFitNM { return lhs.fullFitNM < rhs.fullFitNM }
        if lhs.meanPointDistanceNM != rhs.meanPointDistanceNM {
            return lhs.meanPointDistanceNM < rhs.meanPointDistanceNM
        }
        if lhs.candidate.procedure != rhs.candidate.procedure {
            return lhs.candidate.procedure < rhs.candidate.procedure
        }
        return lhs.candidate.transition < rhs.candidate.transition
    }

    private func nearestTrackSegment(
        to point: [String: Any],
        trackPoints: [TrackPoint]
    ) -> (index: Int, distanceNM: Double) {
        guard let lat = navDouble(point["lat"]),
              let lon = navDouble(point["lon"]),
              trackPoints.count >= 2 else {
            return (0, .greatestFiniteMagnitude)
        }
        var best = (index: 0, distanceNM: Double.greatestFiniteMagnitude)
        for index in 0..<(trackPoints.count - 1) {
            let distance = distanceToTrackSegmentNM(
                lat: lat,
                lon: lon,
                start: trackPoints[index],
                end: trackPoints[index + 1]
            )
            if distance < best.distanceNM {
                best = (index, distance)
            }
        }
        return best
    }

    private func distanceToTrackSegmentNM(
        lat: Double,
        lon: Double,
        start: TrackPoint,
        end: TrackPoint
    ) -> Double {
        let referenceLat = (lat + start.lat + end.lat) / 3
        let startLon = wrapLongitude(start.lon, near: lon)
        let endLon = wrapLongitude(end.lon, near: lon)
        let point = projectXYNM(lat: lat, lon: lon, referenceLat: referenceLat)
        let a = projectXYNM(lat: start.lat, lon: startLon, referenceLat: referenceLat)
        let b = projectXYNM(lat: end.lat, lon: endLon, referenceLat: referenceLat)
        let dx = b.x - a.x
        let dy = b.y - a.y
        if dx == 0, dy == 0 {
            return hypot(point.x - a.x, point.y - a.y)
        }
        let projected = ((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy)
        let t = min(1, max(0, projected))
        return hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy))
    }

    private func matchedProcedureTrackFitNM(
        procedurePoints: [[String: Any]],
        trackStartIndex: Int,
        trackEndIndex: Int,
        trackPoints: [TrackPoint]
    ) -> Double {
        guard procedurePoints.count >= 2, trackPoints.count >= 2 else {
            return .greatestFiniteMagnitude
        }
        let lower = min(trackStartIndex, trackEndIndex)
        let upper = min(trackPoints.count - 1, max(trackStartIndex, trackEndIndex) + 1)
        guard upper > lower else { return .greatestFiniteMagnitude }
        let count = upper - lower + 1
        let step = max(1, count / 64)
        var distances: [Double] = []
        var index = lower
        while index <= upper {
            let point = trackPoints[index]
            distances.append(distanceToPolylineNM(
                lat: point.lat,
                lon: point.lon,
                routePoints: procedurePoints
            ))
            index += step
        }
        if (upper - lower) % step != 0 {
            let point = trackPoints[upper]
            distances.append(distanceToPolylineNM(
                lat: point.lat,
                lon: point.lon,
                routePoints: procedurePoints
            ))
        }
        distances = distances.filter(\.isFinite).sorted()
        guard !distances.isEmpty else { return .greatestFiniteMagnitude }
        let retainedCount = max(1, Int(ceil(Double(distances.count) * 0.9)))
        return distances.prefix(retainedCount).reduce(0, +) / Double(retainedCount)
    }

    private func procedureTrackFitNM(
        candidate: ProcedureRouteCandidate,
        trackPoints: [TrackPoint]
    ) -> Double {
        guard candidate.points.count >= 2, trackPoints.count >= 2,
              let firstProcedurePoint = candidate.points.first,
              let lastProcedurePoint = candidate.points.last else {
            return .greatestFiniteMagnitude
        }
        let firstProjection = nearestTrackSegment(to: firstProcedurePoint, trackPoints: trackPoints)
        let lastProjection = nearestTrackSegment(to: lastProcedurePoint, trackPoints: trackPoints)
        return matchedProcedureTrackFitNM(
            procedurePoints: candidate.points,
            trackStartIndex: firstProjection.index,
            trackEndIndex: lastProjection.index,
            trackPoints: trackPoints
        )
    }

    private func applyProcedureBoundaries(
        matched: RoutePath,
        sid: ProcedureRouteCandidate?,
        star: ProcedureRouteCandidate?,
        database: SQLiteDatabase
    ) throws -> RoutePath {
        var adjusted = matched
        if let sid {
            if let trimmed = try matchedRouteStartingAtFix(
                matched: adjusted,
                endpoint: sid.endpoint,
                database: database
            ) {
                adjusted = trimmed
            } else {
                adjusted = try extendMatchedRouteFromSID(
                    matched: adjusted,
                    endpoint: sid.endpoint,
                    database: database
                )
            }
        }
        if let star {
            adjusted = try trimMatchedRouteAtFix(
                matched: adjusted,
                endpoint: star.endpoint,
                database: database
            )
        }

        var legs = adjusted.legs
        if let sid,
           let first = adjusted.points.first,
           navString(first["ident"]) != navString(sid.endpoint["ident"]),
           routeDistanceNM(sid.endpoint, first) > 0.5 {
            legs.insert(directLeg(from: sid.endpoint, to: first), at: 0)
        }
        if let star,
           let last = adjusted.points.last,
           navString(last["ident"]) != navString(star.endpoint["ident"]),
           routeDistanceNM(last, star.endpoint) > 0.5 {
            legs.append(directLeg(from: last, to: star.endpoint))
        }
        legs = mergeRepeatedAirwayLegs(legs).filter {
            navString($0["entry"]) != navString($0["exit"])
        }
        let points = try pointsFromLegs(legs, database: database)
        return RoutePath(
            points: points,
            legs: legs,
            routeDisplay: routeDisplayFromLegs(legs, fallback: "")
        )
    }

    private func matchedRouteStartingAtFix(
        matched: RoutePath,
        endpoint: [String: Any],
        database: SQLiteDatabase
    ) throws -> RoutePath? {
        let endpointIdent = navString(endpoint["ident"])
        for index in matched.legs.indices {
            let leg = matched.legs[index]
            let type = navString(leg["type"])
            if type == "airway",
               let segment = try expandAirway(
                   navString(leg["name"]),
                   entry: navString(leg["entry"]),
                   exit: navString(leg["exit"]),
                   database: database
               ),
               let endpointIndex = indexOfMatchingPoint(segment.points, target: endpoint) {
                var legs = Array(matched.legs[index...])
                if endpointIndex >= segment.points.count - 1 {
                    legs.removeFirst()
                } else {
                    legs[0]["entry"] = endpointIdent
                    legs[0]["distance_nm"] = pathLengthNM(Array(segment.points[endpointIndex...]))
                }
                legs = legs.filter { navString($0["entry"]) != navString($0["exit"]) }
                let points = try pointsFromLegs(legs, database: database)
                return RoutePath(
                    points: points,
                    legs: legs,
                    routeDisplay: routeDisplayFromLegs(legs, fallback: "")
                )
            }
            if type == "direct" {
                let entryIdent = navString(leg["entry"])
                let exitIdent = navString(leg["exit"])
                if entryIdent == endpointIdent {
                    let legs = Array(matched.legs[index...])
                    return RoutePath(
                        points: try pointsFromLegs(legs, database: database),
                        legs: legs,
                        routeDisplay: routeDisplayFromLegs(legs, fallback: "")
                    )
                }
                if exitIdent == endpointIdent {
                    let legs = index + 1 < matched.legs.count
                        ? Array(matched.legs[(index + 1)...])
                        : []
                    return RoutePath(
                        points: try pointsFromLegs(legs, database: database),
                        legs: legs,
                        routeDisplay: routeDisplayFromLegs(legs, fallback: "")
                    )
                }
            }
        }
        return nil
    }

    private func inferTrackRunway(
        airport: String,
        mode: String,
        trackPoints: [TrackPoint],
        database: SQLiteDatabase
    ) throws -> String {
        guard trackPoints.count >= 2 else { return "ALL" }
        let rows = try database.rows(
            sql: """
            select runway_identifier, runway_latitude, runway_longitude, runway_true_bearing
            from tbl_runways
            where airport_identifier = ?
            order by runway_identifier
            """,
            arguments: [.text(airport.uppercased())]
        )
        guard !rows.isEmpty else { return "ALL" }
        let edgeCount = max(2, min(trackPoints.count, max(32, trackPoints.count / 3)))
        let searchIndices: Range<Int> = mode == "arrival"
            ? (trackPoints.count - edgeCount)..<trackPoints.count
            : 0..<edgeCount
        var best: (score: Double, runway: String)?

        for row in rows {
            guard let runwayLat = navDouble(row["runway_latitude"]),
                  let runwayLon = navDouble(row["runway_longitude"]),
                  let runwayBearing = navDouble(row["runway_true_bearing"]) else {
                continue
            }
            let nearbyTerminalSamples = searchIndices.reduce(into: 0) { count, index in
                let distance = greatCircleNM(
                    lat1: trackPoints[index].lat,
                    lon1: trackPoints[index].lon,
                    lat2: runwayLat,
                    lon2: runwayLon
                )
                if distance <= 8.0 {
                    count += 1
                }
            }
            guard nearbyTerminalSamples >= 4 else { continue }

            // Parallel runways can have longitudinally staggered thresholds.
            // FR24 may also omit the first seconds of a take-off roll. Measure
            // the track against the extended runway centreline so lateral
            // separation, rather than the nearest threshold alone, identifies
            // the actual parallel runway.
            let bearingRadians = runwayBearing * .pi / 180
            let minimumAlongTrackNM = mode == "arrival" ? -10.0 : -1.0
            let maximumAlongTrackNM = mode == "arrival" ? 3.0 : 10.0
            var bestAlignmentScore = Double.greatestFiniteMagnitude

            for index in searchIndices {
                let point = trackPoints[index]
                let referenceLat = (point.lat + runwayLat) / 2
                let wrappedLon = wrapLongitude(point.lon, near: runwayLon)
                let eastNM = (wrappedLon - runwayLon) * 60.0 * cos(referenceLat * .pi / 180)
                let northNM = (point.lat - runwayLat) * 60.0
                let alongTrackNM = eastNM * sin(bearingRadians) + northNM * cos(bearingRadians)
                guard alongTrackNM >= minimumAlongTrackNM,
                      alongTrackNM <= maximumAlongTrackNM else {
                    continue
                }
                let crossTrackNM = abs(eastNM * cos(bearingRadians) - northNM * sin(bearingRadians))
                guard crossTrackNM <= 4.0 else { continue }
                let thresholdDistanceNM = hypot(eastNM, northNM)
                let course = trackCourseNearRunway(
                    closestIndex: index,
                    mode: mode,
                    trackPoints: trackPoints
                )
                let headingPenalty = course.map {
                    angularDifferenceDegrees($0, runwayBearing) / 12.0
                } ?? 15.0
                let alignmentScore = crossTrackNM * 6.0
                    + thresholdDistanceNM * 0.25
                    + headingPenalty
                bestAlignmentScore = min(bestAlignmentScore, alignmentScore)
            }

            let score: Double
            if bestAlignmentScore.isFinite {
                score = bestAlignmentScore
            } else {
                let closestIndex = searchIndices.min { lhs, rhs in
                    greatCircleNM(
                        lat1: trackPoints[lhs].lat,
                        lon1: trackPoints[lhs].lon,
                        lat2: runwayLat,
                        lon2: runwayLon
                    ) < greatCircleNM(
                        lat1: trackPoints[rhs].lat,
                        lon1: trackPoints[rhs].lon,
                        lat2: runwayLat,
                        lon2: runwayLon
                    )
                } ?? searchIndices.lowerBound
                let thresholdDistance = greatCircleNM(
                    lat1: trackPoints[closestIndex].lat,
                    lon1: trackPoints[closestIndex].lon,
                    lat2: runwayLat,
                    lon2: runwayLon
                )
                let course = trackCourseNearRunway(
                    closestIndex: closestIndex,
                    mode: mode,
                    trackPoints: trackPoints
                )
                let headingPenalty = course.map {
                    angularDifferenceDegrees($0, runwayBearing) / 12.0
                } ?? 15.0
                score = thresholdDistance * 3.0 + headingPenalty
            }
            let runway = normalizedRunwayChoice(navString(row["runway_identifier"]))
            if best == nil || score < best!.score || (score == best!.score && runway < best!.runway) {
                best = (score, runway)
            }
        }
        return best?.runway ?? "ALL"
    }

    private func trackCourseNearRunway(
        closestIndex: Int,
        mode: String,
        trackPoints: [TrackPoint]
    ) -> Double? {
        let minimumSeparationNM = 1.5
        if mode == "arrival" {
            for index in stride(from: closestIndex - 1, through: 0, by: -1) {
                if greatCircleNM(
                    lat1: trackPoints[index].lat,
                    lon1: trackPoints[index].lon,
                    lat2: trackPoints[closestIndex].lat,
                    lon2: trackPoints[closestIndex].lon
                ) >= minimumSeparationNM {
                    return initialBearingDegrees(from: trackPoints[index], to: trackPoints[closestIndex])
                }
            }
        } else if closestIndex + 1 < trackPoints.count {
            for index in (closestIndex + 1)..<trackPoints.count {
                if greatCircleNM(
                    lat1: trackPoints[closestIndex].lat,
                    lon1: trackPoints[closestIndex].lon,
                    lat2: trackPoints[index].lat,
                    lon2: trackPoints[index].lon
                ) >= minimumSeparationNM {
                    return initialBearingDegrees(from: trackPoints[closestIndex], to: trackPoints[index])
                }
            }
        }
        return nil
    }

    private func initialBearingDegrees(from start: TrackPoint, to end: TrackPoint) -> Double {
        let lat1 = start.lat * .pi / 180
        let lat2 = end.lat * .pi / 180
        let deltaLon = (end.lon - start.lon) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func angularDifferenceDegrees(_ lhs: Double, _ rhs: Double) -> Double {
        let difference = abs(lhs - rhs).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
    }

    private func selectSIDCandidateForFirstAirway(
        candidates: [ProcedureRouteCandidate],
        legs: [[String: Any]],
        database: SQLiteDatabase
    ) throws -> ProcedureRouteCandidate? {
        guard let firstAirway = legs.first(where: { navString($0["type"]) == "airway" }) else {
            return nil
        }
        let airwayName = navString(firstAirway["name"])
        let entryIdent = navString(firstAirway["entry"])
        let exitIdent = navString(firstAirway["exit"])
        var best: (extraDistanceNM: Double, procedureDistanceNM: Double, candidate: ProcedureRouteCandidate)?

        func isBetter(
            _ lhs: (extraDistanceNM: Double, procedureDistanceNM: Double, candidate: ProcedureRouteCandidate),
            than rhs: (extraDistanceNM: Double, procedureDistanceNM: Double, candidate: ProcedureRouteCandidate)
        ) -> Bool {
            if lhs.extraDistanceNM != rhs.extraDistanceNM { return lhs.extraDistanceNM < rhs.extraDistanceNM }
            if lhs.procedureDistanceNM != rhs.procedureDistanceNM { return lhs.procedureDistanceNM < rhs.procedureDistanceNM }
            if lhs.candidate.procedure != rhs.candidate.procedure { return lhs.candidate.procedure < rhs.candidate.procedure }
            return lhs.candidate.transition < rhs.candidate.transition
        }

        for candidate in candidates {
            let endpointIdent = navString(candidate.endpoint["ident"])
            var extraDistance: Double?
            if endpointIdent == entryIdent {
                extraDistance = 0
            } else if let airway = try expandAirway(
                airwayName,
                entry: endpointIdent,
                exit: exitIdent,
                database: database
            ) {
                let idents = airway.points.map { navString($0["ident"]) }
                if let entryIndex = idents.firstIndex(of: entryIdent) {
                    extraDistance = pathLengthNM(Array(airway.points.prefix(entryIndex + 1)))
                } else if let entryPoint = try resolveRouteBoundaryPoint(
                    entryIdent,
                    airway: airwayName,
                    neighbor: candidate.endpoint,
                    database: database
                ) {
                    extraDistance = routeDistanceNM(candidate.endpoint, entryPoint)
                }
            }
            guard let extraDistance, extraDistance <= 180.0 else {
                continue
            }
            let score = (extraDistance, candidate.distanceNM, candidate)
            if best == nil || isBetter(score, than: best!) {
                best = score
            }
        }
        return best?.candidate
    }

    private func selectSTARCandidateForRouteAirway(
        candidates: [ProcedureRouteCandidate],
        legs: [[String: Any]],
        database: SQLiteDatabase
    ) throws -> ProcedureRouteCandidate? {
        guard !candidates.isEmpty else { return nil }
        for routeIndex in stride(from: legs.count - 1, through: 0, by: -1) {
            let leg = legs[routeIndex]
            guard navString(leg["type"]) == "airway" else {
                continue
            }
            let airwayName = navString(leg["name"])
            let entryIdent = navString(leg["entry"])
            let exitIdent = navString(leg["exit"])
            var best: (extraDistanceNM: Double, legsFromEnd: Int, procedureDistanceNM: Double, candidate: ProcedureRouteCandidate)?

            func isBetter(
                _ lhs: (extraDistanceNM: Double, legsFromEnd: Int, procedureDistanceNM: Double, candidate: ProcedureRouteCandidate),
                than rhs: (extraDistanceNM: Double, legsFromEnd: Int, procedureDistanceNM: Double, candidate: ProcedureRouteCandidate)
            ) -> Bool {
                if lhs.extraDistanceNM != rhs.extraDistanceNM { return lhs.extraDistanceNM < rhs.extraDistanceNM }
                if lhs.legsFromEnd != rhs.legsFromEnd { return lhs.legsFromEnd < rhs.legsFromEnd }
                if lhs.procedureDistanceNM != rhs.procedureDistanceNM { return lhs.procedureDistanceNM < rhs.procedureDistanceNM }
                if lhs.candidate.procedure != rhs.candidate.procedure { return lhs.candidate.procedure < rhs.candidate.procedure }
                return lhs.candidate.transition < rhs.candidate.transition
            }

            for candidate in candidates {
                let endpointIdent = navString(candidate.endpoint["ident"])
                var extraDistance: Double?
                if endpointIdent == exitIdent {
                    extraDistance = 0
                } else if let currentAirway = try expandAirway(
                    airwayName,
                    entry: entryIdent,
                    exit: exitIdent,
                    database: database
                ), indexOfMatchingPoint(currentAirway.points, target: candidate.endpoint) != nil {
                    extraDistance = 0
                } else if let airway = try expandAirway(
                    airwayName,
                    entry: entryIdent,
                    exit: endpointIdent,
                    database: database
                ) {
                    let idents = airway.points.map { navString($0["ident"]) }
                    if let exitIndex = idents.firstIndex(of: exitIdent) {
                        extraDistance = pathLengthNM(Array(airway.points[exitIndex...]))
                    }
                }
                guard let extraDistance, extraDistance <= 180.0 else {
                    continue
                }
                let score = (extraDistance, legs.count - routeIndex, candidate.distanceNM, candidate)
                if best == nil || isBetter(score, than: best!) {
                    best = score
                }
            }
            if let best {
                return best.candidate
            }
        }
        return nil
    }

    private func replaceTerminalDirectWithSTARAirway(
        matched: RoutePath,
        starCandidates: [ProcedureRouteCandidate],
        graph: AirwayGraph,
        database: SQLiteDatabase
    ) throws -> RoutePath {
        guard !starCandidates.isEmpty else { return matched }
        var legs = matched.legs
        var changed = false

        for index in legs.indices {
            let leg = legs[index]
            guard navString(leg["type"]) == "direct",
                  let start = try pointFromLegEndpoint(leg, side: "entry", database: database),
                  let end = try pointFromLegEndpoint(leg, side: "exit", database: database) else {
                continue
            }
            let directDistance = routeDistanceNM(start, end)
            var best: (endpointDistanceNM: Double, airwayDistanceNM: Double, procedureDistanceNM: Double, leg: [String: Any])?

            for star in starCandidates {
                guard let candidate = singleAirwayLegForIdents(
                    entry: navString(start["ident"]),
                    exit: navString(star.endpoint["ident"]),
                    graph: graph
                ) else {
                    continue
                }
                let candidatePoints = try pointsFromLegs([candidate], database: database)
                guard candidatePoints.count >= 2 else {
                    continue
                }
                let airwayDistance = pathLengthNM(candidatePoints)
                let endpointToEnd = routeDistanceNM(star.endpoint, end)
                if airwayDistance <= directDistance * 1.35 + 40.0,
                   endpointToEnd <= max(90.0, directDistance) {
                    let score = (endpointToEnd, airwayDistance, star.distanceNM, candidate)
                    if best == nil
                        || score.0 < best!.endpointDistanceNM
                        || (score.0 == best!.endpointDistanceNM && score.1 < best!.airwayDistanceNM)
                        || (score.0 == best!.endpointDistanceNM && score.1 == best!.airwayDistanceNM && score.2 < best!.procedureDistanceNM) {
                        best = score
                    }
                }
            }
            if let best {
                legs[index] = best.leg
                changed = true
            }
        }

        guard changed else { return matched }
        let mergedLegs = mergeRepeatedAirwayLegs(legs)
        let points = try pointsFromLegs(mergedLegs, database: database)
        return RoutePath(
            points: points,
            legs: mergedLegs,
            routeDisplay: routeDisplayFromLegs(mergedLegs, fallback: "")
        )
    }

    private func extendMatchedRouteFromSID(
        matched: RoutePath,
        endpoint: [String: Any],
        database: SQLiteDatabase
    ) throws -> RoutePath {
        let endpointIdent = navString(endpoint["ident"])
        var legs = matched.legs
        for index in legs.indices {
            let leg = legs[index]
            guard navString(leg["type"]) == "airway",
                  navString(leg["entry"]) != endpointIdent,
                  let airway = try expandAirway(
                    navString(leg["name"]),
                    entry: endpointIdent,
                    exit: navString(leg["exit"]),
                    database: database
                  ) else {
                continue
            }
            var replacement = leg
            replacement["entry"] = endpointIdent
            replacement["distance_nm"] = pathLengthNM(airway.points)
            legs = Array(legs[index...])
            legs[0] = replacement
            legs = legs.filter { navString($0["entry"]) != navString($0["exit"]) }
            let points = try pointsFromLegs(legs, database: database)
            return RoutePath(
                points: points,
                legs: legs,
                routeDisplay: routeDisplayFromLegs(legs, fallback: "")
            )
        }
        return matched
    }

    private func nearestProcedureToRoute(
        candidates: [ProcedureRouteCandidate],
        routePoints: [[String: Any]],
        maxDistanceNM: Double
    ) -> ProcedureRouteCandidate? {
        guard !candidates.isEmpty, !routePoints.isEmpty else { return nil }
        var best: (distanceNM: Double, procedureDistanceNM: Double, candidate: ProcedureRouteCandidate)?

        for candidate in candidates {
            let distance = routePoints.map { routeDistanceNM(candidate.endpoint, $0) }.min() ?? .greatestFiniteMagnitude
            guard distance <= maxDistanceNM else {
                continue
            }
            let score = (distance, candidate.distanceNM, candidate)
            if best == nil
                || score.0 < best!.distanceNM
                || (score.0 == best!.distanceNM && score.1 < best!.procedureDistanceNM)
                || (score.0 == best!.distanceNM && score.1 == best!.procedureDistanceNM && candidate.procedure < best!.candidate.procedure)
                || (score.0 == best!.distanceNM && score.1 == best!.procedureDistanceNM && candidate.procedure == best!.candidate.procedure && candidate.transition < best!.candidate.transition) {
                best = score
            }
        }
        return best?.candidate
    }

    private func trimMatchedRouteAtFix(
        matched: RoutePath,
        endpoint: [String: Any],
        database: SQLiteDatabase
    ) throws -> RoutePath {
        var trimmedLegs: [[String: Any]] = []
        let endpointIdent = navString(endpoint["ident"])

        for originalLeg in matched.legs {
            let type = navString(originalLeg["type"])
            if type == "airway" {
                guard let segment = try expandAirway(
                    navString(originalLeg["name"]),
                    entry: navString(originalLeg["entry"]),
                    exit: navString(originalLeg["exit"]),
                    database: database
                ) else {
                    trimmedLegs.append(originalLeg)
                    continue
                }
                if let endpointIndex = indexOfMatchingPoint(segment.points, target: endpoint) {
                    if endpointIndex > 0 {
                        var leg = originalLeg
                        leg["exit"] = navString(segment.points[endpointIndex]["ident"])
                        let aligned = try alignSTARTrimLeg(
                            priorLegs: &trimmedLegs,
                            leg: leg,
                            endpoint: endpoint,
                            database: database
                        )
                        trimmedLegs.append(aligned)
                    }
                    break
                }
                guard let extendedSegment = try expandAirway(
                    navString(originalLeg["name"]),
                    entry: navString(originalLeg["entry"]),
                    exit: endpointIdent,
                    database: database
                ) else {
                    trimmedLegs.append(originalLeg)
                    continue
                }
                let exitPoint = segment.points.last ?? ["ident": navString(originalLeg["exit"])]
                guard indexOfMatchingPoint(extendedSegment.points, target: exitPoint) != nil else {
                    trimmedLegs.append(originalLeg)
                    continue
                }
                let aligned = try alignSTARTrimLeg(
                    priorLegs: &trimmedLegs,
                    leg: originalLeg,
                    endpoint: endpoint,
                    database: database
                )
                trimmedLegs.append(aligned)
                break
            }

            if type == "direct" {
                trimmedLegs.append(originalLeg)
                if navString(originalLeg["exit"]) == endpointIdent {
                    break
                }
            }
        }

        let points = try pointsFromLegs(trimmedLegs, database: database)
        return RoutePath(
            points: points,
            legs: trimmedLegs,
            routeDisplay: routeDisplayFromLegs(trimmedLegs, fallback: "")
        )
    }

    private func alignSTARTrimLeg(
        priorLegs: inout [[String: Any]],
        leg: [String: Any],
        endpoint: [String: Any],
        database: SQLiteDatabase
    ) throws -> [String: Any] {
        let endpointIdent = navString(endpoint["ident"])
        var aligned = leg
        aligned["exit"] = endpointIdent
        guard !priorLegs.isEmpty,
              navString(leg["type"]) == "airway",
              navString(priorLegs[priorLegs.count - 1]["type"]) == "airway",
              let previousSegment = try expandAirway(
                navString(priorLegs[priorLegs.count - 1]["name"]),
                entry: navString(priorLegs[priorLegs.count - 1]["entry"]),
                exit: navString(priorLegs[priorLegs.count - 1]["exit"]),
                database: database
              ) else {
            return aligned
        }

        let legEntry = navString(leg["entry"])
        for point in previousSegment.points.dropFirst().reversed() {
            let pointIdent = navString(point["ident"])
            if pointIdent == legEntry {
                continue
            }
            guard let candidateSegment = try expandAirway(
                navString(leg["name"]),
                entry: pointIdent,
                exit: endpointIdent,
                database: database
            ) else {
                continue
            }
            if !candidateSegment.points.map({ navString($0["ident"]) }).contains(legEntry) {
                continue
            }
            var previous = priorLegs[priorLegs.count - 1]
            previous["exit"] = pointIdent
            priorLegs[priorLegs.count - 1] = previous
            aligned["entry"] = pointIdent
            aligned["exit"] = endpointIdent
            return aligned
        }
        return aligned
    }

    private func pointFromLegEndpoint(
        _ leg: [String: Any],
        side: String,
        database: SQLiteDatabase
    ) throws -> [String: Any]? {
        if let payload = leg["\(side)_point"] as? [String: Any] {
            return payload
        }
        let ident = navString(leg[side]).uppercased()
        guard !ident.isEmpty else { return nil }
        return try lookupPoint(ident, database: database)
    }

    private func indexOfMatchingPoint(
        _ points: [[String: Any]],
        target: [String: Any],
        maxDistanceNM: Double = 0.5
    ) -> Int? {
        let targetIdent = navString(target["ident"])
        for (index, point) in points.enumerated() {
            if navString(point["ident"]) == targetIdent || routeDistanceNM(point, target) <= maxDistanceNM {
                return index
            }
        }
        return nil
    }

    private func approachSortKey(_ item: [String: Any], selectedRunway: String) -> String {
        let runway = navString(item["runway"]).uppercased()
        let procedure = navString(item["procedure_identifier"]).uppercased()
        let transition = navString(item["transition_identifier"]).uppercased()
        let runwayScore = runway == selectedRunway ? 0 : 1
        return [
            String(format: "%02d", runwayScore),
            String(format: "%02d", approachPriority(procedure)),
            transition == "ALL" ? "00" : "01",
            procedure,
            transition
        ].joined(separator: "\u{0}")
    }

    private func approachPriority(_ procedure: String) -> Int {
        if procedure.hasPrefix("I") { return 0 }
        if procedure.hasPrefix("R") { return 1 }
        if procedure.hasPrefix("L") { return 2 }
        if procedure.hasPrefix("V") { return 3 }
        if procedure.hasPrefix("N") { return 4 }
        return 5
    }

    private func normalizedProcedureTransition(_ value: Any?) -> String {
        let transition = navString(value).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return transition.isEmpty ? "ALL" : transition
    }

    private func normalizedRunwayChoice(_ value: String) -> String {
        let runway = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !runway.isEmpty else { return "ALL" }
        guard let parts = parseRunwayIdentifier(runway) else { return runway }
        return "RW\(parts.number)\(parts.suffix)"
    }

    private func inferProcedureRunway(mode: String, procedure: String, transition: String) -> String {
        if transition.uppercased().hasPrefix("RW") {
            return transition.uppercased()
        }
        let normalizedProcedure = procedure.uppercased()
        if ["sid", "star"].contains(mode.lowercased()), !normalizedProcedure.hasPrefix("DEP") {
            return "ALL"
        }
        return inferRunwayIdentifier(procedure: procedure, transition: transition)
    }

    private func inferRunwayIdentifier(procedure: String, transition: String) -> String {
        let normalizedTransition = transition.uppercased()
        if normalizedTransition.hasPrefix("RW") {
            return normalizedTransition
        }
        let characters = Array(procedure.uppercased())
        for index in characters.indices {
            guard characters[index].isNumber else { continue }
            if index > characters.startIndex, characters[characters.index(before: index)].isNumber {
                continue
            }
            var cursor = index
            var digits = ""
            while cursor < characters.endIndex, characters[cursor].isNumber, digits.count < 2 {
                digits.append(characters[cursor])
                cursor = characters.index(after: cursor)
            }
            guard !digits.isEmpty else { continue }
            var suffix = ""
            if cursor < characters.endIndex, "LCRB".contains(characters[cursor]) {
                suffix.append(characters[cursor])
                cursor = characters.index(after: cursor)
            }
            if cursor < characters.endIndex, characters[cursor].isNumber {
                continue
            }
            guard let number = Int(digits), number > 0 else { continue }
            return String(format: "RW%02d%@", number, suffix)
        }
        return "ALL"
    }

    private func runwayMatches(candidate: String, selected: String) -> Bool {
        let selectedRunway = normalizedRunwayChoice(selected)
        let candidateRunway = normalizedRunwayChoice(candidate)
        if selectedRunway == "ALL" { return true }
        if candidateRunway == "ALL" { return false }
        if candidateRunway == selectedRunway { return true }
        guard let candidateParts = parseRunwayIdentifier(candidateRunway),
              let selectedParts = parseRunwayIdentifier(selectedRunway),
              candidateParts.number == selectedParts.number else {
            return false
        }
        return candidateParts.suffix == selectedParts.suffix
            || candidateParts.suffix == "B"
            || selectedParts.suffix == "B"
            || candidateParts.suffix.isEmpty
            || selectedParts.suffix.isEmpty
    }

    private func parseRunwayIdentifier(_ runway: String) -> (number: String, suffix: String)? {
        let normalized = runway.uppercased()
        guard normalized.hasPrefix("RW") else { return nil }
        let body = Array(normalized.dropFirst(2))
        var digits = ""
        var index = body.startIndex
        while index < body.endIndex, body[index].isNumber {
            digits.append(body[index])
            index = body.index(after: index)
        }
        guard !digits.isEmpty, digits.count <= 2, let intValue = Int(digits), intValue > 0 else {
            return nil
        }
        let suffix = index < body.endIndex ? String(body[index...]) : ""
        guard suffix.count <= 1, suffix.allSatisfy({ "LCRB".contains($0) }) else {
            return nil
        }
        return (String(format: "%02d", intValue), suffix)
    }

    private func runwayPenalty(candidate: String, selected: String) -> Double {
        let selectedRunway = normalizedRunwayChoice(selected)
        guard selectedRunway != "ALL" else { return 0 }
        return runwayMatches(candidate: candidate, selected: selectedRunway) ? 0 : 20
    }

    private func currentDatabaseCacheKey() -> String {
        dataStore.databaseURL?.path ?? "__navplanner_database__"
    }

    private func resetPlanningCachesLocked(databaseKey: String?) {
        planningCacheDatabaseKey = databaseKey
        airwayGraphCache = nil
        routeBetweenCache.removeAll()
        navOverlayCacheDatabaseKey = databaseKey
        navOverlayCache = nil
    }

    private func preparePlanningCacheLocked(databaseKey: String) {
        if planningCacheDatabaseKey != databaseKey {
            resetPlanningCachesLocked(databaseKey: databaseKey)
        }
    }

    private func ifrrRouteBetween(
        _ departurePoint: [String: Any],
        _ arrivalPoint: [String: Any],
        database: SQLiteDatabase,
        excludedAirways: Set<String> = []
    ) throws -> RoutePath {
        let normalizedExcludedAirways = Set(excludedAirways.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }.filter { !$0.isEmpty })
        let databaseKey = currentDatabaseCacheKey()
        let cacheKey = RouteBetweenCacheKey(departurePoint: departurePoint, arrivalPoint: arrivalPoint)

        if normalizedExcludedAirways.isEmpty {
            planningCacheLock.lock()
            preparePlanningCacheLocked(databaseKey: databaseKey)
            if let cached = routeBetweenCache[cacheKey] {
                planningCacheLock.unlock()
                return cached
            }
            planningCacheLock.unlock()
        }

        let route = try ifrrRouteBetween(
            departurePoint,
            arrivalPoint,
            graph: buildAirwayGraph(database: database),
            excludedAirways: normalizedExcludedAirways
        )

        if normalizedExcludedAirways.isEmpty {
            planningCacheLock.lock()
            preparePlanningCacheLocked(databaseKey: databaseKey)
            routeBetweenCache[cacheKey] = route
            planningCacheLock.unlock()
        }
        return route
    }

    private func ifrrRouteBetween(
        _ departurePoint: [String: Any],
        _ arrivalPoint: [String: Any],
        graph: AirwayGraph,
        excludedAirways: Set<String> = []
    ) -> RoutePath {
        let directDistance = routeDistanceNM(departurePoint, arrivalPoint)
        var preferredSingleAirway: RoutePath?

        for (attemptIndex, slackFactor) in routeCorridorSlackFactors(
            departurePoint: departurePoint,
            arrivalPoint: arrivalPoint,
            directDistanceNM: directDistance
        ).enumerated() {
            let corridorSlack = max(120.0, directDistance * slackFactor)
            let allowedNodes = Set(graph.nodes.compactMap { key, point in
                let total =
                    routeDistanceNM(departurePoint, point)
                    + routeDistanceNM(point, arrivalPoint)
                return total <= directDistance + corridorSlack ? key : nil
            })
            let candidateLimit = attemptIndex == 0 ? 20 : 36
            let startCandidates = graphNodeCandidates(
                for: departurePoint,
                allowedNodes: allowedNodes,
                graph: graph,
                limit: candidateLimit
            )
            let endCandidates = graphNodeCandidates(
                for: arrivalPoint,
                allowedNodes: allowedNodes,
                graph: graph,
                limit: candidateLimit
            )
            guard !startCandidates.isEmpty, !endCandidates.isEmpty else {
                continue
            }
            if preferredSingleAirway == nil {
                preferredSingleAirway = preferSingleAirwayRoute(
                    departurePoint: departurePoint,
                    arrivalPoint: arrivalPoint,
                    startCandidates: startCandidates,
                    endCandidates: endCandidates,
                    graph: graph,
                    excludedAirways: excludedAirways
                )
            }
            if let route = shortestGraphRoute(
                departurePoint: departurePoint,
                arrivalPoint: arrivalPoint,
                startCandidates: startCandidates,
                endCandidates: endCandidates,
                allowedNodes: allowedNodes,
                graph: graph,
                directDistanceNM: directDistance,
                preferredSingleAirway: preferredSingleAirway,
                excludedAirways: excludedAirways
            ) {
                return route
            }
        }

        return preferredSingleAirway ?? directRouteBetween(departurePoint, arrivalPoint)
    }

    private func shortestGraphRoute(
        departurePoint: [String: Any],
        arrivalPoint: [String: Any],
        startCandidates: [(key: String, distanceNM: Double)],
        endCandidates: [(key: String, distanceNM: Double)],
        allowedNodes: Set<String>,
        graph: AirwayGraph,
        directDistanceNM: Double,
        preferredSingleAirway: RoutePath?,
        excludedAirways: Set<String> = []
    ) -> RoutePath? {
        let source = "__source__"
        var distances: [String: Double] = [source: 0]
        var previous: [String: (from: String, airway: String)] = [:]
        var frontier = RouteHeap()
        var partialKey: String?
        var partialScore: (total: Double, remaining: Double)?
        let minPartialProgress = partialRouteMinProgressNM(
            departurePoint: departurePoint,
            arrivalPoint: arrivalPoint,
            directDistanceNM: directDistanceNM
        )
        let maxPartialTotal = partialRouteMaxTotalNM(directDistanceNM)

        for candidate in startCandidates {
            let cost = candidate.distanceNM * 1.15
            if cost < distances[candidate.key, default: .greatestFiniteMagnitude] {
                distances[candidate.key] = cost
                previous[candidate.key] = (source, "__connector__")
                frontier.push(cost: cost, key: candidate.key)
            }
        }

        let endCosts = Dictionary(uniqueKeysWithValues: endCandidates.map {
            ($0.key, $0.distanceNM * 1.15)
        })
        var bestEnd: String?
        var bestTotal = Double.greatestFiniteMagnitude

        while let current = frontier.popMin() {
            guard current.cost <= distances[current.key, default: .greatestFiniteMagnitude] else {
                continue
            }
            if let endCost = endCosts[current.key] {
                let total = current.cost + endCost
                if total < bestTotal {
                    bestTotal = total
                    bestEnd = current.key
                }
            }
            if current.key != source, let point = graph.nodes[current.key] {
                let remaining = routeDistanceNM(point, arrivalPoint)
                let progress = directDistanceNM - remaining
                let totalWithDirectTail = current.cost + remaining
                if progress >= minPartialProgress, totalWithDirectTail <= maxPartialTotal {
                    let score = (total: totalWithDirectTail, remaining: remaining)
                    if partialScore == nil
                        || score.total < partialScore!.total
                        || (score.total == partialScore!.total && score.remaining < partialScore!.remaining) {
                        partialScore = score
                        partialKey = current.key
                    }
                }
            }
            for edge in graph.adjacency[current.key] ?? [] {
                guard allowedNodes.contains(edge.to),
                      !excludedAirways.contains(edge.airway) else { continue }
                let nextCost = current.cost + edge.distanceNM
                if nextCost < distances[edge.to, default: .greatestFiniteMagnitude] {
                    distances[edge.to] = nextCost
                    previous[edge.to] = (current.key, edge.airway)
                    frontier.push(cost: nextCost, key: edge.to)
                }
            }
        }

        guard let bestEnd else {
            if let partialKey {
                return buildPartialAirwayRoute(
                    departurePoint: departurePoint,
                    arrivalPoint: arrivalPoint,
                    partialKey: partialKey,
                    previous: previous,
                    graph: graph,
                    source: source
                )
            }
            return nil
        }
        var nodePath: [String] = []
        var cursor = bestEnd
        while cursor != source {
            nodePath.append(cursor)
            guard let prior = previous[cursor] else {
                return nil
            }
            cursor = prior.from
        }
        nodePath.reverse()

        let edgeAirways = nodePath.compactMap { key -> String? in
            guard let prior = previous[key], prior.from != source else {
                return nil
            }
            return prior.airway
        }
        let legs = compressAutoLegs(nodePath: nodePath, edgeAirways: edgeAirways, graph: graph)
        guard !legs.isEmpty else {
            return directRouteBetween(departurePoint, arrivalPoint)
        }
        let points = dedupeRoutePoints([departurePoint] + nodePath.compactMap { graph.nodes[$0] } + [arrivalPoint])
        let mixed = RoutePath(
            points: points,
            legs: legs,
            routeDisplay: routeDisplayFromLegs(legs, fallback: "")
        )
        if let preferredSingleAirway,
           legs.isEmpty
            || pathLengthNM(preferredSingleAirway.points) <= pathLengthNM(mixed.points) + 80
            || legs.count > 1 {
            return preferredSingleAirway
        }
        return mixed
    }

    private func preferSingleAirwayRoute(
        departurePoint: [String: Any],
        arrivalPoint: [String: Any],
        startCandidates: [(key: String, distanceNM: Double)],
        endCandidates: [(key: String, distanceNM: Double)],
        graph: AirwayGraph,
        excludedAirways: Set<String> = []
    ) -> RoutePath? {
        var best: (path: RoutePath, scoreNM: Double)?
        for start in startCandidates {
            for end in endCandidates {
                let sharedAirways = (graph.nodeAirways[start.key] ?? []).intersection(graph.nodeAirways[end.key] ?? [])
                guard !sharedAirways.isEmpty else { continue }
                for airway in sharedAirways {
                    guard !excludedAirways.contains(airway) else {
                        continue
                    }
                    guard let nodePath = singleAirwayNodePath(
                        airway: airway,
                        startKey: start.key,
                        endKey: end.key,
                        graph: graph
                    ), nodePath.count >= 2 else {
                        continue
                    }
                    let segmentPoints = nodePath.compactMap { graph.nodes[$0] }
                    guard segmentPoints.count == nodePath.count else { continue }
                    let points = dedupeRoutePoints([departurePoint] + segmentPoints + [arrivalPoint])
                    let connectorNM = start.distanceNM + end.distanceNM
                    let score = pathLengthNM(segmentPoints) + connectorNM * 2.5
                    let startIdent = navString(graph.nodes[start.key]?["ident"])
                    let endIdent = navString(graph.nodes[end.key]?["ident"])
                    guard !startIdent.isEmpty, !endIdent.isEmpty, startIdent != endIdent else {
                        continue
                    }
                    let route = RoutePath(
                        points: points,
                        legs: [[
                            "type": "airway",
                            "name": airway,
                            "entry": startIdent,
                            "exit": endIdent,
                            "distance_nm": pathLengthNM(segmentPoints)
                        ]],
                        routeDisplay: "\(startIdent) \(airway) \(endIdent)"
                    )
                    if best == nil || score < best!.scoreNM {
                        best = (route, score)
                    }
                }
            }
        }
        return best?.path
    }

    private func singleAirwayNodePath(
        airway: String,
        startKey: String,
        endKey: String,
        graph: AirwayGraph
    ) -> [String]? {
        guard startKey != endKey else { return [startKey] }
        var distances: [String: Double] = [startKey: 0]
        var previous: [String: String] = [:]
        var frontier = RouteHeap()
        frontier.push(cost: 0, key: startKey)

        while let current = frontier.popMin() {
            guard current.cost <= distances[current.key, default: .greatestFiniteMagnitude] else {
                continue
            }
            if current.key == endKey {
                break
            }
            for edge in graph.adjacency[current.key] ?? [] where edge.airway == airway {
                let nextCost = current.cost + edge.distanceNM
                if nextCost < distances[edge.to, default: .greatestFiniteMagnitude] {
                    distances[edge.to] = nextCost
                    previous[edge.to] = current.key
                    frontier.push(cost: nextCost, key: edge.to)
                }
            }
        }

        guard distances[endKey] != nil else { return nil }
        var path = [endKey]
        var cursor = endKey
        while cursor != startKey {
            guard let prior = previous[cursor] else { return nil }
            path.append(prior)
            cursor = prior
        }
        return Array(path.reversed())
    }

    private func buildPartialAirwayRoute(
        departurePoint: [String: Any],
        arrivalPoint: [String: Any],
        partialKey: String,
        previous: [String: (from: String, airway: String)],
        graph: AirwayGraph,
        source: String
    ) -> RoutePath? {
        var nodePath: [String] = []
        var cursor = partialKey
        while cursor != source {
            nodePath.append(cursor)
            guard let prior = previous[cursor] else {
                return nil
            }
            cursor = prior.from
        }
        nodePath.reverse()
        guard !nodePath.isEmpty else { return nil }

        let edgeAirways = nodePath.compactMap { key -> String? in
            guard let prior = previous[key], prior.from != source else {
                return nil
            }
            return prior.airway
        }
        var legs = compressAutoLegs(nodePath: nodePath, edgeAirways: edgeAirways, graph: graph)
        if let tailStart = graph.nodes[nodePath[nodePath.count - 1]] {
            let tailIdent = navString(tailStart["ident"])
            let arrivalIdent = navString(arrivalPoint["ident"])
            if !tailIdent.isEmpty, tailIdent != arrivalIdent {
                legs.append([
                    "type": "direct",
                    "entry": tailIdent,
                    "exit": arrivalIdent,
                    "entry_point": tailStart,
                    "exit_point": arrivalPoint,
                    "distance_nm": routeDistanceNM(tailStart, arrivalPoint)
                ])
            }
        }
        let points = dedupeRoutePoints([departurePoint] + nodePath.compactMap { graph.nodes[$0] } + [arrivalPoint])
        return RoutePath(
            points: points,
            legs: legs,
            routeDisplay: routeDisplayFromLegs(legs, fallback: "")
        )
    }

    private func partialRouteMinProgressNM(
        departurePoint: [String: Any],
        arrivalPoint: [String: Any],
        directDistanceNM: Double
    ) -> Double {
        var progressRatio = 0.12
        if directDistanceNM > 2500 {
            progressRatio = 0.3
        }
        let depLon = navDouble(departurePoint["lon"]) ?? 0
        let arrLon = navDouble(arrivalPoint["lon"]) ?? 0
        if directDistanceNM > 3500 || abs(depLon - arrLon) > 180 {
            progressRatio = 0.35
        }
        return max(120.0, directDistanceNM * progressRatio)
    }

    private func partialRouteMaxTotalNM(_ directDistanceNM: Double) -> Double {
        directDistanceNM * 1.35 + 250
    }

    private func buildAirwayGraph(database: SQLiteDatabase) throws -> AirwayGraph {
        let databaseKey = currentDatabaseCacheKey()
        planningCacheLock.lock()
        preparePlanningCacheLocked(databaseKey: databaseKey)
        if let cached = airwayGraphCache {
            planningCacheLock.unlock()
            return cached
        }
        planningCacheLock.unlock()

        let graph = try buildAirwayGraphUncached(database: database)

        planningCacheLock.lock()
        preparePlanningCacheLocked(databaseKey: databaseKey)
        airwayGraphCache = graph
        planningCacheLock.unlock()
        return graph
    }

    private func buildAirwayGraphUncached(database: SQLiteDatabase) throws -> AirwayGraph {
        let rows = try database.rows(
            sql: """
            select route_identifier, seqno, waypoint_identifier, waypoint_latitude, waypoint_longitude,
                   direction_restriction, inbound_distance, area_code, icao_code, route_type
            from tbl_enroute_airways
            where waypoint_identifier is not null
              and waypoint_latitude is not null
              and waypoint_longitude is not null
            order by route_identifier, seqno
            """
        )
        var grouped: [(airway: String, rows: [[String: Any]])] = []
        for row in rows {
            let airway = navString(row["route_identifier"])
            if grouped.indices.last.map({ grouped[$0].airway == airway }) == true {
                grouped[grouped.count - 1].rows.append(row)
            } else {
                grouped.append((airway: airway, rows: [row]))
            }
        }

        var nodes: [String: [String: Any]] = [:]
        var adjacency: [String: [GraphEdge]] = [:]
        var nodeAirways: [String: Set<String>] = [:]
        var nodesByIdent: [String: [String]] = [:]
        var spatialBuckets: [GraphSpatialKey: [String]] = [:]

        for group in grouped {
            let ordered = group.rows.sorted {
                (navInt($0["seqno"]) ?? 0) < (navInt($1["seqno"]) ?? 0)
            }
            for chunk in partitionAirwayRows(ordered) {
                var previousRow: [String: Any]?
                for row in chunk {
                    guard let key = graphKey(row: row) else {
                        previousRow = row
                        continue
                    }
                    if nodes[key] == nil {
                        nodes[key] = graphPoint(from: row)
                        let ident = navString(row["waypoint_identifier"]).uppercased()
                        nodesByIdent[ident, default: []].append(key)
                        if let lat = navDouble(row["waypoint_latitude"]),
                           let lon = navDouble(row["waypoint_longitude"]) {
                            spatialBuckets[graphSpatialKey(lat: lat, lon: lon), default: []].append(key)
                        }
                    }
                    guard let previous = previousRow,
                          let previousKey = graphKey(row: previous),
                          previousKey != key,
                          let previousLat = navDouble(previous["waypoint_latitude"]),
                          let previousLon = navDouble(previous["waypoint_longitude"]),
                          let currentLat = navDouble(row["waypoint_latitude"]),
                          let currentLon = navDouble(row["waypoint_longitude"]) else {
                        previousRow = row
                        continue
                    }
                    let airway = navString(row["route_identifier"]).uppercased()
                    let distance = greatCircleNM(
                        lat1: previousLat,
                        lon1: previousLon,
                        lat2: currentLat,
                        lon2: currentLon
                    )
                    let restriction = navString(row["direction_restriction"])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .uppercased()
                    if restriction == "F" {
                        adjacency[previousKey, default: []].append(GraphEdge(to: key, distanceNM: distance, airway: airway))
                    } else if restriction == "B" {
                        adjacency[key, default: []].append(GraphEdge(to: previousKey, distanceNM: distance, airway: airway))
                    } else {
                        adjacency[previousKey, default: []].append(GraphEdge(to: key, distanceNM: distance, airway: airway))
                        adjacency[key, default: []].append(GraphEdge(to: previousKey, distanceNM: distance, airway: airway))
                    }
                    nodeAirways[previousKey, default: []].insert(airway)
                    nodeAirways[key, default: []].insert(airway)
                    previousRow = row
                }
            }
        }

        return AirwayGraph(
            nodes: nodes,
            adjacency: adjacency,
            nodeAirways: nodeAirways,
            nodesByIdent: nodesByIdent,
            spatialBuckets: spatialBuckets
        )
    }

    private func partitionAirwayRows(_ rows: [[String: Any]]) -> [[[String: Any]]] {
        guard let first = rows.first else { return [] }
        var chunks: [[[String: Any]]] = []
        var currentChunk = [first]

        for row in rows.dropFirst() {
            let previous = currentChunk[currentChunk.count - 1]
            let previousSeq = navInt(previous["seqno"]) ?? 0
            let currentSeq = navInt(row["seqno"]) ?? 0
            let sequenceGap = abs(currentSeq - previousSeq)
            let geoGap: Double
            if let previousLat = navDouble(previous["waypoint_latitude"]),
               let previousLon = navDouble(previous["waypoint_longitude"]),
               let currentLat = navDouble(row["waypoint_latitude"]),
               let currentLon = navDouble(row["waypoint_longitude"]) {
                geoGap = greatCircleNM(
                    lat1: previousLat,
                    lon1: previousLon,
                    lat2: currentLat,
                    lon2: currentLon
                )
            } else {
                geoGap = 0
            }
            let inboundDistance = navDouble(row["inbound_distance"])
            let inboundMatches = inboundDistance.map {
                $0 > 0 && abs($0 - geoGap) <= max(80.0, $0 * 0.35)
            } ?? false
            let maxGeoGap = inboundMatches ? 900.0 : 300.0
            if sequenceGap > 500 || geoGap > maxGeoGap {
                chunks.append(currentChunk)
                currentChunk = [row]
            } else {
                currentChunk.append(row)
            }
        }
        chunks.append(currentChunk)
        return chunks
    }

    private func graphKey(row: [String: Any]) -> String? {
        guard let lat = navDouble(row["waypoint_latitude"]),
              let lon = navDouble(row["waypoint_longitude"]) else {
            return nil
        }
        let ident = navString(row["waypoint_identifier"]).uppercased()
        guard !ident.isEmpty else { return nil }
        return graphKey(ident: ident, lat: lat, lon: lon)
    }

    private func graphKey(ident: String, lat: Double, lon: Double) -> String {
        "\(ident):\(String(format: "%.6f", lat)):\(String(format: "%.6f", lon))"
    }

    private func graphPoint(from row: [String: Any]) -> [String: Any] {
        let ident = navString(row["waypoint_identifier"]).uppercased()
        return [
            "ident": ident,
            "name": ident,
            "label": ident,
            "kind": "airway-fix",
            "lat": navDouble(row["waypoint_latitude"]) ?? 0,
            "lon": navDouble(row["waypoint_longitude"]) ?? 0,
            "route": navString(row["route_identifier"]).uppercased()
        ]
    }

    private func graphNodeCandidates(
        for point: [String: Any],
        allowedNodes: Set<String>,
        graph: AirwayGraph,
        limit: Int
    ) -> [(key: String, distanceNM: Double)] {
        let ident = navString(point["ident"]).uppercased()
        let exact = (graph.nodesByIdent[ident] ?? []).compactMap { key -> (key: String, distanceNM: Double)? in
            guard allowedNodes.contains(key),
                  let graphPoint = graph.nodes[key] else {
                return nil
            }
            let distance = routeDistanceNM(point, graphPoint)
            guard distance <= 0.5 else { return nil }
            return (key, distance)
        }.sorted {
            if $0.distanceNM != $1.distanceNM {
                return $0.distanceNM < $1.distanceNM
            }
            return $0.key < $1.key
        }
        if !exact.isEmpty {
            return Array(exact.prefix(limit))
        }
        return nearestGraphNodes(
            lat: navDouble(point["lat"]) ?? 0,
            lon: navDouble(point["lon"]) ?? 0,
            allowedNodes: allowedNodes,
            graph: graph,
            limit: limit
        )
    }

    private func nearestGraphNodes(
        lat: Double,
        lon: Double,
        allowedNodes: Set<String>,
        graph: AirwayGraph,
        limit: Int
    ) -> [(key: String, distanceNM: Double)] {
        guard limit > 0 else { return [] }

        if allowedNodes.count == graph.nodes.count {
            let nearbyKeys = nearbyGraphNodeKeys(lat: lat, lon: lon, graph: graph)
            let nearby = nearestGraphNodes(
                lat: lat,
                lon: lon,
                candidateKeys: nearbyKeys,
                allowedNodes: allowedNodes,
                graph: graph,
                limit: limit
            )
            if nearby.count == limit,
               (nearby.last?.distanceNM ?? .greatestFiniteMagnitude) <= 80.0 {
                return nearby
            }
        }

        return nearestGraphNodes(
            lat: lat,
            lon: lon,
            candidateKeys: Array(graph.nodes.keys),
            allowedNodes: allowedNodes,
            graph: graph,
            limit: limit
        )
    }

    private func nearestGraphNodes(
        lat: Double,
        lon: Double,
        candidateKeys: [String],
        allowedNodes: Set<String>,
        graph: AirwayGraph,
        limit: Int
    ) -> [(key: String, distanceNM: Double)] {
        var nearest: [(key: String, distanceNM: Double)] = []
        for key in candidateKeys {
            guard allowedNodes.contains(key),
                  let point = graph.nodes[key],
                  let pointLat = navDouble(point["lat"]),
                  let pointLon = navDouble(point["lon"]) else {
                continue
            }
            let item = (
                key: key,
                distanceNM: greatCircleNM(lat1: lat, lon1: lon, lat2: pointLat, lon2: pointLon)
            )
            let insertionIndex = nearest.firstIndex {
                item.distanceNM < $0.distanceNM
                    || (item.distanceNM == $0.distanceNM && item.key < $0.key)
            } ?? nearest.endIndex
            if insertionIndex < limit {
                nearest.insert(item, at: insertionIndex)
                if nearest.count > limit {
                    nearest.removeLast()
                }
            }
        }
        return nearest
    }

    private func graphSpatialKey(lat: Double, lon: Double) -> GraphSpatialKey {
        let normalizedLon = ((lon + 180).truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) - 180
        return GraphSpatialKey(
            latitude: Int(floor(min(89.999_999, max(-90, lat)))),
            longitude: Int(floor(normalizedLon))
        )
    }

    private func nearbyGraphNodeKeys(lat: Double, lon: Double, graph: AirwayGraph) -> [String] {
        let center = graphSpatialKey(lat: lat, lon: lon)
        let latitudeRadius = 2
        let cosine = max(0.08, abs(cos(lat * .pi / 180)))
        let longitudeRadius = min(24, max(2, Int(ceil(2.0 / cosine))))
        var keys: [String] = []

        for latitude in max(-90, center.latitude - latitudeRadius)...min(89, center.latitude + latitudeRadius) {
            for longitudeOffset in (-longitudeRadius)...longitudeRadius {
                var longitude = center.longitude + longitudeOffset
                while longitude < -180 { longitude += 360 }
                while longitude >= 180 { longitude -= 360 }
                keys.append(contentsOf: graph.spatialBuckets[
                    GraphSpatialKey(latitude: latitude, longitude: longitude)
                ] ?? [])
            }
        }
        return keys
    }

    private func compressAutoLegs(
        nodePath: [String],
        edgeAirways: [String],
        graph: AirwayGraph
    ) -> [[String: Any]] {
        guard nodePath.count >= 2, !edgeAirways.isEmpty else {
            return []
        }
        var legs: [[String: Any]] = []
        var currentAirway = edgeAirways[0]
        var entryKey = nodePath[0]
        for index in 1..<edgeAirways.count {
            let airway = edgeAirways[index]
            if airway != currentAirway {
                let exitKey = nodePath[index]
                let entryIdent = navString(graph.nodes[entryKey]?["ident"])
                let exitIdent = navString(graph.nodes[exitKey]?["ident"])
                if !entryIdent.isEmpty, entryIdent != exitIdent {
                    legs.append([
                        "type": "airway",
                        "name": currentAirway,
                        "entry": entryIdent,
                        "exit": exitIdent
                    ])
                }
                currentAirway = airway
                entryKey = nodePath[index]
            }
        }
        let entryIdent = navString(graph.nodes[entryKey]?["ident"])
        let exitIdent = navString(graph.nodes[nodePath[nodePath.count - 1]]?["ident"])
        if !entryIdent.isEmpty, entryIdent != exitIdent {
            legs.append([
                "type": "airway",
                "name": currentAirway,
                "entry": entryIdent,
                "exit": exitIdent
            ])
        }
        return mergeRepeatedAirwayLegs(mergeContinuingAirwayLegs(legs, graph: graph))
    }

    private func mergeContinuingAirwayLegs(_ legs: [[String: Any]], graph: AirwayGraph) -> [[String: Any]] {
        var merged: [[String: Any]] = []
        for leg in legs {
            let current = leg
            if var previous = merged.last,
               navString(previous["type"]) == "airway",
               navString(current["type"]) == "airway",
               navString(previous["exit"]) == navString(current["entry"]),
               airwayCanContinueThrough(previous: previous, current: current, graph: graph) {
                previous["exit"] = navString(current["exit"])
                previous["count"] = nil
                previous["distance_nm"] = nil
                merged[merged.count - 1] = previous
                continue
            }
            if navString(current["entry"]) != navString(current["exit"]) {
                merged.append(current)
            }
        }
        return merged
    }

    private func airwayCanContinueThrough(
        previous: [String: Any],
        current: [String: Any],
        graph: AirwayGraph
    ) -> Bool {
        let previousAirway = navString(previous["name"]).uppercased()
        let currentAirway = navString(current["name"]).uppercased()
        let previousEntry = navString(previous["entry"]).uppercased()
        let previousExit = navString(previous["exit"]).uppercased()
        let currentEntry = navString(current["entry"]).uppercased()
        let currentExit = navString(current["exit"]).uppercased()
        guard !previousAirway.isEmpty,
              !currentAirway.isEmpty,
              !previousEntry.isEmpty,
              !previousExit.isEmpty,
              !currentEntry.isEmpty,
              !currentExit.isEmpty else {
            return false
        }

        guard let combined = airwayPathPoints(
            airway: previousAirway,
            entry: previousEntry,
            exit: currentExit,
            graph: graph
        ),
              let previousSegment = airwayPathPoints(
                airway: previousAirway,
                entry: previousEntry,
                exit: previousExit,
                graph: graph
              ),
              let currentSegment = airwayPathPoints(
                airway: currentAirway,
                entry: currentEntry,
                exit: currentExit,
                graph: graph
              ) else {
            return false
        }

        guard combined.contains(where: { navString($0["ident"]).uppercased() == previousExit }) else {
            return false
        }
        let combinedDistance = pathLengthNM(combined)
        let originalDistance = pathLengthNM(previousSegment) + pathLengthNM(currentSegment)
        return combinedDistance <= originalDistance * 1.02 + 1.0
    }

    private func airwayPathPoints(
        airway: String,
        entry: String,
        exit: String,
        graph: AirwayGraph
    ) -> [[String: Any]]? {
        let airwayName = airway.uppercased()
        let entryIdent = entry.uppercased()
        let exitIdent = exit.uppercased()
        guard entryIdent != exitIdent else { return nil }

        let entryKeys = graph.nodesByIdent[entryIdent] ?? []
        let exitKeys = graph.nodesByIdent[exitIdent] ?? []
        guard !entryKeys.isEmpty, !exitKeys.isEmpty else { return nil }

        var best: (points: [[String: Any]], distanceNM: Double)?
        for entryKey in entryKeys where graph.nodeAirways[entryKey]?.contains(airwayName) == true {
            for exitKey in exitKeys where graph.nodeAirways[exitKey]?.contains(airwayName) == true {
                guard let nodePath = singleAirwayNodePath(
                    airway: airwayName,
                    startKey: entryKey,
                    endKey: exitKey,
                    graph: graph
                ), nodePath.count >= 2 else {
                    continue
                }
                let points = nodePath.compactMap { graph.nodes[$0] }
                guard points.count == nodePath.count else {
                    continue
                }
                let distance = pathLengthNM(points)
                if best == nil || distance < best!.distanceNM {
                    best = (points, distance)
                }
            }
        }
        return best?.points
    }

    private func mergeRepeatedAirwayLegs(_ legs: [[String: Any]]) -> [[String: Any]] {
        var merged: [[String: Any]] = []
        var index = 0
        while index < legs.count {
            var current = legs[index]
            guard navString(current["type"]) == "airway" else {
                merged.append(current)
                index += 1
                continue
            }

            var lookahead = index + 1
            while lookahead < legs.count,
                  navString(legs[lookahead]["type"]) == "airway",
                  navString(legs[lookahead]["name"]) == navString(current["name"]),
                  navString(legs[lookahead]["entry"]) == navString(current["exit"]) {
                current["exit"] = navString(legs[lookahead]["exit"])
                current["count"] = nil
                current["distance_nm"] = nil
                lookahead += 1
            }
            while lookahead + 1 < legs.count,
                  navString(legs[lookahead]["type"]) == "airway",
                  navString(legs[lookahead + 1]["type"]) == "airway",
                  navString(legs[lookahead + 1]["name"]) == navString(current["name"]),
                  navString(legs[lookahead + 1]["entry"]) == navString(legs[lookahead]["exit"]) {
                current["exit"] = navString(legs[lookahead + 1]["exit"])
                current["count"] = nil
                current["distance_nm"] = nil
                lookahead += 2
            }
            if navString(current["entry"]) != navString(current["exit"]) {
                merged.append(current)
            }
            index = lookahead
        }
        return merged
    }

    private func directRouteBetween(_ departurePoint: [String: Any], _ arrivalPoint: [String: Any]) -> RoutePath {
        let departureIdent = navString(departurePoint["ident"])
        let arrivalIdent = navString(arrivalPoint["ident"])
        guard departureIdent != arrivalIdent else {
            return RoutePath(points: [departurePoint], legs: [], routeDisplay: departureIdent)
        }
        return RoutePath(
            points: [departurePoint, arrivalPoint],
            legs: [[
                "type": "direct",
                "entry": departureIdent,
                "exit": arrivalIdent,
                "entry_point": departurePoint,
                "exit_point": arrivalPoint,
                "distance_nm": routeDistanceNM(departurePoint, arrivalPoint)
            ]],
            routeDisplay: "\(departureIdent) DCT \(arrivalIdent)"
        )
    }

    private func normalizeImportedTrackPoints(_ trackPoints: [[String: Any]]) -> [TrackPoint] {
        trackPoints.compactMap { item in
            let lat = navDouble(item["lat"]) ?? navDouble(item["latitude"])
            let lon = navDouble(item["lon"]) ?? navDouble(item["lng"]) ?? navDouble(item["longitude"])
            guard let lat, let lon, lat.isFinite, lon.isFinite else {
                return nil
            }
            return TrackPoint(lat: lat, lon: lon)
        }
    }

    private func matchTrackPointsToAirways(
        _ trackPoints: [TrackPoint],
        database: SQLiteDatabase
    ) throws -> RoutePath {
        let graph = try buildAirwayGraph(database: database)
        let allNodes = Set(graph.nodes.keys)
        let maxSnapNM = 80.0
        var snappedKeys: [String] = []

        for trackPoint in trackPoints {
            guard let candidate = nearestGraphNodes(
                lat: trackPoint.lat,
                lon: trackPoint.lon,
                allowedNodes: allNodes,
                graph: graph,
                limit: 1
            ).first, candidate.distanceNM <= maxSnapNM else {
                continue
            }
            if snappedKeys.last != candidate.key {
                snappedKeys.append(candidate.key)
            }
        }

        guard snappedKeys.count >= 2 else {
            throw plannerError("导入轨迹点无法匹配到足够的 airway fix。")
        }

        var legs: [[String: Any]] = []
        let maxDetourRatio = 1.8
        let maxDetourExtraNM = 80.0

        for index in 0..<(snappedKeys.count - 1) {
            let startKey = snappedKeys[index]
            let endKey = snappedKeys[index + 1]
            guard let startPoint = graph.nodes[startKey],
                  let endPoint = graph.nodes[endKey] else {
                continue
            }
            let directDistance = routeDistanceNM(startPoint, endPoint)
            if let segment = shortestGraphPath(startKey: startKey, endKey: endKey, graph: graph) {
                let segmentPoints = segment.nodes.compactMap { graph.nodes[$0] }
                let airwayDistance = pathLengthNM(segmentPoints)
                let isDetour = directDistance > 1.0 && (
                    airwayDistance > directDistance * maxDetourRatio
                    || airwayDistance - directDistance > maxDetourExtraNM
                )
                if !isDetour {
                    let segmentLegs = compressAutoLegs(
                        nodePath: segment.nodes,
                        edgeAirways: segment.airways,
                        graph: graph
                    )
                    for leg in segmentLegs {
                        appendMatchedLeg(leg, to: &legs)
                    }
                    continue
                }
            }
            appendMatchedLeg(directLeg(from: startPoint, to: endPoint), to: &legs)
        }

        let simplifiedLegs = try simplifyMatchedTrackLegs(
            mergeRepeatedAirwayLegs(legs),
            trackPoints: trackPoints,
            graph: graph,
            database: database
        )
        let smoothedLegs = try smoothMatchedTrackZigzagLegs(
            simplifiedLegs,
            trackPoints: trackPoints,
            database: database
        )
        let mergedLegs = mergeRepeatedAirwayLegs(smoothedLegs).filter {
            navString($0["entry"]) != navString($0["exit"])
        }
        guard !mergedLegs.isEmpty else {
            throw plannerError("No legal airway path could be built from the imported trajectory.")
        }
        let points = try pointsFromLegs(mergedLegs, database: database)
        guard points.count >= 2 else {
            throw plannerError("No drawable route points could be built from the imported trajectory.")
        }
        return RoutePath(
            points: points,
            legs: mergedLegs,
            routeDisplay: routeDisplayFromLegs(mergedLegs, fallback: "")
        )
    }

    private func simplifyMatchedTrackLegs(
        _ legs: [[String: Any]],
        trackPoints: [TrackPoint],
        graph: AirwayGraph,
        database: SQLiteDatabase
    ) throws -> [[String: Any]] {
        var simplified = legs.filter { navString($0["entry"]) != navString($0["exit"]) }
        var changed = true

        while changed {
            changed = false
            var nextPass: [[String: Any]] = []
            var index = 0

            while index < simplified.count {
                var replacement: (endIndex: Int, leg: [String: Any])?
                let maxEndIndex = min(simplified.count - 1, index + 8)

                if index < maxEndIndex {
                    for endIndex in stride(from: maxEndIndex, through: index + 1, by: -1) {
                        let startIdent = navString(simplified[index]["entry"])
                        let endIdent = navString(simplified[endIndex]["exit"])
                        guard !startIdent.isEmpty,
                              !endIdent.isEmpty,
                              startIdent != endIdent,
                              let candidate = singleAirwayLegForIdents(
                                entry: startIdent,
                                exit: endIdent,
                                graph: graph
                              ) else {
                            continue
                        }

                        let currentPoints = try pointsFromLegs(Array(simplified[index...endIndex]), database: database)
                        let candidatePoints = try pointsFromLegs([candidate], database: database)
                        guard currentPoints.count >= 2,
                              candidatePoints.count >= 2 else {
                            continue
                        }
                        let currentDistance = pathLengthNM(currentPoints)
                        let candidateDistance = pathLengthNM(candidatePoints)
                        if candidateDistance <= currentDistance * 1.25 + 20.0,
                           fr24ReplacementTracksWell(
                            currentPoints: currentPoints,
                            candidatePoints: candidatePoints,
                            trackPoints: trackPoints
                           ) {
                            replacement = (endIndex, candidate)
                            break
                        }
                    }
                }

                if let replacement {
                    nextPass.append(replacement.leg)
                    index = replacement.endIndex + 1
                    changed = true
                } else {
                    nextPass.append(simplified[index])
                    index += 1
                }
            }

            simplified = mergeRepeatedAirwayLegs(nextPass)
        }

        return simplified
    }

    private func smoothMatchedTrackZigzagLegs(
        _ legs: [[String: Any]],
        trackPoints: [TrackPoint],
        database: SQLiteDatabase
    ) throws -> [[String: Any]] {
        guard !trackPoints.isEmpty else { return legs }
        var smoothed = legs
        var changed = true
        let maxWindowDistanceNM = 170.0
        let maxExtraErrorNM = 2.0
        let minOfftrackNM = 10.0

        while changed {
            changed = false
            var nextPass: [[String: Any]] = []
            var index = 0

            while index < smoothed.count {
                var replacement: (endIndex: Int, leg: [String: Any])?

                for windowSize in [3, 2] {
                    let endIndex = index + windowSize
                    if endIndex > smoothed.count {
                        continue
                    }
                    let window = Array(smoothed[index..<endIndex])
                    if !window.contains(where: { navString($0["type"]) == "direct" }) {
                        continue
                    }
                    let currentPoints = try pointsFromLegs(window, database: database)
                    if currentPoints.count < 3 {
                        continue
                    }
                    let currentDistance = pathLengthNM(currentPoints)
                    if currentDistance > maxWindowDistanceNM {
                        continue
                    }
                    let intermediateOfftrack = currentPoints.dropFirst().dropLast().map {
                        pointTrackMinDistanceNM(point: $0, trackPoints: trackPoints)
                    }.max() ?? 0
                    if intermediateOfftrack < minOfftrackNM {
                        continue
                    }
                    guard let first = currentPoints.first,
                          let last = currentPoints.last else {
                        continue
                    }
                    let directPoints = [first, last]
                    let currentError = routeTrackErrorNM(routePoints: currentPoints, trackPoints: trackPoints)
                    let directError = routeTrackErrorNM(routePoints: directPoints, trackPoints: trackPoints)
                    let directDistance = pathLengthNM(directPoints)
                    if directDistance <= currentDistance * 0.9,
                       directError <= currentError + maxExtraErrorNM {
                        replacement = (endIndex, directLeg(from: first, to: last))
                        break
                    }
                }

                if let replacement {
                    nextPass.append(replacement.leg)
                    index = replacement.endIndex
                    changed = true
                } else {
                    nextPass.append(smoothed[index])
                    index += 1
                }
            }

            smoothed = mergeRepeatedAirwayLegs(nextPass)
        }

        return smoothed.filter { navString($0["entry"]) != navString($0["exit"]) }
    }

    private func pointTrackMinDistanceNM(point: [String: Any], trackPoints: [TrackPoint]) -> Double {
        guard !trackPoints.isEmpty,
              let lat = navDouble(point["lat"]),
              let lon = navDouble(point["lon"]) else {
            return .greatestFiniteMagnitude
        }
        return trackPoints.map { trackPoint in
            greatCircleNM(lat1: lat, lon1: lon, lat2: trackPoint.lat, lon2: trackPoint.lon)
        }.min() ?? .greatestFiniteMagnitude
    }

    private func fr24ReplacementTracksWell(
        currentPoints: [[String: Any]],
        candidatePoints: [[String: Any]],
        trackPoints: [TrackPoint]
    ) -> Bool {
        guard !trackPoints.isEmpty else { return true }
        let currentError = routeTrackErrorNM(routePoints: currentPoints, trackPoints: trackPoints)
        let candidateError = routeTrackErrorNM(routePoints: candidatePoints, trackPoints: trackPoints)
        let maxExtra = 8.0
        let maxRatio = 1.25
        return candidateError <= currentError * maxRatio + maxExtra
    }

    private func routeTrackErrorNM(routePoints: [[String: Any]], trackPoints: [TrackPoint]) -> Double {
        guard routePoints.count >= 2, !trackPoints.isEmpty else {
            return .greatestFiniteMagnitude
        }
        var samples = trackSamplesNearRouteExtent(routePoints: routePoints, trackPoints: trackPoints)
        if samples.isEmpty {
            let step = max(1, trackPoints.count / 40)
            samples = stride(from: 0, to: trackPoints.count, by: step).map { trackPoints[$0] }
        }
        var distances = samples.map { trackPoint in
            distanceToPolylineNM(lat: trackPoint.lat, lon: trackPoint.lon, routePoints: routePoints)
        }.sorted()
        guard !distances.isEmpty else {
            return .greatestFiniteMagnitude
        }
        let cutoff = max(1, Int(Double(distances.count) * 0.85))
        distances = Array(distances.prefix(cutoff))
        return distances.reduce(0, +) / Double(cutoff)
    }

    private func trackSamplesNearRouteExtent(routePoints: [[String: Any]], trackPoints: [TrackPoint]) -> [TrackPoint] {
        guard let start = routePoints.first,
              let end = routePoints.last,
              let startLat = navDouble(start["lat"]),
              let startLon = navDouble(start["lon"]),
              let endLat = navDouble(end["lat"]),
              let endLon = navDouble(end["lon"]),
              !trackPoints.isEmpty else {
            return []
        }
        let startIndex = trackPoints.indices.min { lhs, rhs in
            greatCircleNM(lat1: trackPoints[lhs].lat, lon1: trackPoints[lhs].lon, lat2: startLat, lon2: startLon)
                < greatCircleNM(lat1: trackPoints[rhs].lat, lon1: trackPoints[rhs].lon, lat2: startLat, lon2: startLon)
        } ?? trackPoints.startIndex
        let endIndex = trackPoints.indices.min { lhs, rhs in
            greatCircleNM(lat1: trackPoints[lhs].lat, lon1: trackPoints[lhs].lon, lat2: endLat, lon2: endLon)
                < greatCircleNM(lat1: trackPoints[rhs].lat, lon1: trackPoints[rhs].lon, lat2: endLat, lon2: endLon)
        } ?? trackPoints.startIndex
        let lower = min(startIndex, endIndex)
        let upper = max(startIndex, endIndex)
        let segment = Array(trackPoints[lower...upper])
        let step = max(1, segment.count / 40)
        return stride(from: 0, to: segment.count, by: step).map { segment[$0] }
    }

    private func distanceToPolylineNM(lat: Double, lon: Double, routePoints: [[String: Any]]) -> Double {
        guard routePoints.count >= 2 else {
            return .greatestFiniteMagnitude
        }
        return (1..<routePoints.count).map { index in
            distanceToSegmentNM(
                lat: lat,
                lon: lon,
                start: routePoints[index - 1],
                end: routePoints[index]
            )
        }.min() ?? .greatestFiniteMagnitude
    }

    private func distanceToSegmentNM(
        lat: Double,
        lon: Double,
        start: [String: Any],
        end: [String: Any]
    ) -> Double {
        guard let startLat = navDouble(start["lat"]),
              let startLonRaw = navDouble(start["lon"]),
              let endLat = navDouble(end["lat"]),
              let endLonRaw = navDouble(end["lon"]) else {
            return .greatestFiniteMagnitude
        }
        let referenceLat = (lat + startLat + endLat) / 3
        let startLon = wrapLongitude(startLonRaw, near: lon)
        let endLon = wrapLongitude(endLonRaw, near: lon)
        let point = projectXYNM(lat: lat, lon: lon, referenceLat: referenceLat)
        let a = projectXYNM(lat: startLat, lon: startLon, referenceLat: referenceLat)
        let b = projectXYNM(lat: endLat, lon: endLon, referenceLat: referenceLat)
        let dx = b.x - a.x
        let dy = b.y - a.y
        if dx == 0, dy == 0 {
            return hypot(point.x - a.x, point.y - a.y)
        }
        let projected = ((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy)
        let t = min(1, max(0, projected))
        let closestX = a.x + t * dx
        let closestY = a.y + t * dy
        return hypot(point.x - closestX, point.y - closestY)
    }

    private func projectXYNM(lat: Double, lon: Double, referenceLat: Double) -> (x: Double, y: Double) {
        (lon * 60 * cos(referenceLat * .pi / 180), lat * 60)
    }

    private func singleAirwayLegForIdents(
        entry: String,
        exit: String,
        graph: AirwayGraph
    ) -> [String: Any]? {
        let entryKeys = graph.nodesByIdent[entry.uppercased()] ?? []
        let exitKeys = graph.nodesByIdent[exit.uppercased()] ?? []
        var best: (distanceNM: Double, leg: [String: Any])?

        for entryKey in entryKeys {
            for exitKey in exitKeys {
                let sharedAirways = (graph.nodeAirways[entryKey] ?? []).intersection(graph.nodeAirways[exitKey] ?? [])
                for airway in sharedAirways {
                    guard let nodePath = singleAirwayNodePath(
                        airway: airway,
                        startKey: entryKey,
                        endKey: exitKey,
                        graph: graph
                    ), nodePath.count >= 2 else {
                        continue
                    }
                    let points = nodePath.compactMap { graph.nodes[$0] }
                    guard points.count == nodePath.count else {
                        continue
                    }
                    let distance = pathLengthNM(points)
                    let leg = [
                        "type": "airway",
                        "name": airway,
                        "entry": entry,
                        "exit": exit,
                        "distance_nm": distance
                    ] as [String: Any]
                    if best == nil || distance < best!.distanceNM {
                        best = (distance, leg)
                    }
                }
            }
        }

        return best?.leg
    }

    private func shortestGraphPath(
        startKey: String,
        endKey: String,
        graph: AirwayGraph
    ) -> (nodes: [String], airways: [String])? {
        if startKey == endKey {
            return ([startKey], [])
        }

        var distances: [String: Double] = [startKey: 0]
        var previous: [String: (from: String, airway: String)] = [:]
        var frontier = RouteHeap()
        frontier.push(cost: graphHeuristicNM(from: startKey, to: endKey, graph: graph), key: startKey)

        while let current = frontier.popMin() {
            if current.key == endKey {
                break
            }
            let currentDistance = distances[current.key, default: .greatestFiniteMagnitude]
            let expectedPriority = currentDistance + graphHeuristicNM(from: current.key, to: endKey, graph: graph)
            guard current.cost <= expectedPriority + 1e-9 else {
                continue
            }
            for edge in graph.adjacency[current.key] ?? [] {
                let nextDistance = currentDistance + edge.distanceNM
                if nextDistance < distances[edge.to, default: .greatestFiniteMagnitude] {
                    distances[edge.to] = nextDistance
                    previous[edge.to] = (current.key, edge.airway)
                    let priority = nextDistance + graphHeuristicNM(from: edge.to, to: endKey, graph: graph)
                    frontier.push(cost: priority, key: edge.to)
                }
            }
        }

        guard previous[endKey] != nil else {
            return nil
        }

        var nodes: [String] = []
        var airways: [String] = []
        var cursor = endKey
        while cursor != startKey {
            nodes.append(cursor)
            guard let prior = previous[cursor] else {
                return nil
            }
            airways.append(prior.airway)
            cursor = prior.from
        }
        nodes.append(startKey)
        return (Array(nodes.reversed()), Array(airways.reversed()))
    }

    private func graphHeuristicNM(from startKey: String, to endKey: String, graph: AirwayGraph) -> Double {
        guard let start = graph.nodes[startKey], let end = graph.nodes[endKey] else { return 0 }
        return routeDistanceNM(start, end)
    }

    private func directLeg(from startPoint: [String: Any], to endPoint: [String: Any]) -> [String: Any] {
        [
            "type": "direct",
            "entry": navString(startPoint["ident"]),
            "exit": navString(endPoint["ident"]),
            "entry_point": startPoint,
            "exit_point": endPoint,
            "distance_nm": routeDistanceNM(startPoint, endPoint)
        ]
    }

    private func appendMatchedLeg(_ leg: [String: Any], to legs: inout [[String: Any]]) {
        guard !leg.isEmpty,
              navString(leg["entry"]) != navString(leg["exit"]) else {
            return
        }
        if var previous = legs.last {
            if navString(previous["type"]) == "airway",
               navString(leg["type"]) == "airway",
               navString(previous["name"]) == navString(leg["name"]),
               navString(previous["exit"]) == navString(leg["entry"]) {
                previous["exit"] = navString(leg["exit"])
                legs[legs.count - 1] = previous
                return
            }
            if navString(previous["type"]) == "direct",
               navString(leg["type"]) == "direct",
               navString(previous["exit"]) == navString(leg["entry"]) {
                previous["exit"] = navString(leg["exit"])
                previous["exit_point"] = leg["exit_point"] ?? previous["exit_point"] ?? NSNull()
                previous["distance_nm"] = nil
                legs[legs.count - 1] = previous
                return
            }
        }
        legs.append(leg)
    }

    private func pointsFromLegs(_ legs: [[String: Any]], database: SQLiteDatabase) throws -> [[String: Any]] {
        var points: [[String: Any]] = []

        for leg in legs {
            let type = navString(leg["type"])
            let segment: [[String: Any]]
            if type == "airway" {
                guard let airway = try expandAirway(
                    navString(leg["name"]),
                    entry: navString(leg["entry"]),
                    exit: navString(leg["exit"]),
                    database: database
                ) else {
                    continue
                }
                segment = airway.points
            } else if type == "direct" {
                let start: [String: Any]?
                if let entryPoint = leg["entry_point"] as? [String: Any] {
                    start = entryPoint
                } else {
                    start = try lookupPoint(navString(leg["entry"]).uppercased(), database: database)
                }
                let end: [String: Any]?
                if let exitPoint = leg["exit_point"] as? [String: Any] {
                    end = exitPoint
                } else {
                    end = try lookupPoint(navString(leg["exit"]).uppercased(), database: database)
                }
                segment = [start, end].compactMap { $0 }
            } else {
                continue
            }

            guard !segment.isEmpty else {
                continue
            }
            if let last = points.last,
               navString(last["ident"]) == navString(segment[0]["ident"]) {
                points.append(contentsOf: segment.dropFirst())
            } else {
                points.append(contentsOf: segment)
            }
        }

        return dedupeRoutePoints(points)
    }

    private func plannerError(_ message: String) -> NSError {
        NSError(
            domain: "NavPlanner.PlannerService",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func routeCorridorSlackFactors(
        departurePoint: [String: Any],
        arrivalPoint: [String: Any],
        directDistanceNM: Double
    ) -> [Double] {
        var factors = [0.35]
        let depLon = navDouble(departurePoint["lon"]) ?? 0
        let arrLon = navDouble(arrivalPoint["lon"]) ?? 0
        let crossesAntimeridian = abs(depLon - arrLon) > 180
        if directDistanceNM > 1800 || crossesAntimeridian {
            factors.append(contentsOf: [0.65, 1.0, 1.45])
        }
        if directDistanceNM > 4500 || crossesAntimeridian {
            factors.append(2.0)
        }
        return factors
    }

    private func resolveRouteBoundaryPoint(
        _ token: String,
        airway: String?,
        neighbor: [String: Any]?,
        database: SQLiteDatabase
    ) throws -> [String: Any]? {
        let ident = token.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !ident.isEmpty else { return nil }
        if let airway, !airway.isEmpty {
            let rows = try database.rows(
                sql: """
                select route_identifier, waypoint_identifier, waypoint_latitude, waypoint_longitude,
                       area_code, icao_code, route_type, seqno
                from tbl_enroute_airways
                where route_identifier = ?
                  and waypoint_identifier = ?
                  and waypoint_latitude is not null
                  and waypoint_longitude is not null
                """,
                arguments: [.text(airway.uppercased()), .text(ident)]
            )
            let points = rows.map { row in
                [
                    "ident": navString(row["waypoint_identifier"]).uppercased(),
                    "name": navString(row["waypoint_identifier"]).uppercased(),
                    "label": navString(row["waypoint_identifier"]).uppercased(),
                    "kind": "airway-fix",
                    "lat": navDouble(row["waypoint_latitude"]) ?? 0,
                    "lon": navDouble(row["waypoint_longitude"]) ?? 0,
                    "area_code": navString(row["area_code"]),
                    "route": navString(row["route_identifier"]).uppercased(),
                    "seqno": navInt(row["seqno"]) ?? 0
                ] as [String: Any]
            }
            if let neighbor, !points.isEmpty {
                return points.min { routeDistanceNM($0, neighbor) < routeDistanceNM($1, neighbor) }
            }
            if let first = points.first {
                return first
            }
        }
        return try lookupPoint(ident, database: database)
    }

    private func lookupDepartureArrivalPoint(_ token: String, database: SQLiteDatabase) throws -> [String: Any]? {
        guard !token.isEmpty else { return nil }
        if let airportIdent = try resolveAirportIdentifier(token, database: database) {
            let row = try database.first(
                sql: """
                select airport_identifier as ident,
                       coalesce(airport_name, airport_identifier) as name,
                       airport_ref_latitude as lat,
                       airport_ref_longitude as lon,
                       'airport' as kind
                from tbl_airports
                where airport_identifier = ?
                limit 1
                """,
                arguments: [.text(airportIdent.uppercased())]
            )
            if let row,
               navDouble(row["lat"]) != nil,
               navDouble(row["lon"]) != nil {
                return row
            }
        }
        return try lookupPoint(token, database: database)
    }

    private func fr24AirportInfo(point: [String: Any], database: SQLiteDatabase) throws -> [String: Any] {
        let ident = navString(point["ident"]).uppercased()
        let airport = try database.first(
            sql: """
            select airport_identifier, airport_name, iata_ata_designator,
                   airport_ref_latitude, airport_ref_longitude
            from tbl_airports
            where airport_identifier = ?
            limit 1
            """,
            arguments: [.text(ident)]
        )
        let iata = navString(airport?["iata_ata_designator"]).uppercased()
        var codes = [ident]
        if !iata.isEmpty, iata != ident {
            codes.append(iata)
        }
        return [
            "ident": ident,
            "icao": ident,
            "iata": iata,
            "schedule_code": iata.isEmpty ? ident : iata,
            "codes": codes,
            "name": navString(airport?["airport_name"]),
            "lat": navDouble(point["lat"]) ?? navDouble(airport?["airport_ref_latitude"]) ?? 0,
            "lon": navDouble(point["lon"]) ?? navDouble(airport?["airport_ref_longitude"]) ?? 0,
            "point": point
        ]
    }

    private func lookupPoint(_ token: String, database: SQLiteDatabase) throws -> [String: Any]? {
        guard !token.isEmpty else { return nil }
        let normalized = token.uppercased()
        let queries: [(String, [SQLiteArgument])] = [
            (
                """
                select airport_identifier as ident,
                       coalesce(airport_name, airport_identifier) as name,
                       airport_ref_latitude as lat,
                       airport_ref_longitude as lon,
                       'airport' as kind
                from tbl_airports
                where airport_identifier = ?
                limit 1
                """,
                [.text(normalized)]
            ),
            (
                """
                select waypoint_identifier as ident,
                       coalesce(waypoint_name, waypoint_identifier) as name,
                       waypoint_latitude as lat,
                       waypoint_longitude as lon,
                       'waypoint' as kind
                from tbl_enroute_waypoints
                where waypoint_identifier = ?
                limit 1
                """,
                [.text(normalized)]
            ),
            (
                """
                select waypoint_identifier as ident,
                       coalesce(waypoint_name, waypoint_identifier) as name,
                       waypoint_latitude as lat,
                       waypoint_longitude as lon,
                       'waypoint' as kind
                from tbl_terminal_waypoints
                where waypoint_identifier = ?
                limit 1
                """,
                [.text(normalized)]
            ),
            (
                """
                select vor_identifier as ident,
                       coalesce(vor_name, vor_identifier) as name,
                       vor_latitude as lat,
                       vor_longitude as lon,
                       'vor' as kind
                from tbl_vhfnavaids
                where vor_identifier = ?
                limit 1
                """,
                [.text(normalized)]
            ),
            (
                """
                select ndb_identifier as ident,
                       coalesce(ndb_name, ndb_identifier) as name,
                       ndb_latitude as lat,
                       ndb_longitude as lon,
                       'ndb' as kind
                from tbl_enroute_ndbnavaids
                where ndb_identifier = ?
                limit 1
                """,
                [.text(normalized)]
            ),
            (
                """
                select airport_identifier as ident,
                       coalesce(airport_name, airport_identifier) as name,
                       airport_ref_latitude as lat,
                       airport_ref_longitude as lon,
                       'airport' as kind
                from tbl_airports
                where iata_ata_designator = ?
                limit 1
                """,
                [.text(normalized)]
            )
        ]

        for (sql, arguments) in queries {
            guard let row = try database.first(sql: sql, arguments: arguments) else {
                continue
            }
            if navDouble(row["lat"]) != nil,
               navDouble(row["lon"]) != nil {
                return row
            }
        }
        return nil
    }

    private struct AirwayExpansion {
        let entry: String
        let exit: String
        let points: [[String: Any]]
    }

    private func airwayExists(_ airway: String, database: SQLiteDatabase) throws -> Bool {
        let row = try database.first(
            sql: "select 1 as exists_flag from tbl_enroute_airways where route_identifier = ? limit 1",
            arguments: [.text(airway.uppercased())]
        )
        return row != nil
    }

    private func expandAirway(
        _ airway: String,
        entry: String,
        exit: String,
        database: SQLiteDatabase
    ) throws -> AirwayExpansion? {
        let rows = try database.rows(
            sql: """
            select route_identifier, seqno, waypoint_identifier, waypoint_latitude, waypoint_longitude,
                   waypoint_description_code, route_type, area_code, icao_code,
                   minimum_altitude1, maximum_altitude, outbound_course, inbound_distance
            from tbl_enroute_airways
            where route_identifier = ?
            order by seqno
            """,
            arguments: [.text(airway.uppercased())]
        )
        guard !rows.isEmpty else {
            return nil
        }
        for chunk in partitionAirwayRows(rows) {
            let points = chunk.compactMap { row -> [String: Any]? in
                guard navDouble(row["waypoint_latitude"]) != nil,
                      navDouble(row["waypoint_longitude"]) != nil else {
                    return nil
                }
                return airwayPoint(from: row)
            }
            let names = points.map {
                navString($0["ident"]).uppercased()
            }
            guard let start = names.firstIndex(of: entry.uppercased()),
                  let end = names.firstIndex(of: exit.uppercased()),
                  start != end else {
                continue
            }
            let segment = start < end
                ? Array(points[start...end])
                : Array(points[end...start].reversed())
            if !segment.isEmpty {
                return AirwayExpansion(entry: entry.uppercased(), exit: exit.uppercased(), points: segment)
            }
        }
        return nil
    }

    private func airwayPoint(from row: [String: Any]) -> [String: Any] {
        [
            "ident": navString(row["waypoint_identifier"]),
            "name": navString(row["waypoint_identifier"]),
            "kind": "airway-fix",
            "lat": navDouble(row["waypoint_latitude"]) ?? 0,
            "lon": navDouble(row["waypoint_longitude"]) ?? 0,
            "area_code": navString(row["area_code"]),
            "route": navString(row["route_identifier"]),
            "seqno": navInt(row["seqno"]) ?? 0
        ]
    }

    private func appendRoutePoint(
        _ point: [String: Any],
        to points: inout [[String: Any]],
        legs: inout [[String: Any]],
        preferredType: String?
    ) {
        guard let previous = points.last else {
            points.append(point)
            return
        }
        if navString(previous["ident"]) == navString(point["ident"]) {
            points[points.count - 1] = point
            return
        }
        if let preferredType {
            if preferredType == "fix" {
                legs.append(["type": "fix", "name": navString(point["ident"])])
            } else {
                legs.append([
                    "type": preferredType,
                    "entry": navString(previous["ident"]),
                    "exit": navString(point["ident"]),
                    "distance_nm": greatCircleNM(
                        lat1: navDouble(previous["lat"]) ?? 0,
                        lon1: navDouble(previous["lon"]) ?? 0,
                        lat2: navDouble(point["lat"]) ?? 0,
                        lon2: navDouble(point["lon"]) ?? 0
                    )
                ])
            }
        }
        points.append(point)
    }

    private func dedupeRoutePoints(_ points: [[String: Any]]) -> [[String: Any]] {
        var output: [[String: Any]] = []
        for point in points {
            guard output.last.map({
                navString($0["ident"]) == navString(point["ident"])
                && navDouble($0["lat"]) == navDouble(point["lat"])
                && navDouble($0["lon"]) == navDouble(point["lon"])
            }) != true else {
                continue
            }
            output.append(point)
        }
        return output
    }

    private func routeDisplayFromLegs(_ legs: [[String: Any]], fallback: String) -> String {
        let fallbackText = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard fallbackText.isEmpty else {
            return fallbackText
        }
        var tokens: [String] = []
        for leg in legs {
            let type = navString(leg["type"])
            guard type == "airway" || type == "direct" else {
                continue
            }
            if tokens.isEmpty {
                tokens.append(navString(leg["entry"]))
            }
            if type == "airway" {
                tokens.append(navString(leg["name"]))
                tokens.append(navString(leg["exit"]))
            } else {
                tokens.append("DCT")
                tokens.append(navString(leg["exit"]))
            }
        }
        let display = tokens.filter { !$0.isEmpty }.joined(separator: " ")
        return display.isEmpty ? "DIRECT" : display
    }

    private func routeDisplayFromExpandedLegs(_ legs: [[String: Any]]) -> String {
        var tokens: [String] = []
        for leg in legs {
            let type = navString(leg["type"])
            if type == "airway" {
                if tokens.isEmpty {
                    tokens.append(navString(leg["entry"]))
                }
                tokens.append(navString(leg["name"]))
                tokens.append(navString(leg["exit"]))
            } else if type == "direct" {
                if tokens.isEmpty {
                    tokens.append(navString(leg["entry"]))
                }
                tokens.append("DCT")
                tokens.append(navString(leg["exit"]))
            } else if type == "fix" {
                tokens.append(navString(leg["name"]))
            }
        }
        let display = tokens.filter { !$0.isEmpty }.joined(separator: " ")
        return display.isEmpty ? "DIRECT" : display
    }

    private func buildBasicSegments(_ points: [[String: Any]]) -> [String: Any] {
        guard !points.isEmpty else {
            return ["departure": [], "enroute": [], "arrival": []]
        }
        if points.count == 1 {
            return ["departure": points, "enroute": [], "arrival": []]
        }
        return [
            "departure": [points[0], points[1]],
            "enroute": Array(points.dropFirst().dropLast()),
            "arrival": [points[points.count - 2], points[points.count - 1]]
        ]
    }

    private func pathLengthNM(_ points: [[String: Any]]) -> Double {
        guard points.count >= 2 else { return 0 }
        return (1..<points.count).reduce(0) { total, index in
            total + greatCircleNM(
                lat1: navDouble(points[index - 1]["lat"]) ?? 0,
                lon1: navDouble(points[index - 1]["lon"]) ?? 0,
                lat2: navDouble(points[index]["lat"]) ?? 0,
                lon2: navDouble(points[index]["lon"]) ?? 0
            )
        }
    }

    private func routeDistanceNM(_ start: [String: Any], _ end: [String: Any]) -> Double {
        greatCircleNM(
            lat1: navDouble(start["lat"]) ?? 0,
            lon1: navDouble(start["lon"]) ?? 0,
            lat2: navDouble(end["lat"]) ?? 0,
            lon2: navDouble(end["lon"]) ?? 0
        )
    }

    func searchAsync(query: String) async -> [SearchResult] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: self.search(query: query))
            }
        }
    }

    func airportPayloadAsync(ident: String) async -> [String: Any]? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: self.airportPayload(ident: ident))
            }
        }
    }

    private func emptyOverlayPayload() -> [String: Any] {
        ["airports": [], "airways": [], "waypoints": [], "navaids": [], "runways": [], "ils": []]
    }

    private func navOverlayData(database: SQLiteDatabase) throws -> [String: [[String: Any]]] {
        let databaseKey = currentDatabaseCacheKey()
        planningCacheLock.lock()
        if navOverlayCacheDatabaseKey == databaseKey, let navOverlayCache {
            planningCacheLock.unlock()
            return navOverlayCache
        }
        planningCacheLock.unlock()

        let airports = try database.rows(
            sql: """
            select airport_identifier as ident,
                   area_code,
                   coalesce(iata_ata_designator, '') as iata,
                   coalesce(airport_name, airport_identifier) as name,
                   airport_ref_latitude as lat,
                   airport_ref_longitude as lon,
                   'airport' as kind
            from tbl_airports
            where airport_ref_latitude is not null
              and airport_ref_longitude is not null
            order by airport_identifier
            """
        )

        let airwayRows = try database.rows(
            sql: """
            select route_identifier, seqno, waypoint_identifier, waypoint_latitude, waypoint_longitude,
                   coalesce(direction_restriction, '') as direction_restriction,
                   outbound_course, inbound_course,
                   coalesce(area_code, '') as area_code,
                   coalesce(icao_code, '') as icao_code,
                   coalesce(route_type, '') as route_type
            from tbl_enroute_airways
            where waypoint_latitude is not null and waypoint_longitude is not null
            order by route_identifier, cast(seqno as integer), area_code, icao_code, route_type
            """
        )
        var airways: [[String: Any]] = []
        var previous: [String: Any]?
        for row in airwayRows {
            defer { previous = row }
            guard let previous,
                  navString(previous["route_identifier"]) == navString(row["route_identifier"]) else {
                continue
            }
            let previousSeq = navInt(previous["seqno"]) ?? 0
            let currentSeq = navInt(row["seqno"]) ?? 0
            let seqGap = abs(currentSeq - previousSeq)
            guard currentSeq > previousSeq,
                  seqGap <= 5000,
                  let previousLat = navDouble(previous["waypoint_latitude"]),
                  let previousLon = navDouble(previous["waypoint_longitude"]),
                  let currentLat = navDouble(row["waypoint_latitude"]),
                  let currentLon = navDouble(row["waypoint_longitude"]) else {
                continue
            }

            let displayLon = wrapLongitude(currentLon, near: previousLon)
            let lonDelta = abs(displayLon - previousLon)
            if max(previousLat, currentLat) >= 60, lonDelta > 20 {
                continue
            }
            let distance = greatCircleNM(lat1: previousLat, lon1: previousLon, lat2: currentLat, lon2: currentLon)
            guard distance > 0, distance <= 800 else { continue }
            airways.append(segmentRecord(
                name: navString(row["route_identifier"]),
                entry: navString(previous["waypoint_identifier"]),
                exit: navString(row["waypoint_identifier"]),
                path: [[previousLat, previousLon], [currentLat, displayLon]],
                direction: navString(row["direction_restriction"]),
                course: navDouble(row["outbound_course"]) ?? navDouble(previous["outbound_course"]),
                areaCode: navString(row["area_code"])
            ))
        }

        var waypoints = try database.rows(
            sql: """
            select waypoint_identifier as ident,
                   area_code,
                   coalesce(waypoint_name, waypoint_identifier) as name,
                   coalesce(waypoint_type, '') as point_type,
                   coalesce(waypoint_usage, '') as usage,
                   waypoint_latitude as lat,
                   waypoint_longitude as lon,
                   'waypoint' as kind
            from tbl_enroute_waypoints
            where waypoint_latitude is not null and waypoint_longitude is not null
            order by waypoint_identifier
            """
        )

        var terminalWaypoints = try database.rows(
            sql: """
            select waypoint_identifier as ident,
                   coalesce(waypoint_name, waypoint_identifier) as name,
                   coalesce(waypoint_type, '') as point_type,
                   region_code,
                   region_code as area_code,
                   waypoint_latitude as lat,
                   waypoint_longitude as lon,
                   'terminal_waypoint' as kind,
                   '' as usage
            from tbl_terminal_waypoints
            where waypoint_latitude is not null and waypoint_longitude is not null
            order by waypoint_identifier
            """
        )

        var vors = try database.rows(
            sql: """
            select vor_identifier as ident,
                   area_code,
                   coalesce(vor_name, vor_identifier) as name,
                   coalesce(navaid_class, '') as point_type,
                   case when dme_latitude is not null and dme_longitude is not null then 1 else 0 end as has_dme,
                   vor_frequency as frequency,
                   vor_latitude as lat,
                   vor_longitude as lon,
                   'vor' as kind
            from tbl_vhfnavaids
            where vor_latitude is not null and vor_longitude is not null
            order by vor_identifier
            """
        )

        var ndbs = try database.rows(
            sql: """
            select ndb_identifier as ident,
                   area_code,
                   coalesce(ndb_name, ndb_identifier) as name,
                   coalesce(navaid_class, '') as point_type,
                   ndb_frequency as frequency,
                   ndb_latitude as lat,
                   ndb_longitude as lon,
                   'ndb' as kind
            from tbl_enroute_ndbnavaids
            where ndb_latitude is not null and ndb_longitude is not null
            order by ndb_identifier
            """
        )

        var terminalNDBs = try database.rows(
            sql: """
            select ndb_identifier as ident,
                   area_code,
                   coalesce(ndb_name, ndb_identifier) as name,
                   coalesce(navaid_class, '') as point_type,
                   ndb_frequency as frequency,
                   ndb_latitude as lat,
                   ndb_longitude as lon,
                   'ndb' as kind
            from tbl_terminal_ndbnavaids
            where ndb_latitude is not null and ndb_longitude is not null
            order by ndb_identifier
            """
        )

        let connectionIndex = navOverlayConnectionIndex(airways: airways)
        waypoints = waypoints.map { enrichNavOverlayPoint($0, connectionIndex: connectionIndex) }
        terminalWaypoints = terminalWaypoints.map { enrichNavOverlayPoint($0, connectionIndex: connectionIndex) }
        vors = vors.map { enrichNavOverlayPoint($0, connectionIndex: connectionIndex) }
        ndbs = ndbs.map { enrichNavOverlayPoint($0, connectionIndex: connectionIndex) }
        terminalNDBs = terminalNDBs.map { enrichNavOverlayPoint($0, connectionIndex: connectionIndex) }

        let runwayRows = try database.rows(
            sql: """
            select airport_identifier as airport,
                   runway_identifier as ident,
                   runway_latitude as lat,
                   runway_longitude as lon,
                   runway_true_bearing as bearing,
                   runway_length as length_ft
            from tbl_runways
            where runway_latitude is not null and runway_longitude is not null
              and runway_true_bearing is not null and runway_length is not null
            """
        )
        let runways = runwayRows.compactMap { row -> [String: Any]? in
            let lengthNM = max((navDouble(row["length_ft"]) ?? 0) / 6076.12, 0.05)
            return courseSegment(item: row, lengthNM: lengthNM, bidirectional: false)
        }

        let ilsRows = try database.rows(
            sql: """
            select l.airport_identifier as airport,
                   l.runway_identifier as runway,
                   l.llz_identifier as ident,
                   l.llz_latitude as llz_lat,
                   l.llz_longitude as llz_lon,
                   l.llz_bearing as bearing,
                   l.llz_frequency as frequency,
                   r.runway_latitude as lat,
                   r.runway_longitude as lon,
                   r.runway_true_bearing as runway_bearing
            from tbl_localizers_glideslopes l
            left join tbl_runways r
              on r.airport_identifier = l.airport_identifier
             and r.runway_identifier = l.runway_identifier
            where l.llz_latitude is not null
              and l.llz_longitude is not null
              and l.llz_bearing is not null
            """
        )
        let ils = ilsRows.compactMap { row -> [String: Any]? in
            var item = row
            if navDouble(item["lat"]) == nil || navDouble(item["lon"]) == nil {
                item["lat"] = item["llz_lat"]
                item["lon"] = item["llz_lon"]
                item["runway_bearing"] = item["bearing"]
            }
            item["bearing"] = (navDouble(item["runway_bearing"]) ?? navDouble(item["bearing"]) ?? 0) + 180.0
            return courseSegment(item: item, lengthNM: 8.0, bidirectional: false)
        }

        let output: [String: [[String: Any]]] = [
            "airports": airports,
            "airways": airways,
            "waypoints": waypoints,
            "terminal_waypoints": terminalWaypoints,
            "navaids": vors + ndbs,
            "terminal_navaids": terminalNDBs,
            "runways": runways,
            "ils": ils
        ]

        planningCacheLock.lock()
        navOverlayCacheDatabaseKey = databaseKey
        navOverlayCache = output
        planningCacheLock.unlock()
        return output
    }

    private typealias NavOverlayConnectionIndex = (
        connections: [String: Set<String>],
        details: [String: [[String: Any]]]
    )

    private func navOverlayConnectionIndex(airways: [[String: Any]]) -> NavOverlayConnectionIndex {
        var connections: [String: Set<String>] = [:]
        var details: [String: [[String: Any]]] = [:]
        for segment in airways {
            guard let path = segment["path"] as? [[Double]], path.count >= 2 else { continue }
            let endpoints = [
                (navString(segment["from"]), path[0]),
                (navString(segment["to"]), path[path.count - 1])
            ]
            for (ident, point) in endpoints {
                let airway = navString(segment["name"])
                let detail: [String: Any] = [
                    "name": airway,
                    "from": navString(segment["from"]),
                    "to": navString(segment["to"]),
                    "direction": navString(segment["direction"]),
                    "area_code": navString(segment["area_code"])
                ]
                let pointKey = navPointKey(ident: ident, lat: point[0], lon: point[1])
                connections[pointKey, default: []].insert(airway)
                connections[ident, default: []].insert(airway)
                details[pointKey, default: []].append(detail)
                details[ident, default: []].append(detail)
            }
        }
        return (connections, details)
    }

    private func enrichNavOverlayPoint(_ item: [String: Any], connectionIndex: NavOverlayConnectionIndex) -> [String: Any] {
        guard let lat = navDouble(item["lat"]),
              let lon = navDouble(item["lon"]) else {
            return item
        }
        let ident = navString(item["ident"])
        let pointKey = navPointKey(ident: ident, lat: lat, lon: lon)
        let pointConnections = connectionIndex.connections[pointKey] ?? connectionIndex.connections[ident] ?? []
        let routeDetails = connectionIndex.details[pointKey] ?? connectionIndex.details[ident] ?? []
        var uniqueRouteDetails: [[String: Any]] = []
        var seen = Set<String>()
        for detail in routeDetails {
            let key = [
                navString(detail["name"]),
                navString(detail["from"]),
                navString(detail["to"]),
                navString(detail["direction"])
            ].joined(separator: "|")
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            uniqueRouteDetails.append(detail)
        }
        var output = item
        output["region"] = navString(item["area_code"]).isEmpty ? navString(item["region_code"]) : navString(item["area_code"])
        output["connections"] = pointConnections.sorted()
        output["associated_routes"] = uniqueRouteDetails
        return output
    }

    private func resolveAirportIdentifier(_ ident: String, database: SQLiteDatabase) throws -> String? {
        let token = ident.uppercased()
        let row = try database.first(
            sql: """
            select airport_identifier
            from tbl_airports
            where airport_identifier = ? or iata_ata_designator = ?
            order by case when airport_identifier = ? then 0 else 1 end
            limit 1
            """,
            arguments: [.text(token), .text(token), .text(token)]
        )
        return row.map { navString($0["airport_identifier"]) }
    }

    private func procedureSummaries(table: String, airport: String, database: SQLiteDatabase) throws -> [[String: Any]] {
        let normalizedAirport = airport.uppercased()
        let summaries = try database.rows(
            sql: """
            select procedure_identifier,
                   case
                       when coalesce(transition_identifier, '') = '' then 'ALL'
                       else transition_identifier
                   end as transition_identifier,
                   min(seqno) as first_seq,
                   count(*) as legs
            from \(table)
            where airport_identifier = ?
            group by procedure_identifier,
                     case
                         when coalesce(transition_identifier, '') = '' then 'ALL'
                         else transition_identifier
                     end
            order by procedure_identifier, transition_identifier
            limit 200
            """,
            arguments: [.text(normalizedAirport)]
        )

        // Group the airport panel by operational endpoint instead of one long
        // alphabetic list: SID uses the final outbound fix, STAR the first
        // inbound fix, and APPROACH the runway waypoint in its final segment.
        let legRows = try database.rows(
            sql: """
            select procedure_identifier, transition_identifier, seqno, waypoint_identifier
            from \(table)
            where airport_identifier = ?
            order by procedure_identifier, transition_identifier, seqno
            """,
            arguments: [.text(normalizedAirport)]
        )

        var legsByProcedure: [String: [String: [[String: Any]]]] = [:]
        for row in legRows {
            let procedure = navString(row["procedure_identifier"]).uppercased()
            let transition = normalizedProcedureTransition(row["transition_identifier"])
            guard !procedure.isEmpty else { continue }
            legsByProcedure[procedure, default: [:]][transition, default: []].append(row)
        }

        func firstWaypoint(in rows: [[String: Any]]) -> String? {
            rows.lazy
                .map { navString($0["waypoint_identifier"]).uppercased() }
                .first(where: { !$0.isEmpty })
        }

        func lastWaypoint(in rows: [[String: Any]]) -> String? {
            rows.reversed().lazy
                .map { navString($0["waypoint_identifier"]).uppercased() }
                .first(where: { !$0.isEmpty })
        }

        return summaries.map { summary in
            var enriched = summary
            let procedure = navString(summary["procedure_identifier"]).uppercased()
            let transition = normalizedProcedureTransition(summary["transition_identifier"])
            let procedureLegs = legsByProcedure[procedure] ?? [:]
            let commonLegs = procedureLegs["ALL"] ?? []
            let transitionLegs = procedureLegs[transition] ?? []
            let allLegs = procedureLegs.keys.sorted().flatMap { procedureLegs[$0] ?? [] }

            let groupIdentifier: String
            switch table {
            case "tbl_sids":
                groupIdentifier = lastWaypoint(in: commonLegs)
                    ?? lastWaypoint(in: transitionLegs)
                    ?? procedure
            case "tbl_stars":
                groupIdentifier = firstWaypoint(in: commonLegs)
                    ?? firstWaypoint(in: transitionLegs)
                    ?? procedure
            case "tbl_iaps":
                let runwayWaypoints = allLegs.lazy
                    .map { navString($0["waypoint_identifier"]).uppercased() }
                    .filter { $0.hasPrefix("RW") }
                let inferredRunway = inferRunwayIdentifier(procedure: procedure, transition: transition)
                let matchingRunwayWaypoint = inferredRunway == "ALL"
                    ? nil
                    : runwayWaypoints.first(where: { normalizedRunwayChoice($0) == inferredRunway })
                let runwayWaypoint = matchingRunwayWaypoint ?? runwayWaypoints.first
                groupIdentifier = runwayWaypoint.map(normalizedRunwayChoice)
                    ?? (inferredRunway == "ALL" ? procedure : inferredRunway)
            default:
                groupIdentifier = procedure
            }
            enriched["group_identifier"] = groupIdentifier
            return enriched
        }
    }

    private func procedureTable(for type: String) -> String? {
        switch type.lowercased() {
        case "sid": "tbl_sids"
        case "star": "tbl_stars"
        case "approach": "tbl_iaps"
        default: nil
        }
    }

    private func procedureDetails(
        airport: String,
        table: String,
        procedure: String,
        transition: String,
        database: SQLiteDatabase
    ) throws -> [[String: Any]] {
        let requestedTransition = transition.isEmpty ? "ALL" : transition

        func fetchRows(values: [String]) throws -> [[String: Any]] {
            let placeholders = values.map { _ in "?" }.joined(separator: ", ")
            let arguments: [SQLiteArgument] = [.text(airport), .text(procedure)] + values.map { .text($0) }
            return try database.rows(
                sql: """
                select seqno, waypoint_identifier, waypoint_latitude, waypoint_longitude,
                       waypoint_description_code, turn_direction, rnp,
                       path_termination, route_type, magnetic_course, route_distance_holding_distance_time,
                       distance_time, altitude_description, altitude1, altitude2,
                       transition_altitude, speed_limit_description, speed_limit, vertical_angle,
                       arc_radius, theta, rho, center_waypoint,
                       center_waypoint_latitude, center_waypoint_longitude
                from \(table)
                where airport_identifier = ?
                  and procedure_identifier = ?
                  and upper(coalesce(transition_identifier, '')) in (\(placeholders))
                order by seqno
                """,
                arguments: arguments
            )
        }

        if !["", "ALL"].contains(requestedTransition) {
            let transitionRows = normalizeProcedureRows(try fetchRows(values: [requestedTransition]))
            let commonRows = normalizeProcedureRows(try fetchRows(values: ["", "ALL"]))
            if table == "tbl_stars" {
                return commonRows + transitionRows
            }
            if table == "tbl_sids" || table == "tbl_iaps" {
                return transitionRows + commonRows
            }
            return transitionRows
        }
        let transitionValues = ["", "ALL"].contains(requestedTransition) ? ["", "ALL"] : [requestedTransition]
        return normalizeProcedureRows(try fetchRows(values: transitionValues))
    }

    private func normalizeProcedureRows(_ rows: [[String: Any]]) -> [[String: Any]] {
        var grouped: [ProcedureGroupKey: [[String: Any]]] = [:]
        var seen = Set<String>()

        for row in rows {
            let seqno = navInt(row["seqno"]) ?? 0
            let key = procedureExactKey(row)
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let path = navString(row["path_termination"]).uppercased()
            let centerWaypoint = navString(row["center_waypoint"]).uppercased()
            if ["RF", "AF"].contains(path),
               navDouble(row["arc_radius"]) == nil,
               centerWaypoint.hasPrefix("LSC") {
                continue
            }

            let groupKey = ProcedureGroupKey(
                routeType: navString(row["route_type"]),
                seqno: seqno
            )
            grouped[groupKey, default: []].append(row)
        }

        var usedWaypoints = Set<String>()
        var normalized: [[String: Any]] = []
        for groupKey in grouped.keys.sorted() {
            guard let chosen = grouped[groupKey]?.max(by: {
                procedureScore($0, usedWaypoints: usedWaypoints) < procedureScore($1, usedWaypoints: usedWaypoints)
            }) else {
                continue
            }
            normalized.append(chosen)
            let waypoint = navString(chosen["waypoint_identifier"]).uppercased()
            if !waypoint.isEmpty {
                usedWaypoints.insert(waypoint)
            }
        }
        return normalized
    }

    private func procedureExactKey(_ row: [String: Any]) -> String {
        func coordinateKey(_ value: Any?) -> String {
            guard let number = navDouble(value) else { return "<nil>" }
            return String(format: "%.6f", number)
        }

        return [
            navString(row["seqno"]),
            navString(row["waypoint_identifier"]),
            navString(row["path_termination"]),
            coordinateKey(row["waypoint_latitude"]),
            coordinateKey(row["waypoint_longitude"]),
            navString(row["center_waypoint"]),
            navDouble(row["arc_radius"]).map { String($0) } ?? "<nil>"
        ].joined(separator: "|")
    }

    private func procedureScore(_ row: [String: Any], usedWaypoints: Set<String>) -> ProcedureRowScore {
        let path = navString(row["path_termination"]).uppercased()
        let waypoint = navString(row["waypoint_identifier"]).uppercased()
        let centerWaypoint = navString(row["center_waypoint"]).uppercased()
        return ProcedureRowScore(
            hasArcRadius: navDouble(row["arc_radius"]) == nil ? 0 : 1,
            usesFreshWaypoint: !waypoint.isEmpty && usedWaypoints.contains(waypoint) ? 0 : 1,
            hasRealWaypoint: !waypoint.isEmpty && !waypoint.hasPrefix("LSC") ? 1 : 0,
            hasDrawablePath: ["RF", "AF", "TF", "IF", "CF", "DF"].contains(path) ? 1 : 0,
            hasRealCenter: !centerWaypoint.isEmpty && !centerWaypoint.hasPrefix("LSC") ? 1 : 0,
            waypoint: waypoint
        )
    }

    private func buildProcedureGeometry(items: [[String: Any]]) -> [String: Any] {
        var path: [[String: Double]] = []
        var primaryPath: [[String: Double]] = []
        var missedPath: [[String: Double]] = []
        var missedActive = false

        for (index, item) in items.enumerated() {
            guard let point = procedureItemPoint(item) else {
                continue
            }

            if path.isEmpty {
                path.append(point)
                primaryPath.append(point)
                if isRunwayWaypoint(item) {
                    missedActive = true
                    missedPath.append(point)
                }
                continue
            }

            guard let previousIndex = previousCoordinateIndex(before: index, in: items) else {
                path.append(point)
                if missedActive {
                    missedPath.append(point)
                } else {
                    primaryPath.append(point)
                }
                continue
            }

            let previousItem = items[previousIndex]
            let beforePreviousItem = previousCoordinateIndex(before: previousIndex, in: items).map { items[$0] }
            let nextItem = nextCoordinateIndex(after: index, in: items).map { items[$0] }
            let legPoints = procedureLegGeometry(
                previousItem: previousItem,
                currentItem: item,
                beforePreviousItem: beforePreviousItem,
                nextItem: nextItem
            )
            let segment = legPoints.isEmpty ? [point] : Array(legPoints.dropFirst())
            path.append(contentsOf: segment)
            if missedActive {
                missedPath.append(contentsOf: segment)
            } else {
                primaryPath.append(contentsOf: segment)
            }

            let hasLaterCoordinate = nextCoordinateIndex(after: index, in: items) != nil
            if missedActive, isHoldingLeg(item), !hasLaterCoordinate {
                let holdingPoints = procedureHoldingPatternPoints(currentItem: item, previousItem: previousItem)
                if holdingPoints.count > 1 {
                    var holdingSegment = holdingPoints
                    if let last = missedPath.last,
                       let first = holdingPoints.first,
                       greatCircleNM(
                           lat1: last["lat"] ?? 0,
                           lon1: last["lon"] ?? 0,
                           lat2: first["lat"] ?? 0,
                           lon2: first["lon"] ?? 0
                       ) <= 0.03 {
                        holdingSegment = Array(holdingPoints.dropFirst())
                    }
                    path.append(contentsOf: holdingSegment)
                    missedPath.append(contentsOf: holdingSegment)
                }
            }

            if isRunwayWaypoint(item) {
                missedActive = true
                if let lastPrimaryPoint = primaryPath.last {
                    missedPath.append(lastPrimaryPoint)
                }
            }
        }

        return [
            "items": items,
            "path": path,
            "primary_path": primaryPath,
            "missed_path": missedPath
        ]
    }

    private func previousCoordinateIndex(before index: Int, in items: [[String: Any]]) -> Int? {
        guard index > 0 else { return nil }
        for cursor in stride(from: index - 1, through: 0, by: -1) {
            if procedureItemPoint(items[cursor]) != nil {
                return cursor
            }
        }
        return nil
    }

    private func nextCoordinateIndex(after index: Int, in items: [[String: Any]]) -> Int? {
        guard index + 1 < items.count else { return nil }
        for cursor in (index + 1)..<items.count {
            if procedureItemPoint(items[cursor]) != nil {
                return cursor
            }
        }
        return nil
    }

    private func procedureLegGeometry(
        previousItem: [String: Any],
        currentItem: [String: Any],
        beforePreviousItem: [String: Any]?,
        nextItem: [String: Any]?
    ) -> [[String: Double]] {
        guard let start = procedureItemPoint(previousItem),
              let end = procedureItemPoint(currentItem) else {
            return []
        }
        let pathTermination = navString(currentItem["path_termination"]).uppercased()
        if ["RF", "AF"].contains(pathTermination),
           let centerLat = navDouble(currentItem["center_waypoint_latitude"]),
           let centerLon = navDouble(currentItem["center_waypoint_longitude"]) {
            return procedureArcPoints(
                start: start,
                end: end,
                centerLat: centerLat,
                centerLon: centerLon,
                beforePreviousItem: beforePreviousItem,
                currentItem: currentItem,
                nextItem: nextItem
            )
        }
        return [start, end]
    }

    private func procedureHoldingPatternPoints(
        currentItem: [String: Any],
        previousItem: [String: Any]?,
        samplesPerTurn: Int = 20
    ) -> [[String: Double]] {
        guard let fix = procedureItemPoint(currentItem) else { return [] }

        var inboundCourse = navDouble(currentItem["magnetic_course"])
        if inboundCourse == nil, let previousPoint = procedureItemPoint(previousItem) {
            inboundCourse = bearingDegrees(start: previousPoint, end: fix)
        }
        guard let inboundCourseValue = inboundCourse else { return [] }

        var legValue = navDouble(currentItem["route_distance_holding_distance_time"])
        let distanceTime = navString(currentItem["distance_time"]).uppercased()
        if legValue == nil || (legValue ?? 0) <= 0 {
            legValue = distanceTime == "T" ? 1.0 : 4.0
        }
        let rawLegLength = distanceTime == "T" ? (legValue ?? 1.0) * 4.0 : (legValue ?? 4.0)
        let legLengthNM = max(1.5, min(18.0, rawLegLength))
        let turnRadiusNM = max(0.8, min(3.2, legLengthNM * 0.24))

        let bearing = inboundCourseValue * .pi / 180
        let inbound = (sin(bearing), cos(bearing))
        let outbound = (-inbound.0, -inbound.1)
        let rightOfInbound = (inbound.1, -inbound.0)
        let turnRight = navString(currentItem["turn_direction"]).uppercased() != "L"
        let side = turnRight ? rightOfInbound : (-rightOfInbound.0, -rightOfInbound.1)

        let fixXY = (0.0, 0.0)
        let firstCenter = (side.0 * turnRadiusNM, side.1 * turnRadiusNM)
        let outboundStart = (side.0 * turnRadiusNM * 2.0, side.1 * turnRadiusNM * 2.0)
        let outboundEnd = (
            outboundStart.0 + outbound.0 * legLengthNM,
            outboundStart.1 + outbound.1 * legLengthNM
        )
        let secondCenter = (
            outboundEnd.0 - side.0 * turnRadiusNM,
            outboundEnd.1 - side.1 * turnRadiusNM
        )
        let inboundStart = (
            outboundEnd.0 - side.0 * turnRadiusNM * 2.0,
            outboundEnd.1 - side.1 * turnRadiusNM * 2.0
        )

        let firstTurn = localArcPoints(
            center: firstCenter,
            start: fixXY,
            end: outboundStart,
            clockwise: turnRight,
            samples: samplesPerTurn
        )
        let secondTurn = localArcPoints(
            center: secondCenter,
            start: outboundEnd,
            end: inboundStart,
            clockwise: turnRight,
            samples: samplesPerTurn
        )
        let localPoints = firstTurn + [outboundEnd] + Array(secondTurn.dropFirst()) + [fixXY]
        return localPoints.map { localPoint in
            let coordinate = unprojectLocalNM(
                x: localPoint.0,
                y: localPoint.1,
                centerLat: fix["lat"] ?? 0,
                centerLon: fix["lon"] ?? 0
            )
            return ["lat": coordinate.lat, "lon": coordinate.lon]
        }
    }

    private func localArcPoints(
        center: (Double, Double),
        start: (Double, Double),
        end: (Double, Double),
        clockwise: Bool,
        samples: Int
    ) -> [(Double, Double)] {
        let startAngle = normalizeAngle(atan2Degrees(y: start.1 - center.1, x: start.0 - center.0))
        let endAngle = normalizeAngle(atan2Degrees(y: end.1 - center.1, x: end.0 - center.0))
        let clockwiseDelta = positiveRemainder(startAngle - endAngle, dividingBy: 360)
        let counterDelta = positiveRemainder(endAngle - startAngle, dividingBy: 360)
        let delta = clockwise ? -clockwiseDelta : counterDelta
        let sampleCount = max(8, samples)
        let radius = hypot(start.0 - center.0, start.1 - center.1)
        var points: [(Double, Double)] = []
        for step in 0...sampleCount {
            let fraction = Double(step) / Double(sampleCount)
            let angle = (startAngle + delta * fraction) * .pi / 180
            points.append((center.0 + radius * cos(angle), center.1 + radius * sin(angle)))
        }
        if !points.isEmpty {
            points[0] = start
            points[points.count - 1] = end
        }
        return points
    }

    private func procedureArcPoints(
        start: [String: Double],
        end: [String: Double],
        centerLat: Double,
        centerLon: Double,
        beforePreviousItem: [String: Any]?,
        currentItem: [String: Any]?,
        nextItem: [String: Any]?,
        samples: Int = 24
    ) -> [[String: Double]] {
        let startXY = projectLocalNM(lat: start["lat"] ?? 0, lon: start["lon"] ?? 0, centerLat: centerLat, centerLon: centerLon)
        let endXY = projectLocalNM(lat: end["lat"] ?? 0, lon: end["lon"] ?? 0, centerLat: centerLat, centerLon: centerLon)
        let radius1 = hypot(startXY.x, startXY.y)
        let radius2 = hypot(endXY.x, endXY.y)
        guard radius1 > 0, radius2 > 0 else {
            return [start, end]
        }

        let startAngle = normalizeAngle(atan2Degrees(y: startXY.y, x: startXY.x))
        let endAngle = normalizeAngle(atan2Degrees(y: endXY.y, x: endXY.x))
        let clockwiseDelta = positiveRemainder(startAngle - endAngle, dividingBy: 360)
        let counterDelta = positiveRemainder(endAngle - startAngle, dividingBy: 360)
        let clockwise = chooseArcClockwise(
            startAngle: startAngle,
            endAngle: endAngle,
            beforePreviousItem: beforePreviousItem,
            start: start,
            currentItem: currentItem,
            end: end,
            nextItem: nextItem
        )
        let delta = clockwise ? -clockwiseDelta : counterDelta
        let sampleCount = max(samples, min(72, Int(abs(delta) / 5) + 1))

        var points: [[String: Double]] = []
        for step in 0...sampleCount {
            let fraction = Double(step) / Double(sampleCount)
            let angle = (startAngle + delta * fraction) * .pi / 180
            let radius = radius1 + (radius2 - radius1) * fraction
            let coordinate = unprojectLocalNM(
                x: radius * cos(angle),
                y: radius * sin(angle),
                centerLat: centerLat,
                centerLon: centerLon
            )
            points.append(["lat": coordinate.lat, "lon": coordinate.lon])
        }
        if !points.isEmpty {
            points[0] = start
            points[points.count - 1] = end
        }
        return points
    }

    private func chooseArcClockwise(
        startAngle: Double,
        endAngle: Double,
        beforePreviousItem: [String: Any]?,
        start: [String: Double],
        currentItem: [String: Any]?,
        end: [String: Double],
        nextItem: [String: Any]?
    ) -> Bool {
        let clockwiseDelta = positiveRemainder(startAngle - endAngle, dividingBy: 360)
        let counterDelta = positiveRemainder(endAngle - startAngle, dividingBy: 360)
        let shortestClockwise = clockwiseDelta <= counterDelta
        let clockwiseScore = arcDirectionScore(
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true,
            beforePreviousItem: beforePreviousItem,
            start: start,
            currentItem: currentItem,
            end: end,
            nextItem: nextItem,
            sweepDegrees: clockwiseDelta
        )
        let counterScore = arcDirectionScore(
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false,
            beforePreviousItem: beforePreviousItem,
            start: start,
            currentItem: currentItem,
            end: end,
            nextItem: nextItem,
            sweepDegrees: counterDelta
        )
        if abs(clockwiseScore - counterScore) < 1e-6 {
            return shortestClockwise
        }
        return clockwiseScore < counterScore
    }

    private func arcDirectionScore(
        startAngle: Double,
        endAngle: Double,
        clockwise: Bool,
        beforePreviousItem: [String: Any]?,
        start: [String: Double],
        currentItem: [String: Any]?,
        end: [String: Double],
        nextItem: [String: Any]?,
        sweepDegrees: Double
    ) -> Double {
        var score = sweepDegrees * 0.02
        let startTangent = arcTangentBearing(angleDegrees: startAngle, clockwise: clockwise)
        let endTangent = arcTangentBearing(angleDegrees: endAngle, clockwise: clockwise)

        if let previousPoint = procedureItemPoint(beforePreviousItem),
           greatCircleNM(
               lat1: previousPoint["lat"] ?? 0,
               lon1: previousPoint["lon"] ?? 0,
               lat2: start["lat"] ?? 0,
               lon2: start["lon"] ?? 0
           ) > 0.03 {
            score += courseDelta(bearingDegrees(start: previousPoint, end: start), startTangent)
        }

        if let magneticCourse = currentItem.flatMap({ navDouble($0["magnetic_course"]) }) {
            score += courseDelta(magneticCourse, endTangent) * 0.65
        }

        if let followingPoint = procedureItemPoint(nextItem),
           greatCircleNM(
               lat1: end["lat"] ?? 0,
               lon1: end["lon"] ?? 0,
               lat2: followingPoint["lat"] ?? 0,
               lon2: followingPoint["lon"] ?? 0
           ) > 0.03 {
            score += courseDelta(endTangent, bearingDegrees(start: end, end: followingPoint))
        }
        return score
    }

    private func procedureItemPoint(_ item: [String: Any]?) -> [String: Double]? {
        guard let item,
              let lat = navDouble(item["waypoint_latitude"]),
              let lon = navDouble(item["waypoint_longitude"]) else {
            return nil
        }
        return ["lat": lat, "lon": lon]
    }

    private func isRunwayWaypoint(_ item: [String: Any]) -> Bool {
        navString(item["waypoint_identifier"]).uppercased().hasPrefix("RW")
    }

    private func isHoldingLeg(_ item: [String: Any]) -> Bool {
        ["HA", "HF", "HM"].contains(navString(item["path_termination"]).uppercased())
    }

    private func arcTangentBearing(angleDegrees: Double, clockwise: Bool) -> Double {
        let radialBearing = positiveRemainder(90.0 - angleDegrees, dividingBy: 360)
        return positiveRemainder(clockwise ? radialBearing + 90.0 : radialBearing - 90.0, dividingBy: 360)
    }

    private func courseDelta(_ first: Double, _ second: Double) -> Double {
        abs(positiveRemainder(first - second + 180.0, dividingBy: 360) - 180.0)
    }

    private func bearingDegrees(start: [String: Double], end: [String: Double]) -> Double {
        let lat1 = (start["lat"] ?? 0) * .pi / 180
        let lat2 = (end["lat"] ?? 0) * .pi / 180
        let lon1 = (start["lon"] ?? 0) * .pi / 180
        let lon2 = (end["lon"] ?? 0) * .pi / 180
        let dLon = lon2 - lon1
        let x = sin(dLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return positiveRemainder(atan2(x, y) * 180 / .pi + 360, dividingBy: 360)
    }

    private func projectLocalNM(lat: Double, lon: Double, centerLat: Double, centerLon: Double) -> (x: Double, y: Double) {
        let adjustedLon = wrapLongitude(lon, near: centerLon)
        let meanLat = (lat + centerLat) / 2 * .pi / 180
        return (
            x: (adjustedLon - centerLon) * 60.0 * cos(meanLat),
            y: (lat - centerLat) * 60.0
        )
    }

    private func unprojectLocalNM(x: Double, y: Double, centerLat: Double, centerLon: Double) -> (lat: Double, lon: Double) {
        let lat = centerLat + y / 60.0
        let meanLat = (lat + centerLat) / 2 * .pi / 180
        let cosMeanLat = cos(meanLat)
        let cosLat = abs(cosMeanLat) > 1e-6 ? cosMeanLat : 1e-6
        let lon = centerLon + x / (60.0 * cosLat)
        return (lat: lat, lon: lon)
    }

    private func atan2Degrees(y: Double, x: Double) -> Double {
        atan2(y, x) * 180 / .pi
    }

    private func normalizeAngle(_ value: Double) -> Double {
        positiveRemainder(value, dividingBy: 360)
    }

    private func positiveRemainder(_ value: Double, dividingBy divisor: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: divisor)
        return remainder >= 0 ? remainder : remainder + divisor
    }

    private func worldCopyOffsetsForBounds(west: Double, east: Double) -> [Double] {
        let firstCopy = Int(floor((west - 180.0) / 360.0)) - 1
        let lastCopy = Int(floor((east + 180.0) / 360.0)) + 1
        guard firstCopy <= lastCopy else { return [0] }
        return (firstCopy...lastCopy).map { Double($0) * 360.0 }
    }

    private func longitudeForBounds(_ lon: Double, west: Double, east: Double, worldOffsets: [Double]) -> Double {
        worldOffsets
            .map { lon + $0 }
            .min { lhs, rhs in
                func score(_ candidate: Double) -> Double {
                    if west <= candidate, candidate <= east {
                        return 0
                    }
                    return min(abs(candidate - west), abs(candidate - east))
                }
                return score(lhs) < score(rhs)
            } ?? lon
    }

    private func normalizeLongitude(_ lon: Double) -> Double {
        positiveRemainder(lon + 540.0, dividingBy: 360.0) - 180.0
    }

    private func pointInBounds(
        _ item: [String: Any],
        south: Double,
        west: Double,
        north: Double,
        east: Double,
        worldOffsets: [Double]
    ) -> Bool {
        guard let lat = navDouble(item["lat"]),
              let lon = navDouble(item["lon"]),
              south <= lat,
              lat <= north else {
            return false
        }
        return worldOffsets.contains { west <= lon + $0 && lon + $0 <= east }
    }

    private func navPointKey(ident: String, lat: Double, lon: Double) -> String {
        "\(ident):\(String(format: "%.4f", lat)):\(String(format: "%.4f", normalizeLongitude(lon)))"
    }

    private func segmentIntersectsBounds(
        _ item: [String: Any],
        south: Double,
        west: Double,
        north: Double,
        east: Double,
        worldOffsets: [Double]
    ) -> Bool {
        guard let minLat = navDouble(item["min_lat"]),
              let maxLat = navDouble(item["max_lat"]),
              let minLon = navDouble(item["min_lon"]),
              let maxLon = navDouble(item["max_lon"]) else {
            return false
        }
        if maxLat < south || minLat > north {
            return false
        }
        return worldOffsets.contains { maxLon + $0 >= west && minLon + $0 <= east }
    }

    private func segmentCenter(_ item: [String: Any]) -> (lat: Double, lon: Double) {
        guard let path = item["path"] as? [[Double]],
              let first = path.first,
              let last = path.last,
              first.count >= 2,
              last.count >= 2 else {
            return (0, 0)
        }
        return ((first[0] + last[0]) / 2, (first[1] + last[1]) / 2)
    }

    private func spatiallyDistributeSegments(
        _ segments: [[String: Any]],
        maxCount: Int,
        south: Double,
        west: Double,
        north: Double,
        east: Double,
        worldOffsets: [Double]
    ) -> [[String: Any]] {
        guard segments.count > maxCount else { return segments }
        let rows = 6
        let columns = 8
        let latSpan = max(north - south, 0.001)
        let lonSpan = max(east - west, 0.001)
        var buckets: [String: [[String: Any]]] = [:]

        for segment in segments {
            let center = segmentCenter(segment)
            let lon = longitudeForBounds(center.lon, west: west, east: east, worldOffsets: worldOffsets)
            let row = min(rows - 1, max(0, Int((center.lat - south) / latSpan * Double(rows))))
            let column = min(columns - 1, max(0, Int((lon - west) / lonSpan * Double(columns))))
            buckets["\(row):\(column)", default: []].append(segment)
        }

        var selected: [[String: Any]] = []
        var bucketKeys = buckets.keys.sorted()
        var cursor = 0
        while selected.count < maxCount, !bucketKeys.isEmpty {
            let key = bucketKeys[cursor % bucketKeys.count]
            if var bucket = buckets[key], !bucket.isEmpty {
                selected.append(bucket.removeFirst())
                buckets[key] = bucket
            }
            if buckets[key]?.isEmpty != false {
                bucketKeys.removeAll { $0 == key }
                if bucketKeys.isEmpty {
                    break
                }
                cursor %= bucketKeys.count
            } else {
                cursor += 1
            }
        }
        return selected
    }

    private func segmentLabelPoint(_ item: [String: Any]) -> [Double] {
        let center = segmentCenter(item)
        return [center.lat, center.lon]
    }

    private func segmentRecord(
        name: String,
        entry: String,
        exit: String,
        path: [[Double]],
        direction: String,
        course: Double?,
        areaCode: String
    ) -> [String: Any] {
        [
            "name": name,
            "from": entry,
            "to": exit,
            "path": path,
            "direction": direction,
            "course": course ?? NSNull(),
            "area_code": areaCode,
            "label": false,
            "min_lat": min(path[0][0], path[1][0]),
            "max_lat": max(path[0][0], path[1][0]),
            "min_lon": min(path[0][1], path[1][1]),
            "max_lon": max(path[0][1], path[1][1])
        ]
    }

    private func courseSegment(item: [String: Any], lengthNM: Double, bidirectional: Bool) -> [String: Any]? {
        guard let lat = navDouble(item["lat"]),
              let lon = navDouble(item["lon"]),
              let bearing = navDouble(item["bearing"]) else {
            return nil
        }
        let start = bidirectional ? destinationPoint(lat: lat, lon: lon, bearing: bearing + 180, distanceNM: lengthNM) : (lat, lon)
        let end = destinationPoint(lat: lat, lon: lon, bearing: bearing, distanceNM: lengthNM)
        let path = [[start.0, wrapLongitude(start.1, near: lon)], [end.0, wrapLongitude(end.1, near: start.1)]]
        var output = item
        output["path"] = path
        output["min_lat"] = min(path[0][0], path[1][0])
        output["max_lat"] = max(path[0][0], path[1][0])
        output["min_lon"] = min(path[0][1], path[1][1])
        output["max_lon"] = max(path[0][1], path[1][1])
        return output
    }

    private func wrapLongitude(_ lon: Double, near referenceLon: Double) -> Double {
        var adjusted = lon
        while adjusted - referenceLon > 180 { adjusted -= 360 }
        while adjusted - referenceLon < -180 { adjusted += 360 }
        return adjusted
    }

    private func greatCircleNM(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let radiusNM = 3440.065
        let phi1 = lat1 * .pi / 180
        let phi2 = lat2 * .pi / 180
        let dPhi = (lat2 - lat1) * .pi / 180
        let dLambda = (lon2 - lon1) * .pi / 180
        let a = sin(dPhi / 2) * sin(dPhi / 2) + cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2)
        return radiusNM * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }

    private func destinationPoint(lat: Double, lon: Double, bearing: Double, distanceNM: Double) -> (Double, Double) {
        let radiusNM = 3440.065
        let angularDistance = distanceNM / radiusNM
        let bearingRad = bearing * .pi / 180
        let latRad = lat * .pi / 180
        let lonRad = lon * .pi / 180
        let destLat = asin(sin(latRad) * cos(angularDistance) + cos(latRad) * sin(angularDistance) * cos(bearingRad))
        let destLon = lonRad + atan2(
            sin(bearingRad) * sin(angularDistance) * cos(latRad),
            cos(angularDistance) - sin(latRad) * sin(destLat)
        )
        return (destLat * 180 / .pi, ((destLon * 180 / .pi + 540).truncatingRemainder(dividingBy: 360)) - 180)
    }
}
