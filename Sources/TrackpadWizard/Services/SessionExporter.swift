import AppKit
import Foundation

@MainActor
enum SessionExporter {
    static func export(_ session: TouchSessionExport) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Touch Session"
        panel.nameFieldStringValue = "Trackpad Session.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(session).write(to: url, options: .atomic)
        return url
    }
}
