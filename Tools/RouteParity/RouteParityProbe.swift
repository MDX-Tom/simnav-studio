import Foundation

struct RouteParityCase: Decodable {
    let name: String
    let departure: String
    let arrival: String
    let route: String
    let departureRunway: String?
    let arrivalRunway: String?
}

func routeParityString(_ value: Any?) -> String {
    guard let value, !(value is NSNull) else { return "" }
    return String(describing: value)
}

func routeParitySelectedSummary(_ payload: [String: Any]) -> [String: Any] {
    let selected = payload["selected_procedures"] as? [String: Any] ?? [:]
    var output: [String: Any] = [:]
    for key in ["sid", "star", "approach"] {
        let item = selected[key] as? [String: Any] ?? [:]
        output[key] = [
            "procedure": routeParityString(item["procedure"] ?? item["procedure_identifier"]),
            "transition": routeParityString(item["transition"] ?? item["transition_identifier"]),
            "runway": routeParityString(item["runway"])
        ]
    }
    return output
}

func routeParityLegSummary(_ leg: [String: Any]) -> [String: Any] {
    [
        "type": routeParityString(leg["type"]),
        "name": routeParityString(leg["name"]),
        "entry": routeParityString(leg["entry"]),
        "exit": routeParityString(leg["exit"]),
        "transition": routeParityString(leg["transition"]),
        "count": leg["count"] as? Int ?? 0
    ]
}

func routeParityDouble(_ value: Any?) -> Double? {
    guard let value, !(value is NSNull) else { return nil }
    if let double = value as? Double {
        return double.isFinite ? double : nil
    }
    if let int = value as? Int {
        return Double(int)
    }
    if let number = value as? NSNumber {
        let double = number.doubleValue
        return double.isFinite ? double : nil
    }
    if let string = value as? String, let double = Double(string) {
        return double.isFinite ? double : nil
    }
    return nil
}

func routeParityRoundCoord(_ value: Any?) -> Double {
    guard let double = routeParityDouble(value) else { return 0 }
    return (double * 1_000_000).rounded() / 1_000_000
}

func routeParityPointSignature(_ points: [[String: Any]]) -> [String] {
    points.map { point in
        let ident = routeParityString(point["ident"] ?? point["label"])
        let kind = routeParityString(point["kind"])
        let lat = routeParityRoundCoord(point["lat"])
        let lon = routeParityRoundCoord(point["lon"])
        return String(format: "%@|%@|%.6f|%.6f", ident, kind, lat, lon)
    }
}

func routeParityUnwrapLongitude(_ lon: Double, near referenceLon: Double) -> Double {
    var adjusted = lon
    while adjusted - referenceLon > 180 {
        adjusted -= 360
    }
    while adjusted - referenceLon < -180 {
        adjusted += 360
    }
    return adjusted
}

func routeParityGeometrySummary(_ points: [[String: Any]]) -> [String: Any] {
    let rawLongitudes = points.compactMap { routeParityDouble($0["lon"]) }
    guard rawLongitudes.count >= 2 else {
        return [
            "raw_lon_jump_count": 0,
            "max_raw_lon_delta": 0.0,
            "max_unwrapped_lon_delta": 0.0,
            "unwrapped_lon_span": 0.0
        ]
    }
    let rawDeltas = rawLongitudes.indices.dropFirst().map { index in
        abs(rawLongitudes[index] - rawLongitudes[rawLongitudes.index(before: index)])
    }
    var unwrappedLongitudes = [rawLongitudes[0]]
    for lon in rawLongitudes.dropFirst() {
        unwrappedLongitudes.append(routeParityUnwrapLongitude(lon, near: unwrappedLongitudes[unwrappedLongitudes.count - 1]))
    }
    let unwrappedDeltas = unwrappedLongitudes.indices.dropFirst().map { index in
        abs(unwrappedLongitudes[index] - unwrappedLongitudes[unwrappedLongitudes.index(before: index)])
    }
    return [
        "raw_lon_jump_count": rawDeltas.filter { $0 > 180 }.count,
        "max_raw_lon_delta": ((rawDeltas.max() ?? 0) * 1_000_000).rounded() / 1_000_000,
        "max_unwrapped_lon_delta": ((unwrappedDeltas.max() ?? 0) * 1_000_000).rounded() / 1_000_000,
        "unwrapped_lon_span": (((unwrappedLongitudes.max() ?? 0) - (unwrappedLongitudes.min() ?? 0)) * 1_000_000).rounded() / 1_000_000
    ]
}

func routeParityPayloadSummary(_ payload: [String: Any]) -> [String: Any] {
    if let error = payload["error"] {
        return ["error": routeParityString(error)]
    }
    let legs = payload["legs"] as? [[String: Any]] ?? []
    let points = payload["points"] as? [[String: Any]] ?? []
    let distance = payload["distance_nm"] as? Double ?? 0
    return [
        "route_display": routeParityString(payload["route_display"]),
        "legs": legs.map(routeParityLegSummary),
        "point_count": points.count,
        "point_signature": routeParityPointSignature(points),
        "geometry": routeParityGeometrySummary(points),
        "distance_nm": (distance * 1000).rounded() / 1000,
        "selected_procedures": routeParitySelectedSummary(payload),
        "selected_runways": payload["selected_runways"] as? [String: Any] ?? [:],
        "message_kind": payload["error"] != nil ? "error" : ((payload["generated"] as? Bool) == true ? "generated" : "manual")
    ]
}

@main
struct RouteParityProbe {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fputs("usage: RouteParityProbe <workspace-root> <cases-json>\n", stderr)
            Foundation.exit(2)
        }

        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let casesURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let cases = try JSONDecoder().decode([RouteParityCase].self, from: Data(contentsOf: casesURL))
        let databaseURL = root.appendingPathComponent("NavPlanner/Resources/Database/navdata.sqlite")
        let dataStore = LocalDataStore(databaseURL: databaseURL)
        let service = PlannerService(dataStore: dataStore)
        var results: [String: Any] = [:]

        for routeCase in cases {
            let payload = service.routeResolvePayload(
                departure: routeCase.departure,
                arrival: routeCase.arrival,
                route: routeCase.route,
                departureRunway: routeCase.departureRunway ?? "ALL",
                arrivalRunway: routeCase.arrivalRunway ?? "ALL"
            )
            results[routeCase.name] = routeParityPayloadSummary(payload)
        }

        let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        print(String(data: data, encoding: .utf8) ?? "{}")
    }
}
