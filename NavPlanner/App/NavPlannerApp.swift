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
        private static let preferredMacWindowSize = CGSize(width: 1440, height: 960)
        private var didRequestMacGeometry = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            requestMacGeometryIfNeeded()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            requestMacGeometryIfNeeded()
        }

        func requestMacGeometryIfNeeded() {
            guard !didRequestMacGeometry,
                  ProcessInfo.processInfo.isiOSAppOnMac,
                  let windowScene = view.window?.windowScene
            else {
                return
            }

            didRequestMacGeometry = true
            preferredContentSize = Self.preferredMacWindowSize
            parent?.preferredContentSize = Self.preferredMacWindowSize
            view.window?.rootViewController?.preferredContentSize = Self.preferredMacWindowSize

            if #available(iOS 16.0, *) {
                let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
                windowScene.requestGeometryUpdate(preferences) { _ in }
            }

            #if targetEnvironment(macCatalyst)
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 1100, height: 720)
            #endif
        }
    }
}
#endif
