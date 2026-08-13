import Foundation

public struct RuntimeTransportResponse: Sendable {
    public let statusCode: Int
    public let mimeType: String
    public let data: Data
    public let headers: [String: String]

    public init(
        statusCode: Int,
        mimeType: String,
        data: Data,
        headers: [String: String]
    ) {
        self.statusCode = statusCode
        self.mimeType = mimeType
        self.data = data
        self.headers = headers
    }
}

public enum RuntimeWebKitResponseAdapter {
    public static func adapt(
        _ response: RuntimeResponse,
        baseHeaders: [String: String] = [:]
    ) -> RuntimeTransportResponse {
        var headers = baseHeaders
        for (key, value) in response.headers {
            if key.caseInsensitiveCompare("Content-Type") == .orderedSame {
                continue
            }
            if let existing = headers.keys.first(where: {
                $0.caseInsensitiveCompare(key) == .orderedSame
            }) {
                headers.removeValue(forKey: existing)
            }
            headers[key] = value
        }
        return RuntimeTransportResponse(
            statusCode: response.status,
            mimeType: response.contentType,
            data: response.body,
            headers: headers
        )
    }
}
