import SwiftUI

struct MapContainerView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        MapWebView(environment: environment)
            .background(shellBackground)
    }

    private var shellBackground: Color {
        environment.webEffectiveTheme == "day"
            ? Color(red: 0.92, green: 0.96, blue: 0.97)
            : Color(red: 0.07, green: 0.10, blue: 0.13)
    }
}
