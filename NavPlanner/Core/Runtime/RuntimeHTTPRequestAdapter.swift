import Foundation

public extension RuntimeRequest {
    /// Adapts the transport-neutral parts of an HTTP request into the runtime model.
    /// Server frameworks should pass their raw request target so repeated query items
    /// retain the same semantics as the WebKit URLRequest adapter.
    init(
        httpMethod: String,
        httpTarget: String,
        httpHeaders: [String: String] = [:],
        body: Data = Data(),
        bodyFileURL: URL? = nil
    ) {
        let target = httpTarget.isEmpty ? "/" : httpTarget
        let components = URLComponents(string: target)
        var query: [String: [String]] = [:]
        for item in components?.queryItems ?? [] {
            query[item.name, default: []].append(item.value ?? "")
        }

        let rawPath = components?.percentEncodedPath.isEmpty == false
            ? components?.percentEncodedPath ?? "/"
            : target.split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        self.init(
            method: httpMethod,
            path: rawPath,
            query: query,
            headers: httpHeaders,
            body: body,
            bodyFileURL: bodyFileURL
        )
    }
}
