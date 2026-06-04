import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPlanVisible = true
    @State private var isDetailVisible = true
    @State private var mobileSheet: MobileSheet?

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

    private var iPadWorkbench: some View {
        VStack(spacing: 0) {
            WorkbenchHeader(
                isPlanVisible: $isPlanVisible,
                isDetailVisible: $isDetailVisible
            )

            HStack(spacing: 0) {
                if isPlanVisible {
                    PlanPanelView()
                        .frame(width: 330)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Divider()
                }

                MapContainerView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isDetailVisible {
                    Divider()
                    ScrollView {
                        VStack(spacing: 16) {
                            AirportDetailView()
                            SelectionPanelView()
                            OfflineMapsView()
                        }
                        .padding(16)
                    }
                    .frame(width: 360)
                    .background(Color(.secondarySystemGroupedBackground))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private var iPhoneWorkbench: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapContainerView()
                    .ignoresSafeArea(edges: .bottom)

                MobileDock(mobileSheet: $mobileSheet)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
            .navigationTitle("NavPlanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mobileSheet = .offlineMaps
                    } label: {
                        Label("离线地图", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .sheet(item: $mobileSheet) { sheet in
                NavigationStack {
                    sheet.content
                        .navigationTitle(sheet.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct WorkbenchHeader: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var isPlanVisible: Bool
    @Binding var isDetailVisible: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("NavPlanner")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("本地优先 · 离线航路规划")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(environment.lastBridgeEvent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                withAnimation(.snappy) {
                    isPlanVisible.toggle()
                }
            } label: {
                Label(isPlanVisible ? "隐藏计划栏" : "显示计划栏", systemImage: "sidebar.leading")
            }
            .labelStyle(.iconOnly)

            Button {
                withAnimation(.snappy) {
                    isDetailVisible.toggle()
                }
            } label: {
                Label(isDetailVisible ? "隐藏详情栏" : "显示详情栏", systemImage: "sidebar.trailing")
            }
            .labelStyle(.iconOnly)
        }
        .padding(.horizontal, 18)
        .frame(height: 50)
        .background(.bar)
    }
}

private enum MobileSheet: String, Identifiable {
    case plan
    case airports
    case selection
    case offlineMaps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plan: "航路计划"
        case .airports: "机场详情"
        case .selection: "选择信息"
        case .offlineMaps: "离线地图"
        }
    }

    @ViewBuilder
    var content: some View {
        switch self {
        case .plan:
            PlanPanelView()
        case .airports:
            AirportDetailView()
                .padding()
        case .selection:
            SelectionPanelView()
                .padding()
        case .offlineMaps:
            OfflineMapsView()
                .padding()
        }
    }
}

private struct MobileDock: View {
    @Binding var mobileSheet: MobileSheet?

    var body: some View {
        HStack(spacing: 8) {
            DockButton(title: "计划", icon: "point.topleft.down.curvedto.point.bottomright.up") {
                mobileSheet = .plan
            }
            DockButton(title: "机场", icon: "airplane.departure") {
                mobileSheet = .airports
            }
            DockButton(title: "选择", icon: "scope") {
                mobileSheet = .selection
            }
            DockButton(title: "离线", icon: "externaldrive") {
                mobileSheet = .offlineMaps
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DockButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
