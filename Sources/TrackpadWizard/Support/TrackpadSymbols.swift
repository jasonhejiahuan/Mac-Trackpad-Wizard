import Foundation

enum TrackpadSymbols {
    static let connectedDevice = "rectangle.fill"

    static func device(enhanced: Bool) -> String {
        guard enhanced else { return "rectangle.slash" }
        if #available(macOS 26.1, *) {
            return "rectangle.badge.sparkles.fill"
        }
        return "rectangle.fill"
    }
}
