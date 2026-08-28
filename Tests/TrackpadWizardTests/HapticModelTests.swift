import Foundation
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
        #expect(pattern.steps.allSatisfy { HapticStep.amplitudeRange.contains($0.amplitude) })
        #expect(pattern.steps.filter(\.isEnabled).count == 4)
    }

    @Test("Every preset has a stable unique identifier and at least one pulse")
    func presetIntegrity() {
        let identifiers = HapticPattern.presets.map(\.id)
        #expect(Set(identifiers).count == identifiers.count)
        #expect(HapticPattern.presets.allSatisfy { $0.steps.contains(where: \.isEnabled) })
        #expect(
            HapticPattern.presets
                .flatMap(\.steps)
                .allSatisfy { HapticStep.amplitudeRange.contains($0.amplitude) }
        )
    }

    @Test("The ramp preset uses a real amplitude envelope")
    func rampAmplitudeEnvelope() throws {
        let ramp = try #require(HapticPattern.presets.first { $0.id == "ramp" })
        let pulses = ramp.steps.filter(\.isEnabled)
        #expect(Set(pulses.map(\.feedback)).count == 1)
        #expect(pulses.map(\.amplitude) == pulses.map(\.amplitude).sorted())
        #expect(Set(pulses.map(\.amplitude)).count == pulses.count)
    }

    @Test("Saved patterns from before amplitude control remain readable")
    func legacyStepDecoding() throws {
        let data = try #require(
            """
            {
              "id": "F5BEA4A4-E2AF-4619-8D83-32258E641378",
              "isEnabled": true,
              "feedback": 5,
              "length": 2
            }
            """.data(using: .utf8)
        )
        let step = try JSONDecoder().decode(HapticStep.self, from: data)
        #expect(step.amplitude == 1)
        #expect(step.feedback == .mediumTap)
        #expect(step.length == 2)
    }

    @Test("Amplitude stays inside the normalized hardware range")
    func amplitudeClamping() {
        #expect(HapticStep(isEnabled: true, amplitude: -0.5).amplitude == 0)
        #expect(HapticStep(isEnabled: true, amplitude: 1.5).amplitude == 1)
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
