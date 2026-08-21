import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol FR24BrowserFetching: AnyObject {
    func performJSONRequest(path: String, params: [(String, String)]) throws -> [String: Any]
    func performFlightHistoryPageRequest(flightToken: String) throws -> [String: Any]
}

/// Optional lifecycle surface implemented by Local Web's isolated browser
/// adapter. Apple keeps its existing native verification-window callbacks.
public protocol FR24BrowserSessionManaging: AnyObject {
    func openVerificationPage() throws -> [String: Any]
    func browserSessionStatusPayload() -> [String: Any]
    /// Returns browser-derived session material for the shared HTTP FR24
    /// backend. Implementations must keep the visible browser limited to the
    /// user-requested verification page.
    func browserSessionSnapshotPayload() throws -> [String: Any]
    /// Closes the explicit verification page after its session has been
    /// accepted by the shared backend.
    func closeVerificationPage() throws
    /// Apple uses a hidden WKWebView as its request transport. Local Web sets
    /// this to false so schedule/playback requests never create browser tabs.
    var performsBrowserDataRequests: Bool { get }
    func clearBrowserSession() throws
}

public extension FR24BrowserSessionManaging {
    func browserSessionSnapshotPayload() throws -> [String: Any] { [:] }
    func closeVerificationPage() throws {}
    var performsBrowserDataRequests: Bool { true }
}

struct FR24CacheExport: Sendable {
    let filename: String
    let data: Data
}

private final class FR24RequestResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var response: URLResponse?
    private var error: Error?

    func store(data: Data?, response: URLResponse?, error: Error?) {
        lock.lock()
        self.data = data
        self.response = response
        self.error = error
        lock.unlock()
    }

    func snapshot() -> (data: Data?, response: URLResponse?, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        return (data, response, error)
    }
}

final class FR24SessionPreferences: @unchecked Sendable {
    private enum Backend {
        case userDefaults(UserDefaults)
        case file(URL, FileManager)
    }

    static let standard = FR24SessionPreferences(userDefaults: .standard)

    private let backend: Backend
    private let lock = NSLock()
    private var fileValues: [String: Any]?

    init(userDefaults: UserDefaults) {
        backend = .userDefaults(userDefaults)
    }

    init(fileURL: URL, fileManager: FileManager = .default) {
        backend = .file(fileURL.standardizedFileURL, fileManager)
    }

    func string(forKey key: String) -> String? {
        switch backend {
        case let .userDefaults(defaults):
            return defaults.string(forKey: key)
        case .file:
            return withLock { loadFileValues()[key] as? String }
        }
    }

    func double(forKey key: String) -> Double {
        switch backend {
        case let .userDefaults(defaults):
            return defaults.double(forKey: key)
        case .file:
            return withLock {
                let value = loadFileValues()[key]
                if let number = value as? NSNumber { return number.doubleValue }
                if let number = value as? Double { return number }
                return 0
            }
        }
    }

    func set(_ value: Any, forKey key: String) {
        switch backend {
        case let .userDefaults(defaults):
            defaults.set(value, forKey: key)
        case .file:
            withLock {
                var values = loadFileValues()
                values[key] = value
                persistFileValues(values)
            }
        }
    }

    func removeObject(forKey key: String) {
        switch backend {
        case let .userDefaults(defaults):
            defaults.removeObject(forKey: key)
        case .file:
            withLock {
                var values = loadFileValues()
                values.removeValue(forKey: key)
                persistFileValues(values)
            }
        }
    }

    private func loadFileValues() -> [String: Any] {
        if let fileValues { return fileValues }
        guard case let .file(fileURL, _) = backend,
              let data = try? Data(contentsOf: fileURL),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fileValues = [:]
            return [:]
        }
        fileValues = values
        return values
    }

    private func persistFileValues(_ values: [String: Any]) {
        guard case let .file(fileURL, fileManager) = backend else { return }
        fileValues = values
        let parent = fileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            try? fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: 0o700)],
                ofItemAtPath: parent.path
            )
            let data = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
            try data.write(to: fileURL, options: [.atomic])
            try? fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: 0o600)],
                ofItemAtPath: fileURL.path
            )
        } catch {
            // Session persistence is best-effort. Requests still receive their
            // in-memory state, without logging cookie or token material.
        }
    }

    private func withLock<T>(_ operation: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation()
    }
}

enum FR24SessionStore {
    static let webCookieKey = "navplanner.fr24.webCookie"
    static let frPlKey = "navplanner.fr24.frPl"
    static let lastSuccessKey = "navplanner.fr24.lastSuccessAt"
    static let lastChallengeKey = "navplanner.fr24.lastChallengeAt"
    static let browserSyncKey = "navplanner.fr24.browserSyncAt"
    static let lastProbeKey = "navplanner.fr24.lastProbeAt"
    private static let availableWindow: TimeInterval = 12 * 60 * 60
    private static let challengeWindow: TimeInterval = 30 * 60
    private static let browserWarmupWindow: TimeInterval = 6

    static func accessStatusPayload(
        userDefaults: FR24SessionPreferences = .standard,
        now: Date = Date()
    ) -> [String: Any] {
        let cookieConfigured = !storedWebCookie(userDefaults: userDefaults).isEmpty
        let frPlConfigured = !storedFRPl(userDefaults: userDefaults).isEmpty
        let nowTimestamp = now.timeIntervalSince1970
        let lastSuccess = userDefaults.double(forKey: lastSuccessKey)
        let lastChallenge = userDefaults.double(forKey: lastChallengeKey)
        let browserSync = userDefaults.double(forKey: browserSyncKey)
        let lastProbe = userDefaults.double(forKey: lastProbeKey)
        let successAge = lastSuccess > 0 ? max(0, nowTimestamp - lastSuccess) : .infinity
        let challengeIsCurrent = lastChallenge > max(lastSuccess, browserSync)
            && nowTimestamp - lastChallenge <= challengeWindow
        let accessState: String
        if challengeIsCurrent {
            accessState = "challenge"
        } else if lastSuccess > 0, successAge <= availableWindow {
            accessState = "available"
        } else if lastSuccess > 0 {
            accessState = "expired"
        } else if cookieConfigured || frPlConfigured || browserSync > 0 {
            accessState = "configured"
        } else {
            // Keep the state neutral until the platform adapter has established
            // a browser session with a real request.
            accessState = "unknown"
        }
        let warmupUntil = browserSync > 0 ? browserSync + browserWarmupWindow : 0
        let warmupRemaining = max(0, Int(ceil(warmupUntil - nowTimestamp)))
        let message: String
        switch accessState {
        case "available":
            message = "FR24 最近一次访问成功。"
        case "challenge":
            message = "FR24 当前需要验证，系统会自动退避重试。"
        case "expired":
            message = "FR24 最近一次成功记录已过期，将在下次查询时重新探测。"
        case "configured":
            message = "FR24 会话已配置，等待请求验证。"
        default:
            message = "FR24 尚未探测，可直接发起查询。"
        }
        return [
            "access_state": accessState,
            "cookie_configured": cookieConfigured,
            "frpl_configured": frPlConfigured,
            "browser_cookie_detected": browserSync > 0,
            "last_success_at": lastSuccess > 0 ? lastSuccess : NSNull(),
            "last_challenge_at": lastChallenge > 0 ? lastChallenge : NSNull(),
            "browser_sync_at": browserSync > 0 ? browserSync : NSNull(),
            "last_probe_at": lastProbe > 0 ? lastProbe : NSNull(),
            "warmup_until": warmupUntil > 0 ? warmupUntil : NSNull(),
            "warmup_remaining_seconds": warmupRemaining,
            "message": message
        ]
    }

    static func recordSuccessfulAccess(userDefaults: FR24SessionPreferences = .standard, now: Date = Date()) {
        userDefaults.set(now.timeIntervalSince1970, forKey: lastSuccessKey)
        userDefaults.removeObject(forKey: lastChallengeKey)
    }

    static func recordChallenge(userDefaults: FR24SessionPreferences = .standard, now: Date = Date()) {
        userDefaults.set(now.timeIntervalSince1970, forKey: lastChallengeKey)
    }

    static func markBrowserSync(userDefaults: FR24SessionPreferences = .standard, now: Date = Date()) {
        userDefaults.set(now.timeIntervalSince1970, forKey: browserSyncKey)
    }

    static func recordProbeAttempt(userDefaults: FR24SessionPreferences = .standard, now: Date = Date()) {
        userDefaults.set(now.timeIntervalSince1970, forKey: lastProbeKey)
    }

    static func updateAccessPayload(
        webCookie: String?,
        frPl: String?,
        userDefaults: FR24SessionPreferences = .standard
    ) -> [String: Any] {
        let cookie = sanitizedHeaderSecret(webCookie)
        let token = sanitizedHeaderSecret(frPl)
        // 新保存的会话尚未经过 FR24 接受性验证，不能沿用旧会话的成功/挑战结论。
        userDefaults.removeObject(forKey: lastSuccessKey)
        userDefaults.removeObject(forKey: lastChallengeKey)
        userDefaults.removeObject(forKey: lastProbeKey)
        setSecret(cookie, forKey: webCookieKey, userDefaults: userDefaults)
        if !token.isEmpty {
            setSecret(token, forKey: frPlKey, userDefaults: userDefaults)
        } else if let embedded = cookieValue(named: "_frPl", in: cookie), !embedded.isEmpty {
            setSecret(embedded, forKey: frPlKey, userDefaults: userDefaults)
        }
        var payload = accessStatusPayload(userDefaults: userDefaults)
        payload["message"] = "已保存 FR24 Web 会话配置。"
        return payload
    }

    static func clearAccessPayload(userDefaults: FR24SessionPreferences = .standard) -> [String: Any] {
        userDefaults.removeObject(forKey: webCookieKey)
        userDefaults.removeObject(forKey: frPlKey)
        userDefaults.removeObject(forKey: lastSuccessKey)
        userDefaults.removeObject(forKey: lastChallengeKey)
        userDefaults.removeObject(forKey: browserSyncKey)
        userDefaults.removeObject(forKey: lastProbeKey)
        var payload = accessStatusPayload(userDefaults: userDefaults)
        payload["message"] = "已清除 FR24 Web 会话配置。"
        return payload
    }

    static func storedWebCookie(userDefaults: FR24SessionPreferences = .standard) -> String {
        sanitizedHeaderSecret(userDefaults.string(forKey: webCookieKey))
    }

    static func storedFRPl(userDefaults: FR24SessionPreferences = .standard) -> String {
        sanitizedHeaderSecret(userDefaults.string(forKey: frPlKey))
    }

    static func requestCookieHeader(userDefaults: FR24SessionPreferences = .standard) -> String? {
        let cookie = storedWebCookie(userDefaults: userDefaults)
        let frPl = storedFRPl(userDefaults: userDefaults)
        if cookie.isEmpty {
            return frPl.isEmpty ? nil : "_frPl=\(frPl)"
        }
        if !frPl.isEmpty, cookieValue(named: "_frPl", in: cookie) == nil {
            return "\(cookie); _frPl=\(frPl)"
        }
        return cookie
    }

    static func cookieValue(named name: String, in cookie: String) -> String? {
        let parts = cookie.split(separator: ";")
        for part in parts {
            let item = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let equals = item.firstIndex(of: "=") else { continue }
            let key = item[..<equals].trimmingCharacters(in: .whitespacesAndNewlines)
            if key == name {
                let value = item[item.index(after: equals)...].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : String(value)
            }
        }
        return nil
    }

