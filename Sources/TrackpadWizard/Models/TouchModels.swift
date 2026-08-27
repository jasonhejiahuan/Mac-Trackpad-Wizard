import Foundation

enum TouchDataSource: String, Codable, Sendable {
    case appKit
    case enhanced

    var title: String {
        switch self {
        case .appKit: "AppKit"
        case .enhanced: "Enhanced"
        }
    }
}

enum TouchContactPhase: String, Codable, Sendable {
    case began
    case moved
    case stationary
    case ended
    case cancelled

    var isActive: Bool {
        self != .ended && self != .cancelled
    }
}

struct TouchContact: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let x: Double
    let y: Double
    let phase: TouchContactPhase
    let isResting: Bool
    let deviceWidth: Double
    let deviceHeight: Double
    let source: TouchDataSource
    let pressureProxy: Double?
    let totalPressure: Double?
    let velocityX: Double?
    let velocityY: Double?
    let majorAxis: Double?
    let minorAxis: Double?
    let angle: Double?
    let density: Double?

    init(
        id: Int,
        x: Double,
        y: Double,
        phase: TouchContactPhase,
        isResting: Bool,
        deviceWidth: Double,
        deviceHeight: Double,
        source: TouchDataSource = .appKit,
        pressureProxy: Double? = nil,
        totalPressure: Double? = nil,
        velocityX: Double? = nil,
        velocityY: Double? = nil,
        majorAxis: Double? = nil,
        minorAxis: Double? = nil,
        angle: Double? = nil,
        density: Double? = nil
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.phase = phase
        self.isResting = isResting
        self.deviceWidth = deviceWidth
        self.deviceHeight = deviceHeight
        self.source = source
        self.pressureProxy = pressureProxy
        self.totalPressure = totalPressure
        self.velocityX = velocityX
        self.velocityY = velocityY
        self.majorAxis = majorAxis
        self.minorAxis = minorAxis
        self.angle = angle
        self.density = density
    }
}

struct TouchFrame: Codable, Hashable, Sendable {
    let timestamp: TimeInterval
    let contacts: [TouchContact]
    let source: TouchDataSource

    init(
        timestamp: TimeInterval,
        contacts: [TouchContact],
        source: TouchDataSource? = nil
    ) {
        self.timestamp = timestamp
        self.contacts = contacts
        self.source = source ?? contacts.first?.source ?? .appKit
    }
}

enum NativeGestureKind: String, Codable, CaseIterable, Sendable {
    case gestureBegan
    case gestureEnded
    case magnify
    case rotate
    case swipe
    case scroll
    case pressure

    var title: String {
        switch self {
        case .gestureBegan: "Gesture began"
        case .gestureEnded: "Gesture ended"
        case .magnify: "Magnify"
        case .rotate: "Rotate"
        case .swipe: "Swipe"
        case .scroll: "Precision scroll"
        case .pressure: "Pressure"
        }
    }

    var systemImage: String {
        switch self {
        case .gestureBegan: "play.circle"
        case .gestureEnded: "stop.circle"
        case .magnify: "arrow.up.left.and.arrow.down.right"
        case .rotate: "rotate.right"
        case .swipe: "arrow.left.and.right"
        case .scroll: "arrow.up.and.down"
        case .pressure: "circle.dotted.circle"
        }
    }
}

struct NativeGestureSample: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let kind: NativeGestureKind
    let timestamp: TimeInterval
    let primaryValue: Double
    let secondaryValue: Double
    let stage: Int
    let precise: Bool

    init(
        id: UUID = UUID(),
        kind: NativeGestureKind,
        timestamp: TimeInterval,
        primaryValue: Double = 0,
        secondaryValue: Double = 0,
        stage: Int = 0,
        precise: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.primaryValue = primaryValue
        self.secondaryValue = secondaryValue
        self.stage = stage
        self.precise = precise
    }
}

struct RecognizedGestureEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    let trigger: GestureTrigger
    let date: Date
    let source: TouchDataSource

    init(
        id: UUID = UUID(),
        trigger: GestureTrigger,
        date: Date = .now,
        source: TouchDataSource
    ) {
        self.id = id
        self.trigger = trigger
        self.date = date
        self.source = source
    }
}

struct TouchTrailPoint: Identifiable, Hashable, Sendable {
    let id = UUID()
    let contactID: Int
    let x: Double
    let y: Double
    let ageIndex: Int
}

struct TouchEventLogEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let timestamp: TimeInterval
    let contactCount: Int
    let phases: [TouchContactPhase]

    init(id: UUID = UUID(), timestamp: TimeInterval, contacts: [TouchContact]) {
        self.id = id
        self.timestamp = timestamp
        contactCount = contacts.filter(\.phase.isActive).count
        phases = contacts.map(\.phase)
    }
}

struct TouchSessionExport: Codable, Sendable {
    let schemaVersion: Int
    let exportedAt: Date
    let sessionStartedAt: Date?
    let frames: [TouchFrame]
    let gestures: [NativeGestureSample]
    let maximumContactCount: Int
    let estimatedSampleRate: Double
}
