import Foundation

struct ProcedureParityCase: Decodable {
    let name: String
    let type: String
    let airport: String
    let procedure: String
    let transition: String
}

func procedureParityString(_ value: Any?) -> String {
    guard let value, !(value is NSNull) else { return "" }
    return String(describing: value)
}

func procedureParityDouble(_ value: Any?) -> Double? {
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

func procedureParityRoundCoord(_ value: Any?) -> Double {
    guard let double = procedureParityDouble(value) else { return 0 }
    return (double * 1_000_000).rounded() / 1_000_000
}

func procedureParityPointSignature(_ points: [[String: Any]]) -> [String] {
    points.map { point in
        let lat = procedureParityRoundCoord(point["lat"])
        let lon = procedureParityRoundCoord(point["lon"])
        return String(format: "%.6f|%.6f", lat, lon)
    }
}

func procedureParityItemSignature(_ items: [[String: Any]]) -> [String] {
    items.map { item in
        [
            procedureParityString(item["seqno"]),
            procedureParityString(item["waypoint_identifier"]),
            procedureParityString(item["path_termination"]),
            procedureParityString(item["route_type"]),
            String(format: "%.6f", procedureParityRoundCoord(item["waypoint_latitude"])),
            String(format: "%.6f", procedureParityRoundCoord(item["waypoint_longitude"])),
            procedureParityString(item["center_waypoint"]),
            String(format: "%.6f", procedureParityRoundCoord(item["center_waypoint_latitude"])),
            String(format: "%.6f", procedureParityRoundCoord(item["center_waypoint_longitude"]))
        ].joined(separator: "|")
    }
}

func procedureParityPayloadSummary(_ payload: [String: Any]) -> [String: Any] {
    if let error = payload["error"] {
        return ["error": procedureParityString(error)]
    }
    let items = payload["items"] as? [[String: Any]] ?? []
    let path = payload["path"] as? [[String: Any]] ?? []
    let primary = payload["primary_path"] as? [[String: Any]] ?? []
    let missed = payload["missed_path"] as? [[String: Any]] ?? []
    return [
        "item_count": items.count,
        "item_signature": procedureParityItemSignature(items),
        "path_count": path.count,
        "path_signature": procedureParityPointSignature(path),
        "primary_count": primary.count,
        "primary_signature": procedureParityPointSignature(primary),
        "missed_count": missed.count,
        "missed_signature": procedureParityPointSignature(missed)
    ]
}

@main
struct ProcedureParityProbe {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fputs("usage: ProcedureParityProbe <database-path> <cases-json>\n", stderr)
            Foundation.exit(2)
        }

        let databaseURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let casesURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let cases = try JSONDecoder().decode([ProcedureParityCase].self, from: Data(contentsOf: casesURL))
        let dataStore = LocalDataStore(databaseURL: databaseURL)
        let service = PlannerService(dataStore: dataStore)
        var results: [String: Any] = [:]

        for procedureCase in cases {
            let payload = service.procedurePayload(
                type: procedureCase.type,
                airport: procedureCase.airport,
                procedure: procedureCase.procedure,
                transition: procedureCase.transition
            )
            results[procedureCase.name] = procedureParityPayloadSummary(payload)
        }

        let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        print(String(data: data, encoding: .utf8) ?? "{}")
    }
}
