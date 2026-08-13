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
        let platformClass = ProcessInfo.processInfo.navPlannerIsRunningOnMac ? "mac" : "ios"
        configuration.userContentController.addUserScript(WKUserScript(
            source: """
            (() => {
              const root = document.documentElement;
              const deviceClass = "\(deviceClass)";
              const platformClass = "\(platformClass)";
              root.dataset.device = deviceClass;
              root.dataset.platform = platformClass;
              root.dataset.mobileLayout = deviceClass === "phone"
                || (deviceClass === "pad"
                  && platformClass === "ios"
                  && (!window.matchMedia || window.matchMedia("(orientation: portrait)").matches))
                ? "true"
                : "false";
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        if platformClass == "mac" {
            configuration.userContentController.addUserScript(WKUserScript(
                source: macTextInputTraitsScript(),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }
#if DEBUG
        configuration.userContentController.addUserScript(WKUserScript(
            source: runtimeDiagnosticsScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        if let debugScript = simulatorDebugLaunchScript() {
            configuration.userContentController.addUserScript(WKUserScript(
                source: debugScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }
#endif
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
        if deviceClass == "phone" || platformClass == "mac" {
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

#if DEBUG
    private func runtimeDiagnosticsScript() -> String {
        """
        (() => {
          if (window.__navplannerRuntimeDiagnosticsInstalled) return;
          window.__navplannerRuntimeDiagnosticsInstalled = true;

          const describe = (value) => {
            if (value instanceof Error) return value.stack || `${value.name}: ${value.message}`;
            if (typeof value === "string") return value;
            try {
              return JSON.stringify(value);
            } catch (_) {
              return String(value);
            }
          };
          const report = (level, message, details = {}) => {
            try {
              window.webkit?.messageHandlers?.navplanner?.postMessage({
                type: "runtimeDiagnostic",
                payload: {
                  level,
                  message: String(message || "").slice(0, 8000),
                  source: String(details.source || "").slice(0, 2000),
                  line: details.line || 0,
                  column: details.column || 0,
                  stack: String(details.stack || "").slice(0, 12000)
                }
              });
            } catch (_) {}
          };

          for (const level of ["warn", "error"]) {
            const original = console[level];
            console[level] = function(...values) {
              const result = original.apply(this, values);
              report(level === "warn" ? "warning" : "error", values.map(describe).join(" "), {
                stack: new Error().stack || ""
              });
              return result;
            };
          }

          window.addEventListener("error", (event) => {
            report("error", event.message || "Uncaught JavaScript error", {
              source: event.filename,
              line: event.lineno,
              column: event.colno,
              stack: event.error?.stack || ""
            });
          });
          window.addEventListener("unhandledrejection", (event) => {
            report("error", `Unhandled promise rejection: ${describe(event.reason)}`, {
              stack: event.reason?.stack || ""
            });
          });
        })();
        """
    }
    private func simulatorDebugLaunchScript() -> String? {
        let key = "NAVPLANNER_SIM_DEBUG_JSON"
        guard let payload = ProcessInfo.processInfo.environment[key],
              !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = try? JSONEncoder().encode(payload),
              let literal = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return "window.__NAVPLANNER_SIM_DEBUG_JSON = \(literal);"
    }
#endif

    private func macTextInputTraitsScript() -> String {
        """
        (() => {
          if (window.__navplannerMacTextInputTraitsInstalled) return;
          window.__navplannerMacTextInputTraitsInstalled = true;

          const editableTypes = new Set([
            "text", "search", "password", "email", "url", "tel", "number", "decimal"
          ]);
          const configure = (control) => {
            if (!(control instanceof Element)) return;
            const isTextArea = control instanceof HTMLTextAreaElement;
            const isEditable = control.getAttribute("contenteditable") === "true";
            const isTextInput = control instanceof HTMLInputElement
              && editableTypes.has((control.getAttribute("type") || "text").toLowerCase());
            if (!isTextArea && !isEditable && !isTextInput) return;

            // Since iOS 15, disabling autocorrection alone no longer removes the
            // QuickType strip. WebKit maps spellcheck=false to
            // UITextSpellCheckingType.no, which is Apple's supported way to hide it.
            control.setAttribute("spellcheck", "false");
            control.setAttribute("autocorrect", "off");
            control.setAttribute("autocapitalize", "none");
            control.setAttribute("autocomplete", "off");
          };
          const configureTree = (root) => {
            configure(root);
            if (!(root instanceof Document || root instanceof Element)) return;
            root.querySelectorAll("input, textarea, [contenteditable='true']").forEach(configure);
          };

          configureTree(document);
          new MutationObserver((records) => {
            records.forEach((record) => record.addedNodes.forEach(configureTree));
          }).observe(document, { childList: true, subtree: true });
        })();
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIDocumentPickerDelegate, UIDocumentInteractionControllerDelegate, UIScrollViewDelegate {
        let scriptHandler: MapBridgeScriptHandler
        weak var webView: WKWebView?
        private weak var environment: AppEnvironment?
        private var documentInteractionController: UIDocumentInteractionController?
        private var documentPickerPurpose: DocumentPickerPurpose = .database
        private weak var fr24VerificationController: FR24VerificationViewController?
        var locksOuterScroll = false
        private var macFormControlIsActive = false

        private enum DocumentPickerPurpose {
            case database
            case offlineMap
            case fr24GPX
        }

        init(environment: AppEnvironment) {
            self.environment = environment
            self.scriptHandler = MapBridgeScriptHandler(environment: environment)
            super.init()
            self.scriptHandler.selectDatabaseHandler = { [weak self] in
                self?.presentDatabasePicker()
            }
            self.scriptHandler.importOfflineMapHandler = { [weak self] in
                self?.presentOfflineMapPicker()
            }
            self.scriptHandler.importFR24GPXHandler = { [weak self] in
                self?.presentFR24GPXPicker()
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
            self.scriptHandler.openFR24CacheDirectoryHandler = { [weak self] in
                self?.openFR24CacheDirectory()
            }
            self.scriptHandler.shareFileHandler = { [weak self] path, title in
                self?.shareFile(path: path, title: title)
            }
            self.scriptHandler.focusFormControlHandler = { [weak self] in
                self?.focusFormControl()
            }
            self.scriptHandler.blurFormControlHandler = { [weak self] in
                self?.blurFormControl()
            }
        }

        private func presentDatabasePicker() {
            documentPickerPurpose = .database
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

        private func presentFR24GPXPicker() {
            documentPickerPurpose = .fr24GPX
            let types = [
                UTType(filenameExtension: "gpx") ?? .xml,
                .xml,
                .data
            ]
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.delegate = self
            picker.allowsMultipleSelection = false
            topViewController()?.present(picker, animated: true)
        }

        private func presentOfflineMapPicker() {
            documentPickerPurpose = .offlineMap
            let types = [
                UTType(filenameExtension: "pmtiles") ?? .data,
                UTType(filenameExtension: "mbtiles") ?? .data,
                UTType(filenameExtension: "sqlite") ?? .data,
                UTType(filenameExtension: "sqlite3") ?? .data
            ]
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.delegate = self
            picker.allowsMultipleSelection = false
            topViewController()?.present(picker, animated: true)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let purpose = documentPickerPurpose
            documentPickerPurpose = .database
            let canAccess = url.startAccessingSecurityScopedResource()
            if purpose == .offlineMap {
                importOfflineMap(from: url, canAccessSecurityScopedResource: canAccess)
                return
            }
            Task { @MainActor in
                defer {
                    if canAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                switch purpose {
                case .database:
                    guard let environment = self.environment else { return }
                    let payload = environment.importDatabase(from: url)
                    self.notifyDatabaseSelection(payload)
                case .offlineMap:
                    break
                case .fr24GPX:
                    self.importFR24GPX(from: url)
                }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            let purpose = documentPickerPurpose
            documentPickerPurpose = .database
            switch purpose {
            case .database:
                notifyDatabaseSelection([
                    "local_status": "cancelled",
                    "message": "已取消选择数据库文件"
                ])
            case .offlineMap:
                notifyOfflineMapImported([
                    "local_status": "cancelled",
                    "message": "已取消选择离线地图文件。"
                ])
            case .fr24GPX:
                notifyFR24GPXImported([
                    "error": true,
                    "message": "已取消选择 GPX 文件。"
                ])
            }
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
                let alert = UIAlertController(title: "SimNav Studio", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                    completionHandler()
                })
                top.present(alert, animated: true)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            configureMacTextInput(in: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url,
                  Self.isProjectRepositoryURL(url)
            else {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
            UIApplication.shared.open(url)
        }

        private static func isProjectRepositoryURL(_ url: URL) -> Bool {
            url.scheme?.lowercased() == "https"
                && url.host?.lowercased() == "github.com"
                && url.port == nil
                && url.user == nil
                && url.password == nil
                && url.path == "/MDX-Tom/simnav-studio"
                && url.query == nil
                && url.fragment == nil
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
                let alert = UIAlertController(title: "SimNav Studio", message: message, preferredStyle: .alert)
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

        private func importOfflineMap(from url: URL, canAccessSecurityScopedResource: Bool) {
            guard let mapStore = environment?.mapStore else {
                if canAccessSecurityScopedResource {
                    url.stopAccessingSecurityScopedResource()
                }
                notifyOfflineMapImported([
                    "error": true,
                    "message": "离线地图服务不可用。"
                ])
                return
            }
            DispatchQueue.global(qos: .utility).async { [weak self] in
                defer {
                    if canAccessSecurityScopedResource {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let payload: [String: Any]
                do {
                    payload = try mapStore.importResource(from: url)
                } catch {
                    payload = [
                        "error": true,
                        "message": "无法导入离线地图：\(error.localizedDescription)"
                    ]
                }
                DispatchQueue.main.async {
                    self?.notifyOfflineMapImported(payload)
                }
            }
        }

        private func notifyOfflineMapImported(_ payload: [String: Any]) {
            notifyJavaScript(functionName: "window.navplannerNativeOfflineMapImported", payload: payload)
        }

        private func importFR24GPX(from url: URL) {
            do {
                let data = try Data(contentsOf: url)
                let trackPoints = try GPXTrackPointParser.parse(data: data)
                guard trackPoints.count >= 2 else {
                    notifyFR24GPXImported([
                        "error": true,
                        "filename": url.lastPathComponent,
                        "message": "GPX 文件中的轨迹点不足，无法绘制。"
                    ])
                    return
                }
                notifyFR24GPXImported([
                    "filename": url.lastPathComponent,
                    "track_points": trackPoints,
                    "track_point_count": trackPoints.count,
                    "message": "已导入 GPX 轨迹。"
                ])
            } catch {
                notifyFR24GPXImported([
                    "error": true,
                    "filename": url.lastPathComponent,
                    "message": "无法读取 GPX 文件：\(error.localizedDescription)"
                ])
            }
        }

        private func notifyFR24GPXImported(_ payload: [String: Any]) {
            notifyJavaScript(functionName: "window.navplannerNativeFR24GPXImported", payload: payload)
        }

        private func setAppIconChoice(_ choice: String) {
            environment?.setAppIconChoice(choice) { [weak self] payload in
                self?.notifyJavaScript(functionName: "window.navplannerNativeAppIconChanged", payload: payload)
            }
        }

        private func presentFR24VerificationBrowser() {
            if let controller = fr24VerificationController,
               (controller.viewIfLoaded?.window != nil
                || controller.navigationController?.presentingViewController != nil
                || controller.presentingViewController != nil) {
                controller.navigationController?.popToViewController(controller, animated: false)
                NSLog("NavPlanner FR24 verification controller reused")
                return
            }
            let controller = FR24VerificationViewController { [weak self] browserCookie, browserFRPl, browserDiagnostics, completion in
                self?.syncFR24SessionFromBrowser(
                    browserCookie: browserCookie,
                    browserFRPl: browserFRPl,
                    browserDiagnostics: browserDiagnostics,
                    completion: completion
                )
            }
            fr24VerificationController = controller
            let navigation = UINavigationController(rootViewController: controller)
            if UIDevice.current.userInterfaceIdiom == .pad {
                navigation.modalPresentationStyle = .formSheet
            } else {
                navigation.modalPresentationStyle = .fullScreen
            }
            guard let presenter = topViewController() else { return }
            NSLog("NavPlanner FR24 verification controller created")
            presenter.present(navigation, animated: true) {
#if DEBUG
                controller.scheduleSimulatorAutoSyncIfConfigured()
                controller.scheduleSimulatorAutoDismissIfConfigured()
#endif
            }
        }

        private func openFR24CacheDirectory() {
            let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let directory = cacheRoot
                .appendingPathComponent("NavPlanner", isDirectory: true)
                .appendingPathComponent("FR24", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                notifyFR24CacheDirectoryOpened([
                    "error": true,
                    "path": directory.path,
                    "message": "无法创建 FR24 缓存目录：\(error.localizedDescription)"
                ])
                return
            }

            UIApplication.shared.open(directory, options: [:]) { [weak self] opened in
                guard let self else { return }
                if opened {
                    self.notifyFR24CacheDirectoryOpened([
                        "path": directory.path,
                        "message": "已打开 FR24 缓存目录。"
                    ])
                    return
                }
                if self.presentFR24CacheDirectoryOptions(directory) {
                    self.notifyFR24CacheDirectoryOpened([
                        "path": directory.path,
                        "message": "已显示 FR24 缓存目录操作面板。"
                    ])
                } else {
                    self.notifyFR24CacheDirectoryOpened([
                        "error": true,
                        "path": directory.path,
                        "message": "无法直接打开 FR24 缓存目录。"
                    ])
                }
            }
        }

        private func presentFR24CacheDirectoryOptions(_ directory: URL) -> Bool {
            guard let top = topViewController(), let view = top.view else {
                return false
            }
            let controller = UIDocumentInteractionController(url: directory)
            controller.delegate = self
            documentInteractionController = controller
            return controller.presentOptionsMenu(from: view.bounds, in: view, animated: true)
        }

        func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
            if documentInteractionController === controller {
                documentInteractionController = nil
            }
        }

        private func notifyFR24CacheDirectoryOpened(_ payload: [String: Any]) {
            notifyJavaScript(functionName: "window.navplannerNativeFR24CacheDirectoryOpened", payload: payload)
        }

        private func focusFormControl() {
            guard let webView else { return }
            if ProcessInfo.processInfo.navPlannerIsRunningOnMac {
                configureMacTextInput(in: webView)
                // WKContentView can remain first responder even when no HTML form
                // control is editing, so walking UIKit's responder tree gives a false
                // positive. Track the HTML focus lifecycle instead: promote WebKit once
                // when editing begins, not again while focus moves between controls.
                if macFormControlIsActive {
                    return
                }
                macFormControlIsActive = true
            }
            if !webView.isFirstResponder {
                webView.becomeFirstResponder()
            }
            if ProcessInfo.processInfo.navPlannerIsRunningOnMac {
                DispatchQueue.main.async { [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.configureMacTextInput(in: webView)
                }
            }
        }

        private func configureMacTextInput(in webView: WKWebView) {
            guard ProcessInfo.processInfo.navPlannerIsRunningOnMac else { return }
            webView.inputAssistantItem.leadingBarButtonGroups = []
            webView.inputAssistantItem.trailingBarButtonGroups = []
        }

        private func blurFormControl() {
            guard let webView else { return }
            if ProcessInfo.processInfo.navPlannerIsRunningOnMac {
                macFormControlIsActive = false
            }
            webView.endEditing(true)
        }

        private func shareFile(path: String, title: String) {
            guard !path.isEmpty else { return }
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path),
                  let top = topViewController(),
                  let sourceView = top.view else {
                return
            }
            let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if !title.isEmpty {
                controller.setValue(title, forKey: "subject")
            }
            if let popover = controller.popoverPresentationController {
                popover.sourceView = sourceView
                popover.sourceRect = CGRect(
                    x: sourceView.bounds.midX,
                    y: sourceView.bounds.maxY - 44,
                    width: 1,
                    height: 1
                )
                popover.permittedArrowDirections = []
            }
            top.present(controller, animated: true)
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
                    _ = FR24SessionStore.updateAccessPayload(
                        webCookie: cookieHeader,
                        frPl: frPl
                    )
                    FR24SessionStore.markBrowserSync()
                    payload = FR24SessionStore.accessStatusPayload()
                    payload["local_status"] = "synced_from_browser"
                    payload["cookie_count"] = fr24Cookies.count
                    payload["browser_cookie_count"] = browserCookieNames.count
                    payload["message"] = "已保存内置浏览器 FR24 会话，返回 App 后将立即验证。"
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

private final class GPXTrackPointParser: NSObject, XMLParserDelegate {
    private var points: [[String: Any]] = []
    private var currentPoint: [String: Any]?
    private var textBuffer = ""
    private var currentElement = ""
    private var parseError: Error?
    private static let isoFormatter = ISO8601DateFormatter()

    static func parse(data: Data) throws -> [[String: Any]] {
        let parserDelegate = GPXTrackPointParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else {
            throw parser.parserError ?? parserDelegate.parseError ?? NSError(
                domain: "NavPlanner.GPX",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "GPX parse failed."]
            )
        }
        if let parseError = parserDelegate.parseError {
            throw parseError
        }
        return parserDelegate.points
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = (qName ?? elementName).lowercased()
        currentElement = name
        textBuffer = ""
        guard name == "trkpt" else { return }
        if let lat = Double(attributeDict["lat"] ?? ""),
           let lon = Double(attributeDict["lon"] ?? ""),
           lat.isFinite,
           lon.isFinite {
            currentPoint = ["lat": lat, "lon": lon]
        } else {
            currentPoint = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = (qName ?? elementName).lowercased()
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            textBuffer = ""
            currentElement = ""
        }
        guard var point = currentPoint else { return }

        if name == "trkpt" {
            points.append(point)
            currentPoint = nil
            return
        }
        guard !text.isEmpty else { return }
        if name == "ele", let meters = Double(text), meters.isFinite {
            let feet = meters * 3.280839895
            point["altitude_m"] = meters
            point["altitude_ft"] = feet
            point["altitude"] = feet
        } else if name == "time", let date = Self.isoFormatter.date(from: text) {
            point["timestamp"] = Int(date.timeIntervalSince1970)
        } else if name.contains("altitude_ft"), let feet = Double(text), feet.isFinite {
            point["altitude_ft"] = feet
            point["altitude"] = feet
        } else if name.contains("speed_kt") || name.contains("speed_knot"), let knots = Double(text), knots.isFinite {
            point["speed_kt"] = knots
            point["speed"] = knots
        } else if name.contains("speed_mps") || name.contains("speed"), let metersPerSecond = Double(text), metersPerSecond.isFinite {
            let knots = metersPerSecond / 0.514444
            point["speed_kt"] = knots
            point["speed"] = knots
        }
        currentPoint = point
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}

private final class FR24VerificationViewController: UIViewController, WKNavigationDelegate {
    private let syncHandler: (String, String, [String: Any], @escaping ([String: Any]) -> Void) -> Void
    private var webView: WKWebView!
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let loadingOverlay = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var progressObservation: NSKeyValueObservation?
    private var loadingTimeoutWorkItem: DispatchWorkItem?
    private var isDismissingAfterSync = false
    private var didTearDownWebView = false

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
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
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
        progressView.progress = 0
        progressView.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false

        loadingOverlay.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.94)
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = "正在连接 flightradar24.com..."
        loadingLabel.font = .preferredFont(forTextStyle: .body)
        loadingLabel.textColor = .secondaryLabel
        loadingLabel.textAlignment = .center
        loadingLabel.numberOfLines = 0
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("重新加载", for: .normal)
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(reload), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statusLabel)
        view.addSubview(progressView)
        view.addSubview(webView)
        view.addSubview(loadingOverlay)
        loadingOverlay.addSubview(loadingSpinner)
        loadingOverlay.addSubview(loadingLabel)
        loadingOverlay.addSubview(retryButton)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingOverlay.topAnchor.constraint(equalTo: webView.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
            loadingSpinner.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor, constant: -30),
            loadingLabel.topAnchor.constraint(equalTo: loadingSpinner.bottomAnchor, constant: 16),
            loadingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: loadingOverlay.leadingAnchor, constant: 24),
            loadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: loadingOverlay.trailingAnchor, constant: -24),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 12),
            retryButton.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor)
        ])

        progressObservation = webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.progressView.setProgress(Float(webView.estimatedProgress), animated: true)
            }
        }

        if let url = URL(string: "https://www.flightradar24.com/") {
            beginLoadingFeedback()
            webView.load(URLRequest(url: url))
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            tearDownWebView()
        }
    }

    deinit {
        loadingTimeoutWorkItem?.cancel()
        progressObservation?.invalidate()
    }

    @objc private func close() {
        view.endEditing(true)
        dismiss(animated: true) { [weak self] in
            self?.tearDownWebView()
        }
    }

#if DEBUG
    func scheduleSimulatorAutoSyncIfConfigured() {
        let key = "NAVPLANNER_SIM_VERIFICATION_AUTO_SYNC_MS"
        guard let raw = ProcessInfo.processInfo.environment[key],
              let milliseconds = Double(raw),
              milliseconds > 0
        else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + milliseconds / 1_000) { [weak self] in
            self?.syncSession()
        }
    }

    func scheduleSimulatorAutoDismissIfConfigured() {
        let key = "NAVPLANNER_SIM_VERIFICATION_AUTO_DISMISS_MS"
        guard let raw = ProcessInfo.processInfo.environment[key],
              let milliseconds = Double(raw),
              milliseconds > 0
        else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + milliseconds / 1_000) { [weak self] in
            self?.close()
        }
    }
