import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOWebSocket
import SimNavCore

/// Local Web's verification-only equivalent of the Apple FR24 browser.
///
/// On macOS it uses an app-owned WebKit verification window, matching the
/// Apple App's session hand-off without depending on Edge or another installed
/// browser. Windows and Linux keep the isolated Chromium adapter. In either
/// case the page is created only after an explicit verification action, exports
/// its session to the shared FR24 HTTP service, and closes after verification
/// succeeds. Schedule, history, and playback requests never create browser
/// targets.
final class LocalWebFR24BrowserFetch: @unchecked Sendable,
    FR24BrowserFetching,
    FR24BrowserSessionManaging {

    struct Configuration {
        var profileRoot: URL
        var browserExecutableURL: URL?
        var externalEndpointURL: URL?
        var externalEndpointToken: String?
        var apiBaseURL: URL
        var websiteBaseURL: URL
        var launchHeadless: Bool
        var revealVerificationWindow: Bool
        var performsDataRequests: Bool
        var additionalBrowserArguments: [String]
        var useNativeWebKitVerification: Bool

        init(
            dataRoot: URL,
            environment: [String: String] = ProcessInfo.processInfo.environment,
            fileManager: FileManager = .default,
            apiBaseURL: URL = URL(string: "https://api.flightradar24.com")!,
            websiteBaseURL: URL = URL(string: "https://www.flightradar24.com")!
        ) {
            profileRoot = environment["SIMNAV_FR24_BROWSER_PROFILE"].map {
                URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true)
            } ?? dataRoot.appendingPathComponent("FR24Browser", isDirectory: true)
            browserExecutableURL = Self.resolveBrowserExecutable(
                explicitPath: environment["SIMNAV_FR24_BROWSER"],
                environment: environment,
                fileManager: fileManager
            )
            externalEndpointURL = environment["SIMNAV_FR24_CDP_ENDPOINT"].flatMap(URL.init(string:))
            externalEndpointToken = Self.validEndpointToken(
                environment["SIMNAV_FR24_CDP_TOKEN"]
            )
            self.apiBaseURL = apiBaseURL
            self.websiteBaseURL = websiteBaseURL
            launchHeadless = environment["SIMNAV_FR24_BROWSER_HEADLESS"] == "1"
            revealVerificationWindow = environment["SIMNAV_FR24_BROWSER_REVEAL"] != "0"
            performsDataRequests = false
            additionalBrowserArguments = []
#if os(macOS)
            useNativeWebKitVerification = environment["SIMNAV_FR24_WEBKIT_VERIFICATION"] != "0"
                && environment["SIMNAV_FR24_BROWSER"] == nil
                && externalEndpointURL == nil
                && !launchHeadless
#else
            useNativeWebKitVerification = false
#endif
        }

        init(
            profileRoot: URL,
            browserExecutableURL: URL?,
            externalEndpointURL: URL? = nil,
            externalEndpointToken: String? = nil,
            apiBaseURL: URL,
            websiteBaseURL: URL,
            launchHeadless: Bool = false,
            revealVerificationWindow: Bool = true,
            performsDataRequests: Bool = false,
            additionalBrowserArguments: [String] = [],
            useNativeWebKitVerification: Bool = false
        ) {
            self.profileRoot = profileRoot
            self.browserExecutableURL = browserExecutableURL
            self.externalEndpointURL = externalEndpointURL
            self.externalEndpointToken = Self.validEndpointToken(externalEndpointToken)
            self.apiBaseURL = apiBaseURL
            self.websiteBaseURL = websiteBaseURL
            self.launchHeadless = launchHeadless
            self.revealVerificationWindow = revealVerificationWindow
            self.performsDataRequests = performsDataRequests
            self.additionalBrowserArguments = additionalBrowserArguments
            self.useNativeWebKitVerification = useNativeWebKitVerification
        }

        private static func validEndpointToken(_ value: String?) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  (16...256).contains(value.utf8.count),
                  value.unicodeScalars.allSatisfy({ $0.isASCII && $0.value >= 0x21 && $0.value <= 0x7e }) else {
                return nil
            }
            return value
        }

        private static func resolveBrowserExecutable(
            explicitPath: String?,
            environment: [String: String],
            fileManager: FileManager
        ) -> URL? {
            var candidates: [String] = []
            if let explicitPath, !explicitPath.isEmpty {
                candidates.append((explicitPath as NSString).expandingTildeInPath)
            }
#if os(macOS)
            candidates += [
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                "/Applications/Chromium.app/Contents/MacOS/Chromium",
                "/Applications/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
            ]
#elseif os(Windows)
            for root in [environment["PROGRAMFILES"], environment["PROGRAMFILES(X86)"], environment["LOCALAPPDATA"]].compactMap({ $0 }) {
                candidates += [
                    URL(fileURLWithPath: root).appendingPathComponent("Google/Chrome/Application/chrome.exe").path,
                    URL(fileURLWithPath: root).appendingPathComponent("Chromium/Application/chrome.exe").path,
                    URL(fileURLWithPath: root).appendingPathComponent("Microsoft/Edge/Application/msedge.exe").path
                ]
            }
#else
            candidates += [
                "/usr/bin/google-chrome",
                "/usr/bin/google-chrome-stable",
                "/usr/bin/chromium",
                "/usr/bin/chromium-browser",
                "/usr/bin/microsoft-edge",
                "/opt/google/chrome/google-chrome"
            ]
#endif
            return candidates.lazy
                .map { URL(fileURLWithPath: $0).standardizedFileURL }
                .first { fileManager.isExecutableFile(atPath: $0.path) }
        }
    }

    private struct BrowserError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct Target {
        let id: String
        let webSocketURL: URL
    }

    private struct ControlHTTPResult {
        let status: Int
        let body: Data
    }

    /// Chromium's DevTools HTTP endpoint emits valid compact fields such as
    /// `Content-Length:438`. Swift 6.1 FoundationNetworking rejects those
    /// responses with `Failed writing header`, so control-plane HTTP uses the
    /// already-shipped SwiftNIO transport. DevTools WebSockets use NIO as well,
    /// because URLSessionWebSocketTask is unavailable in the Swift 6.1 Linux
    /// runtime used by the release container.
    private final class ControlHTTPHandler: ChannelInboundHandler, @unchecked Sendable {
        typealias InboundIn = HTTPClientResponsePart

        private let completion: EventLoopPromise<ControlHTTPResult>
        private var status = 0
        private var body = Data()
        private var completed = false

        init(completion: EventLoopPromise<ControlHTTPResult>) {
            self.completion = completion
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            switch unwrapInboundIn(data) {
            case .head(let head):
                status = Int(head.status.code)
            case .body(let buffer):
                body.append(contentsOf: buffer.readableBytesView)
            case .end:
                finish(.success(ControlHTTPResult(status: status, body: body)))
                context.close(promise: nil)
            }
        }

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            finish(.failure(error))
            context.close(promise: nil)
        }

        func channelInactive(context: ChannelHandlerContext) {
            if !completed {
                finish(.failure(BrowserError(message: "FR24 browser control connection closed early.")))
            }
            context.fireChannelInactive()
        }

        func timeOut(channel: Channel) {
            finish(.failure(BrowserError(message: "FR24 browser control timed out.")))
            channel.close(promise: nil)
        }

        private func finish(_ result: Result<ControlHTTPResult, Error>) {
            guard !completed else { return }
            completed = true
            completion.completeWith(result)
        }
    }

    private final class WebSocketCommandState: @unchecked Sendable {
        let completion: EventLoopPromise<Data>
        private var completed = false

        init(completion: EventLoopPromise<Data>) {
            self.completion = completion
        }

        func succeed(_ data: Data, channel: Channel) {
            guard !completed else { return }
            completed = true
            completion.succeed(data)
            channel.close(promise: nil)
        }

        func fail(_ error: Error, channel: Channel) {
            guard !completed else { return }
            completed = true
            completion.fail(error)
            channel.close(promise: nil)
        }
    }

    private final class WebSocketUpgradeRequestHandler:
        ChannelInboundHandler,
        RemovableChannelHandler,
        @unchecked Sendable {

        typealias InboundIn = HTTPClientResponsePart
        typealias OutboundOut = HTTPClientRequestPart

        private let uri: String
        private let headers: HTTPHeaders
        private let state: WebSocketCommandState

        init(uri: String, headers: HTTPHeaders, state: WebSocketCommandState) {
            self.uri = uri
            self.headers = headers
            self.state = state
        }

        func channelActive(context: ChannelHandlerContext) {
            let head = HTTPRequestHead(
                version: .http1_1,
                method: .GET,
                uri: uri,
                headers: headers
            )
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            if case .head(let head) = unwrapInboundIn(data) {
                state.fail(
                    BrowserError(message: "FR24 browser WebSocket returned HTTP \(head.status.code)."),
                    channel: context.channel
                )
            }
        }

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            state.fail(error, channel: context.channel)
        }
    }

    private final class WebSocketCommandHandler:
        ChannelInboundHandler,
        @unchecked Sendable {

        typealias InboundIn = WebSocketFrame
        typealias OutboundOut = WebSocketFrame

        private let commands: [String]
        private let state: WebSocketCommandState
        private var commandIndex = 0
        private var messageData = Data()

        init(commands: [String], state: WebSocketCommandState) {
            self.commands = commands
            self.state = state
        }

        func send(channel: Channel) {
            sendCurrentCommand(channel: channel)
        }

        private func sendCurrentCommand(channel: Channel) {
            guard commands.indices.contains(commandIndex) else {
                state.fail(
                    BrowserError(message: "FR24 browser command sequence was empty."),
                    channel: channel
                )
                return
            }
            let command = commands[commandIndex]
            var buffer = channel.allocator.buffer(capacity: command.utf8.count)
            buffer.writeString(command)
            let frame = WebSocketFrame(
                fin: true,
                opcode: .text,
                maskKey: .random(),
                data: buffer
            )
            channel.writeAndFlush(frame).whenFailure { error in
                self.state.fail(error, channel: channel)
            }
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let frame = unwrapInboundIn(data)
            switch frame.opcode {
            case .text, .binary:
                messageData.removeAll(keepingCapacity: true)
                append(frame.unmaskedData)
                if frame.fin { finishMessage(context: context) }
            case .continuation:
                append(frame.unmaskedData)
                if frame.fin { finishMessage(context: context) }
            case .ping:
                let pong = WebSocketFrame(
                    fin: true,
                    opcode: .pong,
                    maskKey: .random(),
                    data: frame.unmaskedData
                )
                context.writeAndFlush(wrapOutboundOut(pong), promise: nil)
            case .connectionClose:
                state.fail(
                    BrowserError(message: "FR24 browser WebSocket closed before returning a result."),
                    channel: context.channel
                )
            case .pong:
                break
            default:
                break
            }
        }

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            state.fail(error, channel: context.channel)
        }

        func channelInactive(context: ChannelHandlerContext) {
            state.fail(
                BrowserError(message: "FR24 browser WebSocket connection closed early."),
                channel: context.channel
            )
            context.fireChannelInactive()
        }

        private func append(_ buffer: ByteBuffer) {
            messageData.append(contentsOf: buffer.readableBytesView)
        }

        private func finishMessage(context: ChannelHandlerContext) {
            guard let object = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
                  (object["id"] as? NSNumber)?.intValue == commandIndex + 1 else {
                return
            }
            if object["error"] != nil || commandIndex == commands.count - 1 {
                state.succeed(messageData, channel: context.channel)
                return
            }
            commandIndex += 1
            sendCurrentCommand(channel: context.channel)
        }
    }

    private let configuration: Configuration
    private let fileManager: FileManager
    private let requestLock = NSLock()
    private let stateLock = NSLock()
    private var ownedBrowserProcess: Process?
    private var endpointURL: URL?
    private var verificationTargetID: String?
    private let nativeVerification: LocalWebFR24NativeVerificationSession?

    init(
        dataRoot: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        let configuration = Configuration(
            dataRoot: dataRoot,
            environment: environment,
            fileManager: fileManager
        )
        self.configuration = configuration
        self.fileManager = fileManager
        self.nativeVerification = configuration.useNativeWebKitVerification
            ? makeLocalWebFR24NativeVerificationSession()
            : nil
    }

    init(configuration: Configuration, fileManager: FileManager = .default) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.nativeVerification = configuration.useNativeWebKitVerification
            ? makeLocalWebFR24NativeVerificationSession()
            : nil
    }

    deinit {
        nativeVerification?.close()
        terminateOwnedBrowser()
    }

    var performsBrowserDataRequests: Bool {
        configuration.performsDataRequests
    }

    func performJSONRequest(path: String, params: [(String, String)]) throws -> [String: Any] {
        requestLock.lock()
        defer { requestLock.unlock() }
        let url = try requestURL(baseURL: configuration.apiBaseURL, path: path, params: params)
        let target = try createTarget(
            url: url,
            referrer: configuration.websiteBaseURL
        )
        do {
            let snapshot = try waitForPage(target: target, timeout: 28)
            let text = stringValue(snapshot["text"])
            if isVerificationPage(title: stringValue(snapshot["title"]), text: text) {
                // The App performs data requests in a hidden WKWebView while
                // the visible verification controller remains on the FR24
                // homepage. Keep the Local Web data target background-only as
                // well: close its challenge page and leave the retained public
                // homepage in front for the user to verify/sync again.
                closeTarget(target)
                throw BrowserError(message: "FR24 web access requires verification in the SimNav browser window.")
            }
            let status = (snapshot["status"] as? NSNumber)?.intValue ?? 0
            if status >= 400 {
                closeTarget(target)
                throw BrowserError(message: "FR24 web returned HTTP \(status).")
            }
            guard let data = text.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                closeTarget(target)
                let href = stringValue(snapshot["href"])
                let title = stringValue(snapshot["title"])
                throw BrowserError(message: "FR24 web response was not valid JSON (url=\(href), title=\(title), characters=\(text.count)).")
            }
            closeTarget(target)
            return payload
        } catch {
            if !isVerificationError(error) {
                closeTarget(target)
            }
            throw error
        }
    }

    func performFlightHistoryPageRequest(flightToken: String) throws -> [String: Any] {
        requestLock.lock()
        defer { requestLock.unlock() }
        let token = flightToken.lowercased().filter { $0.isLetter || $0.isNumber }
        guard !token.isEmpty else {
            throw BrowserError(message: "FR24 flight number missing.")
        }
        let url = configuration.websiteBaseURL
            .appendingPathComponent("data/flights")
            .appendingPathComponent(token)
        let target = try createTarget(
            url: url,
            referrer: configuration.websiteBaseURL
        )
        do {
            let page = try waitForPage(target: target, timeout: 28)
            if isVerificationPage(title: stringValue(page["title"]), text: stringValue(page["text"])) {
                closeTarget(target)
                throw BrowserError(message: "FR24 web access requires verification in the SimNav browser window.")
            }
            let deadline = Date().addingTimeInterval(7)
            var best = ""
            var bestScore = -1
            var lastSignature = ""
            var stableCount = 0
            let started = Date()
            Thread.sleep(forTimeInterval: 0.45)
            while Date() < deadline {
                let value = try evaluate(
                    target: target,
                    expression: FR24BrowserScripts.flightHistoryExtraction,
                    timeout: 10
                )
                let text = value as? String ?? ""
                let metrics = historySnapshotMetrics(text)
                if metrics.score > bestScore {
                    bestScore = metrics.score
                    best = text
                }
                if metrics.signature == lastSignature {
                    stableCount += 1
                } else {
                    lastSignature = metrics.signature
                    stableCount = 0
                }
                if Date().timeIntervalSince(started) >= 3, stableCount >= 2 {
                    break
                }
                Thread.sleep(forTimeInterval: 0.45)
            }
            if best.isEmpty {
                let value = try evaluate(
                    target: target,
                    expression: FR24BrowserScripts.flightHistoryExtraction,
                    timeout: 10
                )
                best = value as? String ?? ""
            }
            guard let data = best.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw BrowserError(message: "FR24 web response was not valid JSON.")
            }
            closeTarget(target)
            return payload
        } catch {
            if !isVerificationError(error) {
                closeTarget(target)
            }
            throw error
        }
    }

    func openVerificationPage() throws -> [String: Any] {
        requestLock.lock()
        defer { requestLock.unlock() }
        if let nativeVerification {
            let visible = try nativeVerification.open(
                url: configuration.websiteBaseURL,
                reveal: configuration.revealVerificationWindow
            )
            return [
                "opened": true,
                "visible": visible,
                "access_method": "managed_browser",
                "isolated_profile": true,
                "verification_transport": "app_webkit",
                "message": "FR24 verification opened in SimNav's built-in WebKit window."
            ]
        }
        closeRetainedVerificationTarget()
        let target = try createTarget(url: configuration.websiteBaseURL)
        retainForVerification(target)
        let visible = configuration.revealVerificationWindow
            && !configuration.launchHeadless
            && revealTargetWindow(target)
        return [
            "opened": true,
            "visible": visible,
            "access_method": "managed_browser",
            "isolated_profile": true,
            "message": "FR24 verification opened in the dedicated SimNav browser profile."
        ]
    }

    func browserSessionStatusPayload() -> [String: Any] {
        if let nativeVerification {
            return [
                "available": nativeVerification.isAvailable,
                "running": nativeVerification.isOpen,
                "isolated_profile": true,
                "background_requests": false,
                "verification_only": true,
                "automatic_sync": true,
                "browser": nativeVerification.displayName,
                "verification_transport": "app_webkit",
                "verification_opened": nativeVerification.isOpen
            ]
        }
        let storedEndpoint = stateLock.withLock { endpointURL }
        let running = storedEndpoint.map(endpointIsReady) ?? false
        let available = configuration.externalEndpointURL != nil
            || configuration.browserExecutableURL != nil
        return [
            "available": available,
            "running": running,
            "isolated_profile": true,
            "background_requests": false,
            "verification_only": true,
            "automatic_sync": true,
            "browser": browserDisplayName,
            "verification_opened": stateLock.withLock { verificationTargetID != nil }
        ]
    }

    func browserSessionSnapshotPayload() throws -> [String: Any] {
        requestLock.lock()
        defer { requestLock.unlock() }
        if let nativeVerification {
            return try nativeVerification.snapshot(for: configuration.websiteBaseURL)
        }
        guard let target = retainedVerificationTarget() else {
            return [
                "verification_opened": false,
                "web_cookie": "",
                "frpl": ""
            ]
        }

        let page = (try? evaluate(
            target: target,
            expression: #"""
            (() => {
              const keys = (storage) => {
                const output = [];
                try {
                  for (let index = 0; index < storage.length; index += 1) {
                    const key = storage.key(index);
                    if (key) output.push(key);
                  }
                } catch (_error) {}
                return output;
              };
              const findFRPl = (storage) => {
                try {
                  for (const name of ["_frPl", "_frpl", "frPl", "frpl"]) {
                    const value = storage.getItem(name);
                    if (value) return value;
                  }
                  for (const name of keys(storage)) {
                    if (String(name).toLowerCase().includes("frpl")) {
                      const value = storage.getItem(name);
                      if (value) return value;
                    }
                  }
                } catch (_error) {}
                return "";
              };
              return {
                href: location.href || "",
                title: document.title || "",
                text: String(document.body?.innerText || "").slice(0, 4000),
                cookie: document.cookie || "",
                frpl: findFRPl(localStorage) || findFRPl(sessionStorage) || ""
              };
            })()
            """#,
            timeout: 8
        )) as? [String: Any] ?? [:]

        var cookieValues = cookieValues(fromHeader: stringValue(page["cookie"]))
        if let result = try? performTargetCommand(
            target: target,
            method: "Network.getAllCookies",
            timeout: 8
        ), let cookies = result["cookies"] as? [[String: Any]] {
            for cookie in cookies where cookieBelongsToVerificationSite(cookie) {
                let name = stringValue(cookie["name"])
                let value = stringValue(cookie["value"])
                if !name.isEmpty, !value.isEmpty {
                    cookieValues[name] = value
                }
            }
        }
        let header = cookieValues.keys.sorted().compactMap { name -> String? in
            guard let value = cookieValues[name], !value.isEmpty else { return nil }
            return "\(name)=\(value)"
        }.joined(separator: "; ")
        let frPl = cookieValues["_frPl"]
            ?? stringValue(page["frpl"])
        let verificationPending = isVerificationPage(
            title: stringValue(page["title"]),
            text: stringValue(page["text"])
        )
        return [
            "verification_opened": true,
            "verification_pending": verificationPending,
            "web_cookie": header,
            "frpl": frPl,
            "cookie_count": cookieValues.count
        ]
    }

    func closeVerificationPage() throws {
        requestLock.lock()
        defer { requestLock.unlock() }
        if let nativeVerification {
            nativeVerification.close()
            return
        }
        closeRetainedVerificationTarget()
        if configuration.externalEndpointURL == nil {
            terminateOwnedBrowser()
        }
        stateLock.withLock {
            endpointURL = nil
            verificationTargetID = nil
        }
    }

    func clearBrowserSession() throws {
        requestLock.lock()
        defer { requestLock.unlock() }
        nativeVerification?.close()
        try nativeVerification?.clearWebsiteData(for: configuration.websiteBaseURL)
        terminateOwnedBrowser()
        stateLock.withLock {
            endpointURL = nil
            verificationTargetID = nil
        }
        // A host-side bridge owns an external browser profile. The Local Web
        // server clears only its own session marker and must not delete a path
        // inside the container as if it were that host profile.
        if configuration.externalEndpointURL != nil {
            return
        }
        let root = configuration.profileRoot.standardizedFileURL
        guard root.lastPathComponent == "FR24Browser"
                || root.path.contains("SimNav")
                || root.path.contains("simnav") else {
            throw BrowserError(message: "Refusing to clear an unexpected browser profile path.")
        }
        if fileManager.fileExists(atPath: root.path) {
            try fileManager.removeItem(at: root)
        }
    }

    private var browserDisplayName: String {
        if let nativeVerification {
            return nativeVerification.displayName
        }
        let name = configuration.browserExecutableURL?.lastPathComponent.lowercased() ?? ""
        if name.contains("edge") { return "Microsoft Edge" }
        if name.contains("chromium") { return "Chromium" }
        if name.contains("chrome") { return "Google Chrome" }
        return configuration.externalEndpointURL == nil ? "Chromium" : "External Chromium"
    }

    private func requestURL(
        baseURL: URL,
        path: String,
        params: [(String, String)]
    ) throws -> URL {
        let relativePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(
            url: baseURL.appendingPathComponent(relativePath),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components?.url else {
            throw BrowserError(message: "FR24 web request could not be constructed.")
        }
        return url
    }

    private func ensureEndpoint() throws -> URL {
        if let stored = stateLock.withLock({ endpointURL }), endpointIsReady(stored) {
            return stored
        }
        if let external = configuration.externalEndpointURL {
            guard endpointIsReady(external) else {
                throw BrowserError(message: "The configured FR24 browser session is not reachable.")
            }
            stateLock.withLock { endpointURL = external }
            return external
        }
        guard let executable = configuration.browserExecutableURL else {
            throw BrowserError(message: "Install Google Chrome, Chromium, or Microsoft Edge to open FR24 verification in Local Web.")
        }

        let profile = configuration.profileRoot.standardizedFileURL
        try fileManager.createDirectory(at: profile, withIntermediateDirectories: true)
        try? fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: 0o700)],
            ofItemAtPath: profile.path
        )
        clearRestoredTabState(in: profile)
        let legacyActivePortFile = profile.appendingPathComponent("DevToolsActivePort")
        let controlPortFile = profile.appendingPathComponent(".simnav-control-port")
        try? fileManager.removeItem(at: legacyActivePortFile)
        try? fileManager.removeItem(at: controlPortFile)

        // Chromium exposes navigator.webdriver=true when it is launched with
        // a zero-valued remote debugging port. Cloudflare can therefore keep a human in
        // a verification loop even after the checkbox succeeds. Reserve a
        // random non-zero loopback port first: DevTools remains private to the
        // host while the visible page has normal headed-browser semantics.
        let browserPort = try availableLoopbackPort()
        guard let browserEndpoint = URL(string: "http://127.0.0.1:\(browserPort)") else {
            throw BrowserError(message: "The dedicated FR24 browser port was invalid.")
        }

        let process = Process()
        process.executableURL = executable
        var arguments = [
            "--remote-debugging-port=\(browserPort)",
            "--remote-debugging-address=127.0.0.1",
            "--user-data-dir=\(profile.path)",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-sync",
            "--disable-background-mode",
            "--no-startup-window"
        ]
        // Keep the managed Chromium subprocess browser-compatible (including
        // navigator.webdriver=false) while its internal request targets run as
        // an off-screen background process. Only the explicit verification
        // action moves this dedicated window on-screen.
        if !configuration.launchHeadless {
            arguments += [
                "--window-position=-10000,-10000",
                "--window-size=1280,900"
            ]
        }
        arguments.append(contentsOf: configuration.additionalBrowserArguments)
        if configuration.launchHeadless {
            arguments.insert("--headless=new", at: 0)
        }
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        stateLock.withLock { ownedBrowserProcess = process }

        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if !process.isRunning {
                throw BrowserError(message: "The dedicated FR24 browser exited during startup.")
            }
            if endpointIsReady(browserEndpoint) {
                try? Data("\(browserPort)\n".utf8).write(to: controlPortFile, options: .atomic)
                stateLock.withLock { endpointURL = browserEndpoint }
                return browserEndpoint
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        terminateOwnedBrowser()
        throw BrowserError(message: "The dedicated FR24 browser did not expose its local session in time.")
    }

    private func availableLoopbackPort() throws -> Int {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }
        let channel = try ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.eventLoop.makeSucceededVoidFuture()
            }
            .bind(host: "127.0.0.1", port: 0)
            .wait()
        defer { try? channel.close().wait() }
        guard let port = channel.localAddress?.port, (1...65_535).contains(port) else {
            throw BrowserError(message: "A private FR24 browser port could not be reserved.")
        }
        return port
    }

    private func endpointIsReady(_ endpoint: URL) -> Bool {
        guard let url = URL(string: "/json/version", relativeTo: endpoint) else { return false }
        var request = controlRequest(url: url)
        request.timeoutInterval = 1.5
        guard let object = try? performHTTPJSON(request),
              object["Protocol-Version"] != nil else {
            return false
        }
        return true
    }

    private func createTarget(
        url: URL,
        referrer: URL? = nil
    ) throws -> Target {
        let endpoint = try ensureEndpoint()
        // Create an empty target first. Apple loads FR24 data pages through a
        // URLRequest carrying the public-site Referer and no-cache semantics;
        // navigating directly through /json/new omits that context and can be
        // treated as a different browser flow even though the profile is
        // already valid. Configure the target, then navigate it like WebKit.
        let encodedURL = percentEncodeQuery("about:blank")
        guard let requestURL = URL(string: "/json/new?\(encodedURL)", relativeTo: endpoint) else {
            throw BrowserError(message: "FR24 browser target could not be constructed.")
        }
        var request = controlRequest(url: requestURL)
        request.httpMethod = "PUT"
        let object = try performHTTPJSON(request)
        guard let id = object["id"] as? String,
              let webSocket = object["webSocketDebuggerUrl"] as? String,
              let rawWebSocketURL = URL(string: webSocket),
              let webSocketURL = externalWebSocketURL(
                rawWebSocketURL,
                endpoint: endpoint
              ) else {
            throw BrowserError(message: "FR24 browser target could not be opened.")
        }
        let target = Target(id: id, webSocketURL: webSocketURL)
        reactivateRetainedVerificationTarget(excluding: target.id)
        do {
            let headers: [String: String] = [
                "Cache-Control": "no-cache",
                "Pragma": "no-cache"
            ]
            var navigationParameters: [String: Any] = ["url": url.absoluteString]
            if let referrer {
                navigationParameters["referrer"] = referrer.absoluteString
            }
            let navigation = try performTargetCommandSequence(
                target: target,
                commands: [
                    ("Network.enable", [:]),
                    ("Network.setExtraHTTPHeaders", ["headers": headers]),
                    ("Network.setCacheDisabled", ["cacheDisabled": true]),
                    ("Page.navigate", navigationParameters)
                ],
                timeout: 8
            )
            if let errorText = navigation["errorText"] as? String,
               !errorText.isEmpty,
               !errorText.contains("ERR_HTTP_RESPONSE_CODE_FAILURE") {
                throw BrowserError(message: "FR24 browser navigation failed: \(errorText)")
            }
            reactivateRetainedVerificationTarget(excluding: target.id)
            return target
        } catch {
            closeTarget(target)
            throw error
        }
    }

    private func retainForVerification(_ target: Target) {
        stateLock.withLock { verificationTargetID = target.id }
        activateTarget(target)
    }

    private func retainedVerificationTarget() -> Target? {
        guard let retainedID = stateLock.withLock({ verificationTargetID }),
              let endpoint = stateLock.withLock({ endpointURL }),
              let listURL = URL(string: "/json/list", relativeTo: endpoint),
              let list = try? performHTTPJSONList(controlRequest(url: listURL)),
              let item = list.first(where: { stringValue($0["id"]) == retainedID }),
              let webSocket = URL(string: stringValue(item["webSocketDebuggerUrl"])),
              let webSocketURL = externalWebSocketURL(webSocket, endpoint: endpoint) else {
            return nil
        }
        return Target(id: retainedID, webSocketURL: webSocketURL)
    }

    /// Moves the dedicated headed window on-screen only for the user-triggered
    /// verification action. All schedule/history/playback data requests stay in
    /// the shared FR24Service and never create a browser target.
    private func revealTargetWindow(_ target: Target) -> Bool {
        do {
            let window = try performTargetCommand(
                target: target,
                method: "Browser.getWindowForTarget",
                params: ["targetId": target.id],
                timeout: 5
            )
            guard let windowID = (window["windowId"] as? NSNumber)?.intValue else {
                return false
            }
            if let bounds = window["bounds"] as? [String: Any],
               stringValue(bounds["windowState"]) != "normal" {
                _ = try performTargetCommand(
                    target: target,
                    method: "Browser.setWindowBounds",
                    params: [
                        "windowId": windowID,
                        "bounds": ["windowState": "normal"]
                    ],
                    timeout: 5
                )
            }
            _ = try performTargetCommand(
                target: target,
                method: "Browser.setWindowBounds",
                params: [
                    "windowId": windowID,
                    "bounds": [
                        "left": 72,
                        "top": 72,
                        "width": 1280,
                        "height": 900
                    ]
                ],
                timeout: 5
            )
            _ = try performTargetCommand(
                target: target,
                method: "Page.bringToFront",
                timeout: 5
            )
            activateTarget(target)
            return true
        } catch {
            activateTarget(target)
            return false
        }
    }

    private func reactivateRetainedVerificationTarget(excluding targetID: String) {
        guard let retainedID = stateLock.withLock({ verificationTargetID }),
              retainedID != targetID,
              let endpoint = stateLock.withLock({ endpointURL }),
              let url = URL(string: "/json/activate/\(retainedID)", relativeTo: endpoint) else {
            return
        }
        _ = try? performHTTPData(controlRequest(url: url))
    }

    private func closeRetainedVerificationTarget() {
        let retainedID = stateLock.withLock { () -> String? in
            let retainedID = verificationTargetID
            verificationTargetID = nil
            return retainedID
        }
        guard let retainedID,
              let endpoint = stateLock.withLock({ endpointURL }),
              let url = URL(string: "/json/close/\(retainedID)", relativeTo: endpoint) else {
            return
        }
        _ = try? performHTTPData(controlRequest(url: url))
    }

    private func clearRestoredTabState(in profile: URL) {
        // Keep the dedicated profile's Cloudflare/FR24 site data, but do not
        // reopen raw JSON or challenge tabs after a Local Web restart.
        for relativePath in [
            "Default/Sessions",
            "Default/Current Session",
            "Default/Current Tabs",
            "Default/Last Session",
            "Default/Last Tabs"
        ] {
            let item = profile.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: item.path) {
                try? fileManager.removeItem(at: item)
            }
        }
    }

    private func activateTarget(_ target: Target) {
        guard let endpoint = stateLock.withLock({ endpointURL }),
              let url = URL(string: "/json/activate/\(target.id)", relativeTo: endpoint) else {
            return
        }
        _ = try? performHTTPData(controlRequest(url: url))
    }

    private func closeTarget(_ target: Target) {
        guard stateLock.withLock({ verificationTargetID != target.id }),
              let endpoint = stateLock.withLock({ endpointURL }),
              let url = URL(string: "/json/close/\(target.id)", relativeTo: endpoint) else {
            return
        }
        _ = try? performHTTPData(controlRequest(url: url))
    }

    private func waitForPage(target: Target, timeout: TimeInterval) throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(timeout)
        var latest: [String: Any] = [:]
        let expression = #"""
        (() => ({
          ready: document.readyState || "",
          title: document.title || "",
          href: window.location.href || "",
          status: Number(performance.getEntriesByType("navigation")[0]?.responseStatus || 0),
          text: String((\#(FR24BrowserScripts.pageText)) || "")
        }))()
        """#
        while Date() < deadline {
            if let value = try evaluate(target: target, expression: expression, timeout: 8) as? [String: Any] {
                latest = value
                let ready = stringValue(value["ready"])
                let text = stringValue(value["text"])
                if isVerificationPage(title: stringValue(value["title"]), text: text) {
                    return value
                }
                if ["interactive", "complete"].contains(ready), !text.isEmpty {
                    return value
                }
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        if !latest.isEmpty { return latest }
        throw BrowserError(message: "FR24 web request timed out.")
    }

    private func evaluate(target: Target, expression: String, timeout: TimeInterval) throws -> Any {
        let result = try performTargetCommand(
            target: target,
            method: "Runtime.evaluate",
            params: [
                "expression": expression,
                "returnByValue": true,
                "awaitPromise": true
            ],
            timeout: timeout
        )
        if let exception = result["exceptionDetails"] as? [String: Any] {
            let exceptionObject = exception["exception"] as? [String: Any]
            let detail = stringValue(exceptionObject?["description"])
            let summary = detail.isEmpty ? stringValue(exception["text"]) : detail
            throw BrowserError(message: summary.isEmpty
                ? "FR24 browser evaluation raised a JavaScript exception."
                : "FR24 browser evaluation raised a JavaScript exception: \(String(summary.prefix(240)))")
        }
        guard let remote = result["result"] as? [String: Any] else {
            throw BrowserError(message: "FR24 browser evaluation failed.")
        }
        return remote["value"] ?? NSNull()
    }

    private func performTargetCommand(
        target: Target,
        method: String,
        params: [String: Any] = [:],
        timeout: TimeInterval
    ) throws -> [String: Any] {
        try performTargetCommandSequence(
            target: target,
            commands: [(method, params)],
            timeout: timeout
        )
    }

    private func performTargetCommandSequence(
        target: Target,
        commands: [(method: String, params: [String: Any])],
        timeout: TimeInterval
    ) throws -> [String: Any] {
        guard let finalMethod = commands.last?.method else {
            throw BrowserError(message: "FR24 browser command sequence was empty.")
        }
        let encodedCommands = try commands.enumerated().map { index, command -> String in
            let object: [String: Any] = [
                "id": index + 1,
                "method": command.method,
                "params": command.params
            ]
            let data = try JSONSerialization.data(withJSONObject: object)
            return String(decoding: data, as: UTF8.self)
        }
        let response = try performWebSocketCommands(
            url: target.webSocketURL,
            commands: encodedCommands,
            timeout: timeout
        )
        if let error = response["error"] as? [String: Any] {
            let message = stringValue(error["message"])
            throw BrowserError(message: message.isEmpty
                ? "FR24 browser command \(finalMethod) failed."
                : message)
        }
        guard let result = response["result"] as? [String: Any] else {
            throw BrowserError(message: "FR24 browser command \(finalMethod) returned no result.")
        }
        return result
    }

    private func performWebSocketCommands(
        url: URL,
        commands: [String],
        timeout: TimeInterval
    ) throws -> [String: Any] {
        guard !commands.isEmpty else {
            throw BrowserError(message: "FR24 browser command sequence was empty.")
        }
        guard url.scheme?.lowercased() == "ws", let host = url.host else {
            throw BrowserError(message: "FR24 browser control requires a local WebSocket endpoint.")
        }
        let port = url.port ?? 80
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var uri = components?.percentEncodedPath ?? url.path
        if uri.isEmpty { uri = "/" }
        if let query = components?.percentEncodedQuery, !query.isEmpty {
            uri += "?\(query)"
        }

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: "Host", value: port == 80 ? host : "\(host):\(port)")
        headers.replaceOrAdd(name: "Content-Length", value: "0")
        for (name, value) in controlRequest(url: url).allHTTPHeaderFields ?? [:] {
            headers.replaceOrAdd(name: name, value: value)
        }

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }
        let eventLoop = group.next()
        let completion = eventLoop.makePromise(of: Data.self)
        let state = WebSocketCommandState(completion: completion)
        let commandHandler = WebSocketCommandHandler(commands: commands, state: state)
        let upgrader = NIOWebSocketClientUpgrader(
            maxFrameSize: 4 * 1_024 * 1_024,
            automaticErrorHandling: true
        ) { channel, _ in
            channel.pipeline.addHandler(commandHandler).map {
                commandHandler.send(channel: channel)
            }
        }
        let requestHandler = WebSocketUpgradeRequestHandler(
            uri: uri,
            headers: headers,
            state: state
        )
        let upgradeConfiguration: NIOHTTPClientUpgradeSendableConfiguration = (
            upgraders: [upgrader],
            completionHandler: { context in
                context.pipeline.syncOperations.removeHandler(requestHandler, promise: nil)
            }
        )
        let bootstrap = ClientBootstrap(group: eventLoop)
            .connectTimeout(.seconds(4))
            .channelOption(ChannelOptions.tcpOption(.tcp_nodelay), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers(
                    withClientUpgrade: upgradeConfiguration
                ).flatMap {
                    channel.pipeline.addHandler(requestHandler)
                }
            }
        let channel: Channel
        do {
            channel = try bootstrap.connect(host: host, port: port).wait()
        } catch {
            completion.fail(error)
            throw error
        }
        let timeoutTask = channel.eventLoop.scheduleTask(
            in: .milliseconds(Int64(max(1, timeout * 1_000)))
        ) {
            state.fail(
                BrowserError(message: "FR24 browser response timed out."),
                channel: channel
            )
        }
        defer {
            timeoutTask.cancel()
            try? channel.close().wait()
        }
        do {
            let responseData = try completion.futureResult.wait()
            guard let object = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                throw BrowserError(message: "FR24 browser response was invalid.")
            }
            return object
        } catch {
            if let browserError = error as? BrowserError {
                throw browserError
            }
            throw BrowserError(message: "FR24 browser response failed: \(error.localizedDescription)")
        }
    }

    private func performHTTPJSON(_ request: URLRequest) throws -> [String: Any] {
        let data = try performHTTPData(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BrowserError(message: "FR24 browser control returned invalid JSON.")
        }
        return object
    }

    private func performHTTPJSONList(_ request: URLRequest) throws -> [[String: Any]] {
        let data = try performHTTPData(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw BrowserError(message: "FR24 browser control returned an invalid target list.")
        }
        return object
    }

    private func controlRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = configuration.externalEndpointToken {
            // Keep this spelling short: Swift 6.1 FoundationNetworking rejects
            // some longer custom field names with `Failed writing header`,
            // although Darwin accepts them. `X-CDP-Token` is covered by the
            // Linux container transport probe and is removed by the Windows
            // host relay before forwarding the request to Chromium.
            request.setValue(token, forHTTPHeaderField: "X-CDP-Token")
        }
        return request
    }

    private func externalWebSocketURL(_ source: URL, endpoint: URL) -> URL? {
        guard configuration.externalEndpointURL != nil else {
            return source
        }
        guard var components = URLComponents(url: source, resolvingAgainstBaseURL: false),
              let endpointComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
              let host = endpointComponents.host else {
            return nil
        }
        components.scheme = endpointComponents.scheme == "https" ? "wss" : "ws"
        components.host = host
        components.port = endpointComponents.port
        return components.url
    }

    private func performHTTPData(_ request: URLRequest) throws -> Data {
        guard let url = request.url,
              url.scheme?.lowercased() == "http",
              let host = url.host else {
            throw BrowserError(message: "FR24 browser control requires a local HTTP endpoint.")
        }
        let port = url.port ?? 80
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }
        let eventLoop = group.next()
        let completion = eventLoop.makePromise(of: ControlHTTPResult.self)
        let handler = ControlHTTPHandler(completion: completion)
        let bootstrap = ClientBootstrap(group: eventLoop)
            .connectTimeout(.seconds(4))
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelOption(ChannelOptions.tcpOption(.tcp_nodelay), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().flatMap {
                    channel.pipeline.addHandler(handler)
                }
            }
        let channel: Channel
        do {
            channel = try bootstrap.connect(host: host, port: port).wait()
        } catch {
            completion.fail(error)
            throw error
        }
        let timeout = channel.eventLoop.scheduleTask(in: .seconds(12)) {
            handler.timeOut(channel: channel)
        }
        defer {
            timeout.cancel()
            try? channel.close().wait()
        }

        var headers = HTTPHeaders()
        let hostValue = port == 80 ? host : "\(host):\(port)"
        headers.replaceOrAdd(name: "Host", value: hostValue)
        headers.replaceOrAdd(name: "Connection", value: "close")
        headers.replaceOrAdd(name: "Content-Length", value: String(request.httpBody?.count ?? 0))
        for (name, value) in request.allHTTPHeaderFields ?? [:] {
            headers.replaceOrAdd(name: name, value: value)
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var uri = components?.percentEncodedPath ?? url.path
        if uri.isEmpty { uri = "/" }
        if let query = components?.percentEncodedQuery, !query.isEmpty {
            uri += "?\(query)"
        }
        let method: HTTPMethod
        switch request.httpMethod?.uppercased() ?? "GET" {
        case "GET": method = .GET
        case "PUT": method = .PUT
        case "POST": method = .POST
        case "DELETE": method = .DELETE
        default: method = .RAW(value: request.httpMethod ?? "GET")
        }
        let head = HTTPRequestHead(
            version: .http1_1,
            method: method,
            uri: uri,
            headers: headers
        )
        channel.write(HTTPClientRequestPart.head(head), promise: nil)
        if let body = request.httpBody, !body.isEmpty {
            var buffer = channel.allocator.buffer(capacity: body.count)
            buffer.writeBytes(body)
            channel.write(HTTPClientRequestPart.body(.byteBuffer(buffer)), promise: nil)
        }
        try channel.writeAndFlush(HTTPClientRequestPart.end(nil)).wait()
        let result = try completion.futureResult.wait()
        guard (200..<300).contains(result.status) else {
            throw BrowserError(message: "Browser control returned HTTP \(result.status).")
        }
        return result.body
    }

    private func percentEncodeQuery(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private func stringValue(_ value: Any?) -> String {
        switch value {
        case let value as String: return value.trimmingCharacters(in: .whitespacesAndNewlines)
        case let value as NSNumber: return value.stringValue
        case is NSNull, nil: return ""
        default: return String(describing: value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func cookieValues(fromHeader header: String) -> [String: String] {
        var values: [String: String] = [:]
        for part in header.split(separator: ";") {
            let item = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = item.firstIndex(of: "=") else { continue }
            let name = String(item[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(item[item.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, !value.isEmpty {
                values[name] = value
            }
        }
        return values
    }

    private func cookieBelongsToVerificationSite(_ cookie: [String: Any]) -> Bool {
        guard let host = configuration.websiteBaseURL.host?.lowercased() else { return false }
        let domain = stringValue(cookie["domain"])
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return !domain.isEmpty && (host == domain || host.hasSuffix(".\(domain)"))
    }

    private func isVerificationPage(title: String, text: String) -> Bool {
        let sample = "\(title)\n\(text)".lowercased()
        return [
            "cloudflare",
            "challenge-platform",
            "just a moment",
            "checking your browser",
            "verify you are human",
            "security verification",
            "正在进行安全验证",
            "安全验证"
        ].contains { sample.contains($0) }
    }

    private func isVerificationError(_ error: Error) -> Bool {
        error.localizedDescription.localizedCaseInsensitiveContains("verification")
            || error.localizedDescription.localizedCaseInsensitiveContains("cloudflare")
    }

    private func historySnapshotMetrics(_ text: String) -> (score: Int, signature: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (text.count, "invalid|\(text.count)|\(text.hashValue)")
        }
        let rows = object["rows"] as? [[String: Any]] ?? []
        let rowText = rows.map { stringValue($0["text"]) }.joined(separator: "|")
        let bodyText = stringValue(object["bodyText"])
        let score = rows.count * 10_000_000
            + min(rowText.count, 900_000) * 10
            + min(bodyText.count, 999_999)
        return (score, "\(rows.count)|\(bodyText.count)|\(rowText.hashValue)")
    }

    private func terminateOwnedBrowser() {
        let process = stateLock.withLock { () -> Process? in
            let process = ownedBrowserProcess
            ownedBrowserProcess = nil
            return process
        }
        guard let process, process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(3)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.interrupt()
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
