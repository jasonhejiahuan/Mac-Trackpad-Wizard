import Foundation

enum HapticFeedbackKind: Int, CaseIterable, Codable, Identifiable, Sendable {
    case weakClick = 1
    case strongClick = 2
    case buzz = 3
    case lightTap = 4
    case mediumTap = 5
    case strongTap = 6
    case softThud = 15
    case strongThud = 16

    var id: Self { self }

    var title: String {
        switch self {
        case .weakClick: "Weak Click"
        case .strongClick: "Strong Click"
        case .buzz: "Buzz"
        case .lightTap: "Light Tap"
        case .mediumTap: "Medium Tap"
        case .strongTap: "Strong Tap"
        case .softThud: "Soft Thud"
        case .strongThud: "Strong Thud"
        }
    }

    var systemImage: String {
        switch self {
        case .weakClick: "circle"
        case .strongClick: "circle.inset.filled"
        case .buzz: "waveform.path"
        case .lightTap: "circle.dotted"
        case .mediumTap: "circle.fill"
        case .strongTap: "circle.circle.fill"
        case .softThud: "smallcircle.filled.circle"
        case .strongThud: "dot.circle.and.hand.point.up.left.fill"
        }
    }

    var waveformID: Int32 { Int32(rawValue) }
}

struct HapticStep: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var isEnabled: Bool
    var feedback: HapticFeedbackKind
    var length: Int

    init(
        id: UUID = UUID(),
        isEnabled: Bool,
        feedback: HapticFeedbackKind = .mediumTap,
        length: Int = 1
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.feedback = feedback
        self.length = length
    }
}

enum HapticOutputMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case enhanced

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .enhanced: "Enhanced"
        }
    }
}

enum HapticDeviceTarget: String, CaseIterable, Codable, Identifiable, Sendable {
    case all
    case builtIn
    case external

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All Trackpads"
        case .builtIn: "Built-in Trackpad"
        case .external: "External Trackpad"
        }
    }
}

struct EnhancedTrackpadSummary: Identifiable, Hashable, Sendable {
    let id: String
    let isBuiltIn: Bool
    let isPresent: Bool

    var title: String { isBuiltIn ? "Built-in Trackpad" : "External Trackpad" }
}

struct HapticPattern: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let detail: String
    let systemImage: String
    var steps: [HapticStep]

    static let presets: [HapticPattern] = [
        HapticPattern(
            id: "single",
            name: "Single",
            detail: "One clean confirmation",
            systemImage: "circle",
            steps: [HapticStep(isEnabled: true)]
        ),
        HapticPattern(
            id: "double",
            name: "Double",
            detail: "A compact two-pulse cue",
            systemImage: "circle.grid.2x1",
            steps: [
                HapticStep(isEnabled: true, feedback: .mediumTap),
                HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .mediumTap)
            ]
        ),
        HapticPattern(
            id: "heartbeat",
            name: "Heartbeat",
            detail: "Short–long paired rhythm",
            systemImage: "heart",
            steps: [
                HapticStep(isEnabled: true, feedback: .strongTap),
                HapticStep(isEnabled: true, feedback: .lightTap),
                HapticStep(isEnabled: false, length: 2),
                HapticStep(isEnabled: true, feedback: .strongTap),
                HapticStep(isEnabled: true, feedback: .lightTap)
            ]
        ),
        HapticPattern(
            id: "ramp",
            name: "Ramp",
            detail: "Light, medium, then firm",
            systemImage: "chart.line.uptrend.xyaxis",
            steps: [
                HapticStep(isEnabled: true, feedback: .lightTap),
                HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .mediumTap),
                HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .strongTap)
            ]
        ),
        HapticPattern(
            id: "knock",
            name: "Knock",
            detail: "A weighty two-part cue",
            systemImage: "door.left.hand.closed",
            steps: [
                HapticStep(isEnabled: true, feedback: .strongThud),
                HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .softThud)
            ]
        ),
        HapticPattern(
            id: "flutter",
            name: "Flutter",
            detail: "A quick, delicate texture",
            systemImage: "wind",
            steps: [
                HapticStep(isEnabled: true, feedback: .lightTap),
                HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .lightTap),
                HapticStep(isEnabled: true, feedback: .weakClick),
                HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .lightTap),
                HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .weakClick)
            ]
        ),
        HapticPattern(
            id: "sos",
            name: "SOS",
            detail: "A tactile Morse-inspired phrase",
            systemImage: "ellipsis",
            steps: [
                HapticStep(isEnabled: true, feedback: .lightTap), HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .lightTap), HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .lightTap), HapticStep(isEnabled: false, length: 2),
                HapticStep(isEnabled: true, feedback: .strongTap, length: 2), HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .strongTap, length: 2), HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .strongTap, length: 2), HapticStep(isEnabled: false, length: 2),
                HapticStep(isEnabled: true, feedback: .lightTap), HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .lightTap), HapticStep(isEnabled: false),
                HapticStep(isEnabled: true, feedback: .lightTap)
            ]
        )
    ]

    static var customDefault: HapticPattern {
        HapticPattern(
            id: "custom",
            name: "Custom",
            detail: "Your sixteen-step sequence",
            systemImage: "square.grid.4x3.fill",
            steps: (0..<16).map { index in
                HapticStep(isEnabled: index == 0 || index == 4 || index == 7 || index == 12)
            }
        )
    }
}
