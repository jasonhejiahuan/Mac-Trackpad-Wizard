import Foundation

enum ExperimentalFeatureKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case surfaceOrientation
    case systemHaptics

    var id: Self { self }

    var title: String {
        switch self {
        case .surfaceOrientation: "Surface Orientation"
        case .systemHaptics: "System Haptic Feedback"
        }
    }
}

enum ExperimentalSurfaceOrientation: Int, CaseIterable, Identifiable, Codable, Sendable {
    case degrees0 = 0
    case degrees90 = 90
    case degrees180 = 180
    case degrees270 = 270

    var id: Self { self }
    var title: String { "\(rawValue)°" }

    /// The available `MTDeviceSetSurfaceOrientation` runtime accepts only 0 and 2.
    /// Quarter turns therefore keep the hardware at its normal orientation and
    /// rotate Trackpad Wizard's normalized coordinate space.
    var privateOrientationCode: UInt32 {
        self == .degrees180 ? 2 : 0
    }

    var previewRotationDegrees: Int {
        switch self {
        case .degrees90, .degrees270: rawValue
        case .degrees0, .degrees180: 0
        }
    }

    var usesNativeOrientation: Bool {
        self == .degrees0 || self == .degrees180
    }

    func transformPoint(x: Double, y: Double) -> (x: Double, y: Double) {
        switch previewRotationDegrees {
        case 90: (1 - y, x)
        case 270: (y, 1 - x)
        default: (x, y)
        }
    }

    func transformVector(x: Double, y: Double) -> (x: Double, y: Double) {
        switch previewRotationDegrees {
        case 90: (-y, x)
        case 270: (y, -x)
        default: (x, y)
        }
    }
}

struct AdvancedFeatureConfirmation: Identifiable, Equatable, Sendable {
    let id: UUID
    let feature: ExperimentalFeatureKind
    let title: String
    let message: String
    let deadline: Date

    init(
        id: UUID = UUID(),
        feature: ExperimentalFeatureKind,
        title: String,
        message: String,
        deadline: Date
    ) {
        self.id = id
        self.feature = feature
        self.title = title
        self.message = message
        self.deadline = deadline
    }
}

struct SurfaceOrientationSnapshot: Equatable, Sendable {
    let valuesByDevice: [UInt64: UInt32]
}

struct SystemHapticsSnapshot: Equatable, Sendable {
    let valuesByDevice: [UInt64: Bool]
}
