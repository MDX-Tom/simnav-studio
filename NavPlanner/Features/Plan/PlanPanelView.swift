import SwiftUI

struct PlanPanelView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var departure = ""
    @State private var arrival = ""
    @State private var routeText = ""
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "计划", subtitle: "本地搜索与第一阶段航路输入")

                VStack(alignment: .leading, spacing: 10) {
                    TextField("搜索 ICAO / IATA / 航点 / 导航台", text: $searchText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .task(id: searchText) {
                            await performSearch()
                        }

                    if isSearching {
                        ProgressView("正在搜索本地数据库")
                            .font(.caption)
                    }

                    ForEach(searchResults) { result in
                        Button {
                            environment.selectSearchResult(result)
                            if result.kind == "airport" {
                                if departure.isEmpty {
                                    departure = result.ident
                                } else if arrival.isEmpty {
                                    arrival = result.ident
                                }
                            }
                        } label: {
                            SearchResultRow(result: result)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField("始发机场", text: $departure)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    TextField("目的机场", text: $arrival)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Text("航路")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $routeText)
                        .frame(minHeight: 100)
                        .padding(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        }

                    Button {
                        // 第一阶段保留本地 API 入口，完整自动规划在 PlannerCore 迁移阶段接入。
                        environment.lastBridgeEvent = "已记录航路输入，自动规划待迁移"
                    } label: {
                        Label("构建航路", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("当前阶段已接入本地 SQLite 搜索、机场详情和地图 nav-overlay；自动规划、DCT 与航路展开会在下一阶段迁移。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    @MainActor
    private func performSearch() async {
        let token = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        try? await Task.sleep(nanoseconds: 220_000_000)
        guard !Task.isCancelled else { return }
        searchResults = await environment.plannerService.searchAsync(query: token)
        isSearching = false
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