#endif

    @objc private func reload() {
        guard webView != nil else { return }
        beginLoadingFeedback()
        webView.reload()
    }

    @objc private func syncSession() {
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = false }
        statusLabel.text = "正在同步 FR24 会话..."
        extractBrowserSession { [weak self] browserCookie, browserFRPl, diagnostics in
            guard let self else { return }
            self.syncHandler(browserCookie, browserFRPl, diagnostics) { [weak self] payload in
                guard let self else { return }
                let message = navString(payload["message"]).isEmpty
                    ? "FR24 会话同步完成。"
                    : navString(payload["message"])
                self.statusLabel.text = message
                let hasError = (payload["error"] as? Bool) ?? false
                guard hasError else {
                    self.dismissAfterSuccessfulSync()
                    return
                }
                self.navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = true }
                let alert = UIAlertController(title: "FR24", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "继续", style: .default))
                DispatchQueue.main.async { [weak self] in
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    private func beginLoadingFeedback() {
        loadingTimeoutWorkItem?.cancel()
        loadingOverlay.alpha = 1
        loadingOverlay.isHidden = false
        loadingLabel.text = "正在连接 flightradar24.com..."
        retryButton.isHidden = true
        loadingSpinner.startAnimating()
        progressView.isHidden = false
        progressView.setProgress(0.05, animated: false)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.webView?.isLoading == true else { return }
            self.loadingLabel.text = "页面加载时间较长，可继续等待或重新加载。"
            self.retryButton.isHidden = false
        }
        loadingTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: workItem)
    }

    private func finishLoadingFeedback() {
        loadingTimeoutWorkItem?.cancel()
        loadingTimeoutWorkItem = nil
        progressView.setProgress(1, animated: true)
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.loadingOverlay.alpha = 0
        }, completion: { [weak self] _ in
            self?.loadingSpinner.stopAnimating()
            self?.loadingOverlay.isHidden = true
            self?.loadingOverlay.alpha = 1
            self?.progressView.isHidden = true
        })
    }

    private func showMainFrameLoadError(_ error: Error) {
        if (error as NSError).code == NSURLErrorCancelled {
            return
        }
        loadingTimeoutWorkItem?.cancel()
        loadingTimeoutWorkItem = nil
        loadingSpinner.stopAnimating()
        loadingOverlay.alpha = 1
        loadingOverlay.isHidden = false
        loadingLabel.text = "FR24 主页面加载失败：\(error.localizedDescription)"
        retryButton.isHidden = false
        progressView.isHidden = true
    }

    private func dismissAfterSuccessfulSync() {
        guard !isDismissingAfterSync else { return }
        isDismissingAfterSync = true
        view.endEditing(true)
        // Separate bar/status updates and the full-screen dismissal across run-loop
        // turns to avoid multiple iOS 27 Liquid Glass mutations in one frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            self.dismiss(animated: true) { [weak self] in
                self?.tearDownWebView()
            }
        }
    }

    private func tearDownWebView() {
        guard !didTearDownWebView else { return }
        didTearDownWebView = true
        loadingTimeoutWorkItem?.cancel()
        loadingTimeoutWorkItem = nil
        progressObservation?.invalidate()
        progressObservation = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.removeFromSuperview()
        webView = nil
        NSLog("NavPlanner FR24 verification controller web view released")
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        beginLoadingFeedback()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishLoadingFeedback()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showMainFrameLoadError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showMainFrameLoadError(error)
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
