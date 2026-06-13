import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WebKit

struct MapWebView: UIViewRepresentable {
    let environment: AppEnvironment

    func makeCoordinator() -> Coordinator {
        Coordinator(environment: environment)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(
            NavPlannerSchemeHandler(
                plannerService: environment.plannerService,
                mapStore: environment.mapStore
            ),
            forURLScheme: "navplanner"
        )
        let deviceClass = UIDevice.current.userInterfaceIdiom == .pad ? "pad" : "phone"
        configuration.userContentController.addUserScript(WKUserScript(
            source: "document.documentElement.dataset.device = '\(deviceClass)';",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        configuration.userContentController.add(context.coordinator.scriptHandler, name: "navplanner")
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        // 需要保持 scroll view 可用，WKWebView 才能把外接鼠标滚轮 / 触控板事件交给地图；页面级偏移仍由 Coordinator 锁定。
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.delegate = context.coordinator
        context.coordinator.locksOuterScroll = true
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        webView.scrollView.delaysContentTouches = false
        if deviceClass == "phone" {
            webView.inputAssistantItem.leadingBarButtonGroups = []
            webView.inputAssistantItem.trailingBarButtonGroups = []
        }
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        if let htmlURL = Bundle.main.url(forResource: "map", withExtension: "html", subdirectory: "Web") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: URL(string: "navplanner://app/map.html")!))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIDocumentPickerDelegate, UIScrollViewDelegate {
        let scriptHandler: MapBridgeScriptHandler
        weak var webView: WKWebView?
        private weak var environment: AppEnvironment?
        var locksOuterScroll = false

        init(environment: AppEnvironment) {
            self.environment = environment
            self.scriptHandler = MapBridgeScriptHandler(environment: environment)
            super.init()
            self.scriptHandler.selectDatabaseHandler = { [weak self] in
                self?.presentDatabasePicker()
            }
            self.scriptHandler.setAppIconHandler = { [weak self] choice in
                self?.setAppIconChoice(choice)
            }
            self.scriptHandler.openFR24VerificationHandler = { [weak self] in
                self?.presentFR24VerificationBrowser()
            }
            self.scriptHandler.syncFR24SessionHandler = { [weak self] in
                self?.syncFR24SessionFromBrowser { _ in }
            }
        }

        private func presentDatabasePicker() {
            let types = [
                UTType(filenameExtension: "s3db") ?? .data,
                UTType(filenameExtension: "sqlite") ?? .data,
                UTType(filenameExtension: "sqlite3") ?? .data,
                UTType(filenameExtension: "db") ?? .data
            ]
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.delegate = self
            picker.allowsMultipleSelection = false
            topViewController()?.present(picker, animated: true)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let canAccess = url.startAccessingSecurityScopedResource()
            Task { @MainActor in
                defer {
                    if canAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                guard let environment = self.environment else { return }
                let payload = environment.importDatabase(from: url)
                self.notifyDatabaseSelection(payload)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            notifyDatabaseSelection([
                "local_status": "cancelled",
                "message": "已取消选择数据库文件"
            ])
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            DispatchQueue.main.async { [weak self] in
                guard let top = self?.topViewController() else {
                    completionHandler()
                    return
                }
                let alert = UIAlertController(title: "NavPlanner", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                    completionHandler()
                })
                top.present(alert, animated: true)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            DispatchQueue.main.async { [weak self] in
                guard let top = self?.topViewController() else {
                    completionHandler(false)
                    return
                }
                let alert = UIAlertController(title: "NavPlanner", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                    completionHandler(false)
                })
                alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                    completionHandler(true)
                })
                top.present(alert, animated: true)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            DispatchQueue.main.async { [weak self] in
                guard let top = self?.topViewController() else {
                    completionHandler(nil)
                    return
                }
                let alert = UIAlertController(title: "输入轨迹点", message: prompt, preferredStyle: .alert)
                alert.addTextField { textField in
                    textField.text = defaultText
                    textField.placeholder = #"JSON [{"lat":37.9,"lon":23.9}] 或 CSV"#
                    textField.autocapitalizationType = .none
                    textField.autocorrectionType = .no
                }
                alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                    completionHandler(nil)
                })
                alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                    completionHandler(alert.textFields?.first?.text)
                })
                top.present(alert, animated: true)
            }
        }

        private func notifyDatabaseSelection(_ payload: [String: Any]) {
            notifyJavaScript(functionName: "window.navplannerNativeDatabaseSelected", payload: payload)
        }

        private func setAppIconChoice(_ choice: String) {
            environment?.setAppIconChoice(choice) { [weak self] payload in
                self?.notifyJavaScript(functionName: "window.navplannerNativeAppIconChanged", payload: payload)
            }
        }

        private func presentFR24VerificationBrowser() {
            let controller = FR24VerificationViewController { [weak self] browserCookie, browserFRPl, browserDiagnostics, completion in
                self?.syncFR24SessionFromBrowser(
                    browserCookie: browserCookie,
                    browserFRPl: browserFRPl,
                    browserDiagnostics: browserDiagnostics,
                    completion: completion
                )
            }
            let navigation = UINavigationController(rootViewController: controller)
            if UIDevice.current.userInterfaceIdiom == .pad {
                navigation.modalPresentationStyle = .formSheet
            } else {
                navigation.modalPresentationStyle = .fullScreen
            }
            topViewController()?.present(navigation, animated: true)
        }

        private func syncFR24SessionFromBrowser(
            browserCookie: String = "",
            browserFRPl: String = "",
            browserDiagnostics: [String: Any] = [:],
            completion: @escaping ([String: Any]) -> Void
        ) {
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                let fr24Cookies = cookies
                    .filter { cookie in
                        let domain = cookie.domain.lowercased()
                        return domain.contains("flightradar24.com")
                    }
                    .sorted { lhs, rhs in
                        if lhs.domain == rhs.domain {
                            return lhs.name < rhs.name
                        }
                        return lhs.domain < rhs.domain
                    }
                let cookieHeader = Self.mergedCookieHeader(
                    storeCookies: fr24Cookies,
                    browserCookie: browserCookie
                )
                let frPl = fr24Cookies.first { $0.name == "_frPl" }?.value
                    ?? FR24SessionStore.cookieValue(named: "_frPl", in: browserCookie)
                    ?? browserFRPl
                let browserCookieNames = Self.cookieNames(from: browserCookie)
                let storeCookieNames = fr24Cookies.map(\.name)
                let frPlSource: String
                if fr24Cookies.contains(where: { $0.name == "_frPl" }) {
                    frPlSource = "cookieStore"
                } else if FR24SessionStore.cookieValue(named: "_frPl", in: browserCookie) != nil {
                    frPlSource = "document.cookie"
                } else if !browserFRPl.isEmpty {
                    frPlSource = navString(browserDiagnostics["frpl_source"]).isEmpty
                        ? "pageStorage"
                        : navString(browserDiagnostics["frpl_source"])
                } else {
                    frPlSource = "missing"
                }
                var payload: [String: Any]
                if cookieHeader.isEmpty && frPl.isEmpty {
                    payload = FR24SessionStore.accessStatusPayload()
                    payload["error"] = true
                    payload["message"] = "内置浏览器还没有可同步的 FR24 会话。请先完成 FR24 / Cloudflare 验证。"
                } else {
                    payload = FR24SessionStore.updateAccessPayload(
                        webCookie: cookieHeader,
                        frPl: frPl
                    )
                    payload["local_status"] = "synced_from_browser"
                    payload["cookie_count"] = fr24Cookies.count
                    payload["browser_cookie_count"] = browserCookieNames.count
                    payload["message"] = "已从内置浏览器同步 FR24 Web 会话。"
                }
                payload["debug"] = [
                    "url": navString(browserDiagnostics["url"]),
                    "title": navString(browserDiagnostics["title"]),
                    "store_cookie_names": storeCookieNames,
                    "browser_cookie_names": browserCookieNames,
                    "local_storage_keys": browserDiagnostics["local_storage_keys"] as? [String] ?? [],
                    "session_storage_keys": browserDiagnostics["session_storage_keys"] as? [String] ?? [],
                    "frpl_source": frPlSource,
                    "frpl_configured_after_sync": !frPl.isEmpty
                ]
                NSLog(
                    "NavPlanner FR24 sync debug url=%@ storeCookies=%@ browserCookies=%@ localKeys=%@ sessionKeys=%@ frPlSource=%@ frPl=%@",
                    navString(browserDiagnostics["url"]),
                    storeCookieNames.joined(separator: ","),
                    browserCookieNames.joined(separator: ","),
                    (browserDiagnostics["local_storage_keys"] as? [String] ?? []).joined(separator: ","),
                    (browserDiagnostics["session_storage_keys"] as? [String] ?? []).joined(separator: ","),
                    frPlSource,
                    frPl.isEmpty ? "missing" : "configured"
                )
                DispatchQueue.main.async {
                    self?.notifyJavaScript(functionName: "window.navplannerNativeFR24SessionUpdated", payload: payload)
                    completion(payload)
                }
            }
        }

        private static func cookieNames(from cookieHeader: String) -> [String] {
            cookieHeader.split(separator: ";").compactMap { part in
                let item = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let equals = item.firstIndex(of: "=") else { return nil }
                let name = item[..<equals].trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : String(name)
            }
        }

        private static func mergedCookieHeader(storeCookies: [HTTPCookie], browserCookie: String) -> String {
            var values: [String: String] = [:]
            var order: [String] = []
            func set(name: String, value: String) {
                let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedName.isEmpty, !normalizedValue.isEmpty else { return }
                if values[normalizedName] == nil {
                    order.append(normalizedName)
                }
                values[normalizedName] = normalizedValue
            }
            for cookie in storeCookies {
                set(name: cookie.name, value: cookie.value)
            }
            for part in browserCookie.split(separator: ";") {
                let item = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let equals = item.firstIndex(of: "=") else { continue }
                set(
                    name: String(item[..<equals]),
                    value: String(item[item.index(after: equals)...])
                )
            }
            return order.compactMap { name in
                values[name].map { "\(name)=\($0)" }
            }.joined(separator: "; ")
        }

        private func notifyJavaScript(functionName: String, payload: [String: Any]) {
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else {
                return
            }
            webView?.evaluateJavaScript("\(functionName)?.(\(json));")
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard locksOuterScroll else { return }
            if scrollView.contentOffset != .zero {
                scrollView.setContentOffset(.zero, animated: false)
            }
            if scrollView.contentInset != .zero {
                scrollView.contentInset = .zero
            }
            scrollView.verticalScrollIndicatorInsets = .zero
            scrollView.horizontalScrollIndicatorInsets = .zero
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            nil
        }

        private func topViewController() -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            let root = scene?.windows.first { $0.isKeyWindow }?.rootViewController
            var top = root
            while let presented = top?.presentedViewController {
                top = presented
            }
            return top
        }
    }
}

