import Foundation
import SimNavCore

struct LocalWebTransportRequest: Sendable {
    var method: String
    var target: String
    var authority: String?
    var headers: [String: String]
    var body: Data
    var bodyFileURL: URL?

    init(
        method: String,
        target: String,
        authority: String? = nil,
        headers: [String: String] = [:],
        body: Data = Data(),
        bodyFileURL: URL? = nil
    ) {
        self.method = method.uppercased()
        self.target = target.isEmpty ? "/" : target
        self.authority = authority
        self.headers = headers
        self.body = body
        self.bodyFileURL = bodyFileURL
    }

    var path: String {
        let targetPath = target.split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        return targetPath.isEmpty ? "/" : targetPath
    }

    func headerValue(_ name: String) -> String? {
        headers.first { key, _ in
            key.caseInsensitiveCompare(name) == .orderedSame
        }?.value
    }
}

struct LocalWebUploadPlan: Sendable {
    let rootURL: URL
    let fileURL: URL
    let maximumBytes: Int
    let maximumSizeDescription: String
    let uploadKind: String
}

enum LocalWebUploadDecision: Sendable {
    case none
    case upload(LocalWebUploadPlan)
    case reject(RuntimeResponse)
}

struct LocalWebRequestProcessor: Sendable {
    static let maxRequestBodyBytes = 4 * 1_024 * 1_024
    static let maxDatabaseUploadBytes = 8 * 1_024 * 1_024 * 1_024
    static let maxOfflineMapUploadBytes = 64 * 1_024 * 1_024 * 1_024
    private static let tokenPlaceholder = "__SIMNAV_WRITE_TOKEN__"
    private static let exposedHeaders = [
        "Accept-Ranges",
        "Content-Disposition",
        "Content-Length",
        "Content-Range",
        "Date",
        "ETag",
        "X-Map-Cache",
        "X-Map-Fallback-Levels",
        "X-Map-Fallback-Target-State",
        "X-Map-Fallback-Zoom",
        "X-Offline-Map",
        "X-Weather-Source",
        "X-Weather-Updated"
    ].joined(separator: ", ")

    let settings: LocalWebSettings
    let runtimeRouter: SimNavRuntimeRouter
    let webResourceStore: SimNavWebResourceStore

    init(
        settings: LocalWebSettings,
        fr24BrowserFetcher: FR24BrowserFetching? = nil
    ) {
        self.settings = settings
        let browserFetcher = fr24BrowserFetcher ?? LocalWebFR24BrowserFetch(dataRoot: settings.dataRoot)
        self.runtimeRouter = SimNavRuntimeRouter(
            configuration: settings.runtimeConfiguration,
            fr24BrowserFetcher: browserFetcher
        )
        self.webResourceStore = SimNavWebResourceStore(rootURL: settings.webRoot)
    }

    func headRejection(for request: LocalWebTransportRequest) -> RuntimeResponse? {
        guard isAllowedHost(request.authority ?? request.headerValue("Host")) else {
            return errorResponse("Invalid Host header.", status: 403, request: request)
        }
        guard isAllowedOrigin(request.headerValue("Origin")) else {
            return errorResponse("Origin is not allowed.", status: 403, request: request)
        }
        if request.method == "OPTIONS" {
            return finalize(
                RuntimeResponse(
                    status: 204,
                    headers: [
                        "Access-Control-Allow-Headers": "Content-Type, X-SimNav-Filename, X-SimNav-Token",
                        "Access-Control-Allow-Methods": "GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS",
                        "Access-Control-Max-Age": "600",
                        "Cache-Control": "no-store"
                    ]
                ),
                request: request
            )
        }
        if isWriteMethod(request.method),
           !tokensEqual(request.headerValue("X-SimNav-Token") ?? "", settings.writeToken) {
            return errorResponse("Missing or invalid write token.", status: 403, request: request)
        }
        return nil
    }

