import SwiftUI

struct SelectionPanelView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "选择", subtitle: "地图点击与 Procedure 预览状态")

            VStack(alignment: .leading, spacing: 8) {
                Label(environment.selectedMapItemSummary, systemImage: "scope")
                    .font(.subheadline)
                Text(environment.lastBridgeEvent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Web 地图内核已通过 WKScriptMessageHandler 向 SwiftUI 外壳回传机场和导航点选择事件。后续阶段会把 Selection 明细表逐步原生化。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