private final class FR24VerificationViewController: UIViewController, WKNavigationDelegate {
    private let syncHandler: (String, String, [String: Any], @escaping ([String: Any]) -> Void) -> Void
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        return webView
    }()
    private let statusLabel = UILabel()

    init(syncHandler: @escaping (String, String, [String: Any], @escaping ([String: Any]) -> Void) -> Void) {
        self.syncHandler = syncHandler
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "FR24 验证"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭",
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                title: "同步会话",
                style: .done,
                target: self,
                action: #selector(syncSession)
            ),
            UIBarButtonItem(
                barButtonSystemItem: .refresh,
                target: self,
                action: #selector(reload)
            )
        ]

        statusLabel.text = "完成 FR24 / Cloudflare 验证后，点右上角“同步会话”。"
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = .secondarySystemBackground
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            webView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if let url = URL(string: "https://www.flightradar24.com/") {
            webView.load(URLRequest(url: url))
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func reload() {
        webView.reload()
    }

    @objc private func syncSession() {
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = false }
        statusLabel.text = "正在同步 FR24 会话..."
        extractBrowserSession { [weak self] browserCookie, browserFRPl, diagnostics in
            guard let self else { return }
            self.syncHandler(browserCookie, browserFRPl, diagnostics) { [weak self] payload in
                guard let self else { return }
                self.navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = true }
                let message = navString(payload["message"]).isEmpty
                    ? "FR24 会话同步完成。"
                    : navString(payload["message"])
                self.statusLabel.text = message
                let alert = UIAlertController(title: "FR24", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "继续", style: .default))
                alert.addAction(UIAlertAction(title: "完成", style: .default) { [weak self] _ in
                    self?.dismiss(animated: true)
                })
                self.present(alert, animated: true)
            }
        }
    }

    private func extractBrowserSession(completion: @escaping (String, String, [String: Any]) -> Void) {
        let script = """
        (() => {
          const storageKeys = (storage) => {
            const keys = [];
            try {
              for (let i = 0; i < storage.length; i += 1) {
                const key = storage.key(i);
                if (key) keys.push(key);
              }
            } catch (_error) {}
            return keys;
          };
          const findFRPl = (storage) => {
            try {
              const exact = storage.getItem("_frPl") || storage.getItem("_frpl") || storage.getItem("frPl") || storage.getItem("frpl");
              if (exact) return { value: exact, source: "storage:_frPl" };
              for (const key of storageKeys(storage)) {
                if (String(key).toLowerCase().includes("frpl")) {
                  const value = storage.getItem(key);
                  if (value) return { value, source: `storage:${key}` };
                }
              }
            } catch (_error) {}
            return { value: "", source: "" };
          };
          const local = findFRPl(window.localStorage);
          const session = findFRPl(window.sessionStorage);
          const frpl = local.value ? local : session;
          return JSON.stringify({
            url: location.href,
            title: document.title || "",
            cookie: document.cookie || "",
            frpl: frpl.value || "",
            frpl_source: frpl.source || "",
            local_storage_keys: storageKeys(window.localStorage),
            session_storage_keys: storageKeys(window.sessionStorage)
          });
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            guard let text = result as? String,
                  let data = text.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion("", "", [:])
                return
            }
            completion(
                navString(payload["cookie"]),
                navString(payload["frpl"]),
                payload
            )
        }
    }
}
