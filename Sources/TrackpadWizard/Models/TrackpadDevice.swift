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

    var reportRate: Double? {
        guard let reportIntervalMicroseconds, reportIntervalMicroseconds > 0 else { return nil }
        return 1_000_000 / Double(reportIntervalMicroseconds)
    }
}

struct TrackpadSetting: Identifiable, Codable, Hashable, Sendable {
    let key: String
    let title: String
    let value: String

    var id: String { key }
}
