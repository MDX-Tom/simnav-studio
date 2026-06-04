import Foundation

struct SearchResult: Identifiable, Hashable {
    let ident: String
    let name: String
    let kind: String
    let lat: Double
    let lon: Double

    var id: String {
        "\(kind)-\(ident)-\(lat)-\(lon)"
    }

    var localizedKind: String {
        switch kind {
        case "airport": "机场"
        case "waypoint": "航点"
        case "vor": "VOR"
        case "ndb": "NDB"
        default: "导航点"
        }
    }

    var dictionary: [String: Any] {
        [
            "ident": ident,
            "name": name,
            "kind": kind,
            "lat": lat,
            "lon": lon
        ]
    }

    init?(row: [String: Any]) {
        let ident = navString(row["ident"]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ident.isEmpty,
              let lat = navDouble(row["lat"]),
              let lon = navDouble(row["lon"]) else {
            return nil
        }
        self.ident = ident
        self.name = navString(row["name"]).isEmpty ? ident : navString(row["name"])
        self.kind = navString(row["kind"]).isEmpty ? "waypoint" : navString(row["kind"])
        self.lat = lat
        self.lon = lon
    }
}

func navString(_ value: Any?) -> String {
    switch value {
    case _ as NSNull:
        return ""
    case let value as String:
        return value
    case let value as NSNumber:
        return value.stringValue
    case .some(let value):
        return String(describing: value)
    case .none:
        return ""
    }
}

func navDouble(_ value: Any?) -> Double? {
    switch value {
    case let value as Double:
        return value
    case let value as Float:
        return Double(value)
    case let value as Int:
        return Double(value)
    case let value as Int64:
        return Double(value)
    case let value as NSNumber:
        return value.doubleValue
    case let value as String:
        return Double(value)
    default:
        return nil
    }
}

func navInt(_ value: Any?) -> Int? {
    switch value {
    case let value as Int:
        return value
    case let value as Int64:
        return Int(value)
    case let value as NSNumber:
        return value.intValue
    case let value as String:
        return Int(value)
    default:
        return nil
    }
}
