import AppKit
import ApplicationServices

@MainActor
enum ShortcutService {
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibility() -> Bool {
        // The imported C global is marked mutable and is rejected by Swift 6
        // strict concurrency. Its documented CFString value is stable.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @discardableResult
    static func post(_ shortcut: ShortcutDefinition) -> Bool {
        guard isAccessibilityGranted,
              let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(shortcut.keyCode),
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(shortcut.keyCode),
                keyDown: false
              ) else { return false }
        let flags = shortcut.modifiers.cgEventFlags
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

extension ShortcutModifiers {
    init(eventFlags: NSEvent.ModifierFlags) {
        var value: ShortcutModifiers = []
        if eventFlags.contains(.command) { value.insert(.command) }
        if eventFlags.contains(.option) { value.insert(.option) }
        if eventFlags.contains(.control) { value.insert(.control) }
        if eventFlags.contains(.shift) { value.insert(.shift) }
        if eventFlags.contains(.function) { value.insert(.function) }
        self = value
    }

    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }
}

enum KeyLabelFormatter {
    static func label(for event: NSEvent) -> String {
        let named: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc",
            76: "⌤", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑",
            115: "Home", 119: "End", 116: "Page Up", 121: "Page Down"
        ]
        if let value = named[event.keyCode] { return value }
        let functionKeys: [UInt16: String] = [
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18",
            80: "F19", 90: "F20"
        ]
        if let value = functionKeys[event.keyCode] { return value }
        let characters = event.charactersIgnoringModifiers ?? ""
        return characters.isEmpty ? "Key \(event.keyCode)" : characters.uppercased()
    }
}
