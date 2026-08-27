import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppSection
    let deviceCount: Int

    var body: some View {
        List(selection: $selection) {
            Section("Workspace") {
                ForEach(AppSection.allCases) { section in
                    SidebarRow(section: section)
                        .tag(section)
                }
            }

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(deviceCount) trackpad\(deviceCount == 1 ? "" : "s")")
                        Text(deviceCount == 0 ? "No device reported" : "Live HID status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: deviceCount == 0 ? "rectangle.slash" : "rectangle.connected.to.line.below")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct SidebarRow: View {
    let section: AppSection

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: section.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 17)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .lineLimit(1)
                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
