import Foundation
import WebKit

final class NavPlannerSchemeHandler: NSObject, WKURLSchemeHandler {
    private typealias SchemeResponse = RuntimeTransportResponse

    private let runtimeRouter: SimNavRuntimeRouter
    private let webResourceStore: SimNavWebResourceStore?
    private let workQueue = DispatchQueue(
        label: "com.navplanner.web-bridge",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let lock = NSLock()
    private var stoppedTasks = Set<ObjectIdentifier>()
    init(plannerService: PlannerService, mapStore: MapStore) {
        let onlineTileCache = SimNavOnlineTileCache()
        let fr24Service = FR24Service(browserFetcher: FR24BrowserFetch.shared)
        self.runtimeRouter = SimNavRuntimeRouter(
            plannerService: plannerService,
            mapStore: mapStore,
            onlineTileCache: onlineTileCache,
            fr24Service: fr24Service
        )
        self.webResourceStore = Bundle.main
            .url(forResource: "Web", withExtension: nil)
            .map(SimNavWebResourceStore.init(rootURL:))
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        _ = lock.withLock {
            stoppedTasks.remove(taskID)
        }

        guard let url = urlSchemeTask.request.url else {
            deliver(response: jsonResponse(["error": "Invalid URL"], statusCode: 400), to: urlSchemeTask)
            return
        }

        workQueue.async { [weak self] in
            guard let self else { return }
            guard !self.consumeStoppedTask(taskID) else { return }
            let response = self.response(for: url, request: urlSchemeTask.request, taskID: taskID)
            self.deliver(response: response, to: urlSchemeTask)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        _ = lock.withLock {
            stoppedTasks.insert(taskID)
        }
    }

    private func response(
        for url: URL,
        request: URLRequest,
        taskID: ObjectIdentifier? = nil
    ) -> SchemeResponse {
        switch url.host {
        case "app":
            if url.path == "/api" || url.path.hasPrefix("/api/") {
                return apiResponse(for: url, request: request, taskID: taskID)
            }
            return appResourceResponse(for: url)
        case "api":
            return apiResponse(for: url, request: request, taskID: taskID)
        case "tiles":
            let runtimeRequest = RuntimeRequest(urlRequest: request, pathOverride: url.path)
            guard runtimeRouter.canHandle(runtimeRequest) else {
                return jsonResponse(["error": "Tile API not found"], statusCode: 404)
            }
            return schemeResponse(from: runtimeRouter.handle(runtimeRequest))
        default:
            return jsonResponse(["error": "Unknown navplanner host"], statusCode: 404)
        }
    }

    private func appResourceResponse(for url: URL) -> SchemeResponse {
        guard let webResourceStore else {
            return jsonResponse(["error": "Web resource not found"], statusCode: 404)
        }
        return schemeResponse(from: webResourceStore.response(for: url.path))
    }

    private func apiResponse(
        for url: URL,
        request: URLRequest,
        taskID: ObjectIdentifier? = nil
    ) -> SchemeResponse {
        let path = normalizedAPIPath(url.path)
        let runtimeRequest = RuntimeRequest(urlRequest: request, pathOverride: path)
        guard runtimeRouter.canHandle(runtimeRequest) else {
            return jsonResponse(["error": "API not found"], statusCode: 404)
        }
        let cancelled = { [weak self] in
            guard let self, let taskID else { return false }
            return self.isStoppedTask(taskID)
        }
        return schemeResponse(from: runtimeRouter.handle(
            runtimeRequest,
            shouldCancel: cancelled
        ))
    }

    private func jsonResponse(_ object: Any, statusCode: Int = 200) -> SchemeResponse {
        let sanitized = sanitizeJSON(object)
        let data = (try? JSONSerialization.data(withJSONObject: sanitized, options: [])) ?? Data("{}".utf8)
        return schemeResponse(from: RuntimeResponse(
            status: statusCode,
            headers: ["Content-Type": "application/json"],
            body: data
        ))
    }

    private func schemeResponse(from response: RuntimeResponse) -> SchemeResponse {
        RuntimeWebKitResponseAdapter.adapt(
            response,
            baseHeaders: cacheHeaders
        )
    }

    private func sanitizeJSON(_ value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            return dictionary.mapValues(sanitizeJSON)
        case let array as [Any]:
            return array.map(sanitizeJSON)
        case is NSNull, is String, is Int, is Double, is Bool:
            return value
        case let number as NSNumber:
            return number
        default:
            return NSNull()
        }
    }

    private func normalizedAPIPath(_ path: String) -> String {
        if path == "/api" {
            return "/"
        }
        if path.hasPrefix("/api/") {
            return String(path.dropFirst(4))
        }
        return path
    }

    private func deliver(response: SchemeResponse, to task: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(task as AnyObject)
        DispatchQueue.main.async {
            guard !self.consumeStoppedTask(taskID) else { return }
            guard let url = task.request.url,
                  let httpResponse = HTTPURLResponse(
                    url: url,
                    statusCode: response.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: response.headers.merging(["Content-Type": response.mimeType]) { _, new in new }
                  ) else {
                return
            }
            task.didReceive(httpResponse)
            if !response.data.isEmpty {
                task.didReceive(response.data)
            }
            task.didFinish()
        }
    }

    private func isStoppedTask(_ taskID: ObjectIdentifier) -> Bool {
        lock.withLock {
            stoppedTasks.contains(taskID)
        }
    }

    @discardableResult
    private func consumeStoppedTask(_ taskID: ObjectIdentifier) -> Bool {
        lock.withLock {
            stoppedTasks.remove(taskID) != nil
        }
    }

    private var cacheHeaders: [String: String] {
        [
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Expose-Headers": [
                "Accept-Ranges",
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
            ].joined(separator: ", "),
            "Cache-Control": "no-store"
        ]
    }

}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

