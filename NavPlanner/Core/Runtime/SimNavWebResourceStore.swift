import Foundation

public struct SimNavWebResourceStore: Sendable {
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL.resolvingSymlinksInPath().standardizedFileURL
    }

    public func response(for requestPath: String) -> RuntimeResponse {
        let decodedPath = requestPath.removingPercentEncoding ?? requestPath
        guard !decodedPath.contains("\0") else {
            return errorResponse("Invalid resource path.", status: 400)
        }
        let relativePath = decodedPath == "/"
            ? "map.html"
            : String(decodedPath.drop(while: { $0 == "/" }))
        guard !relativePath.isEmpty else {
            return errorResponse("Web resource not found.", status: 404)
        }

        let resourceURL = rootURL
            .appendingPathComponent(relativePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard resourceURL.path == rootURL.path
                || resourceURL.path.hasPrefix(rootURL.path + "/") else {
            return errorResponse("Resource path escapes the Web root.", status: 403)
        }
        guard let values = try? resourceURL.resourceValues(forKeys: [.isRegularFileKey]),
              values.isRegularFile == true,
              let data = try? Data(contentsOf: resourceURL, options: [.mappedIfSafe]) else {
            return errorResponse("Web resource not found.", status: 404)
        }
        return RuntimeResponse(
            status: 200,
            headers: [
                "Cache-Control": "no-cache",
                "Content-Type": Self.mimeType(forExtension: resourceURL.pathExtension)
            ],
            body: data
        )
    }

    public static func mimeType(forExtension pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "css": "text/css; charset=utf-8"
        case "gif": "image/gif"
        case "html", "htm": "text/html; charset=utf-8"
        case "ico": "image/x-icon"
        case "jpeg", "jpg": "image/jpeg"
        case "js", "mjs": "text/javascript; charset=utf-8"
        case "json", "map": "application/json"
        case "pbf", "mvt": "application/x-protobuf"
        case "pmtiles", "mbtiles", "sqlite", "sqlite3": "application/octet-stream"
        case "png": "image/png"
        case "svg": "image/svg+xml"
        case "ttf": "font/ttf"
        case "wasm": "application/wasm"
        case "woff": "font/woff"
        case "woff2": "font/woff2"
        default: "application/octet-stream"
        }
    }

    private func errorResponse(_ message: String, status: Int) -> RuntimeResponse {
        let body = (try? JSONSerialization.data(
            withJSONObject: ["error": message],
            options: [.sortedKeys]
        )) ?? Data("{\"error\":\"Web resource error\"}".utf8)
        return RuntimeResponse(
            status: status,
            headers: [
                "Cache-Control": "no-store",
                "Content-Type": "application/json"
            ],
            body: body
        )
    }
}
