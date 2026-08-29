import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum HapticPatternFileService {
    static func importPattern() throws -> HapticPatternDocument? {
        let panel = NSOpenPanel()
        panel.title = "Import Haptic Pattern"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HapticPatternDocument.self, from: Data(contentsOf: url)).validated()
    }

    static func exportPattern(_ pattern: HapticPatternDocument) throws -> URL? {
        let pattern = try pattern.validated()
        let panel = NSSavePanel()
        panel.title = "Export Haptic Pattern"
        panel.nameFieldStringValue = "\(safeFileName(pattern.name)).trackpadhaptic.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(pattern).write(to: url, options: .atomic)
        return url
    }

    private static func safeFileName(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = name.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Haptic Pattern" : cleaned
    }
}
