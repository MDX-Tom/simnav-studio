import Foundation
import WebKit

final class MapBridgeScriptHandler: NSObject, WKScriptMessageHandler {
    weak var environment: AppEnvironment?
    var selectDatabaseHandler: (() -> Void)?
    var setAppIconHandler: ((String) -> Void)?
    var openFR24VerificationHandler: (() -> Void)?
    var syncFR24SessionHandler: (() -> Void)?
    var openFR24CacheDirectoryHandler: (() -> Void)?
    var shareFileHandler: ((String, String) -> Void)?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let event = message.body as? [String: Any] else { return }
        DispatchQueue.main.async { [weak self] in
            let type = navString(event["type"])
            if type == "selectDatabase" {
                self?.selectDatabaseHandler?()
                return
            }
            if type == "setAppIcon" {
                let payload = event["payload"] as? [String: Any] ?? [:]
                self?.setAppIconHandler?(navString(payload["iconChoice"]))
                return
            }
            if type == "openFR24Verification" {
                self?.openFR24VerificationHandler?()
                return
            }
            if type == "syncFR24Session" {
                self?.syncFR24SessionHandler?()
                return
            }
            if type == "openFR24CacheDirectory" {
                self?.openFR24CacheDirectoryHandler?()
                return
            }
            if type == "shareFile" {
                let payload = event["payload"] as? [String: Any] ?? [:]
                self?.shareFileHandler?(navString(payload["path"]), navString(payload["title"]))
                return
            }
            self?.environment?.handleMapEvent(event)
        }
    }
}