private final class FR24BrowserFetch: NSObject, WKNavigationDelegate, FR24BrowserFetching {
    private struct BrowserError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static let shared = FR24BrowserFetch()
    private let requestLock = NSLock()
    private var webView: WKWebView?
    private var idleReleaseWorkItem: DispatchWorkItem?
    private struct PageResponse {
        let status: Int
        let contentType: String
        let text: String
    }
    private var pendingPageCompletion: ((Result<PageResponse, Error>) -> Void)?
    private var pendingPageURL: URL?
    private var pendingPageNavigation: WKNavigation?
    private var pendingPageRequestID: UInt64 = 0
    private var nextPageRequestID: UInt64 = 0
    private var pendingPageStatus = 0
    private var pendingPageContentType = ""
    private var pendingPageReadScript = ""
    private var pendingPageReadDelay: TimeInterval = 0
    private var pendingPageWaitsForStableResult = false
    private var pendingPageReadStartedAt: Date?
    private var pendingPageBestText = ""
    private var pendingPageBestScore = -1
    private var pendingPageLastSignature = ""
    private var pendingPageStableReadCount = 0

    func performJSONRequest(path: String, params: [(String, String)]) throws -> [String: Any] {
        requestLock.lock()
        defer { requestLock.unlock() }
        guard var components = URLComponents(string: "https://api.flightradar24.com\(path)") else {
            throw BrowserError(message: "FR24 web request failed.")
        }
        components.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components.url else {
            throw BrowserError(message: "FR24 web request failed.")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var output: Result<[String: Any], Error>?
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                output = .failure(BrowserError(message: "FR24 web request failed."))
                semaphore.signal()
                return
            }
            self.loadJSONPage(url: url) { result in
                output = result.flatMap { page in
                    Self.decodePageResponse(page, requestURL: url)
                }
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .now() + 28) == .timedOut {
            throw BrowserError(message: "FR24 web request timed out.")
        }
        switch output {
        case let .success(payload):
            return payload
        case let .failure(error):
            throw error
        case .none:
            throw BrowserError(message: "FR24 web request failed.")
        }
    }

