import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(result.ident)
                        .font(.subheadline.weight(.semibold))
                    Text(result.localizedKind)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(result.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch result.kind {
        case "airport": "airplane.circle"
        case "vor": "dot.radiowaves.left.and.right"
        case "ndb": "antenna.radiowaves.left.and.right"
        default: "smallcircle.filled.circle"
        }
    }
}

