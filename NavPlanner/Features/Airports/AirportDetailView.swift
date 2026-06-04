import SwiftUI

struct AirportDetailView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var airportText = ""
    @State private var details: [String: Any]?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "机场详情", subtitle: "跑道、通信频率和 Procedure 摘要")

            HStack {
                TextField("输入机场 ICAO / IATA", text: $airportText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await loadAirport(airportText) }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("加载机场详情")
            }

            if isLoading {
                ProgressView("正在读取本地机场数据")
                    .font(.caption)
            } else if let details {
                AirportContent(details: details)
            } else {
                Text("从搜索结果或地图机场弹窗选择机场，也可以直接输入机场代码。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let ident = environment.selectedAirportIdent, airportText.isEmpty {
                airportText = ident
                Task { await loadAirport(ident) }
            }
        }
        .onChange(of: environment.selectedAirportIdent) { _, ident in
            guard let ident else { return }
            airportText = ident
            Task { await loadAirport(ident) }
        }
    }

    @MainActor
    private func loadAirport(_ ident: String) async {
        let token = ident.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        isLoading = true
        details = await environment.plannerService.airportPayloadAsync(ident: token)
        isLoading = false
    }
}

private struct AirportContent: View {
    let details: [String: Any]

    var body: some View {
        let airport = details["airport"] as? [String: Any] ?? [:]
        let runways = details["runways"] as? [[String: Any]] ?? []
        let communications = details["communications"] as? [[String: Any]] ?? []
        let procedures = details["procedures"] as? [String: Any] ?? [:]

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(navString(airport["airport_identifier"]))
                    .font(.title3.weight(.semibold))
                Text(navString(airport["airport_name"]))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("坐标 \(coordinateText(lat: airport["airport_ref_latitude"], lon: airport["airport_ref_longitude"]))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DetailBlock(title: "跑道 \(runways.count)") {
                if runways.isEmpty {
                    EmptyText("无跑道数据")
                } else {
                    ForEach(runways.indices, id: \.self) { index in
                        let runway = runways[index]
                        HStack {
                            Text(navString(runway["runway_identifier"]))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(navString(runway["runway_length"])) ft")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            DetailBlock(title: "通信频率 \(communications.count)") {
                if communications.isEmpty {
                    EmptyText("无通信频率数据")
                } else {
                    ForEach(communications.indices.prefix(8), id: \.self) { index in
                        let comm = communications[index]
                        HStack {
                            Text(navString(comm["communication_type"]))
                            Spacer()
                            Text(navString(comm["communication_frequency"]))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }

            DetailBlock(title: "Procedure") {
                ProcedureCountRow(title: "SID", value: count(in: procedures, key: "sid"), color: .cyan)
                ProcedureCountRow(title: "STAR", value: count(in: procedures, key: "star"), color: .orange)
                ProcedureCountRow(title: "APPROACH", value: count(in: procedures, key: "approach"), color: .purple)
            }
        }
    }

    private func count(in procedures: [String: Any], key: String) -> Int {
        (procedures[key] as? [[String: Any]])?.count ?? 0
    }

    private func coordinateText(lat: Any?, lon: Any?) -> String {
        guard let lat = navDouble(lat), let lon = navDouble(lon) else {
            return "--"
        }
        return String(format: "%.4f, %.4f", lat, lon)
    }
}

private struct DetailBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProcedureCountRow: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
            Spacer()
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
        }
        .font(.caption)
    }
}

private struct EmptyText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