    func performFlightHistoryPageRequest(flightToken: String) throws -> [String: Any] {
        requestLock.lock()
        defer { requestLock.unlock() }
        let token = flightToken.lowercased().filter { $0.isLetter || $0.isNumber }
        guard !token.isEmpty,
              let url = URL(string: "https://www.flightradar24.com/data/flights/\(token)") else {
            throw BrowserError(message: "FR24 flight number missing.")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var output: Result<[String: Any], Error>?
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                output = .failure(BrowserError(message: "FR24 web request failed."))
                semaphore.signal()
                return
            }
            self.loadPage(
                url: url,
                acceptHeader: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                readScript: FR24BrowserScripts.flightHistoryExtraction,
                readDelay: 0.45,
                waitForStableResult: true
            ) { result in
                output = result.flatMap { page in
                    Self.decodeFlightHistoryPageResponse(page, requestURL: url)
                }
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .now() + 30) == .timedOut {
            throw BrowserError(message: "FR24 web request timed out.")
        }
        switch output {
        case let .success(payload):
            return payload
        case let .failure(error):
            throw error
        case .none:
            throw BrowserError(message: "FR24 web request failed.")
        }
    }

    private func loadJSONPage(url: URL, completion: @escaping (Result<PageResponse, Error>) -> Void) {
        loadPage(
            url: url,
            acceptHeader: "application/json, text/plain, */*",
            readScript: FR24BrowserScripts.pageText,
            readDelay: 0,
            completion: completion
        )
    }

