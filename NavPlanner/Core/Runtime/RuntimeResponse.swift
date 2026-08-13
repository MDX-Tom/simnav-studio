import Foundation

public struct RuntimeResponse: Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(
        status: Int,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public var contentType: String {
        headers.first { key, _ in
            key.caseInsensitiveCompare("Content-Type") == .orderedSame
        }?.value ?? "application/octet-stream"
    }
}
