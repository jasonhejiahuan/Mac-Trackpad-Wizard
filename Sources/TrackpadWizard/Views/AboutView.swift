import AppKit
import SwiftUI

struct AboutView: View {
    private let version = BundleVersion.current

    var body: some View {
        HStack(alignment: .center, spacing: 44) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 164, height: 164)
                .accessibilityLabel("Trackpad Wizard application icon")

            VStack(alignment: .leading, spacing: 0) {
                Text("Trackpad Wizard")
                    .font(.system(size: 42, weight: .regular))
                    .lineLimit(1)
                Text(version.displayString)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Spacer().frame(height: 34)

                Text("A native macOS laboratory for touch contacts, gestures, Force Touch, haptic composition, mappings, and live device diagnostics.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 18)

                LabeledContent("Author") {
                    Text("JASON Studio")
                        .fontWeight(.medium)
                }
                .font(.subheadline)

                Spacer().frame(height: 24)

                HStack {
                    Spacer()
                    Link(destination: URL(string: "https://github.com/jasonhejiahuan/Mac-Trackpad-Wizard")!) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.glass)
                }
            }
            .frame(maxWidth: 410, maxHeight: 250, alignment: .topLeading)
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 34)
        .frame(width: 700, height: 360)
        .containerBackground(.thickMaterial, for: .window)
    }
}

struct BundleVersion {
    let marketing: String
    let build: String

    static var current: BundleVersion {
        let dictionary = Bundle.main.infoDictionary ?? [:]
        return BundleVersion(
            marketing: dictionary["CFBundleShortVersionString"] as? String ?? "Unknown",
            build: dictionary["CFBundleVersion"] as? String ?? "Unknown"
        )
    }

    var displayString: String {
        build == "Unknown" ? "Version \(marketing)" : "Version \(marketing) (\(build))"
    }
}