    private func loadPage(
        url: URL,
        acceptHeader: String,
        readScript: String,
        readDelay: TimeInterval,
        waitForStableResult: Bool = false,
        completion: @escaping (Result<PageResponse, Error>) -> Void
    ) {
        guard pendingPageCompletion == nil else {
            completion(.failure(BrowserError(message: "FR24 browser is already handling a web request.")))
            return
        }
        let webView = ensureWebView()
        nextPageRequestID &+= 1
        if nextPageRequestID == 0 {
            nextPageRequestID = 1
        }
        let requestID = nextPageRequestID
        pendingPageCompletion = completion
        pendingPageURL = url
        pendingPageRequestID = requestID
        pendingPageStatus = 0
        pendingPageContentType = ""
        pendingPageReadScript = readScript
        pendingPageReadDelay = readDelay
        pendingPageWaitsForStableResult = waitForStableResult
        pendingPageReadStartedAt = nil
        pendingPageBestText = ""
        pendingPageBestScore = -1
        pendingPageLastSignature = ""
        pendingPageStableReadCount = 0
        let pageTimeout: TimeInterval = waitForStableResult ? 29 : 24
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: pageTimeout
        )
        request.setValue(acceptHeader, forHTTPHeaderField: "Accept")
        request.setValue("https://www.flightradar24.com/", forHTTPHeaderField: "Referer")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        pendingPageNavigation = webView.load(request)
        DispatchQueue.main.asyncAfter(deadline: .now() + pageTimeout) { [weak self] in
            guard let self,
                  self.pendingPageCompletion != nil,
                  self.pendingPageURL == url,
                  self.pendingPageRequestID == requestID else {
                return
            }
            self.finishPendingPage(
                .failure(BrowserError(message: "FR24 web request timed out.")),
                requestID: requestID
            )
        }
    }

    private func ensureWebView() -> WKWebView {
        idleReleaseWorkItem?.cancel()
        idleReleaseWorkItem = nil
        if let webView {
            return webView
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        self.webView = webView
        return webView
    }

    private func scheduleIdleWebViewRelease() {
        idleReleaseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.pendingPageCompletion == nil else { return }
            self.webView?.stopLoading()
            self.webView?.navigationDelegate = nil
            self.webView?.removeFromSuperview()
            self.webView = nil
            self.idleReleaseWorkItem = nil
            NSLog("NavPlanner FR24 browser released after idle timeout")
        }
        idleReleaseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: workItem)
    }

    private static func decodePageResponse(_ page: PageResponse, requestURL: URL) -> Result<[String: Any], Error> {
        NSLog(
            "NavPlanner FR24 browser load path=%@ status=%d type=%@ body=%@",
            requestURL.path,
            page.status,
            page.contentType,
            bodyKind(page.text)
        )
        if page.status == 401 || page.status == 403 {
            return .failure(BrowserError(message: "FR24 web access was blocked. Open FR24 verification in Query, complete verification, then sync the session."))
        }
        guard page.status == 0 || (200..<300).contains(page.status) else {
            return .failure(BrowserError(message: "FR24 web returned HTTP \(page.status)."))
        }
        if page.text.localizedCaseInsensitiveContains("cloudflare")
            || page.text.localizedCaseInsensitiveContains("challenge-platform")
            || page.text.localizedCaseInsensitiveContains("just a moment")
            || page.text.localizedCaseInsensitiveContains("<html") {
            return .failure(BrowserError(message: "FR24 web returned an HTML response."))
        }
        guard let bodyData = page.text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return .failure(BrowserError(message: "FR24 web response was not valid JSON."))
        }
        return .success(object)
    }

    private static func bodyKind(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "empty"
        }
        if trimmed.localizedCaseInsensitiveContains("cloudflare")
            || trimmed.localizedCaseInsensitiveContains("challenge-platform")
            || trimmed.localizedCaseInsensitiveContains("just a moment") {
            return "cloudflare"
        }
        if trimmed.localizedCaseInsensitiveContains("<html") {
            return "html"
        }
        if trimmed.hasPrefix("{") {
            return "json-object"
        }
        if trimmed.hasPrefix("[") {
            return "json-array"
        }
        return "text"
    }

    private static func decodeFlightHistoryPageResponse(_ page: PageResponse, requestURL: URL) -> Result<[String: Any], Error> {
        NSLog(
            "NavPlanner FR24 browser history path=%@ status=%d type=%@ body=%@",
            requestURL.path,
            page.status,
            page.contentType,
            bodyKind(page.text)
        )
        if page.status == 401 || page.status == 403 {
            return .failure(BrowserError(message: "FR24 web access was blocked. Open FR24 verification in Query, complete verification, then sync the session."))
        }
        guard page.status == 0 || (200..<300).contains(page.status) else {
            return .failure(BrowserError(message: "FR24 web returned HTTP \(page.status)."))
        }
        guard let bodyData = page.text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return .failure(BrowserError(message: "FR24 web response was not valid JSON."))
        }
        let bodyText = Self.stringValue(object["bodyText"])
        let combined = "\(page.text)\n\(bodyText)"
        if combined.localizedCaseInsensitiveContains("cloudflare")
            || combined.localizedCaseInsensitiveContains("challenge-platform")
            || combined.localizedCaseInsensitiveContains("just a moment") {
            return .failure(BrowserError(message: "FR24 web returned an HTML response."))
        }
        return .success(object)
    }

    private static func stringValue(_ value: Any?) -> String {
        switch value {
        case let value as String:
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        case let value as NSNumber:
            return value.stringValue
        case is NSNull, nil:
            return ""
        default:
            return String(describing: value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if pendingPageCompletion != nil,
           let response = navigationResponse.response as? HTTPURLResponse {
            pendingPageStatus = response.statusCode
            pendingPageContentType = response.mimeType ?? response.value(forHTTPHeaderField: "Content-Type") ?? ""
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard pendingPageCompletion != nil,
              pendingPageReadStartedAt == nil,
              isCurrentPendingNavigation(navigation) else { return }
        let requestID = pendingPageRequestID
        pendingPageReadStartedAt = Date()
        readPendingPage(from: webView, after: pendingPageReadDelay, requestID: requestID)
    }

    private func readPendingPage(from webView: WKWebView, after delay: TimeInterval, requestID: UInt64) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
            guard let self,
                  self.pendingPageCompletion != nil,
                  self.pendingPageRequestID == requestID else { return }
            guard let webView else {
                self.finishPendingPage(
                    .failure(BrowserError(message: "FR24 web request failed.")),
                    requestID: requestID
                )
                return
            }
            let script = self.pendingPageReadScript
            webView.evaluateJavaScript(script) { [weak self, weak webView] result, error in
                guard let self,
                      self.pendingPageCompletion != nil,
                      self.pendingPageRequestID == requestID else { return }
                if let error {
                    self.finishPendingPage(
                        .failure(BrowserError(message: "FR24 web response could not be read: \(error.localizedDescription)")),
                        requestID: requestID
                    )
                    return
                }
                let text = result as? String ?? ""
                guard self.pendingPageWaitsForStableResult else {
                    self.finishPendingPage(.success(PageResponse(
                        status: self.pendingPageStatus,
                        contentType: self.pendingPageContentType,
                        text: text
                    )), requestID: requestID)
                    return
                }

                let metrics = self.historySnapshotMetrics(text)
                if metrics.score > self.pendingPageBestScore {
                    self.pendingPageBestScore = metrics.score
                    self.pendingPageBestText = text
                }
                if metrics.signature == self.pendingPageLastSignature {
                    self.pendingPageStableReadCount += 1
                } else {
                    self.pendingPageLastSignature = metrics.signature
                    self.pendingPageStableReadCount = 0
                }

                let elapsed = Date().timeIntervalSince(self.pendingPageReadStartedAt ?? Date())
                let isStable = elapsed >= 3.0 && self.pendingPageStableReadCount >= 2
                if isStable || elapsed >= 6.0 {
                    self.finishPendingPage(.success(PageResponse(
                        status: self.pendingPageStatus,
                        contentType: self.pendingPageContentType,
                        text: self.pendingPageBestText.isEmpty ? text : self.pendingPageBestText
                    )), requestID: requestID)
                    return
                }
                guard let webView else {
                    self.finishPendingPage(
                        .failure(BrowserError(message: "FR24 web request failed.")),
                        requestID: requestID
                    )
                    return
                }
                self.readPendingPage(from: webView, after: 0.45, requestID: requestID)
            }
        }
    }

    private func historySnapshotMetrics(_ text: String) -> (score: Int, signature: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (text.count, "invalid|\(text.count)|\(text.hashValue)")
        }
        let rows = object["rows"] as? [[String: Any]] ?? []
        let rowText = rows.map { Self.stringValue($0["text"]) }.joined(separator: "|")
        let bodyText = Self.stringValue(object["bodyText"])
        let score = rows.count * 10_000_000 + min(rowText.count, 900_000) * 10 + min(bodyText.count, 999_999)
        return (score, "\(rows.count)|\(bodyText.count)|\(rowText.hashValue)")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishPendingNavigationFailure(navigation: navigation, error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishPendingNavigationFailure(navigation: navigation, error: error)
    }

    private func isCurrentPendingNavigation(_ navigation: WKNavigation?) -> Bool {
        guard pendingPageCompletion != nil else { return false }
        guard let pendingPageNavigation, let navigation else { return true }
        return pendingPageNavigation === navigation
    }

    private func finishPendingNavigationFailure(navigation: WKNavigation?, error: Error) {
        guard isCurrentPendingNavigation(navigation) else {
            return
        }
        let requestID = pendingPageRequestID
        if (error as NSError).code == NSURLErrorCancelled {
            finishPendingPage(.failure(URLError(.cancelled)), requestID: requestID)
            return
        }
        finishPendingPage(
            .failure(BrowserError(message: "FR24 web request failed: \(error.localizedDescription)")),
            requestID: requestID
        )
    }

    private func finishPendingPage(_ result: Result<PageResponse, Error>, requestID: UInt64? = nil) {
        if let requestID, requestID != pendingPageRequestID {
            return
        }
        let completion = pendingPageCompletion
        pendingPageCompletion = nil
        pendingPageURL = nil
        pendingPageNavigation = nil
        pendingPageRequestID = 0
        pendingPageStatus = 0
        pendingPageContentType = ""
        pendingPageReadScript = ""
        pendingPageReadDelay = 0
        pendingPageWaitsForStableResult = false
        pendingPageReadStartedAt = nil
        pendingPageBestText = ""
        pendingPageBestScore = -1
        pendingPageLastSignature = ""
        pendingPageStableReadCount = 0
        completion?(result)
        scheduleIdleWebViewRelease()
    }
}
