import Foundation
import Testing
@testable import TrackpadWizard

struct HapticPatternDocumentTests {
    @Test("Schema v1 round-trips time, amplitude, frequency, and waveform")
    func schemaRoundTrip() throws {
        let document = HapticPatternDocument(
            name: "Measured Rhythm",
            events: [
                HapticPatternEvent(
                    timeSeconds: 0,
                    amplitude: 0.42,
                    frequencyHz: 20,
                    durationSeconds: 0.05,
                    feedback: .lightTap
                ),
                HapticPatternEvent(
                    timeSeconds: 0.4,
                    amplitude: 0.8,
                    frequencyHz: 20,
                    durationSeconds: 0.1,
                    feedback: .strongTap
                )
            ]
        )

        let validated = try document.validated()
        #expect(validated.schemaVersion == 1)
        #expect(validated.pulseCount == 3)
        #expect(validated.events[1].frequencyHz == 20)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(validated)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HapticPatternDocument.self, from: data).validated()
        #expect(decoded.format == validated.format)
        #expect(decoded.schemaVersion == validated.schemaVersion)
        #expect(decoded.id == validated.id)
        #expect(decoded.name == validated.name)
        #expect(decoded.events == validated.events)
        #expect(abs(decoded.createdAt.timeIntervalSince(validated.createdAt)) < 1)
        #expect(abs(decoded.modifiedAt.timeIntervalSince(validated.modifiedAt)) < 1)
    }

    @Test("Imported pattern values outside safe playback bounds are rejected")
    func validationRejectsUnsafeValues() {
        let document = HapticPatternDocument(
            name: "Unsafe",
            events: [
                HapticPatternEvent(
                    timeSeconds: 0,
                    amplitude: 1.2,
                    frequencyHz: 200,
                    durationSeconds: 1,
                    feedback: .buzz
                )
            ]
        )

        #expect(throws: HapticPatternValidationError.invalidAmplitude(0)) {
            try document.validated()
        }
    }

    @Test("The step composer converts into a portable one-oscillation event sequence")
    func composerConversion() throws {
        let source = HapticPattern.presets[0]
        let document = try HapticPatternDocument.from(
            source,
            beatsPerMinute: 120
        ).validated()
        #expect(document.name == source.name)
        #expect(document.pulseCount == source.steps.filter(\.isEnabled).count)
        #expect(document.events.allSatisfy { HapticStep.amplitudeRange.contains($0.amplitude) })
        #expect(document.events.allSatisfy { HapticPatternEvent.frequencyRange.contains($0.frequencyHz) })
    }
}
