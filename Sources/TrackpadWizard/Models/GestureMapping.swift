import Foundation

struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt8

    static let command = ShortcutModifiers(rawValue: 1 << 0)
    static let option = ShortcutModifiers(rawValue: 1 << 1)
    static let control = ShortcutModifiers(rawValue: 1 << 2)
    static let shift = ShortcutModifiers(rawValue: 1 << 3)
    static let function = ShortcutModifiers(rawValue: 1 << 4)
}

struct ShortcutDefinition: Codable, Hashable, Sendable {
    var keyCode: UInt16
    var modifiers: ShortcutModifiers
    var keyLabel: String

    var displayName: String {
        var value = ""
        if modifiers.contains(.control) { value += "⌃" }
        if modifiers.contains(.option) { value += "⌥" }
        if modifiers.contains(.shift) { value += "⇧" }
        if modifiers.contains(.command) { value += "⌘" }
        if modifiers.contains(.function) { value += "fn " }
        value += keyLabel.uppercased()
        return value
    }

    static let commandLeftBracket = ShortcutDefinition(
        keyCode: 33,
        modifiers: .command,
        keyLabel: "["
    )

    static let commandRightBracket = ShortcutDefinition(
        keyCode: 30,
        modifiers: .command,
        keyLabel: "]"
    )
}

enum GestureTrigger: String, CaseIterable, Codable, Identifiable, Sendable {
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case pinchIn
    case pinchOut
    case rotateClockwise
    case rotateCounterclockwise
    case forceClick

    var id: Self { self }

    var title: String {
        switch self {
        case .swipeLeft: "Swipe Left"
        case .swipeRight: "Swipe Right"
        case .swipeUp: "Swipe Up"
        case .swipeDown: "Swipe Down"
        case .pinchIn: "Pinch In"
        case .pinchOut: "Pinch Out"
        case .rotateClockwise: "Rotate Clockwise"
        case .rotateCounterclockwise: "Rotate Counterclockwise"
        case .forceClick: "Force Click"
        }
    }

    var systemImage: String {
        switch self {
        case .swipeLeft: "arrow.left"
        case .swipeRight: "arrow.right"
        case .swipeUp: "arrow.up"
        case .swipeDown: "arrow.down"
        case .pinchIn: "arrow.down.right.and.arrow.up.left"
        case .pinchOut: "arrow.up.left.and.arrow.down.right"
        case .rotateClockwise: "rotate.right"
        case .rotateCounterclockwise: "rotate.left"
        case .forceClick: "circle.dotted.circle"
        }
    }
}

enum MappingActionKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case keyboardShortcut
    case hapticPattern

    var id: Self { self }

    var title: String {
        switch self {
        case .keyboardShortcut: "Keyboard Shortcut"
        case .hapticPattern: "Haptic Pattern"
        }
    }
}

struct GestureMapping: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var isEnabled: Bool
    var trigger: GestureTrigger
    var actionKind: MappingActionKind
    var shortcut: ShortcutDefinition
    var hapticPatternID: String

    init(
        id: UUID = UUID(),
        isEnabled: Bool = false,
        trigger: GestureTrigger,
        actionKind: MappingActionKind = .keyboardShortcut,
        shortcut: ShortcutDefinition,
        hapticPatternID: String = "single"
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.actionKind = actionKind
        self.shortcut = shortcut
        self.hapticPatternID = hapticPatternID
    }

    static let defaults: [GestureMapping] = [
        GestureMapping(trigger: .swipeLeft, shortcut: .commandLeftBracket),
        GestureMapping(trigger: .swipeRight, shortcut: .commandRightBracket),
        GestureMapping(
            trigger: .forceClick,
            actionKind: .hapticPattern,
            shortcut: .commandLeftBracket,
            hapticPatternID: "double"
        )
    ]
}
