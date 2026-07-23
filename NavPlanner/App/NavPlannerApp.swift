import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct NavPlannerApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            rootView
        }
        .defaultSize(width: 1440, height: 960)
        #else
        WindowGroup {
            rootView
        }
        #endif
    }

    private var rootView: some View {
        AppRootView()
            .environmentObject(environment)
            .background {
                #if canImport(UIKit)
                MacWindowGeometryConfigurator()
                    .frame(width: 0, height: 0)
                #else
                EmptyView()
                #endif
            }
    }
}

#if canImport(UIKit)
private enum MacWindowSizeStore {
    private static let widthKey = "NavPlannerMacWindowWidth"
    private static let heightKey = "NavPlannerMacWindowHeight"
    private static let minimumDimension: CGFloat = 320

    static let defaultSize = CGSize(width: 1440, height: 960)

    static var savedSize: CGSize? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: widthKey) != nil,
              defaults.object(forKey: heightKey) != nil
        else {
            return nil
        }

        let width = defaults.double(forKey: widthKey)
        let height = defaults.double(forKey: heightKey)
        guard width.isFinite,
              height.isFinite,
              width >= minimumDimension,
              height >= minimumDimension
        else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    static func save(_ size: CGSize) {
        let normalizedSize = CGSize(width: size.width.rounded(), height: size.height.rounded())
        guard normalizedSize.width.isFinite,
              normalizedSize.height.isFinite,
              normalizedSize.width >= minimumDimension,
              normalizedSize.height >= minimumDimension
        else {
            return
        }

        let defaults = UserDefaults.standard
        defaults.set(normalizedSize.width, forKey: widthKey)
        defaults.set(normalizedSize.height, forKey: heightKey)
    }
}

private enum MacWindowSystemGeometry {
    private static let systemFrameKey = "systemFrame"
    private static let systemFrameSelector = NSSelectorFromString(systemFrameKey)

    // Designed-for-iPad builds use the iOS SDK, while the Mac compatibility
    // runtime supplies the public Mac scene-geometry objects at runtime.
    static func frame(for windowScene: UIWindowScene) -> CGRect? {
        let geometry = windowScene.effectiveGeometry as NSObject
        guard geometry.responds(to: systemFrameSelector),
              let value = geometry.value(forKey: systemFrameKey) as? NSValue
        else {
            return nil
        }

        let frame = value.cgRectValue
        guard !frame.isNull,
              !frame.isInfinite,
              frame.width > 0,
              frame.height > 0
        else {
            return nil
        }
        return frame
    }

    static func preferences(for frame: CGRect) -> UIWindowScene.GeometryPreferences? {
        guard let preferencesType = NSClassFromString("UIWindowSceneGeometryPreferencesMac") as? NSObject.Type else {
            return nil
        }

        let preferences = preferencesType.init()
        guard preferences.responds(to: systemFrameSelector) else {
            return nil
        }
        preferences.setValue(NSValue(cgRect: frame), forKey: systemFrameKey)
        return preferences as? UIWindowScene.GeometryPreferences
    }
}

private struct MacWindowGeometryConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GeometryController {
        let controller = GeometryController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: GeometryController, context: Context) {
        uiViewController.requestMacGeometryIfNeeded()
    }

    final class GeometryController: UIViewController {
        private var didRequestMacGeometry = false
        private var geometryTimer: Timer?
        private var lifecycleObservers: [NSObjectProtocol] = []
        private var canPersistMacWindowSize = false
        private var lastPersistedSize: CGSize?

        deinit {
            geometryTimer?.invalidate()
            lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            requestMacGeometryIfNeeded()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            requestMacGeometryIfNeeded()
        }

        override func viewWillDisappear(_ animated: Bool) {
            captureMacWindowSize()
            super.viewWillDisappear(animated)
        }

        func requestMacGeometryIfNeeded() {
            let forceLandscapeForSimulatorDebug = ProcessInfo.processInfo.environment["NAVPLANNER_SIM_FORCE_LANDSCAPE"] == "1"
            let isRunningOnMac = ProcessInfo.processInfo.isiOSAppOnMac
            guard !didRequestMacGeometry,
                  (isRunningOnMac || forceLandscapeForSimulatorDebug),
                  let windowScene = view.window?.windowScene
            else {
                return
            }

            didRequestMacGeometry = true
            if isRunningOnMac {
                startMacGeometryPolling()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak windowScene] in
                    guard let self, let windowScene else {
                        return
                    }
                    self.restoreMacWindowSize(in: windowScene)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.canPersistMacWindowSize = true
                    self?.captureMacWindowSize()
                }
            }

            if #available(iOS 16.0, *) {
                let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
                windowScene.requestGeometryUpdate(preferences) { _ in }
            }

            #if targetEnvironment(macCatalyst)
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 1100, height: 720)
            #endif
        }

        private func startMacGeometryPolling() {
            guard geometryTimer == nil else {
                return
            }

            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.captureMacWindowSize()
            }
            geometryTimer = timer
            RunLoop.main.add(timer, forMode: .common)

            let center = NotificationCenter.default
            lifecycleObservers = [
                UIScene.willDeactivateNotification,
                UIScene.didEnterBackgroundNotification,
                UIApplication.willTerminateNotification,
                UIWindow.didBecomeHiddenNotification
            ].map { name in
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.captureMacWindowSize()
                }
            }
        }

        private func restoreMacWindowSize(in windowScene: UIWindowScene) {
            let savedSize = MacWindowSizeStore.savedSize ?? MacWindowSizeStore.defaultSize
            if let currentFrame = MacWindowSystemGeometry.frame(for: windowScene),
               let preferences = MacWindowSystemGeometry.preferences(
                   for: CGRect(origin: currentFrame.origin, size: savedSize)
               ) {
                windowScene.requestGeometryUpdate(preferences) { _ in }
                return
            }

            // Older compatibility runtimes do not expose Mac system geometry.
            // Keep their existing UIKit sizing behavior as a fallback.
            preferredContentSize = savedSize
            parent?.preferredContentSize = savedSize
            view.window?.rootViewController?.preferredContentSize = savedSize
        }

        private func captureMacWindowSize() {
            guard ProcessInfo.processInfo.isiOSAppOnMac,
                  canPersistMacWindowSize,
                  let windowScene = view.window?.windowScene
            else {
                return
            }

            let fallbackSize: CGSize
            if #available(iOS 26.0, *) {
                guard !windowScene.effectiveGeometry.isInteractivelyResizing else {
                    return
                }
                fallbackSize = windowScene.effectiveGeometry.coordinateSpace.bounds.size
            } else {
                fallbackSize = windowScene.coordinateSpace.bounds.size
            }

            let sceneSize = MacWindowSystemGeometry.frame(for: windowScene)?.size ?? fallbackSize

            let normalizedSize = CGSize(width: sceneSize.width.rounded(), height: sceneSize.height.rounded())
            guard normalizedSize != lastPersistedSize else {
                return
            }

            MacWindowSizeStore.save(normalizedSize)
            lastPersistedSize = normalizedSize
        }
    }
}
#endif