    static func sanitizedHeaderSecret(_ value: String?) -> String {
        var text = (value ?? "")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("cookie:") {
            text = String(text.dropFirst("cookie:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func setSecret(_ value: String?, forKey key: String, userDefaults: FR24SessionPreferences) {
        let secret = sanitizedHeaderSecret(value)
        if secret.isEmpty {
            userDefaults.removeObject(forKey: key)
        } else {
            userDefaults.set(secret, forKey: key)
        }
    }
}

final class FR24Service: @unchecked Sendable {
    private struct ServiceError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let fileManager: FileManager
    private let userDefaults: FR24SessionPreferences
    private let rootDirectory: URL
    private let session: URLSession
    private let browserFetcher: FR24BrowserFetching?
    private let apiBaseURL: URL
    private let isoFormatter = ISO8601DateFormatter()

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        rootDirectory: URL? = nil,
        sessionFileURL: URL? = nil,
        browserFetcher: FR24BrowserFetching? = nil,
        apiBaseURL: URL = URL(string: "https://api.flightradar24.com")!
    ) {
        self.fileManager = fileManager
        self.userDefaults = sessionFileURL.map {
            FR24SessionPreferences(fileURL: $0, fileManager: fileManager)
        } ?? FR24SessionPreferences(userDefaults: userDefaults)
        self.browserFetcher = browserFetcher
        self.apiBaseURL = apiBaseURL
        if let rootDirectory {
            self.rootDirectory = rootDirectory.standardizedFileURL
        } else {
            let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.rootDirectory = cacheRoot
                .appendingPathComponent("NavPlanner", isDirectory: true)
                .appendingPathComponent("FR24", isDirectory: true)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 16
        configuration.timeoutIntervalForResource = 22
        configuration.httpMaximumConnectionsPerHost = 2
        self.session = URLSession(configuration: configuration)

        try? fileManager.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true)
    }

    static func extractFlightID(from text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        for pattern in [
            #"flightId=([0-9a-fA-F]{6,12})"#,
            #"/data/flights/[^/#?\s]+#([0-9a-fA-F]{6,12})"#,
            #"/flight/[^/#?\s]+#([0-9a-fA-F]{6,12})"#,
            #"FR24[:\s]+([0-9a-fA-F]{6,12})"#,
            #"#([0-9a-fA-F]{6,12})(?:$|[?&\s])"#,
            #"^([0-9a-fA-F]{6,12})$"#
        ] {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               let range = Range(match.range(at: 1), in: value) {
                return (String(value[range]).removingPercentEncoding ?? String(value[range])).lowercased()
            }
        }
        return nil
    }

    static func extractFlightNumber(from text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        for pattern in [
            #"/data/flights/([A-Za-z0-9]{2,8})"#,
            #"^([A-Za-z]{1,3}\d{1,4}[A-Za-z]?)$"#
        ] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               let range = Range(match.range(at: 1), in: value) {
                let token = String(value[range]).uppercased().filter { $0.isLetter || $0.isNumber }
                return token.isEmpty ? nil : token
            }
        }
        return nil
    }

    func cacheStatusPayload() -> [String: Any] {
        let usage = diskUsage()
        return [
            "root": rootDirectory.path,
            "file_count": usage.files,
            "size_bytes": usage.bytes,
            "message": "FR24 轨迹缓存状态已读取。"
        ]
    }

    func cacheListPayload(query: String, limit: Int) -> [String: Any] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let loweredQuery = trimmedQuery.lowercased()
        let normalizedQuery = normalizedFlightToken(trimmedQuery).lowercased()
        let clampedLimit = max(1, min(limit, 300))
        let items = cachedFlightItems()
            .filter { item in
                guard !loweredQuery.isEmpty || !normalizedQuery.isEmpty else { return true }
                let searchable = [
                    Self.stringValue(item["cache_key"]),
                    Self.stringValue(item["fr24_id"]),
                    Self.stringValue(item["flight"]),
                    Self.stringValue(item["callsign"]),
                    Self.stringValue(item["airline"]),
                    Self.stringValue(item["aircraft"]),
                    Self.stringValue(item["aircraft_registration"]),
                    Self.stringValue(item["origin_icao"]),
                    Self.stringValue(item["origin_iata"]),
                    Self.stringValue(item["origin_actual_code"]),
                    Self.stringValue(item["dest_icao"]),
                    Self.stringValue(item["dest_iata"]),
                    Self.stringValue(item["dest_actual_code"]),
                    Self.stringValue(item["gpx_filename"])
                ].joined(separator: " ").lowercased()
                let normalizedSearchable = normalizedFlightToken(searchable).lowercased()
                return (!loweredQuery.isEmpty && searchable.contains(loweredQuery))
                    || (!normalizedQuery.isEmpty && normalizedSearchable.contains(normalizedQuery))
            }
            .prefix(clampedLimit)
        return [
            "items": Array(items),
            "cache": cacheStatusPayload(),
            "message": "已读取 FR24 下载缓存。"
        ]
    }

    func accessStatusPayload() -> [String: Any] {
        var payload = FR24SessionStore.accessStatusPayload(userDefaults: userDefaults)
        guard let manager = browserFetcher as? FR24BrowserSessionManaging else {
            payload["access_method"] = "web_session"
            return payload
        }
        let browser = manager.browserSessionStatusPayload()
        payload["access_method"] = "managed_browser"
        payload["managed_browser"] = browser
        payload["browser_adapter_available"] = browser["available"] as? Bool ?? false
        payload["browser_running"] = browser["running"] as? Bool ?? false
        return payload
    }

    func updateAccessPayload(webCookie: String?, frPl: String?) -> [String: Any] {
        FR24SessionStore.updateAccessPayload(
            webCookie: webCookie,
            frPl: frPl,
            userDefaults: userDefaults
        )
    }

    func clearAccessPayload() -> [String: Any] {
        if let manager = browserFetcher as? FR24BrowserSessionManaging {
            try? manager.clearBrowserSession()
        }
        _ = FR24SessionStore.clearAccessPayload(userDefaults: userDefaults)
        var payload = accessStatusPayload()
        payload["message"] = "已清除 FR24 浏览器会话与兼容配置。"
        return payload
    }

    func openBrowserVerificationPayload() -> [String: Any] {
        guard let manager = browserFetcher as? FR24BrowserSessionManaging else {
            return ["error": "FR24 managed browser is unavailable.", "access": accessStatusPayload()]
        }
        do {
            var payload = try manager.openVerificationPage()
            payload["access"] = accessStatusPayload()
            return payload
        } catch {
            return ["error": error.localizedDescription, "access": accessStatusPayload()]
        }
    }

    func syncBrowserSessionPayload() -> [String: Any] {
        guard let manager = browserFetcher as? FR24BrowserSessionManaging else {
            return ["error": "FR24 managed browser is unavailable.", "access": accessStatusPayload()]
        }

        do {
            let snapshot = try manager.browserSessionSnapshotPayload()
            let webCookie = Self.stringValue(snapshot["web_cookie"])
            let frPl = Self.stringValue(snapshot["frpl"])
            let hasSnapshot = !webCookie.isEmpty || !frPl.isEmpty
            if !snapshot.isEmpty, !hasSnapshot {
                var payload = accessStatusPayload()
                payload["verified"] = false
                payload["probe_result"] = "waiting_for_verification"
                payload["automatic_sync"] = true
                payload["message"] = "正在等待 FR24 验证完成，会话将在完成后自动同步。"
                return payload
            }
            if hasSnapshot {
                _ = FR24SessionStore.updateAccessPayload(
                    webCookie: webCookie,
                    frPl: frPl,
                    userDefaults: userDefaults
                )
            }
        } catch {
            var payload = accessStatusPayload()
            payload["verified"] = false
            payload["probe_result"] = "waiting_for_verification"
            payload["automatic_sync"] = true
            payload["message"] = "正在等待 FR24 验证完成，会话将在完成后自动同步。"
            return payload
        }

        FR24SessionStore.markBrowserSync(userDefaults: userDefaults)
        var payload = probeAccessPayload()
        payload["automatic_sync"] = true
        if payload["verified"] as? Bool == true {
            do {
                try manager.closeVerificationPage()
                payload["verification_closed"] = true
                payload["message"] = "FR24 会话已自动同步，验证页已关闭。"
            } catch {
                payload["verification_closed"] = false
            }
        }
        return payload
    }

    func probeAccessPayload() -> [String: Any] {
        FR24SessionStore.recordProbeAttempt(userDefaults: userDefaults)
        let managedBrowserConfigured = browserFetcher is FR24BrowserSessionManaging
            && userDefaults.double(forKey: FR24SessionStore.browserSyncKey) > 0
        let configured = managedBrowserConfigured
            || !FR24SessionStore.storedWebCookie(userDefaults: userDefaults).isEmpty
            || !FR24SessionStore.storedFRPl(userDefaults: userDefaults).isEmpty
        guard configured else {
            var payload = accessStatusPayload()
            payload["verified"] = false
            payload["probe_result"] = "missing_session"
            payload["error"] = "FR24 Web 会话尚未保存。"
            payload["message"] = "请先打开 FR24 验证页并同步会话。"
            return payload
        }

        do {
            _ = try webGet(
                path: "/common/v1/airport.json",
                params: [
                    ("code", "ATH"),
                    ("plugin[]", "schedule"),
                    ("plugin-setting[schedule][mode]", "departures"),
                    ("page", "1"),
                    ("limit", "1")
                ],
                useBrowser: managedBrowserConfigured,
                retryChallenge: false
            )
            var payload = accessStatusPayload()
            payload["verified"] = true
            payload["probe_result"] = "available"
            payload["message"] = "FR24 会话已验证，可执行在线查询。"
            return payload
        } catch {
            if Self.isChallengeLikeRequestError(error.localizedDescription) {
                FR24SessionStore.recordChallenge(userDefaults: userDefaults)
            }
            var payload = accessStatusPayload()
            payload["verified"] = false
            payload["probe_result"] = "failed"
            payload["error"] = error.localizedDescription
            payload["message"] = "FR24 尚未接受已保存会话，请重新验证后重试。"
            return payload
        }
    }

