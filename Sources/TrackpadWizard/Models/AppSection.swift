import Foundation

enum AppSection: String, CaseIterable, Identifiable, Codable, Sendable {
    case overview
    case touchLab
    case gestureStudio
    case haptics
    case mappings
    case devices

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .touchLab: "Touch Lab"
        case .gestureStudio: "Gesture Studio"
        case .haptics: "Haptic Composer"
        case .mappings: "Mappings"
        case .devices: "Devices"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: "Status and quick actions"
        case .touchLab: "Contacts, trails, and heatmap"
        case .gestureStudio: "Inspect native gesture events"
        case .haptics: "Compose direct actuator waveforms"
        case .mappings: "Turn gestures into shortcuts"
        case .devices: "Live HID capabilities"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .touchLab: "hand.point.up.left"
        case .gestureStudio: "waveform.path"
        case .haptics: "waveform"
        case .mappings: "command"
        case .devices: "rectangle.connected.to.line.below"
        }
    }

    var keyboardNumber: Character {
        switch self {
        case .overview: "1"
        case .touchLab: "2"
        case .gestureStudio: "3"
        case .haptics: "4"
        case .mappings: "5"
        case .devices: "6"
        }
    }
}
