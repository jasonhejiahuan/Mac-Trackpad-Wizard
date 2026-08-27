import Testing
@testable import TrackpadWizard

struct HapticModelTests {
    @Test("Empirical actuator waveform IDs remain explicit")
    func waveformIdentifiers() {
        #expect(HapticFeedbackKind.weakClick.waveformID == 1)
        #expect(HapticFeedbackKind.strongClick.waveformID == 2)
        #expect(HapticFeedbackKind.buzz.waveformID == 3)
        #expect(HapticFeedbackKind.strongThud.waveformID == 16)
    }

    @Test("The custom composer always starts with sixteen steps")
    func customPatternShape() {
        let pattern = HapticPattern.customDefault
        #expect(pattern.steps.count == 16)
        #expect(pattern.steps.allSatisfy { (1...4).contains($0.length) })
        #expect(pattern.steps.filter(\.isEnabled).count == 4)
    }

    @Test("Every preset has a stable unique identifier and at least one pulse")
    func presetIntegrity() {
        let identifiers = HapticPattern.presets.map(\.id)
        #expect(Set(identifiers).count == identifiers.count)
        #expect(HapticPattern.presets.allSatisfy { $0.steps.contains(where: \.isEnabled) })
    }

    @Test("Shortcut symbols use macOS modifier order")
    func shortcutFormatting() {
        let shortcut = ShortcutDefinition(
            keyCode: 1,
            modifiers: [.command, .option, .shift, .control],
            keyLabel: "s"
        )
        #expect(shortcut.displayName == "⌃⌥⇧⌘S")
    }
}