    func clearCachePayload(includeFavorites: Bool = false) -> [String: Any] {
        let favoriteKeys = Set(cachedFlightItems()
            .filter { ($0["favorite"] as? Bool) == true }
            .map { Self.stringValue($0["cache_key"]) }
            .filter { !$0.isEmpty })
        let favoritePaths = Set(favoriteKeys.flatMap { cacheKey in
            cacheFileURLs(cacheKey: cacheKey).map { $0.standardizedFileURL.path }
        })
        var preservedFavorites = 0
        if let items = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil,
            options: []
        ) {
            for item in items {
                if !includeFavorites && favoritePaths.contains(item.standardizedFileURL.path) {
                    preservedFavorites += 1
                    continue
                }
                try? fileManager.removeItem(at: item)
            }
        }
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        var payload = cacheStatusPayload()
        payload["preserved_favorite_file_count"] = preservedFavorites
        payload["favorite_count"] = includeFavorites ? 0 : favoriteKeys.count
        payload["message"] = includeFavorites ? "已清理全部 FR24 轨迹缓存。" : "已清理 FR24 轨迹缓存。"
        return payload
    }

    func deleteCacheItemPayload(cacheKey: String) -> [String: Any] {
        let normalizedKey = sanitizeCacheKey(cacheKey)
        guard !normalizedKey.isEmpty else {
            return ["error": "FR24 cache key missing.", "cache": cacheStatusPayload()]
        }
        var removed = 0
        for url in cacheFileURLs(cacheKey: normalizedKey) where fileManager.fileExists(atPath: url.path) {
            if (try? fileManager.removeItem(at: url)) != nil {
                removed += 1
            }
        }
        guard removed > 0 else {
            return ["error": "FR24 cache item not found.", "cache": cacheStatusPayload()]
        }
        return [
            "cache_key": normalizedKey,
            "removed_file_count": removed,
            "cache": cacheStatusPayload(),
            "message": "已删除 FR24 缓存文件。"
        ]
    }

    func updateCacheFavoritePayload(cacheKey: String, favorite: Bool) -> [String: Any] {
        let normalizedKey = sanitizeCacheKey(cacheKey)
        guard !normalizedKey.isEmpty else {
            return ["error": "FR24 cache key missing.", "cache": cacheStatusPayload()]
        }
        guard var meta = readCacheMeta(cacheKey: normalizedKey) else {
            return ["error": "FR24 cache item not found.", "cache": cacheStatusPayload()]
        }
        meta["favorite"] = favorite
        writeCacheMeta(meta, cacheKey: normalizedKey)
        guard let item = cacheItem(cacheKey: normalizedKey, meta: meta) else {
            return ["error": "FR24 cache item not found.", "cache": cacheStatusPayload()]
        }
        return [
            "item": item,
            "cache": cacheStatusPayload(),
            "message": favorite ? "已收藏 FR24 缓存文件。" : "已取消收藏 FR24 缓存文件。"
        ]
    }

    func shareCacheItemPayload(cacheKey: String) -> [String: Any] {
        let normalizedKey = sanitizeCacheKey(cacheKey)
        guard !normalizedKey.isEmpty else {
            return ["error": "FR24 cache key missing.", "cache": cacheStatusPayload()]
        }
        guard var meta = readCacheMeta(cacheKey: normalizedKey) else {
            return ["error": "FR24 cache item not found.", "cache": cacheStatusPayload()]
        }
        let trackPoints = meta["track_points"] as? [[String: Any]] ?? []
        var flight = (meta["flight"] as? [String: Any]) ?? [:]
        if Self.stringValue(flight["fr24_id"]).isEmpty {
            flight["fr24_id"] = normalizedKey
        }
        flight["cache_key"] = normalizedKey
        let targetURL: URL
        if trackPoints.count >= 2,
           let gpxURL = try? writeGPXCacheFile(
            cacheKey: normalizedKey,
            flight: flight,
            trackPoints: trackPoints,
            previousMeta: meta
           ) {
            meta["gpx_filename"] = gpxURL.lastPathComponent
            meta["gpx_path"] = gpxURL.path
            meta["flight"] = flight
            writeCacheMeta(meta, cacheKey: normalizedKey)
            targetURL = gpxURL
        } else if let sourceURL = cacheGPXURL(cacheKey: normalizedKey, meta: meta),
                  fileManager.fileExists(atPath: sourceURL.path) {
            let shareDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("NavPlannerFR24Share", isDirectory: true)
            try? fileManager.createDirectory(at: shareDirectory, withIntermediateDirectories: true)
            let filename = displayGPXFilename(cacheKey: normalizedKey, flight: flight, trackPoints: trackPoints)
            let shareURL = shareDirectory.appendingPathComponent(filename)
            try? fileManager.removeItem(at: shareURL)
            do {
                try fileManager.copyItem(at: sourceURL, to: shareURL)
                targetURL = shareURL
            } catch {
                return [
                    "error": "无法准备 FR24 GPX 分享文件：\(error.localizedDescription)",
                    "cache": cacheStatusPayload()
                ]
            }
        } else {
            return ["error": "FR24 cache GPX file not found.", "cache": cacheStatusPayload()]
        }
        return [
            "cache_key": normalizedKey,
            "filename": targetURL.lastPathComponent,
            "share_path": targetURL.path,
            "gpx_path": targetURL.path,
            "cache": cacheStatusPayload(),
            "message": "已准备 FR24 GPX 分享文件。"
        ]
    }

    func cacheExport(cacheKey: String) -> FR24CacheExport? {
        let payload = shareCacheItemPayload(cacheKey: cacheKey)
        guard payload["error"] == nil,
              let path = payload["share_path"] as? String,
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        let rawFilename = payload["filename"] as? String ?? "simnav-fr24.gpx"
        let filename = URL(fileURLWithPath: rawFilename).lastPathComponent
        guard !filename.isEmpty else { return nil }
        return FR24CacheExport(filename: filename, data: data)
    }

    func searchPayload(routeAirports: [String: Any], limit: Int) -> [String: Any] {
        let clampedLimit = max(1, min(limit, 10))
        do {
            let flights = try routeFlights(
                routeAirports: routeAirports,
                limit: clampedLimit,
                flightNumber: "",
                callsign: "",
                lookbackHours: 720
            )
            if flights.isEmpty {
                return [
                    "error": "FR24 web did not find recent flights for this route.",
                    "flights": [],
                    "cache": cacheStatusPayload(),
                    "access": accessStatusPayload()
                ]
            }
            return [
                "route": routeAirports,
                "flights": flights,
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload(),
                "message": "已读取 FR24 航线查询结果。"
            ]
        } catch {
            return [
                "error": error.localizedDescription,
                "flights": [],
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload()
            ]
        }
    }

    func historyPayload(
        routeAirports: [String: Any],
        flightNumber: String,
        callsign: String,
        limit: Int
    ) -> [String: Any] {
        let token = normalizedFlightToken(flightNumber).isEmpty
            ? normalizedFlightToken(callsign)
            : normalizedFlightToken(flightNumber)
        guard !token.isEmpty else {
            return [
                "error": "FR24 flight number missing.",
                "flights": [],
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload()
            ]
        }
        let clampedLimit = limit <= 0 ? 0 : max(1, min(limit, 100))
        do {
            let flights: [[String: Any]]
            if let browserFetcher, shouldUseBrowserDataRequests {
                let page = try browserFetcher.performFlightHistoryPageRequest(flightToken: token)
                FR24SessionStore.recordSuccessfulAccess(userDefaults: userDefaults)
                flights = parseFlightHistoryPage(
                    page,
                    flightToken: token,
                    routeAirports: routeAirports,
                    limit: clampedLimit
                )
            } else {
                flights = try routeFlights(
                    routeAirports: routeAirports,
                    limit: clampedLimit == 0 ? 100 : clampedLimit,
                    flightNumber: token,
                    callsign: "",
                    lookbackHours: 720
                )
            }
            return [
                "route": routeAirports,
                "flights": flights,
                "history_url": "https://www.flightradar24.com/data/flights/\(token.lowercased())",
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload(),
                "message": flights.isEmpty ? "未找到该航班号的 FR24 历史记录。" : "已读取 FR24 航班历史。"
            ]
        } catch {
            if Self.isChallengeLikeRequestError(error.localizedDescription) {
                FR24SessionStore.recordChallenge(userDefaults: userDefaults)
            }
            return [
                "error": error.localizedDescription,
                "flights": [],
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload()
            ]
        }
    }

    func manualHistoryPayload(
        routeAirports: [String: Any],
        query: String,
        limit: Int
    ) -> [String: Any] {
        let rawQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawQuery.isEmpty else {
            return [
                "error": "FR24 flight number missing.",
                "flights": [],
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload()
            ]
        }
        if let tokenFromURL = Self.extractFlightNumber(from: rawQuery) {
            return historyPayload(routeAirports: routeAirports, flightNumber: tokenFromURL, callsign: "", limit: limit)
        }
        if let flightID = Self.extractFlightID(from: rawQuery),
           normalizedFlightToken(rawQuery).lowercased() == flightID.lowercased() {
            var flight = manualFlightIDPayload(flightID: flightID)
            var message = "已按 FR24 flightId 生成单条历史记录。"
            do {
                let playback = try webGet(path: "/common/v1/flight-playback.json", params: [
                    ("flightId", flightID),
                    ("timestamp", String(Int(Date().timeIntervalSince1970)))
                ])
                let trackPoints = extractPlaybackTrackPoints(playback)
                flight = enrichedFlightPayload(
                    flightID: flightID,
                    flight: flight,
                    playback: playback,
                    trackPoints: trackPoints,
                    routeAirports: routeAirports
                )
                message = "已按 FR24 flightId 读取航班基本信息。"
            } catch {
                flight["metadata_error"] = error.localizedDescription
            }
            return [
                "route": routeAirports,
                "flights": [flight],
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload(),
                "message": message
            ]
        }
        return historyPayload(routeAirports: routeAirports, flightNumber: rawQuery, callsign: "", limit: limit)
    }

    private func manualFlightIDPayload(flightID: String) -> [String: Any] {
        [
            "fr24_id": flightID,
            "flight": "",
            "callsign": "",
            "airline": "",
            "aircraft": "",
            "aircraft_registration": "",
            "origin_icao": "",
            "origin_iata": "",
            "origin_actual_code": "",
            "origin_name": "",
            "dest_icao": "",
            "dest_iata": "",
            "dest_actual_code": "",
            "dest_name": "",
            "status": "flightId",
            "timestamp": 0,
            "scheduled_departure": NSNull(),
            "scheduled_arrival": NSNull(),
            "actual_departure": NSNull(),
            "actual_arrival": NSNull(),
            "estimated_departure": NSNull(),
            "estimated_arrival": NSNull(),
            "duration_seconds": NSNull(),
            "source_provider": "Flightradar24 flightId"
        ]
    }

    private func enrichedFlightPayload(
        flightID: String,
        flight: [String: Any],
        playback: [String: Any],
        trackPoints: [[String: Any]],
        routeAirports: [String: Any] = [:]
    ) -> [String: Any] {
        let departure = routeAirports["departure"] as? [String: Any] ?? [:]
        let arrival = routeAirports["arrival"] as? [String: Any] ?? [:]
        let candidates = playbackFlightInfoCandidates(playback)
        let best = candidates
            .map { normalizeOfficialFlight($0, departure: departure, arrival: arrival) }
            .max { flightInfoScore($0) < flightInfoScore($1) }
        var output = best ?? manualFlightIDPayload(flightID: flightID)
        output["fr24_id"] = Self.stringValue(output["fr24_id"]).isEmpty ? flightID : Self.stringValue(output["fr24_id"])

        for (key, value) in flight where !hasMeaningfulFlightValue(output[key]) && hasMeaningfulFlightValue(value) {
            output[key] = value
        }
        if !hasMeaningfulFlightValue(output["timestamp"]),
           let firstTimestamp = trackPoints.compactMap({ Self.intValue($0["timestamp"]) }).map(normalizedTimestamp).first {
            output["timestamp"] = firstTimestamp
        }
        if !hasMeaningfulFlightValue(output["actual_departure"]),
           let firstTimestamp = trackPoints.compactMap({ Self.intValue($0["timestamp"]) }).map(normalizedTimestamp).first {
            output["actual_departure"] = firstTimestamp
        }
        if Self.stringValue(output["source_provider"]).isEmpty {
            output["source_provider"] = "Flightradar24 playback"
        }
        return output
    }

    private func playbackFlightInfoCandidates(_ payload: [String: Any]) -> [[String: Any]] {
        var candidates: [[String: Any]] = []
        func visit(_ item: Any) {
            guard candidates.count < 300 else { return }
            if let dictionary = item as? [String: Any] {
                candidates.append(dictionary)
                dictionary.values.forEach(visit)
            } else if let array = item as? [Any], array.count < 80 {
                array.forEach(visit)
            }
        }
        visit(payload)
        return candidates
    }

    private func flightInfoScore(_ flight: [String: Any]) -> Int {
        var score = 0
        if !Self.stringValue(flight["flight"]).isEmpty { score += 6 }
        if !Self.stringValue(flight["callsign"]).isEmpty { score += 4 }
        if !Self.stringValue(flight["aircraft_registration"]).isEmpty { score += 5 }
        if !Self.stringValue(flight["aircraft"]).isEmpty { score += 2 }
        if !Self.stringValue(flight["airline"]).isEmpty { score += 2 }
        if !Self.stringValue(flight["origin_icao"]).isEmpty || !Self.stringValue(flight["origin_iata"]).isEmpty { score += 2 }
        if !Self.stringValue(flight["dest_icao"]).isEmpty || !Self.stringValue(flight["dest_iata"]).isEmpty { score += 2 }
        if hasMeaningfulFlightValue(flight["actual_departure"]) || hasMeaningfulFlightValue(flight["scheduled_departure"]) { score += 3 }
        if hasMeaningfulFlightValue(flight["timestamp"]) { score += 2 }
        return score
    }

    private func hasMeaningfulFlightValue(_ value: Any?) -> Bool {
        switch value {
        case let value as String:
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case let value as NSNumber:
            return value.doubleValue != 0
        case let value as Int:
            return value != 0
        case let value as Double:
            return value.isFinite && value != 0
        case is NSNull, nil:
            return false
        default:
            return !Self.stringValue(value).isEmpty
        }
    }

    private func parseFlightHistoryPage(
        _ payload: [String: Any],
        flightToken: String,
        routeAirports: [String: Any],
        limit: Int
    ) -> [[String: Any]] {
        let departure = routeAirports["departure"] as? [String: Any] ?? [:]
        let arrival = routeAirports["arrival"] as? [String: Any] ?? [:]
        let pageTitle = Self.stringValue(payload["title"])
        let pageURL = Self.stringValue(payload["url"]).isEmpty
            ? "https://www.flightradar24.com/data/flights/\(flightToken.lowercased())"
            : Self.stringValue(payload["url"])
        let airline = airlineName(from: pageTitle, flightToken: flightToken)
        let rows = historyRows(from: payload)
        var flights: [[String: Any]] = []
        var seen = Set<String>()

        for row in rows {
            let text = row.text
            if !historyRowLooksLikeFlight(text, hrefs: row.hrefs, flightToken: flightToken) {
                continue
            }
            let flightID = row.hrefs.compactMap(Self.extractFlightID(from:)).first
                ?? Self.extractFlightID(from: text)
            let fieldMap = historyFieldMap(headers: row.headers, cells: row.cells)
            let dateTimestamp = firstHistoryDate(in: Self.stringValue(fieldMap["date"])) ?? firstHistoryDate(in: text)
            let scheduledDeparture = timeFromHistoryCell(Self.stringValue(fieldMap["std"]), preferredDate: dateTimestamp)
                ?? labeledTime("STD", in: text, preferredDate: dateTimestamp)
            let actualDeparture = timeFromHistoryCell(Self.stringValue(fieldMap["atd"]), preferredDate: dateTimestamp)
                ?? labeledTime("ATD", in: text, preferredDate: dateTimestamp)
                ?? labeledTime("DEP", in: text, preferredDate: dateTimestamp)
                ?? statusTimeFromHistoryCell(Self.stringValue(fieldMap["status"]), statusWords: ["Departed"], preferredDate: dateTimestamp)
                ?? statusTimeFromHistoryCell(text, statusWords: ["Departed"], preferredDate: dateTimestamp)
            let scheduledArrival = timeFromHistoryCell(
                Self.stringValue(fieldMap["sta"]),
                preferredDate: dateTimestamp,
                rollAfter: scheduledDeparture ?? actualDeparture
            ) ?? labeledTime("STA", in: text, preferredDate: dateTimestamp, rollAfter: scheduledDeparture ?? actualDeparture)
            let actualArrival = statusTimeFromHistoryCell(
                Self.stringValue(fieldMap["status"]),
                statusWords: ["Landed", "Arrived"],
                preferredDate: dateTimestamp,
                rollAfter: actualDeparture ?? scheduledDeparture
            ) ?? labeledTime("ATA", in: text, preferredDate: dateTimestamp, rollAfter: actualDeparture ?? scheduledDeparture)
                ?? statusTimeFromHistoryCell(text, statusWords: ["Landed", "Arrived"], preferredDate: dateTimestamp, rollAfter: actualDeparture ?? scheduledDeparture)
            let estimatedArrival = timeFromHistoryCell(
                Self.stringValue(fieldMap["eta"]),
                preferredDate: dateTimestamp,
                rollAfter: scheduledDeparture ?? actualDeparture
            ) ?? statusTimeFromHistoryCell(
                Self.stringValue(fieldMap["status"]),
                statusWords: ["Estimated", "ETA"],
                preferredDate: dateTimestamp,
                rollAfter: actualDeparture ?? scheduledDeparture
            ) ?? labeledTime("ETA", in: text, preferredDate: dateTimestamp, rollAfter: scheduledDeparture ?? actualDeparture)
            let duration = durationFromHistoryCell(Self.stringValue(fieldMap["flight_time"]))
                ?? durationFromHistoryText(text)
                ?? positiveDuration(departure: actualDeparture ?? scheduledDeparture, arrival: actualArrival ?? estimatedArrival ?? scheduledArrival)
            let aircraftInfo = aircraftFromHistoryText(Self.stringValue(fieldMap["aircraft"]))
                ?? aircraftFromHistoryText(text)
                ?? ("", "")
            let originCode = airportCodeFromHistoryCell(Self.stringValue(fieldMap["from"]))
            let destinationCode = airportCodeFromHistoryCell(Self.stringValue(fieldMap["to"]))
            let statusFromCell = statusFromHistoryText(Self.stringValue(fieldMap["status"]))
            let status = statusFromCell.isEmpty ? statusFromHistoryText(text) : statusFromCell
            var publicFlight: [String: Any] = [
                "fr24_id": flightID ?? "",
                "flight": flightToken,
                "callsign": flightToken,
                "airline": airline,
                "aircraft": aircraftInfo.type,
                "aircraft_registration": aircraftInfo.registration,
                "origin_icao": Self.stringValue(departure["icao"]),
                "origin_iata": Self.stringValue(departure["iata"]),
                "origin_name": Self.stringValue(departure["name"]),
                "dest_icao": Self.stringValue(arrival["icao"]),
                "dest_iata": Self.stringValue(arrival["iata"]),
                "dest_name": Self.stringValue(arrival["name"]),
                "status": status,
                "history_url": pageURL,
                "raw_history": text,
                "timestamp": actualDeparture ?? scheduledDeparture ?? dateTimestamp ?? 0,
                "source_provider": "Flightradar24 data page"
            ]
            annotateActualAirports(
                &publicFlight,
                expectedDeparture: departure,
                expectedArrival: arrival,
                parsedOriginCode: originCode,
                parsedDestinationCode: destinationCode
            )
            publicFlight["scheduled_departure"] = scheduledDeparture ?? NSNull()
            publicFlight["scheduled_arrival"] = scheduledArrival ?? NSNull()
            publicFlight["actual_departure"] = actualDeparture ?? NSNull()
            publicFlight["actual_arrival"] = actualArrival ?? NSNull()
            publicFlight["estimated_departure"] = NSNull()
            publicFlight["estimated_arrival"] = estimatedArrival ?? NSNull()
            publicFlight["duration_seconds"] = duration ?? NSNull()

            let dedupeKey = (flightID?.isEmpty == false ? flightID! : "\(flightToken)|\(Self.stringValue(publicFlight["timestamp"]))|\(text.prefix(160))").lowercased()
            if seen.contains(dedupeKey) {
                continue
            }
            seen.insert(dedupeKey)
            flights.append(publicFlight)
            if limit > 0, flights.count >= limit {
                break
            }
        }
        return sortedFlights(flights)
    }

    private func airportCodeSet(_ airport: [String: Any]) -> Set<String> {
        [
            Self.stringValue(airport["icao"]),
            Self.stringValue(airport["iata"]),
            Self.stringValue(airport["schedule_code"])
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
            .reduce(into: Set<String>()) { result, code in result.insert(code) }
    }

    private func annotateActualAirports(
        _ flight: inout [String: Any],
        expectedDeparture: [String: Any],
        expectedArrival: [String: Any],
        parsedOriginCode: String,
        parsedDestinationCode: String
    ) {
        let departureCodes = airportCodeSet(expectedDeparture)
        let arrivalCodes = airportCodeSet(expectedArrival)
        let actualOrigin = parsedOriginCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let actualDestination = parsedDestinationCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var mismatch = false
        if !actualOrigin.isEmpty, !departureCodes.contains(actualOrigin) {
            flight["origin_actual_code"] = actualOrigin
            mismatch = true
        }
        if !actualDestination.isEmpty, !arrivalCodes.contains(actualDestination) {
            flight["dest_actual_code"] = actualDestination
            mismatch = true
        }
        if mismatch {
            flight["actual_route_mismatch"] = true
        }
    }

    private func historyRows(from payload: [String: Any]) -> [(text: String, hrefs: [String], cells: [String], headers: [String])] {
        var rows: [(text: String, hrefs: [String], cells: [String], headers: [String])] = []
        if let rawRows = payload["rows"] as? [[String: Any]] {
            for rawRow in rawRows {
                let text = Self.stringValue(rawRow["text"])
                let hrefs = hrefs(from: rawRow["hrefs"])
                let cells = Self.stringArray(rawRow["cells"])
                let headers = Self.stringArray(rawRow["headers"])
                if !text.isEmpty {
                    rows.append((text, hrefs, cells, headers))
                }
            }
        }
        if rows.isEmpty, let links = payload["links"] as? [[String: Any]] {
            for link in links {
                let rowText = Self.stringValue(link["rowText"])
                let href = Self.stringValue(link["href"])
                if !rowText.isEmpty {
                    rows.append((rowText, href.isEmpty ? [] : [href], [], []))
                }
            }
        }
        return rows
    }

    private func historyFieldMap(headers: [String], cells: [String]) -> [String: String] {
        var fields: [String: String] = [:]

        func normalizedHeader(_ value: String) -> String {
            let lowercased = value.lowercased()
            if lowercased.contains("date") { return "date" }
            if lowercased == "flight" || lowercased.contains("flight no") || lowercased.contains("flight number") { return "flight" }
            if lowercased == "from" || lowercased.contains("origin") || lowercased.contains("from") { return "from" }
            if lowercased == "to" || lowercased.contains("destination") || lowercased.contains("arrival airport") { return "to" }
            if lowercased.contains("aircraft") { return "aircraft" }
            if lowercased.contains("flight time") || lowercased.contains("duration") { return "flight_time" }
            if lowercased.contains("std") { return "std" }
            if lowercased.contains("atd") { return "atd" }
            if lowercased.contains("sta") { return "sta" }
            if lowercased.contains("ata") { return "ata" }
            if lowercased.contains("eta") { return "eta" }
            if lowercased.contains("status") { return "status" }
            return ""
        }

        func assign(_ key: String, _ value: String) {
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !cleaned.isEmpty, fields[key, default: ""].isEmpty {
                fields[key] = cleaned
            }
        }

        func labeledCell(_ cell: String) -> (String, String)? {
            let labels: [(String, String)] = [
                ("flight time", "flight_time"),
                ("duration", "flight_time"),
                ("aircraft", "aircraft"),
                ("status", "status"),
                ("date", "date"),
                ("from", "from"),
                ("origin", "from"),
                ("to", "to"),
                ("destination", "to"),
                ("std", "std"),
                ("atd", "atd"),
                ("sta", "sta"),
                ("ata", "ata"),
                ("eta", "eta")
            ]
            let cleaned = cell
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = cleaned.lowercased()
            for (label, key) in labels {
                if lowercased == label {
                    return nil
                }
                if lowercased.hasPrefix(label) {
                    let suffix = lowercased.dropFirst(label.count)
                    if let first = suffix.first,
                       !first.isWhitespace,
                       first != ":",
                       first != "-",
                       first != "–" {
                        continue
                    }
                    var value = String(cleaned.dropFirst(label.count))
                        .trimmingCharacters(in: CharacterSet(charactersIn: " :\n\t-"))
                    if value.isEmpty,
                       let range = cleaned.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: label) + #"\b\s*[:\-]?\s*(.+)$"#, options: [.regularExpression, .caseInsensitive]) {
                        value = String(cleaned[range]).replacingOccurrences(
                            of: #"\b"# + NSRegularExpression.escapedPattern(for: label) + #"\b\s*[:\-]?\s*"#,
                            with: "",
                            options: [.regularExpression, .caseInsensitive]
                        )
                    }
                    return value.isEmpty ? nil : (key, value)
                }
            }
            return nil
        }

        func cellLooksLikeFlightNumber(_ cell: String) -> Bool {
            let cleaned = cell
                .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
                .uppercased()
            guard let regex = try? NSRegularExpression(pattern: #"^[A-Z]{1,3}\d{1,4}[A-Z]?$"#) else {
                return false
            }
            return regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) != nil
        }

        func cellLooksLikeDate(_ cell: String) -> Bool {
            firstHistoryDate(in: cell) != nil
        }

        for (index, header) in headers.enumerated() where index < cells.count {
            let key = normalizedHeader(header)
            assign(key, cells[index])
        }

        for cell in cells {
            if let (key, value) = labeledCell(cell) {
                assign(key, value)
            }
        }

        if cells.count >= 8 {
            let fallbackKeys = ["date", "from", "to", "aircraft", "flight_time", "std", "atd", "sta", "status"]
            let fallbackWithFlightKeys = ["date", "flight", "from", "to", "aircraft", "flight_time", "std", "atd", "sta", "status"]
            let startIndex = cells.firstIndex(where: cellLooksLikeDate) ?? 0
            let remaining = Array(cells.dropFirst(startIndex))
            let keys = remaining.count >= fallbackWithFlightKeys.count || (remaining.count >= 9 && remaining.indices.contains(1) && cellLooksLikeFlightNumber(remaining[1]))
                ? fallbackWithFlightKeys
                : fallbackKeys
            for (index, key) in keys.enumerated() where index < remaining.count {
                assign(key, remaining[index])
            }
        }
        return fields
    }

    private func hrefs(from value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings.filter { !$0.isEmpty }
        }
        guard let items = value as? [[String: Any]] else {
            return []
        }
        return items.flatMap { item in
            [Self.stringValue(item["href"]), Self.stringValue(item["text"]), Self.stringValue(item["title"])]
        }.filter { !$0.isEmpty }
    }

    private func historyRowLooksLikeFlight(_ text: String, hrefs: [String], flightToken: String) -> Bool {
        let lowercased = text.lowercased()
        let hasDate = firstHistoryDate(in: text) != nil
        let hasFlightID = hrefs.contains { Self.extractFlightID(from: $0) != nil }
        let statusTerms = [
            "std", "atd", "sta", "eta", "landed", "scheduled", "cancelled", "canceled",
            "diverted", "unknown", "kml", "csv", "play"
        ]
        let hasStatus = statusTerms.contains { lowercased.contains($0) }
        let hasToken = normalizedFlightToken(text).contains(flightToken)
        return (hasDate || hasFlightID) && (hasStatus || hasFlightID || hasToken)
    }

    private func airlineName(from pageTitle: String, flightToken: String) -> String {
        let cleaned = pageTitle
            .replacingOccurrences(of: "| Flightradar24", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "Flightradar24", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "Flight Tracker", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: flightToken, with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: " - ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "" : cleaned
    }

    private func firstHistoryDate(in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d{1,2})\s+([A-Za-z]{3})\s+(20\d{2})\b"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let dayRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let yearRange = Range(match.range(at: 3), in: text) else {
            return nil
        }
        let dateText = "\(text[dayRange]) \(text[monthRange]) \(text[yearRange])"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "d MMM yyyy"
        guard let date = formatter.date(from: dateText) else {
            return nil
        }
        return Int(date.timeIntervalSince1970)
    }

    private func timeFromHistoryCell(_ text: String, preferredDate: Int?, rollAfter: Int? = nil) -> Int? {
        guard let dateStart = preferredDate,
              let regex = try? NSRegularExpression(pattern: #"\b([0-2]?\d):([0-5]\d)\b"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hours = Int(text[hourRange]),
              let minutes = Int(text[minuteRange]) else {
            return nil
        }
        var timestamp = dateStart + hours * 3600 + minutes * 60
        if let rollAfter, timestamp + 6 * 3600 < rollAfter {
            timestamp += 24 * 3600
        }
        return timestamp
    }

    private func labeledTime(_ label: String, in text: String, preferredDate: Int?, rollAfter: Int? = nil) -> Int? {
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: label) + #"\s+([0-2]?\d:[0-5]\d)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let timeRange = Range(match.range(at: 1), in: text),
              let dateStart = preferredDate else {
            return nil
        }
        let parts = text[timeRange].split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else {
            return nil
        }
        var timestamp = dateStart + parts[0] * 3600 + parts[1] * 60
        if let rollAfter, timestamp + 6 * 3600 < rollAfter {
            timestamp += 24 * 3600
        }
        return timestamp
    }

    private func statusTimeFromHistoryCell(
        _ text: String,
        statusWords: [String],
        preferredDate: Int?,
        rollAfter: Int? = nil
    ) -> Int? {
        guard let preferredDate,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let words = statusWords
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        let pattern = #"\b(?:"# + words + #")\b[^\d]{0,24}([0-2]?\d:[0-5]\d)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let timeRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return timeFromHistoryCell(String(text[timeRange]), preferredDate: preferredDate, rollAfter: rollAfter)
    }

    private func durationFromHistoryText(_ text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"\b(?:Landed|Arrived|Flight time|Duration)\s+(\d{1,2}):([0-5]\d)\b"#, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hours = Int(text[hourRange]),
              let minutes = Int(text[minuteRange]) else {
            return nil
        }
        return hours * 3600 + minutes * 60
    }

    private func durationFromHistoryCell(_ text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"^\s*(\d{1,2}):([0-5]\d)\s*$"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hours = Int(text[hourRange]),
              let minutes = Int(text[minuteRange]) else {
            return nil
        }
        return hours * 3600 + minutes * 60
    }

    private func aircraftFromHistoryText(_ text: String) -> (type: String, registration: String)? {
        if let regex = try? NSRegularExpression(pattern: #"\b([A-Z0-9]{3,5})\s*\(([A-Z0-9-]{3,12})\)"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let typeRange = Range(match.range(at: 1), in: text),
           let registrationRange = Range(match.range(at: 2), in: text) {
            return (String(text[typeRange]), String(text[registrationRange]))
        }
        if let regex = try? NSRegularExpression(pattern: #"\b(A[0-9][A-Z0-9]{2}|B[0-9][A-Z0-9]{2}|E[0-9]{3}|CRJ[0-9]{1,3}|AT[0-9]{2}|DH[0-9A-Z]{2}|C[0-9]{3})\b"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let typeRange = Range(match.range(at: 1), in: text) {
            return (String(text[typeRange]), "")
        }
        return nil
    }

    private func airportCodeFromHistoryCell(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\(([A-Z0-9]{3,4})\)"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return ""
        }
        return String(text[range]).uppercased()
    }

    private func statusFromHistoryText(_ text: String) -> String {
        for status in ["Landed", "Scheduled", "Cancelled", "Canceled", "Diverted", "Unknown", "Estimated"] {
            if text.range(of: status, options: [.caseInsensitive]) != nil {
                return status
            }
        }
        return ""
    }

    func downloadPayload(flightID: String, flight: [String: Any]) -> [String: Any] {
        let normalizedID = sanitizeCacheKey(flightID)
        guard !normalizedID.isEmpty else {
            return ["error": "FR24 flightId missing.", "cache": cacheStatusPayload()]
        }
        if let cached = cachedDownloadPayload(cacheKey: normalizedID, flight: flight) {
            return cached
        }
        do {
            let playback = try webGet(path: "/common/v1/flight-playback.json", params: [
                ("flightId", flightID),
                ("timestamp", String(Int(Date().timeIntervalSince1970)))
            ])
            let trackPoints = extractPlaybackTrackPoints(playback)
            guard trackPoints.count >= 2 else {
                return [
                    "error": "FR24 web playback did not return enough trajectory points.",
                    "cache": cacheStatusPayload(),
                    "access": accessStatusPayload()
                ]
            }
            let enrichedFlight = enrichedFlightPayload(
                flightID: flightID,
                flight: flight,
                playback: playback,
                trackPoints: trackPoints
            )
            return try cacheDownloadResponse(
                flightID: flightID,
                cacheKey: normalizedID,
                flight: enrichedFlight,
                playback: playback,
                trackPoints: trackPoints,
                cacheHit: false
            )
        } catch {
            return [
                "error": error.localizedDescription,
                "cache": cacheStatusPayload(),
                "access": accessStatusPayload()
            ]
        }
    }

    private func cacheDownloadResponse(
        flightID: String,
        cacheKey: String,
        flight: [String: Any],
        playback: [String: Any],
        trackPoints: [[String: Any]],
        cacheHit: Bool
    ) throws -> [String: Any] {
        let jsonURL = rootDirectory.appendingPathComponent("\(cacheKey).json")
        let payload: [String: Any] = [
            "flight": flight,
            "track_points": trackPoints,
            "playback": playback
        ]
        if let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
            try? payloadData.write(to: jsonURL, options: [.atomic])
        }
        var publicFlight = flight
        publicFlight["fr24_id"] = flightID
        publicFlight["cache_key"] = cacheKey
        let existingMeta = readCacheMeta(cacheKey: cacheKey)
        let existingFavorite = existingMeta.flatMap { meta -> Bool? in
            (meta["favorite"] as? Bool) ?? (meta["favorite"] as? NSNumber)?.boolValue
        } ?? false
        publicFlight["favorite"] = existingFavorite
        let gpxURL = try writeGPXCacheFile(
            cacheKey: cacheKey,
            flight: publicFlight,
            trackPoints: trackPoints,
            previousMeta: existingMeta
        )
        let meta: [String: Any] = [
            "flight": publicFlight,
            "track_points": trackPoints,
            "gpx_filename": gpxURL.lastPathComponent,
            "gpx_path": gpxURL.path,
            "json_filename": jsonURL.lastPathComponent,
            "downloaded_at": Int(Date().timeIntervalSince1970),
            "favorite": existingFavorite
        ]
        writeCacheMeta(meta, cacheKey: cacheKey)
        return downloadResponse(
            cacheKey: cacheKey,
            flight: publicFlight,
            trackPoints: trackPoints,
            cacheHit: cacheHit
        )
    }

    private func routeFlights(
        routeAirports: [String: Any],
        limit: Int,
        flightNumber: String,
        callsign: String,
        lookbackHours: Int
    ) throws -> [[String: Any]] {
        guard let departure = routeAirports["departure"] as? [String: Any],
              let arrival = routeAirports["arrival"] as? [String: Any] else {
            throw serviceError("Departure or arrival could not be resolved.")
        }
        let departureCodes = Set(Self.stringArray(departure["codes"]).map { $0.uppercased() })
        let arrivalCodes = Set(Self.stringArray(arrival["codes"]).map { $0.uppercased() })
        let flightFilter = normalizedFlightToken(flightNumber)
        let callsignFilter = normalizedFlightToken(callsign)
        let departureScheduleCode = scheduleCode(for: departure)
        let arrivalScheduleCode = scheduleCode(for: arrival)
        let now = Date()
        let stepHours = 24
        var flights: [[String: Any]] = []
        var seen = Set<String>()

        for offsetHours in stride(from: 0, through: max(1, lookbackHours), by: stepHours) {
            let timestamp = Int(now.addingTimeInterval(TimeInterval(-offsetHours * 3600)).timeIntervalSince1970)
            var offsetHadSuccess = false
            var offsetHTTP400Count = 0
            for modeInfo in [
                (mode: "departures", airportCode: departureScheduleCode),
                (mode: "arrivals", airportCode: arrivalScheduleCode)
            ] {
                var params = [
                    ("code", modeInfo.airportCode),
                    ("plugin[]", "schedule"),
                    ("plugin-setting[schedule][mode]", modeInfo.mode)
                ]
                if offsetHours == 0 {
                    params.append(("page", "1"))
                    params.append(("limit", "100"))
                } else {
                    params.append(("plugin-setting[schedule][timestamp]", String(timestamp)))
                }
                let payload: [String: Any]
                do {
                    payload = try webGet(
                        path: "/common/v1/airport.json",
                        params: params,
                        expectedPaginationHTTP400: offsetHours > 0
                    )
                    offsetHadSuccess = true
                } catch {
                    if error.localizedDescription.contains("HTTP 400") {
                        offsetHTTP400Count += 1
                    }
                    if offsetHours == 0, flights.isEmpty {
                        throw error
                    }
                    continue
                }
                let rawFlights = extractScheduleFlights(payload)
                var appendedFromPayload = 0
                for rawFlight in rawFlights {
                    var flight = normalizeOfficialFlight(rawFlight, departure: departure, arrival: arrival)
                    if modeInfo.mode == "departures" {
                        if Self.stringValue(flight["origin_icao"]).isEmpty {
                            flight["origin_icao"] = Self.stringValue(departure["icao"])
                        }
                        if Self.stringValue(flight["origin_iata"]).isEmpty {
                            flight["origin_iata"] = Self.stringValue(departure["iata"])
                        }
                    } else {
                        if Self.stringValue(flight["dest_icao"]).isEmpty {
                            flight["dest_icao"] = Self.stringValue(arrival["icao"])
                        }
                        if Self.stringValue(flight["dest_iata"]).isEmpty {
                            flight["dest_iata"] = Self.stringValue(arrival["iata"])
                        }
                    }
                    guard flightMatchesRoute(flight, departureCodes: departureCodes, arrivalCodes: arrivalCodes) else {
                        continue
                    }
                    if !flightFilter.isEmpty || !callsignFilter.isEmpty {
                        let number = normalizedFlightToken(Self.stringValue(flight["flight"]))
                        let call = normalizedFlightToken(Self.stringValue(flight["callsign"]))
                        if !flightFilter.isEmpty, number != flightFilter {
                            continue
                        }
                        if flightFilter.isEmpty, !callsignFilter.isEmpty, call != callsignFilter {
                            continue
                        }
                    }
                    let identifier = Self.stringValue(flight["fr24_id"])
                    let dedupeKey = identifier.isEmpty
                        ? "\(Self.stringValue(flight["flight"]))|\(Self.stringValue(flight["callsign"]))|\(Self.intValue(flight["timestamp"]) ?? flights.count)"
                        : identifier
                    if seen.contains(dedupeKey) {
                        continue
                    }
                    seen.insert(dedupeKey)
                    flights.append(flight)
                    appendedFromPayload += 1
                    if flights.count >= limit {
                        NSLog(
                            "NavPlanner FR24 schedule code=%@ mode=%@ offset=%d raw=%d appended=%d total=%d",
                            modeInfo.airportCode,
                            modeInfo.mode,
                            offsetHours,
                            rawFlights.count,
                            appendedFromPayload,
                            flights.count
                        )
                        return sortedFlights(flights)
                    }
                }
                NSLog(
                    "NavPlanner FR24 schedule code=%@ mode=%@ offset=%d raw=%d appended=%d total=%d",
                    modeInfo.airportCode,
                    modeInfo.mode,
                    offsetHours,
                    rawFlights.count,
                    appendedFromPayload,
                    flights.count
                )
            }
            if offsetHours > 0, !offsetHadSuccess, offsetHTTP400Count == 2 {
                NSLog(
                    "NavPlanner FR24 schedule pagination_end offset=%d responses=%d total=%d",
                    offsetHours,
                    offsetHTTP400Count,
                    flights.count
                )
                break
            }
        }
        return sortedFlights(flights)
    }

    private func scheduleCode(for airport: [String: Any]) -> String {
        let schedule = Self.stringValue(airport["schedule_code"])
        if !schedule.isEmpty {
            return schedule
        }
        let iata = Self.stringValue(airport["iata"])
        if !iata.isEmpty {
            return iata
        }
        let ident = Self.stringValue(airport["ident"])
        if !ident.isEmpty {
            return ident
        }
        return Self.stringValue(airport["icao"])
    }

    private func extractScheduleFlights(_ payload: [String: Any]) -> [[String: Any]] {
        var flights: [[String: Any]] = []

        func visit(_ item: Any) {
            if let dictionary = item as? [String: Any] {
                let flightID = Self.stringValue(Self.firstDeepValue(dictionary, paths: [
                    ["flight", "identification", "id"],
                    ["identification", "id"]
                ]))
                if !flightID.isEmpty {
                    flights.append(dictionary)
                }
                dictionary.values.forEach(visit)
            } else if let array = item as? [Any] {
                array.forEach(visit)
            }
        }

        visit(payload)
        return flights
    }

    private func normalizeOfficialFlight(
        _ rawFlight: [String: Any],
        departure: [String: Any],
        arrival: [String: Any]
    ) -> [String: Any] {
        let scheduledDeparture = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "scheduled", "departure"],
            ["scheduled_out"],
            ["scheduled_departure"],
            ["scheduled_departure_time"],
            ["datetime_scheduled_departure"],
            ["time", "scheduled", "departure"]
        ]))
        let scheduledArrival = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "scheduled", "arrival"],
            ["scheduled_in"],
            ["scheduled_arrival"],
            ["scheduled_arrival_time"],
            ["datetime_scheduled_arrival"],
            ["time", "scheduled", "arrival"]
        ]))
        let actualDeparture = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "real", "departure"],
            ["actual_out"],
            ["actual_off"],
            ["actual_departure"],
            ["actual_departure_time"],
            ["datetime_takeoff"],
            ["datetime_real_departure"],
            ["time", "real", "departure"],
            ["time", "actual", "departure"]
        ]))
        let actualArrival = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "real", "arrival"],
            ["actual_on"],
            ["actual_in"],
            ["actual_arrival"],
            ["actual_arrival_time"],
            ["datetime_landed"],
            ["datetime_real_arrival"],
            ["time", "real", "arrival"],
            ["time", "actual", "arrival"]
        ]))
        let estimatedDeparture = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "estimated", "departure"],
            ["estimated_out"],
            ["estimated_off"],
            ["estimated_departure"],
            ["estimated_departure_time"],
            ["datetime_estimated_departure"],
            ["time", "estimated", "departure"]
        ]))
        let estimatedArrival = Self.timestampValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "time", "estimated", "arrival"],
            ["estimated_on"],
            ["estimated_in"],
            ["estimated_arrival"],
            ["estimated_arrival_time"],
            ["datetime_estimated_arrival"],
            ["time", "estimated", "arrival"]
        ]))
        let originICAO = Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "airport", "origin", "code", "icao"],
            ["origin", "code"],
            ["origin", "icao"],
            ["orig_icao"],
            ["origin_icao"],
            ["departure_icao"],
            ["airport", "origin", "code", "icao"]
        ]))
        let originIATA = Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "airport", "origin", "code", "iata"],
            ["origin", "alternate_ident"],
            ["origin", "iata"],
            ["orig_iata"],
            ["origin_iata"],
            ["departure_iata"],
            ["airport", "origin", "code", "iata"]
        ]))
        let destICAO = Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "airport", "destination", "code", "icao"],
            ["destination", "code"],
            ["destination", "icao"],
            ["dest_icao"],
            ["destination_icao"],
            ["arrival_icao"],
            ["airport", "destination", "code", "icao"]
        ]))
        let destIATA = Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
            ["flight", "airport", "destination", "code", "iata"],
            ["destination", "alternate_ident"],
            ["destination", "iata"],
            ["dest_iata"],
            ["destination_iata"],
            ["arrival_iata"],
            ["airport", "destination", "code", "iata"]
        ]))
        let duration = positiveDuration(
            departure: actualDeparture ?? scheduledDeparture,
            arrival: actualArrival ?? scheduledArrival
        )
        var publicFlight: [String: Any] = [
            "fr24_id": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "identification", "id"],
                ["identification", "id"],
                ["fr24_id"],
                ["flight_id"],
                ["id"],
                ["ident"]
            ])),
            "flight": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "identification", "number", "default"],
                ["ident"],
                ["flight"],
                ["flight_number"],
                ["number"],
                ["identification", "number", "default"]
            ])),
            "callsign": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "identification", "callsign"],
                ["ident"],
                ["callsign"],
                ["identification", "callsign"]
            ])),
            "airline": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "airline", "name"],
                ["airline", "name"],
                ["operator"],
                ["operator_icao"],
                ["operator_iata"],
                ["airline"],
                ["airline_name"],
                ["flight", "airline", "name"]
            ])),
            "aircraft": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "aircraft", "model", "code"],
                ["flight", "aircraft", "model", "text"],
                ["aircraft_type"],
                ["aircraft"],
                ["aircraft_code"],
                ["type"],
                ["model"],
                ["aircraft", "model", "code"],
                ["aircraft", "model", "text"]
            ])),
            "aircraft_registration": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "aircraft", "identification", "registration"],
                ["flight", "aircraft", "registration"],
                ["registration"],
                ["reg"],
                ["aircraft_registration"],
                ["aircraft", "identification", "registration"],
                ["aircraft", "registration"]
            ])),
            "origin_icao": originICAO.isEmpty ? Self.stringValue(departure["icao"]) : originICAO,
            "origin_iata": originIATA.isEmpty ? Self.stringValue(departure["iata"]) : originIATA,
            "origin_name": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "airport", "origin", "name"],
                ["origin", "name"],
                ["origin_name"],
                ["departure_name"],
                ["airport", "origin", "name"]
            ])),
            "dest_icao": destICAO.isEmpty ? Self.stringValue(arrival["icao"]) : destICAO,
            "dest_iata": destIATA.isEmpty ? Self.stringValue(arrival["iata"]) : destIATA,
            "dest_name": Self.stringValue(Self.firstDeepValue(rawFlight, paths: [
                ["flight", "airport", "destination", "name"],
                ["destination", "name"],
                ["dest_name"],
                ["destination_name"],
                ["arrival_name"],
                ["airport", "destination", "name"]
            ])),
            "timestamp": actualDeparture ?? scheduledDeparture ?? actualArrival ?? scheduledArrival ?? 0,
            "source_provider": "Flightradar24 web"
        ]
        publicFlight["scheduled_departure"] = scheduledDeparture ?? NSNull()
        publicFlight["scheduled_arrival"] = scheduledArrival ?? NSNull()
        publicFlight["actual_departure"] = actualDeparture ?? NSNull()
        publicFlight["actual_arrival"] = actualArrival ?? NSNull()
        publicFlight["estimated_departure"] = estimatedDeparture ?? NSNull()
        publicFlight["estimated_arrival"] = estimatedArrival ?? NSNull()
        publicFlight["duration_seconds"] = duration ?? NSNull()
        return publicFlight
    }

    private func sortedFlights(_ flights: [[String: Any]]) -> [[String: Any]] {
        flights.sorted {
            (Self.intValue($0["timestamp"]) ?? 0) > (Self.intValue($1["timestamp"]) ?? 0)
        }
    }

    private func serviceError(_ message: String) -> ServiceError {
        ServiceError(message: message)
    }

    private func flightMatchesRoute(
        _ flight: [String: Any],
        departureCodes: Set<String>,
        arrivalCodes: Set<String>
    ) -> Bool {
        let originCodes = [
            Self.stringValue(flight["origin_icao"]).uppercased(),
            Self.stringValue(flight["origin_iata"]).uppercased()
        ].filter { !$0.isEmpty }
        let destCodes = [
            Self.stringValue(flight["dest_icao"]).uppercased(),
            Self.stringValue(flight["dest_iata"]).uppercased()
        ].filter { !$0.isEmpty }
        return !departureCodes.intersection(originCodes).isEmpty
            && !arrivalCodes.intersection(destCodes).isEmpty
    }

    private func webGet(
        path: String,
        params: [(String, String)],
        expectedPaginationHTTP400: Bool = false,
        useBrowser: Bool = true,
        retryChallenge: Bool = true
    ) throws -> [String: Any] {
        let retryDelays: [TimeInterval] = [0.7, 1.5]
        if useBrowser, shouldUseBrowserDataRequests, let browserFetcher {
            for attempt in 0...retryDelays.count {
                do {
                    let payload = try browserFetcher.performJSONRequest(path: path, params: params)
                    FR24SessionStore.recordSuccessfulAccess(userDefaults: userDefaults)
                    return payload
                } catch {
                    let message = error.localizedDescription
                    let retryable = Self.isChallengeLikeRequestError(message)
                    let cancelled = Self.isCancelledRequestError(message)
                    let expectedPaginationEnd = expectedPaginationHTTP400 && message.contains("HTTP 400")
                    if !cancelled && !expectedPaginationEnd {
                        NSLog(
                            "NavPlanner FR24 browser request error path=%@ attempt=%d retryable=%@ error=%@",
                            path,
                            attempt + 1,
                            retryable ? "yes" : "no",
                            message
                        )
                    }
                    if retryable {
                        FR24SessionStore.recordChallenge(userDefaults: userDefaults)
                        if retryChallenge, attempt < retryDelays.count {
                            let jitter = Double.random(in: 0.05...0.25)
                            Thread.sleep(forTimeInterval: retryDelays[attempt] + jitter)
                            continue
                        }
                    }
                    if cancelled {
                        break
                    }
                    if browserFetcher is FR24BrowserSessionManaging {
                        throw serviceError(message)
                    }
                    if Self.shouldSurfaceBrowserRequestError(message) {
                        throw serviceError(message)
                    }
                    break
                }
            }
        }

        guard var components = URLComponents(
            url: apiBaseURL.appendingPathComponent(
                path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            ),
            resolvingAgainstBaseURL: false
        ) else {
            throw serviceError("FR24 web request failed.")
        }
        components.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components.url else {
            throw serviceError("FR24 web request failed.")
        }
        var request = URLRequest(url: url)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.flightradar24.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.flightradar24.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        if let cookie = FR24SessionStore.requestCookieHeader(userDefaults: userDefaults), !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        do {
            let payload = try performJSONRequest(request)
            FR24SessionStore.recordSuccessfulAccess(userDefaults: userDefaults)
            return payload
        } catch {
            if Self.isChallengeLikeRequestError(error.localizedDescription) {
                FR24SessionStore.recordChallenge(userDefaults: userDefaults)
            }
            throw error
        }
    }

    private var shouldUseBrowserDataRequests: Bool {
        guard let browserFetcher else { return false }
        return (browserFetcher as? FR24BrowserSessionManaging)?.performsBrowserDataRequests ?? true
    }

    private static func isChallengeLikeRequestError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("blocked")
            || lowercased.contains("cloudflare")
            || lowercased.contains("html response")
            || lowercased.contains("http 429")
            || lowercased.contains("too many requests")
    }

    private static func isCancelledRequestError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("cancelled")
            || lowercased.contains("canceled")
            || lowercased.contains("-999")
    }

    private static func shouldSurfaceBrowserRequestError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("blocked")
            || lowercased.contains("cloudflare")
            || lowercased.contains("html response")
            || lowercased.contains("returned http")
            || lowercased.contains("not valid json")
    }

    private func performJSONRequest(_ request: URLRequest) throws -> [String: Any] {
        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = FR24RequestResultBox()
        let task = session.dataTask(with: request) { data, response, error in
            resultBox.store(data: data, response: response, error: error)
            semaphore.signal()
        }
        task.resume()
        if semaphore.wait(timeout: .now() + 22) == .timedOut {
            task.cancel()
            throw serviceError("FR24 web request timed out.")
        }
        let result = resultBox.snapshot()
        if let outputError = result.error {
            throw serviceError("FR24 web request failed: \(outputError.localizedDescription)")
        }
        let httpResponse = result.response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 0
        let data = result.data ?? Data()
        if Self.isCloudflareChallenge(data: data, response: httpResponse) {
            throw serviceError("FR24 web access was blocked by Cloudflare verification.")
        }
        if statusCode == 401 || statusCode == 403 {
            throw serviceError(Self.fr24HTTPErrorMessage(statusCode: statusCode, data: data))
        }
        guard (200..<300).contains(statusCode) else {
            throw serviceError(Self.fr24HTTPErrorMessage(statusCode: statusCode, data: data))
        }
        if let text = String(data: data.prefix(400), encoding: .utf8),
           text.localizedCaseInsensitiveContains("just a moment")
            || text.localizedCaseInsensitiveContains("cloudflare")
            || text.localizedCaseInsensitiveContains("<html") {
            throw serviceError("FR24 web returned an HTML response.")
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw serviceError("FR24 web response was not valid JSON.")
        }
        return object
    }

    private static func fr24HTTPErrorMessage(statusCode: Int, data: Data) -> String {
        if statusCode == 401 || statusCode == 403 {
            return "FR24 web access was blocked. Open FR24 verification in Query, complete verification, then sync the session."
        }
        let summary: String
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            summary = stringValue(object["message"]).isEmpty
                ? (stringValue(object["error"]).isEmpty ? stringValue(object["detail"]) : stringValue(object["error"]))
                : stringValue(object["message"])
        } else {
            summary = String(data: data, encoding: .utf8)?
                .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        if summary.isEmpty {
            return "FR24 web returned HTTP \(statusCode)."
        }
        return "FR24 web returned HTTP \(statusCode): \(String(summary.prefix(180)))."
    }

    private static func isCloudflareChallenge(data: Data, response: HTTPURLResponse?) -> Bool {
        let mitigated = response?.value(forHTTPHeaderField: "cf-mitigated")?.lowercased() == "challenge"
        guard let text = String(data: data.prefix(1200), encoding: .utf8) else {
            return mitigated
        }
        return mitigated
            || text.localizedCaseInsensitiveContains("cloudflare")
            || text.localizedCaseInsensitiveContains("challenge-platform")
            || text.localizedCaseInsensitiveContains("just a moment")
    }

    private func extractPlaybackTrackPoints(_ payload: [String: Any]) -> [[String: Any]] {
        var candidateTracks: [[[String: Any]]] = []

        func normalizedTrack(_ items: [Any]) -> [[String: Any]] {
            func firstFiniteDouble(_ values: [Any?]) -> Double? {
                for value in values {
                    if let number = Self.doubleValue(value), number.isFinite {
                        return number
                    }
                }
                return nil
            }

            func assignAltitude(_ altitudeFeet: Double?, _ altitudeMeters: Double?, to point: inout [String: Any]) {
                if let altitudeFeet, altitudeFeet.isFinite {
                    point["altitude"] = Int(altitudeFeet.rounded())
                    point["altitude_ft"] = altitudeFeet
                } else if let altitudeMeters, altitudeMeters.isFinite {
                    point["altitude_m"] = altitudeMeters
                    point["altitude_ft"] = altitudeMeters * 3.280839895
                    point["altitude"] = Int((altitudeMeters * 3.280839895).rounded())
                }
            }

            func assignSpeed(_ speedKnots: Double?, to point: inout [String: Any]) {
                if let speedKnots, speedKnots.isFinite {
                    point["speed"] = speedKnots
                    point["speed_kt"] = speedKnots
                }
            }

            func normalizedArrayPoint(_ array: [Any]) -> [String: Any]? {
                let layouts: [(timestamp: Int?, lat: Int, lon: Int, altitude: Int?, speed: Int?)] = [
                    (0, 1, 2, 3, 4),
                    (2, 0, 1, 3, 4),
                    (nil, 0, 1, 2, 3)
                ]
                for layout in layouts {
                    guard array.count > layout.lon,
                          let lat = Self.doubleValue(array[layout.lat]),
                          let lon = Self.doubleValue(array[layout.lon]),
                          lat.isFinite,
                          lon.isFinite,
                          abs(lat) <= 90,
                          abs(lon) <= 360 else {
                        continue
                    }
                    var point: [String: Any] = ["lat": lat, "lon": lon]
                    if let timestampIndex = layout.timestamp,
                       array.count > timestampIndex,
                       let timestamp = Self.timestampValue(array[timestampIndex]) {
                        point["timestamp"] = timestamp
                    }
                    let altitudeFeet = layout.altitude.flatMap { index -> Double? in
                        array.count > index ? Self.doubleValue(array[index]) : nil
                    }
                    let speedKnots = layout.speed.flatMap { index -> Double? in
                        array.count > index ? Self.doubleValue(array[index]) : nil
                    }
                    assignAltitude(altitudeFeet, nil, to: &point)
                    assignSpeed(speedKnots, to: &point)
                    return point
                }
                return nil
            }

            return items.compactMap { item -> [String: Any]? in
                if let dictionary = item as? [String: Any] {
                    let lat = Self.doubleValue(dictionary["lat"])
                        ?? Self.doubleValue(dictionary["latitude"])
                        ?? Self.doubleValue(Self.deepValue(dictionary, path: ["position", "lat"]))
                    let lon = Self.doubleValue(dictionary["lon"])
                        ?? Self.doubleValue(dictionary["lng"])
                        ?? Self.doubleValue(dictionary["longitude"])
                        ?? Self.doubleValue(Self.deepValue(dictionary, path: ["position", "lng"]))
                        ?? Self.doubleValue(Self.deepValue(dictionary, path: ["position", "lon"]))
                    guard let lat, let lon, lat.isFinite, lon.isFinite else {
                        return nil
                    }
                    var point: [String: Any] = [
                        "lat": lat,
                        "lon": lon
                    ]
                    if let timestamp = Self.timestampValue(dictionary["timestamp"])
                        ?? Self.timestampValue(dictionary["ts"])
                        ?? Self.timestampValue(dictionary["time"]) {
                        point["timestamp"] = timestamp
                    }
                    let altitudeFeet = firstFiniteDouble([
                        dictionary["altitude"],
                        dictionary["alt"],
                        dictionary["alt_ft"],
                        dictionary["altitude_ft"],
                        dictionary["altitudeFt"],
                        dictionary["altitude_feet"],
                        Self.deepValue(dictionary, path: ["altitude", "feet"]),
                        Self.deepValue(dictionary, path: ["altitude", "ft"])
                    ])
                    let altitudeMeters = firstFiniteDouble([
                        dictionary["altitude_m"],
                        dictionary["alt_m"],
                        dictionary["altitudeMeters"],
                        dictionary["altitude_meter"],
                        Self.deepValue(dictionary, path: ["altitude", "meters"]),
                        Self.deepValue(dictionary, path: ["altitude", "m"])
                    ])
                    assignAltitude(altitudeFeet, altitudeMeters, to: &point)
                    let speedKnots = firstFiniteDouble([
                        dictionary["speed"],
                        dictionary["spd"],
                        dictionary["speed_kt"],
                        dictionary["speed_kts"],
                        dictionary["speedKt"],
                        dictionary["speedKts"],
                        dictionary["ground_speed"],
                        dictionary["groundspeed"],
                        dictionary["groundSpeed"],
                        dictionary["ground_speed_kt"],
                        dictionary["gs"],
                        Self.deepValue(dictionary, path: ["speed", "kts"]),
                        Self.deepValue(dictionary, path: ["speed", "knots"]),
                        Self.deepValue(dictionary, path: ["groundSpeed", "knots"])
                    ])
                    assignSpeed(speedKnots, to: &point)
                    return point
                }
                if let array = item as? [Any], array.count >= 2 {
                    return normalizedArrayPoint(array)
                }
                return nil
            }
        }

        func visit(_ item: Any) {
            if let array = item as? [Any] {
                let points = normalizedTrack(array)
                if points.count >= 2 {
                    candidateTracks.append(points)
                }
                array.forEach(visit)
            } else if let dictionary = item as? [String: Any] {
                dictionary.values.forEach(visit)
            }
        }

        visit(payload)
        return candidateTracks.max { $0.count < $1.count } ?? []
    }

    private func cacheFileURLs(cacheKey: String) -> [URL] {
        var urls = [
            rootDirectory.appendingPathComponent("\(cacheKey).gpx"),
            rootDirectory.appendingPathComponent("\(cacheKey).json"),
            rootDirectory.appendingPathComponent("\(cacheKey).meta.json")
        ]
        if let meta = readCacheMeta(cacheKey: cacheKey),
           let gpxURL = cacheGPXURL(cacheKey: cacheKey, meta: meta) {
            urls.append(gpxURL)
        }
        var seen: Set<String> = []
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }

    private func readCacheMeta(cacheKey: String) -> [String: Any]? {
        let metaURL = rootDirectory.appendingPathComponent("\(cacheKey).meta.json")
        guard let data = try? Data(contentsOf: metaURL),
              let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return meta
    }

    private func writeCacheMeta(_ meta: [String: Any], cacheKey: String) {
        let metaURL = rootDirectory.appendingPathComponent("\(cacheKey).meta.json")
        if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]) {
            try? metaData.write(to: metaURL, options: [.atomic])
        }
    }

    private func cacheGPXURL(cacheKey: String, meta: [String: Any]?) -> URL? {
        if let path = meta.flatMap({ Self.stringValue($0["gpx_path"]) }), !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        if let filename = meta.flatMap({ Self.stringValue($0["gpx_filename"]) }), !filename.isEmpty {
            return rootDirectory.appendingPathComponent(filename)
        }
        return rootDirectory.appendingPathComponent("\(cacheKey).gpx")
    }

    private func displayGPXFilename(
        cacheKey: String,
        flight: [String: Any],
        trackPoints: [[String: Any]]
    ) -> String {
        let timestamp = [
            Self.intValue(flight["actual_departure"]),
            Self.intValue(flight["scheduled_departure"]),
            Self.intValue(flight["timestamp"]),
            trackPoints.compactMap { Self.intValue($0["timestamp"]) }.first
        ].compactMap { $0 }.map(normalizedTimestamp).first ?? Int(Date().timeIntervalSince1970)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HHmmZ"
        let dateToken = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
        let flightToken = normalizedFlightToken(Self.stringValue(flight["flight"])).isEmpty
            ? normalizedFlightToken(Self.stringValue(flight["callsign"]))
            : normalizedFlightToken(Self.stringValue(flight["flight"]))
        let registration = filenameToken(Self.stringValue(flight["aircraft_registration"]), fallback: "REG")
        let identifier = filenameToken(Self.stringValue(flight["fr24_id"]).isEmpty ? cacheKey : Self.stringValue(flight["fr24_id"]), fallback: cacheKey)
        return "\(dateToken)_\(flightToken.isEmpty ? "FR24" : flightToken)_\(registration)_\(identifier).gpx"
    }

    private func filenameToken(_ value: String, fallback: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var output = ""
        for scalar in trimmed.unicodeScalars {
            if allowed.contains(scalar) {
                output += String(scalar)
            }
        }
        return output.isEmpty ? fallback : output
    }

    private func writeGPXCacheFile(
        cacheKey: String,
        flight: [String: Any],
        trackPoints: [[String: Any]],
        previousMeta: [String: Any]? = nil
    ) throws -> URL {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let filename = displayGPXFilename(cacheKey: cacheKey, flight: flight, trackPoints: trackPoints)
        let gpxURL = rootDirectory.appendingPathComponent(filename)
        let gpxText = gpxDocument(
            flightID: Self.stringValue(flight["fr24_id"]).isEmpty ? cacheKey : Self.stringValue(flight["fr24_id"]),
            flight: flight,
            trackPoints: trackPoints
        )
        try gpxText.data(using: .utf8)?.write(to: gpxURL, options: [.atomic])

        let oldURLs = [
            rootDirectory.appendingPathComponent("\(cacheKey).gpx"),
            cacheGPXURL(cacheKey: cacheKey, meta: previousMeta)
        ].compactMap { $0 }
        for oldURL in oldURLs where oldURL.standardizedFileURL.path != gpxURL.standardizedFileURL.path {
            try? fileManager.removeItem(at: oldURL)
        }
        return gpxURL
    }

    private func cachedFlightItems() -> [[String: Any]] {
        guard let metaURLs = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return metaURLs
            .filter { $0.lastPathComponent.hasSuffix(".meta.json") }
            .compactMap { url -> [String: Any]? in
                let cacheKey = url.lastPathComponent.replacingOccurrences(of: ".meta.json", with: "")
                guard let meta = readCacheMeta(cacheKey: cacheKey) else { return nil }
                return cacheItem(cacheKey: cacheKey, meta: meta)
            }
            .sorted { left, right in
                let leftTime = Self.intValue(left["downloaded_at"]) ?? Self.intValue(left["timestamp"]) ?? 0
                let rightTime = Self.intValue(right["downloaded_at"]) ?? Self.intValue(right["timestamp"]) ?? 0
                if leftTime != rightTime {
                    return leftTime > rightTime
                }
                return Self.stringValue(left["cache_key"]) < Self.stringValue(right["cache_key"])
            }
    }

    private func cacheItem(cacheKey: String, meta: [String: Any]) -> [String: Any]? {
        let trackPoints = meta["track_points"] as? [[String: Any]] ?? []
        let gpxURL = cacheGPXURL(cacheKey: cacheKey, meta: meta)
            ?? rootDirectory.appendingPathComponent("\(cacheKey).gpx")
        let jsonURL = rootDirectory.appendingPathComponent("\(cacheKey).json")
        guard fileManager.fileExists(atPath: gpxURL.path) || fileManager.fileExists(atPath: jsonURL.path) || !trackPoints.isEmpty else {
            return nil
        }
        var item = (meta["flight"] as? [String: Any]) ?? [:]
        if Self.stringValue(item["fr24_id"]).isEmpty {
            item["fr24_id"] = cacheKey
        }
        item["cache_key"] = cacheKey
        item["cache_hit"] = true
        item["favorite"] = (meta["favorite"] as? Bool) ?? (meta["favorite"] as? NSNumber)?.boolValue ?? false
        item["downloaded_at"] = Self.intValue(meta["downloaded_at"]) ?? NSNull()
        item["track_point_count"] = trackPoints.count
        item["gpx_filename"] = gpxURL.lastPathComponent
        item["gpx_path"] = gpxURL.path
        item["json_filename"] = Self.stringValue(meta["json_filename"]).isEmpty ? jsonURL.lastPathComponent : Self.stringValue(meta["json_filename"])
        return item
    }

    private func cachedDownloadPayload(cacheKey: String, flight: [String: Any]) -> [String: Any]? {
        guard let meta = readCacheMeta(cacheKey: cacheKey),
              var trackPoints = meta["track_points"] as? [[String: Any]],
              trackPoints.count >= 2 else {
            return nil
        }
        var refreshedMeta = meta
        var cachedFlight = (meta["flight"] as? [String: Any]) ?? flight
        let jsonURL = rootDirectory.appendingPathComponent("\(cacheKey).json")
        if let data = try? Data(contentsOf: jsonURL),
           let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let playback = payload["playback"] as? [String: Any] {
            let extractedPoints = extractPlaybackTrackPoints(playback)
            if extractedPoints.count >= 2 {
                trackPoints = extractedPoints
                refreshedMeta["track_points"] = extractedPoints
                writeCacheMeta(refreshedMeta, cacheKey: cacheKey)
            }
            let flightID = Self.stringValue(cachedFlight["fr24_id"]).isEmpty ? cacheKey : Self.stringValue(cachedFlight["fr24_id"])
            cachedFlight = enrichedFlightPayload(
                flightID: flightID,
                flight: cachedFlight,
                playback: playback,
                trackPoints: trackPoints
            )
        }
        cachedFlight["favorite"] = (meta["favorite"] as? Bool) ?? (meta["favorite"] as? NSNumber)?.boolValue ?? false
        cachedFlight["cache_key"] = cacheKey
        if let gpxURL = try? writeGPXCacheFile(
            cacheKey: cacheKey,
            flight: cachedFlight,
            trackPoints: trackPoints,
            previousMeta: meta
        ) {
            refreshedMeta["gpx_filename"] = gpxURL.lastPathComponent
            refreshedMeta["gpx_path"] = gpxURL.path
            refreshedMeta["track_points"] = trackPoints
            refreshedMeta["flight"] = cachedFlight
            writeCacheMeta(refreshedMeta, cacheKey: cacheKey)
        }
        return downloadResponse(
            cacheKey: cacheKey,
            flight: cachedFlight,
            trackPoints: trackPoints,
            cacheHit: true
        )
    }

    private func downloadResponse(
        cacheKey: String,
        flight: [String: Any],
        trackPoints: [[String: Any]],
        cacheHit: Bool
    ) -> [String: Any] {
        let meta = readCacheMeta(cacheKey: cacheKey)
        let gpxURL = cacheGPXURL(cacheKey: cacheKey, meta: meta)
            ?? rootDirectory.appendingPathComponent("\(cacheKey).gpx")
        return [
            "flight": flight,
            "track_points": trackPoints,
            "track_point_count": trackPoints.count,
            "cache_key": cacheKey,
            "gpx_filename": gpxURL.lastPathComponent,
            "gpx_path": gpxURL.path,
            "cache_hit": cacheHit,
            "cache": cacheStatusPayload(),
            "access": accessStatusPayload(),
            "message": cacheHit ? "已读取缓存的 FR24 GPX 轨迹。" : "已下载并缓存 FR24 GPX 轨迹。"
        ]
    }

    private func gpxDocument(
        flightID: String,
        flight: [String: Any],
        trackPoints: [[String: Any]]
    ) -> String {
        let title = [
            Self.stringValue(flight["flight"]),
            Self.stringValue(flight["origin_icao"]).isEmpty ? Self.stringValue(flight["origin_iata"]) : Self.stringValue(flight["origin_icao"]),
            Self.stringValue(flight["dest_icao"]).isEmpty ? Self.stringValue(flight["dest_iata"]) : Self.stringValue(flight["dest_icao"])
        ].filter { !$0.isEmpty }.joined(separator: " ")
        let name = title.isEmpty ? "FR24 \(flightID)" : title
        let body = trackPoints.map { point -> String in
            let lat = Self.doubleValue(point["lat"]) ?? 0
            let lon = Self.doubleValue(point["lon"]) ?? 0
            let time = Self.intValue(point["timestamp"]).map { normalizedTimestamp($0) }
            let altitudeFeet = Self.doubleValue(point["altitude_ft"]) ?? Self.doubleValue(point["altitude"])
            let speedKnots = Self.doubleValue(point["speed_kt"]) ?? Self.doubleValue(point["speed"])
            var children: [String] = []
            if let altitudeFeet, altitudeFeet.isFinite {
                children.append("<ele>\(gpxNumber(altitudeFeet * 0.3048, decimals: 1))</ele>")
            }
            if let time {
                children.append("<time>\(xmlEscape(isoFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(time)))))</time>")
            }
            var extensionChildren: [String] = []
            if let altitudeFeet, altitudeFeet.isFinite {
                extensionChildren.append("<navplanner:altitude_ft>\(gpxNumber(altitudeFeet, decimals: 0))</navplanner:altitude_ft>")
            }
            if let speedKnots, speedKnots.isFinite {
                extensionChildren.append("<navplanner:speed_kt>\(gpxNumber(speedKnots, decimals: 1))</navplanner:speed_kt>")
                extensionChildren.append("<navplanner:speed_mps>\(gpxNumber(speedKnots * 0.514444, decimals: 2))</navplanner:speed_mps>")
            }
            if !extensionChildren.isEmpty {
                children.append("""
                <extensions>
                  \(extensionChildren.joined(separator: "\n          "))
                </extensions>
                """)
            }
            let content = children.isEmpty ? "" : "\n        \(children.joined(separator: "\n        "))\n      "
            return """
            <trkpt lat="\(lat)" lon="\(lon)">\(content)</trkpt>
            """
        }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="SimNav Studio" xmlns="http://www.topografix.com/GPX/1/1" xmlns:navplanner="https://navplanner.app/gpx/1/0">
          <trk>
            <name>\(xmlEscape(name))</name>
            <trkseg>
        \(body)
            </trkseg>
          </trk>
        </gpx>
        """
    }

    private func diskUsage() -> (files: Int, bytes: Int64) {
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }
        var files = 0
        var bytes: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            files += 1
            bytes += Int64(values?.fileSize ?? 0)
        }
        return (files, bytes)
    }

    private func sanitizeCacheKey(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var output = ""
        for scalar in value.lowercased().unicodeScalars {
            output += allowed.contains(scalar) ? String(scalar) : "-"
        }
        return output
    }

    private func normalizedFlightToken(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private func positiveDuration(departure: Int?, arrival: Int?) -> Int? {
        guard let departure, let arrival else { return nil }
        let normalizedDeparture = normalizedTimestamp(departure)
        let normalizedArrival = normalizedTimestamp(arrival)
        let duration = normalizedArrival - normalizedDeparture
        return duration > 0 && duration < 172800 ? duration : nil
    }

    private func normalizedTimestamp(_ value: Int) -> Int {
        value > 1_000_000_000_000 ? value / 1000 : value
    }

    private func gpxNumber(_ value: Double, decimals: Int) -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        switch decimals {
        case 0:
            return String(format: "%.0f", locale: locale, value)
        case 1:
            return String(format: "%.1f", locale: locale, value)
        case 2:
            return String(format: "%.2f", locale: locale, value)
        default:
            return String(format: "%.3f", locale: locale, value)
        }
    }

    private func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func firstDeepValue(_ dictionary: [String: Any], paths: [[String]]) -> Any? {
        for path in paths {
            if let value = deepValue(dictionary, path: path),
               !stringValue(value).isEmpty || intValue(value) != nil || doubleValue(value) != nil {
                return value
            }
        }
        return nil
    }

    private static func deepValue(_ dictionary: [String: Any], path: [String]) -> Any? {
        var cursor: Any? = dictionary
        for key in path {
            guard let object = cursor as? [String: Any], object.keys.contains(key) else {
                return nil
            }
            cursor = object[key]
        }
        return cursor
    }

    private static func stringArray(_ value: Any?) -> [String] {
        if let array = value as? [String] {
            return array.filter { !$0.isEmpty }
        }
        if let array = value as? [Any] {
            return array.map(stringValue).filter { !$0.isEmpty }
        }
        let single = stringValue(value)
        return single.isEmpty ? [] : [single]
    }

    private static func stringValue(_ value: Any?) -> String {
        switch value {
        case let value as String:
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        case let value as NSNumber:
            return value.stringValue
        case let value as Int:
            return String(value)
        case let value as Double:
            return String(value)
        case is NSNull, nil:
            return ""
        default:
            return String(describing: value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func timestampValue(_ value: Any?) -> Int? {
        if let number = intValue(value) {
            return number > 1_000_000_000_000 ? number / 1000 : number
        }
        let text = stringValue(value)
        guard !text.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: text) {
            return Int(date.timeIntervalSince1970)
        }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        for pattern in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"] {
            fallback.dateFormat = pattern
            if let date = fallback.date(from: text) {
                return Int(date.timeIntervalSince1970)
            }
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as Double where value.isFinite:
            return Int(value)
        case let value as String:
            guard let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)),
                  number.isFinite else {
                return nil
            }
            return Int(number)
        default:
            return nil
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }
}