    func uploadDecision(for request: LocalWebTransportRequest) -> LocalWebUploadDecision {
        guard request.method == "POST" else { return .none }

        let specification: (
            maximumBytes: Int,
            maximumSizeDescription: String,
            extensions: Set<String>,
            uploadKind: String
        )
        switch request.path {
        case "/api/databases/import":
            specification = (
                Self.maxDatabaseUploadBytes,
                "8 GiB",
                ["sqlite", "sqlite3", "s3db", "db"],
                "Database"
            )
        case "/api/offline-maps/import":
            specification = (
                Self.maxOfflineMapUploadBytes,
                "64 GiB",
                ["pmtiles", "mbtiles", "sqlite", "sqlite3"],
                "Offline map"
            )
        default:
            return .none
        }

        if let rawLength = request.headerValue("Content-Length"),
           let contentLength = Int(rawLength),
           contentLength > specification.maximumBytes {
            return .reject(errorResponse(
                "\(specification.uploadKind) upload exceeds the \(specification.maximumSizeDescription) limit.",
                status: 413,
                request: request
            ))
        }

        let encodedName = request.headerValue("X-SimNav-Filename") ?? ""
        let decodedName = encodedName.removingPercentEncoding ?? encodedName
        let fileName = URL(fileURLWithPath: decodedName).lastPathComponent
        guard !fileName.isEmpty,
              !decodedName.contains("/"),
              !decodedName.contains("\\"),
              fileName == decodedName,
              specification.extensions.contains(URL(fileURLWithPath: fileName).pathExtension.lowercased()) else {
            return .reject(errorResponse(
                "A valid \(specification.uploadKind.lowercased()) filename is required.",
                status: 400,
                request: request
            ))
        }

        let uploadRoot = settings.dataRoot
            .appendingPathComponent("Uploads", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let uploadURL = uploadRoot.appendingPathComponent(fileName).standardizedFileURL
        guard uploadURL.deletingLastPathComponent() == uploadRoot.standardizedFileURL else {
            return .reject(errorResponse("Invalid upload path.", status: 400, request: request))
        }
        return .upload(LocalWebUploadPlan(
            rootURL: uploadRoot,
            fileURL: uploadURL,
            maximumBytes: specification.maximumBytes,
            maximumSizeDescription: specification.maximumSizeDescription,
            uploadKind: specification.uploadKind
        ))
    }

    func response(to request: LocalWebTransportRequest) -> RuntimeResponse {
        if let rejection = headRejection(for: request) {
            return rejection
        }

        if request.path == "/healthz" {
            return finalize(
                RuntimeResponse(
                    status: 200,
                    headers: [
                        "Cache-Control": "no-store",
                        "Content-Type": "application/json"
                    ],
                    body: Data("{\"status\":\"ok\"}".utf8)
                ),
                request: request
            )
        }

        if request.path == "/api" || request.path.hasPrefix("/api/") {
            guard request.body.count <= Self.maxRequestBodyBytes || request.bodyFileURL != nil else {
                return errorResponse("Request body is too large.", status: 413, request: request)
            }
            let runtimeRequest = RuntimeRequest(
                httpMethod: request.method,
                httpTarget: request.target,
                httpHeaders: request.headers,
                body: request.body,
                bodyFileURL: request.bodyFileURL
            )
            guard runtimeRouter.canHandle(runtimeRequest) else {
                return errorResponse("API not found.", status: 404, request: request)
            }
            return finalize(runtimeRouter.handle(runtimeRequest), request: request)
        }

        guard request.method == "GET" || request.method == "HEAD" else {
            return errorResponse("Method not allowed.", status: 405, request: request)
        }
        var result = webResourceStore.response(for: request.path)
        let decodedPath = request.path.removingPercentEncoding ?? request.path
        if result.status == 200,
           ["/", "/map.html"].contains(decodedPath),
           var html = String(data: result.body, encoding: .utf8) {
            html = html.replacingOccurrences(
                of: Self.tokenPlaceholder,
                with: settings.writeToken
            )
            result.body = Data(html.utf8)
        }
        return finalize(result, request: request)
    }

    func uploadFailure(
        _ message: String,
        status: Int,
        request: LocalWebTransportRequest
    ) -> RuntimeResponse {
        errorResponse(message, status: status, request: request)
    }

    private func errorResponse(
        _ message: String,
        status: Int,
        request: LocalWebTransportRequest
    ) -> RuntimeResponse {
        let data = (try? JSONSerialization.data(
            withJSONObject: ["error": message],
            options: [.sortedKeys]
        )) ?? Data("{\"error\":\"Local Web error\"}".utf8)
        return finalize(
            RuntimeResponse(
                status: status,
                headers: [
                    "Cache-Control": "no-store",
                    "Content-Type": "application/json"
                ],
                body: data
            ),
            request: request
        )
    }

    private func finalize(
        _ source: RuntimeResponse,
        request: LocalWebTransportRequest
    ) -> RuntimeResponse {
        var response = source
        response.headers["X-Content-Type-Options"] = "nosniff"
        if response.headers.first(where: {
            $0.key.caseInsensitiveCompare("Access-Control-Expose-Headers") == .orderedSame
        }) == nil {
            response.headers["Access-Control-Expose-Headers"] = Self.exposedHeaders
        }
        if let origin = request.headerValue("Origin") {
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Vary"] = "Origin"
        }
        if request.method == "HEAD" {
            response.headers["Content-Length"] = String(response.body.count)
            response.body = Data()
        }
        return response
    }

    private func isAllowedHost(_ rawHost: String?) -> Bool {
        guard let host = rawHost?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !host.isEmpty else {
            return false
        }
        return Set([
            "127.0.0.1",
            "127.0.0.1:\(settings.port)",
            "localhost",
            "localhost:\(settings.port)",
            "[::1]",
            "[::1]:\(settings.port)"
        ]).contains(host)
    }

    private func isAllowedOrigin(_ origin: String?) -> Bool {
        guard let origin else { return true }
        guard let components = URLComponents(string: origin),
              components.scheme?.lowercased() == "http",
              let host = components.host?.lowercased(),
              ["127.0.0.1", "localhost", "::1"].contains(host) else {
            return false
        }
        return (components.port ?? 80) == settings.port
    }

    private func isWriteMethod(_ method: String) -> Bool {
        !["GET", "HEAD", "OPTIONS"].contains(method)
    }

    private func tokensEqual(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for index in left.indices {
            difference |= left[index] ^ right[index]
        }
        return difference == 0
    }
}
