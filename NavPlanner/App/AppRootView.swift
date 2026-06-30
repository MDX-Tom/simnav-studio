import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ZStack {
            shellBackground
                .ignoresSafeArea()

            MapContainerView()
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        }
        .preferredColorScheme(preferredColorScheme)
        .tint(.teal)
    }

    private var shellBackground: Color {
        environment.webEffectiveTheme == "day"
            ? Color(red: 0.92, green: 0.96, blue: 0.97)
            : Color(red: 0.07, green: 0.10, blue: 0.13)
    }

    private var preferredColorScheme: ColorScheme? {
        switch environment.webThemeMode {
        case "day":
            .light
        case "night":
            .dark
        default:
            nil
        }
    }
}
