import SwiftUI

struct OfflineMapsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var status: [String: Any] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "离线地图", subtitle: "单文件地图包扫描与状态")
                Spacer()
                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("刷新离线地图")
            }

            let resources = status["resources"] as? [[String: Any]] ?? []
            if resources.isEmpty {
                Text("暂无已导入地图包。第一阶段会扫描 Application Support/NavPlanner/MapOffline 中的 PMTiles、MBTiles 和 SQLite 单文件资源。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(resources.indices, id: \.self) { index in
                    let resource = resources[index]
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(navString(resource["label"]))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(navString(resource["kind"]))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(navString(resource["storage_layout"])) · \(formatSize(navInt(resource["size_bytes"]) ?? 0))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Text(navString(status["message"]))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        status = environment.mapStore.statusPayload()
    }

    private func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

