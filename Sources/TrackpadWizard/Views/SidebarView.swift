import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppSection
    let deviceCount: Int
    let experimentalFeatureCount: Int
    let showsHints: Bool

    var body: some View {
        List(selection: $selection) {
            Section("Workspace") {
                ForEach(AppSection.allCases) { section in
                    SidebarRow(
                        section: section,
                        showsHint: showsHints,
                        trailingCount: count(for: section)
                    )
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func count(for section: AppSection) -> Int? {
        switch section {
        case .devices: deviceCount
        case .advanced: experimentalFeatureCount
        default: nil
        }
    }
}

private struct SidebarRow: View {
    let section: AppSection
    let showsHint: Bool
    let trailingCount: Int?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: section.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 17)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .lineLimit(1)
                if showsHint {
                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if let trailingCount {
                Text(trailingCount.formatted())
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .accessibilityLabel(
                        section == .devices
                            ? "\(trailingCount) connected trackpads"
                            : "\(trailingCount) enabled experimental features"
                    )
            }
        }
        .padding(.vertical, 2)
    }
}
