import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension RuntimeRequest {
    init(urlRequest: URLRequest, pathOverride: String? = nil) {
        let queryItems = urlRequest.url.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems
        } ?? []
        var query: [String: [String]] = [:]
        for item in queryItems {
            query[item.name, default: []].append(item.value ?? "")
        }

        self.init(
            method: urlRequest.httpMethod ?? "GET",
            path: pathOverride ?? urlRequest.url?.path ?? "/",
            query: query,
            headers: urlRequest.allHTTPHeaderFields ?? [:],
            body: Self.runtimeBody(from: urlRequest)
        )
    }

    private static func runtimeBody(from request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
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
        return data
    }
}
