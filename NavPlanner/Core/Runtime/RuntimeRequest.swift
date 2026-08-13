import Foundation

public struct RuntimeRequest: Sendable {
    public var method: String
    public var path: String
    public var query: [String: [String]]
    public var headers: [String: String]
    public var body: Data
    public var bodyFileURL: URL?

    public init(
        method: String,
        path: String,
        query: [String: [String]] = [:],
        headers: [String: String] = [:],
        body: Data = Data(),
        bodyFileURL: URL? = nil
    ) {
        self.method = method.isEmpty ? "GET" : method.uppercased()
        self.path = path.hasPrefix("/") ? path : "/\(path)"
        self.query = query
        self.headers = headers
        self.body = body
        self.bodyFileURL = bodyFileURL?.standardizedFileURL
    }

    public func queryValue(_ name: String, default fallback: String = "") -> String {
        query[name]?.first ?? fallback
    }

    public func headerValue(_ name: String) -> String? {
        headers.first { key, _ in
            key.caseInsensitiveCompare(name) == .orderedSame
        }?.value
    }
}
