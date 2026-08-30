import Foundation

/// Portable, versioned interchange format for Trackpad Wizard haptic patterns.
///
/// `frequencyHz` is the pulse-repetition rate, not the actuator's private
/// carrier frequency. One event contains one or more complete oscillations;
/// `durationSeconds * frequencyHz` determines the oscillation count.
struct HapticPatternDocument: Identifiable, Codable, Hashable, Sendable {
    static let formatIdentifier = "cc.jasonstu.trackpadwizard.haptic-pattern"
    static let currentSchemaVersion = 1
    static let maximumEventCount = 500
    static let maximumPulseCount = 20_000
    static let maximumDuration: TimeInterval = 300

    var format: String
    var schemaVersion: Int
    var id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var events: [HapticPatternEvent]

    init(
        format: String = Self.formatIdentifier,
        schemaVersion: Int = Self.currentSchemaVersion,
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        events: [HapticPatternEvent]
    ) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.events = events
    }

    var pulseCount: Int {
        events.reduce(0) { $0 + $1.oscillationCount }
    }

    var duration: TimeInterval {
        events.map(\.endTime).max() ?? 0
    }

    func validated() throws -> HapticPatternDocument {
        guard format == Self.formatIdentifier else {
            throw HapticPatternValidationError.unsupportedFormat(format)
        }
        guard schemaVersion == Self.currentSchemaVersion else {
            throw HapticPatternValidationError.unsupportedSchema(schemaVersion)
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 80 else {
            throw HapticPatternValidationError.invalidName
        }
        guard !events.isEmpty, events.count <= Self.maximumEventCount else {
            throw HapticPatternValidationError.invalidEventCount(events.count)
        }

        for (index, event) in events.enumerated() {
            try event.validate(index: index)
        }

        let sortedEvents = events.sorted {
            if $0.timeSeconds == $1.timeSeconds { return $0.id.uuidString < $1.id.uuidString }
            return $0.timeSeconds < $1.timeSeconds
        }
        guard (sortedEvents.map(\.endTime).max() ?? 0) <= Self.maximumDuration else {
            throw HapticPatternValidationError.patternTooLong
        }
        guard sortedEvents.reduce(0, { $0 + $1.oscillationCount }) <= Self.maximumPulseCount else {
            throw HapticPatternValidationError.tooManyPulses
        }

        var result = self
        result.name = trimmedName
        result.events = sortedEvents
        return result
    }

    static func from(
        _ pattern: HapticPattern,
        beatsPerMinute: Double,
        name: String? = nil
    ) -> HapticPatternDocument {
        let stepDuration = 60 / min(max(beatsPerMinute, 40), 240) / 4
        var cursor: TimeInterval = 0
        var events: [HapticPatternEvent] = []

        for step in pattern.steps {
            if step.isEnabled {
                let frequency = 80.0
                events.append(
                    HapticPatternEvent(
                        timeSeconds: cursor,
                        amplitude: step.amplitude,
                        frequencyHz: frequency,
                        durationSeconds: 1 / frequency,
                        feedback: step.feedback
                    )
                )
            }
            cursor += stepDuration * Double(max(step.length, 1))
        }

        return HapticPatternDocument(name: name ?? pattern.name, events: events)
    }
}

struct HapticPatternEvent: Identifiable, Codable, Hashable, Sendable {
    static let frequencyRange = 8.0...120.0

    var id: UUID
    var timeSeconds: TimeInterval
    var amplitude: Double
    var frequencyHz: Double
    var durationSeconds: TimeInterval
    var feedback: HapticFeedbackKind

    init(
        id: UUID = UUID(),
        timeSeconds: TimeInterval,
        amplitude: Double,
        frequencyHz: Double,
        durationSeconds: TimeInterval,
        feedback: HapticFeedbackKind = .mediumTap
    ) {
        self.id = id
        self.timeSeconds = timeSeconds
        self.amplitude = amplitude
        self.frequencyHz = frequencyHz
        self.durationSeconds = durationSeconds
        self.feedback = feedback
    }

    var oscillationCount: Int {
        max(1, Int((durationSeconds * frequencyHz).rounded()))
    }

    var endTime: TimeInterval {
        timeSeconds + (Double(oscillationCount - 1) / frequencyHz) + (1 / frequencyHz)
    }

    fileprivate func validate(index: Int) throws {
        guard timeSeconds.isFinite,
              timeSeconds >= 0,
              timeSeconds <= HapticPatternDocument.maximumDuration else {
            throw HapticPatternValidationError.invalidTime(index)
        }
        guard amplitude.isFinite, HapticStep.amplitudeRange.contains(amplitude) else {
            throw HapticPatternValidationError.invalidAmplitude(index)
        }
        guard frequencyHz.isFinite, Self.frequencyRange.contains(frequencyHz) else {
            throw HapticPatternValidationError.invalidFrequency(index)
        }
        guard durationSeconds.isFinite,
              durationSeconds >= (1 / frequencyHz),
              durationSeconds <= HapticPatternDocument.maximumDuration else {
            throw HapticPatternValidationError.invalidDuration(index)
        }
    }
}

enum HapticPatternValidationError: LocalizedError, Equatable {
    case unsupportedFormat(String)
    case unsupportedSchema(Int)
    case invalidName
    case invalidEventCount(Int)
    case invalidTime(Int)
    case invalidAmplitude(Int)
    case invalidFrequency(Int)
    case invalidDuration(Int)
    case patternTooLong
    case tooManyPulses

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            "This file is not a Trackpad Wizard haptic pattern."
        case .unsupportedSchema(let version):
            "Haptic pattern schema version \(version) is not supported."
        case .invalidName:
            "The pattern name must contain 1–80 characters."
        case .invalidEventCount(let count):
            "The pattern contains an unsupported number of events (\(count))."
        case .invalidTime(let index):
            "Event \(index + 1) has an invalid start time."
        case .invalidAmplitude(let index):
            "Event \(index + 1) has an amplitude outside 0–1."
        case .invalidFrequency(let index):
            "Event \(index + 1) has a frequency outside 8–120 Hz."
        case .invalidDuration(let index):
            "Event \(index + 1) has an invalid duration."
        case .patternTooLong:
            "The pattern is longer than five minutes."
        case .tooManyPulses:
            "The pattern expands to more than 20,000 oscillations."
        }
    }
}
