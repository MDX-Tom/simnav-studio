import Foundation

protocol LocalWebFR24NativeVerificationSession: AnyObject {
    var isAvailable: Bool { get }
    var isOpen: Bool { get }
    var displayName: String { get }

    @discardableResult
    func open(url: URL, reveal: Bool) throws -> Bool
    func snapshot(for websiteURL: URL) throws -> [String: Any]
    func close()
    func clearWebsiteData(for websiteURL: URL) throws
}

func makeLocalWebFR24NativeVerificationSession() -> LocalWebFR24NativeVerificationSession? {
#if os(macOS) && canImport(AppKit) && canImport(WebKit)
    LocalWebFR24WebKitVerification()
#else
    nil
#endif
}

#if os(macOS) && canImport(AppKit) && canImport(WebKit)
import AppKit
import WebKit

/// A small App-owned WKWebView used only for explicit FR24 verification.
///
/// This mirrors the Apple App's verification controller and cookie-store
/// export. It does not attach to Safari, read the user's Safari profile, or
/// launch a separately installed Chromium browser.
private final class LocalWebFR24WebKitVerification:
    NSObject,
    LocalWebFR24NativeVerificationSession,
    NSWindowDelegate,
    WKNavigationDelegate,
    @unchecked Sendable {

    private struct VerificationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private final class ResultBox<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Value, Error>?

        func store(_ value: Result<Value, Error>) {
            lock.lock()
            result = value
            lock.unlock()
        }

        func load() -> Result<Value, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return result
        }
    }

    private let stateLock = NSLock()
    private var openState = false

    /// Main-thread-only AppKit/WebKit objects.
    private var window: NSWindow?
    private var webView: WKWebView?

    var isAvailable: Bool { true }

    var isOpen: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return openState
    }

    var displayName: String { "SimNav App WebKit" }

    @discardableResult
    func open(url: URL, reveal: Bool) throws -> Bool {
        try onMainThread(timeout: 10) { [weak self] in
            guard let self else {
                throw VerificationError(message: "The FR24 WebKit verification session was released.")
            }
            let application = NSApplication.shared
            if application.activationPolicy() == .prohibited {
                application.setActivationPolicy(.accessory)
            }

            let webView: WKWebView
            let window: NSWindow
            if let existingWebView = self.webView,
               let existingWindow = self.window {
                webView = existingWebView
                window = existingWindow
            } else {
                let configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = .default()
                configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
                webView = WKWebView(
                    frame: NSRect(x: 0, y: 0, width: 1_240, height: 860),
                    configuration: configuration
                )
                webView.navigationDelegate = self
                if #available(macOS 13.3, *) {
                    webView.isInspectable = true
                }
                window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 1_240, height: 860),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                window.title = "SimNav Studio · FR24 验证"
                window.minSize = NSSize(width: 760, height: 560)
                window.contentView = webView
                window.delegate = self
                window.isReleasedWhenClosed = false
                window.center()
                self.webView = webView
                self.window = window
            }

            self.setOpenState(true)
            webView.load(URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            ))
            if reveal {
                window.makeKeyAndOrderFront(nil)
                application.activate(ignoringOtherApps: true)
            } else {
                window.orderOut(nil)
            }
            return reveal
        }
    }

    func snapshot(for websiteURL: URL) throws -> [String: Any] {
        guard isOpen else {
            return [
                "verification_opened": false,
                "web_cookie": "",
                "frpl": ""
            ]
        }
        guard !Thread.isMainThread else {
            throw VerificationError(message: "FR24 WebKit session inspection must run outside the main thread.")
        }

        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox<[String: Any]>()
        DispatchQueue.main.async { [weak self] in
            guard let self, let webView = self.webView else {
                box.store(.success([
                    "verification_opened": false,
                    "web_cookie": "",
                    "frpl": ""
                ]))
                semaphore.signal()
                return
            }
            webView.evaluateJavaScript(Self.sessionSnapshotScript) { pageValue, _ in
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    let page = pageValue as? [String: Any] ?? [:]
                    var cookieValues = Self.cookieValues(
                        fromHeader: Self.stringValue(page["cookie"])
                    )
                    for cookie in cookies where Self.cookie(cookie, belongsTo: websiteURL) {
                        let name = cookie.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = cookie.value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty, !value.isEmpty {
                            cookieValues[name] = value
                        }
                    }
                    let header = cookieValues.keys.sorted().compactMap { name -> String? in
                        guard let value = cookieValues[name], !value.isEmpty else { return nil }
                        return "\(name)=\(value)"
                    }.joined(separator: "; ")
                    let frPl = cookieValues["_frPl"] ?? Self.stringValue(page["frpl"])
                    let pending = Self.isVerificationPage(
                        title: Self.stringValue(page["title"]),
                        text: Self.stringValue(page["text"])
                    )
                    box.store(.success([
                        "verification_opened": true,
                        "verification_pending": pending,
                        "web_cookie": header,
                        "frpl": frPl,
                        "cookie_count": cookieValues.count,
                        "verification_transport": "app_webkit"
                    ]))
                    semaphore.signal()
                }
            }
        }
        guard semaphore.wait(timeout: .now() + 12) == .success,
              let result = box.load() else {
            throw VerificationError(message: "FR24 WebKit session inspection timed out.")
        }
        return try result.get()
    }

    func close() {
        let work = { [weak self] in
            guard let self else { return }
            self.webView?.stopLoading()
            self.window?.orderOut(nil)
            self.setOpenState(false)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    func clearWebsiteData(for websiteURL: URL) throws {
        close()
        guard !Thread.isMainThread else {
            throw VerificationError(message: "FR24 WebKit website data clearing must run outside the main thread.")
        }
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            let store = WKWebsiteDataStore.default()
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            store.fetchDataRecords(ofTypes: types) { records in
                let host = websiteURL.host?.lowercased() ?? "flightradar24.com"
                let matching = records.filter { record in
                    let name = record.displayName.lowercased()
                    return name == host
                        || name.hasSuffix(".\(host)")
                        || name.contains("flightradar24")
                }
                guard !matching.isEmpty else {
                    semaphore.signal()
                    return
                }
                store.removeData(ofTypes: types, for: matching) {
                    semaphore.signal()
                }
            }
        }
        guard semaphore.wait(timeout: .now() + 15) == .success else {
            throw VerificationError(message: "FR24 WebKit website data clearing timed out.")
        }
    }

    func windowWillClose(_ notification: Notification) {
        webView?.stopLoading()
        setOpenState(false)
    }

    private func setOpenState(_ value: Bool) {
        stateLock.lock()
        openState = value
        stateLock.unlock()
    }

    private func onMainThread<Value>(
        timeout: TimeInterval,
        _ operation: @escaping () throws -> Value
    ) throws -> Value {
        if Thread.isMainThread {
            return try operation()
        }
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox<Value>()
        DispatchQueue.main.async {
            do {
                box.store(.success(try operation()))
            } catch {
                box.store(.failure(error))
            }
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + timeout) == .success,
              let result = box.load() else {
            throw VerificationError(message: "FR24 WebKit main-thread operation timed out.")
        }
        return try result.get()
    }

    private static func cookie(_ cookie: HTTPCookie, belongsTo websiteURL: URL) -> Bool {
        guard let host = websiteURL.host?.lowercased() else { return false }
        let domain = cookie.domain
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return !domain.isEmpty && (host == domain || host.hasSuffix(".\(domain)"))
    }

    private static func cookieValues(fromHeader header: String) -> [String: String] {
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

    private static func isVerificationPage(title: String, text: String) -> Bool {
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

    private static let sessionSnapshotScript = #"""
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
    """#
}
#endif
