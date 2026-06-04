import Foundation
import WebKit

final class MapBridgeScriptHandler: NSObject, WKScriptMessageHandler {
    weak var environment: AppEnvironment?
    var selectDatabaseHandler: (() -> Void)?
    var setAppIconHandler: ((String) -> Void)?

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
            self?.environment?.handleMapEvent(event)
        }
    }
}
