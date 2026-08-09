import Combine
import Foundation
import UIKit

@MainActor
final class AppEnvironment: ObservableObject {
    let dataStore: LocalDataStore
    let plannerService: PlannerService
    let mapStore: MapStore

    @Published var selectedAirportIdent: String?
    @Published var selectedMapItemSummary = "尚未选择地图对象"
    @Published var lastBridgeEvent = "地图内核尚未发送事件"
    @Published var webThemeMode = "system"
    @Published var webEffectiveTheme = "night"
    @Published var appIconChoice = UserDefaults.standard.string(forKey: "NavPlannerAppIconChoice") ?? "primary"

    init() {
        let dataStore = LocalDataStore()
        let plannerService = PlannerService(dataStore: dataStore)
        self.dataStore = dataStore
        self.plannerService = plannerService
        self.mapStore = MapStore()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35) {
            plannerService.prewarmAirportIndex()
        }
    }

    func selectSearchResult(_ result: SearchResult) {
        selectedMapItemSummary = "\(result.localizedKind) \(result.ident) · \(result.name)"
        if result.kind == "airport" {
            selectedAirportIdent = result.ident
        }
    }

    func handleMapEvent(_ event: [String: Any]) {
        let type = navString(event["type"])
        let payload = event["payload"] as? [String: Any] ?? [:]

        switch type {
        case "airportSelected":
            let ident = navString(payload["ident"]).uppercased()
            selectedAirportIdent = ident.isEmpty ? selectedAirportIdent : ident
            selectedMapItemSummary = "机场 \(ident)"
            lastBridgeEvent = "地图选择了机场 \(ident)"
        case "pointSelected":
            let ident = navString(payload["ident"])
            let kind = navString(payload["kind"])
            selectedMapItemSummary = "\(kind.isEmpty ? "导航点" : kind) \(ident)"
            lastBridgeEvent = "地图选择了 \(ident)"
        case "mapReady":
            lastBridgeEvent = "地图内核已就绪"
        case "themeChanged":
            updateWebTheme(
                mode: navString(payload["mode"]),
                effectiveTheme: navString(payload["effectiveTheme"])
            )
        default:
            lastBridgeEvent = type.isEmpty ? "收到未知地图事件" : "收到地图事件：\(type)"
        }
    }

    func updateWebTheme(mode: String, effectiveTheme: String) {
        let normalizedMode = ["system", "day", "night"].contains(mode) ? mode : "system"
        let normalizedEffective = ["day", "night"].contains(effectiveTheme) ? effectiveTheme : "night"
        webThemeMode = normalizedMode
        webEffectiveTheme = normalizedEffective
    }

    func setAppIconChoice(_ choice: String, completion: @escaping ([String: Any]) -> Void) {
        let iconOptions: [String: (iconName: String?, label: String)] = [
            "day-high": ("AppIconDayHigh", "日间高饱和"),
            "primary": (nil, "日间均衡"),
            "day-soft": ("AppIconDaySoft", "日间柔和"),
            "night-high": ("AppIconNightHigh", "夜间高对比"),
            "night-medium": ("AppIconNightMedium", "夜间均衡"),
            "night-soft": ("AppIconNightSoft", "夜间柔和")
        ]
        let normalized = iconOptions.keys.contains(choice) ? choice : "primary"
        let iconName = iconOptions[normalized]?.iconName ?? nil
        guard UIApplication.shared.supportsAlternateIcons else {
            completion([
                "icon_choice": appIconChoice,
                "error": true,
                "message": "当前系统不支持切换 App 图标。"
            ])
            return
        }
        if UIApplication.shared.alternateIconName == iconName {
            appIconChoice = normalized
            UserDefaults.standard.set(normalized, forKey: "NavPlannerAppIconChoice")
            completion([
                "icon_choice": normalized,
                "message": "应用图标已是当前选择。"
            ])
            return
        }
        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    completion([
                        "icon_choice": self.appIconChoice,
                        "error": true,
                        "message": "切换应用图标失败：\(error.localizedDescription)"
                    ])
                    return
                }
                self.appIconChoice = normalized
                UserDefaults.standard.set(normalized, forKey: "NavPlannerAppIconChoice")
                let label = iconOptions[normalized]?.label ?? "默认"
                completion([
                    "icon_choice": normalized,
                    "message": "已切换为\(label)应用图标。"
                ])
            }
        }
    }

    func importDatabase(from url: URL) -> [String: Any] {
        do {
            let payload = try dataStore.importDatabase(from: url)
            plannerService.invalidatePlanningCaches()
            lastBridgeEvent = navString(payload["message"])
            return payload
        } catch {
            let message = "导入数据库失败：\(error.localizedDescription)"
            lastBridgeEvent = message
            return [
                "local_status": "import_failed",
                "database_path": dataStore.databaseURL?.path ?? "",
                "database_name": dataStore.databaseURL?.lastPathComponent ?? "",
                "message": message
            ]
        }
    }
}
