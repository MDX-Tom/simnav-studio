import Foundation
import WebKit

final class MapBridgeScriptHandler: NSObject, WKScriptMessageHandler {
    weak var environment: AppEnvironment?
    var selectDatabaseHandler: (() -> Void)?
    var importOfflineMapHandler: (() -> Void)?
    var importFR24GPXHandler: (() -> Void)?
    var setAppIconHandler: ((String) -> Void)?
    var openFR24VerificationHandler: (() -> Void)?
    var syncFR24SessionHandler: (() -> Void)?
    var openFR24CacheDirectoryHandler: (() -> Void)?
    var shareFileHandler: ((String, String) -> Void)?
    var focusFormControlHandler: (() -> Void)?
    var blurFormControlHandler: (() -> Void)?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let event = message.body as? [String: Any] else { return }
        let type = navString(event["type"])
        if type == "runtimeDiagnostic" {
#if DEBUG
            writeRuntimeDiagnostic(event["payload"] as? [String: Any] ?? [:])
#endif
            return
        }
        if type == "focusFormControl" {
            if Thread.isMainThread {
                focusFormControlHandler?()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.focusFormControlHandler?()
                }
            }
            return
        }
        if type == "blurFormControl" {
            if Thread.isMainThread {
                blurFormControlHandler?()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.blurFormControlHandler?()
                }
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            if type == "selectDatabase" {
                self?.selectDatabaseHandler?()
                return
            }
            if type == "importOfflineMap" {
                self?.importOfflineMapHandler?()
                return
            }
            if type == "importFR24GPX" {
                self?.importFR24GPXHandler?()
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

#if DEBUG
    private func writeRuntimeDiagnostic(_ payload: [String: Any]) {
        let rawLevel = navString(payload["level"]).lowercased()
        let level = rawLevel == "warning" ? "warning" : "error"
        let message = String(navString(payload["message"]).prefix(8_000))
        let source = String(navString(payload["source"]).prefix(2_000))
        let line = navString(payload["line"])
        let column = navString(payload["column"])
        let stack = String(navString(payload["stack"]).prefix(12_000))

        var location = source
        if !line.isEmpty, line != "0" {
            location += ":\(line)"
            if !column.isEmpty, column != "0" {
                location += ":\(column)"
            }
        }

        var output = "[NavPlanner JS \(level)]"
        if !location.isEmpty {
            output += " \(location)"
        }
        output += " \(message)"
        if !stack.isEmpty {
            output += "\n\(stack)"
        }
        output += "\n"
        FileHandle.standardError.write(Data(output.utf8))
    }
#endif
}
