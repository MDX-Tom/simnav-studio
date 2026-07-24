import Foundation

struct TrackParityCase: Decodable {
    let name: String
    let departure: String
    let arrival: String
    let trackPoints: [[String: Double]]

    enum CodingKeys: String, CodingKey {
        case name
        case departure
        case arrival
        case trackPoints = "track_points"
    }
}

func trackParityString(_ value: Any?) -> String {
    guard let value, !(value is NSNull) else { return "" }
    return String(describing: value)
}

func trackParitySelectedSummary(_ payload: [String: Any]) -> [String: Any] {
    let selected = payload["selected_procedures"] as? [String: Any] ?? [:]
    var output: [String: Any] = [:]
    for key in ["sid", "star", "approach"] {
        let item = selected[key] as? [String: Any] ?? [:]
        output[key] = [
            "procedure": trackParityString(item["procedure"] ?? item["procedure_identifier"]),
            "transition": trackParityString(item["transition"] ?? item["transition_identifier"]),
            "runway": trackParityString(item["runway"])
        ]
    }
    return output
}

func trackParityLegSummary(_ leg: [String: Any]) -> [String: Any] {
    [
        "type": trackParityString(leg["type"]),
        "name": trackParityString(leg["name"]),
        "entry": trackParityString(leg["entry"]),
        "exit": trackParityString(leg["exit"]),
        "transition": trackParityString(leg["transition"]),
        "count": leg["count"] as? Int ?? 0
    ]
}

func trackParityDouble(_ value: Any?) -> Double? {
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

func trackParityRoundCoord(_ value: Any?) -> Double {
    guard let double = trackParityDouble(value) else { return 0 }
    return (double * 1_000_000).rounded() / 1_000_000
}

func trackParityPointSignature(_ points: [[String: Any]]) -> [String] {
    points.map { point in
        let ident = trackParityString(point["ident"] ?? point["label"])
        let kind = trackParityString(point["kind"])
        let lat = trackParityRoundCoord(point["lat"])
        let lon = trackParityRoundCoord(point["lon"])
        return String(format: "%@|%@|%.6f|%.6f", ident, kind, lat, lon)
    }
}

func trackParityUnwrapLongitude(_ lon: Double, near referenceLon: Double) -> Double {
    var adjusted = lon
    while adjusted - referenceLon > 180 {
        adjusted -= 360
    }
    while adjusted - referenceLon < -180 {
        adjusted += 360
    }
    return adjusted
}

func trackParityGeometrySummary(_ points: [[String: Any]]) -> [String: Any] {
    let rawLongitudes = points.compactMap { trackParityDouble($0["lon"]) }
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
        unwrappedLongitudes.append(trackParityUnwrapLongitude(lon, near: unwrappedLongitudes[unwrappedLongitudes.count - 1]))
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

func trackParityPayloadSummary(_ payload: [String: Any]) -> [String: Any] {
    if let error = payload["error"] {
        return ["error": trackParityString(error)]
    }
    let legs = payload["legs"] as? [[String: Any]] ?? []
    let points = payload["points"] as? [[String: Any]] ?? []
    let distance = trackParityDouble(payload["distance_nm"]) ?? 0
    let source = payload["source"] as? [String: Any] ?? [:]
    let sourceTrackPoints = source["track_points"] as? [[String: Any]] ?? []
    return [
        "route_display": trackParityString(payload["route_display"]),
        "legs": legs.map(trackParityLegSummary),
        "point_count": points.count,
        "point_signature": trackParityPointSignature(points),
        "geometry": trackParityGeometrySummary(points),
        "distance_nm": (distance * 1000).rounded() / 1000,
        "selected_procedures": trackParitySelectedSummary(payload),
        "selected_runways": payload["selected_runways"] as? [String: Any] ?? [:],
        "message_kind": payload["error"] != nil ? "error" : ((payload["generated"] as? Bool) == true ? "generated" : "manual"),
        "source_provider": trackParityString(source["provider"]),
        "source_track_count": sourceTrackPoints.count
    ]
}

func trackParitySelectedProcedureItems(
    service: PlannerService,
    payload: [String: Any]
) -> [String: [String]] {
    let selected = payload["selected_procedures"] as? [String: Any] ?? [:]
    var output: [String: [String]] = [:]
    for type in ["sid", "star", "approach"] {
        guard let item = selected[type] as? [String: Any] else { continue }
        let airport = trackParityString(item["airport"])
        let procedure = trackParityString(item["procedure"] ?? item["procedure_identifier"])
        let transition = trackParityString(item["transition"] ?? item["transition_identifier"])
        guard !airport.isEmpty, !procedure.isEmpty else { continue }
        let details = service.procedurePayload(
            type: type,
            airport: airport,
            procedure: procedure,
            transition: transition
        )
        let rows = details["items"] as? [[String: Any]] ?? []
        output[type] = rows.compactMap { row in
            let ident = trackParityString(row["waypoint_identifier"]).uppercased()
            return ident.isEmpty ? nil : ident
        }
    }
    return output
}

@main
struct TrackParityProbe {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fputs("usage: TrackParityProbe <workspace-root> <cases-json>\n", stderr)
            Foundation.exit(2)
        }

        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let casesURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let cases = try JSONDecoder().decode([TrackParityCase].self, from: Data(contentsOf: casesURL))
        let databaseURL = root.appendingPathComponent("NavPlanner/Resources/Database/navdata.sqlite")
        let dataStore = LocalDataStore(databaseURL: databaseURL)
        let service = PlannerService(dataStore: dataStore)
        var results: [String: Any] = [:]

        for trackCase in cases {
            let trackPoints = trackCase.trackPoints.map { point in
                point.reduce(into: [String: Any]()) { output, item in
                    output[item.key] = item.value
                }
            }
            let payload = service.trackMatchPayload(
                departure: trackCase.departure,
                arrival: trackCase.arrival,
                trackPoints: trackPoints
            )
            var summary = trackParityPayloadSummary(payload)
            if payload["error"] == nil {
                summary["selected_procedure_items"] = trackParitySelectedProcedureItems(
                    service: service,
                    payload: payload
                )
            }
            results[trackCase.name] = summary
        }

        let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        print(String(data: data, encoding: .utf8) ?? "{}")
    }
}
