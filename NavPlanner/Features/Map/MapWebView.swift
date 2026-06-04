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
        // iPhone 键盘弹出时仍需让 WKWebView 接收原生输入手势；页面级偏移由 Coordinator 锁定。
        webView.scrollView.isScrollEnabled = deviceClass == "phone"
        webView.scrollView.delegate = context.coordinator
        context.coordinator.locksOuterScroll = deviceClass == "phone"
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
        webView.load(URLRequest(url: URL(string: "navplanner://app/map.html")!))
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
