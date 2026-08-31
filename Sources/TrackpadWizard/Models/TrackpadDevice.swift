import Foundation

enum TrackpadConnection: String, Codable, Sendable {
    case builtIn
    case bluetooth
    case usb
    case unknown

    var title: String {
        switch self {
        case .builtIn: "Built-in"
        case .bluetooth: "Bluetooth"
        case .usb: "USB"
        case .unknown: "Connected"
        }
    }

    var systemImage: String {
        switch self {
        case .builtIn: "laptopcomputer"
        case .bluetooth: "antenna.radiowaves.left.and.right"
        case .usb: "cable.connector"
        case .unknown: "questionmark.circle"
        }
    }
}

struct TrackpadDevice: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let manufacturer: String?
    let connection: TrackpadConnection
    let batteryPercent: Int?
    let reportIntervalMicroseconds: Int?
    let vendorID: Int?
    let productID: Int?
    let isBuiltIn: Bool
    let forceSupported: Bool?
    let surfaceWidthMM: Double?
    let surfaceHeightMM: Double?

    var reportRate: Double? {
        guard let reportIntervalMicroseconds, reportIntervalMicroseconds > 0 else { return nil }
        return 1_000_000 / Double(reportIntervalMicroseconds)
    }

    var surfaceSizeMM: CGSize? {
        guard let surfaceWidthMM,
              let surfaceHeightMM,
              surfaceWidthMM > 20,
              surfaceHeightMM > 20 else { return nil }
        return CGSize(width: surfaceWidthMM, height: surfaceHeightMM)
    }
}

enum TrackpadSurfaceSizeResolver {
    static func preferredSize(
        for target: HapticDeviceTarget,
        devices: [TrackpadDevice]
    ) -> CGSize? {
        let candidates: [TrackpadDevice]
        switch target {
        case .builtIn:
            candidates = devices.filter(\.isBuiltIn)
        case .external:
            candidates = devices.filter { !$0.isBuiltIn }
        case .all:
            // Public AppKit events do not identify which trackpad produced a
            // touch. Match macOS's built-in-first behavior when both classes
            // are selected, then fall back to any connected surface.
            candidates = devices.sorted { lhs, rhs in
                lhs.isBuiltIn && !rhs.isBuiltIn
            }
        }
        return candidates.lazy.compactMap(\.surfaceSizeMM).first
    }
}

struct TrackpadSetting: Identifiable, Codable, Hashable, Sendable {
    let key: String
    let title: String
    let value: String

    var id: String { key }

    var indicator: TrackpadSettingIndicator {
        if value == "Off" { return .disabled }
        if value == "On" || value.hasPrefix("On (") { return .enabled }
        if ["Light", "Medium", "Firm"].contains(value) || value.hasPrefix("Level ") {
            return .level
        }
        return .reported
    }
}

enum TrackpadSettingIndicator: Equatable, Sendable {
    case enabled
    case disabled
    case level
    case reported

    var systemImage: String {
        switch self {
        case .enabled: "checkmark.circle.fill"
        case .disabled: "minus.circle"
        case .level: "circle.lefthalf.filled"
        case .reported: "info.circle"
        }
    }
}
