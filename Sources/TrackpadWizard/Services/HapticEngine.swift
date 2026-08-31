import Foundation
import Observation

@MainActor
@Observable
final class HapticEngine {
    var target: HapticDeviceTarget = .all {
        didSet { enhancedActuator?.target = target }
    }
    var isPlaying = false
    private(set) var isPlayingLibraryPattern = false
    var currentStep: Int?
    var enhancedDevices: [EnhancedTrackpadSummary] = []
    private(set) var enhancedHapticsEnabled = false
    var lastMessage: String?

    @ObservationIgnored private var enhancedActuator: EnhancedHapticActuator?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var actuationObserver: (@Sendable (HapticCounterDevice) -> Void)?
    @ObservationIgnored private var failureHandler: ((String) -> Void)?

    var enhancedAvailable: Bool { enhancedHapticsEnabled }

    @discardableResult
    func enableEnhancedHaptics() -> Bool {
        stopPlayback()
        stopBuzz()
        if enhancedActuator == nil {
            enhancedActuator = EnhancedHapticActuator()
        }
        guard let enhancedActuator else {
            enhancedDevices = []
            enhancedHapticsEnabled = false
            lastMessage = "The enhanced actuator is unavailable. No haptic pulse was sent."
            return false
        }
        enhancedActuator.target = target
        enhancedActuator.setActuationObserver(actuationObserver)
        enhancedActuator.refreshDevices()
        enhancedDevices = enhancedActuator.summaries
        enhancedHapticsEnabled = true
        lastMessage = "Enhanced waveforms are active for this session."
        return true
    }

    func disableEnhancedHaptics() {
        stopPlayback()
        stopBuzz()
        enhancedActuator?.shutDown()
        enhancedActuator = nil
        enhancedDevices = []
        enhancedHapticsEnabled = false
        lastMessage = "Enhanced Mode actuator output is off."
    }

    func refreshDevices() {
        enhancedActuator?.refreshDevices()
        enhancedDevices = enhancedActuator?.summaries ?? []
    }

    @discardableResult
    func play(_ pattern: HapticPattern, beatsPerMinute: Double) -> Bool {
        stopPlayback()
        stopBuzz()
        guard enhancedAvailable else {
            lastMessage = "Enable Enhanced Mode before playing a pattern."
            return false
        }
        isPlaying = true
        isPlayingLibraryPattern = false
        let stepDuration = 60 / min(max(beatsPerMinute, 40), 240) / 4

        playbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for (index, step) in pattern.steps.enumerated() {
                guard !Task.isCancelled else { break }
                currentStep = index
                if step.isEnabled {
                    _ = perform(step.feedback, amplitude: step.amplitude)
                }
                let nanoseconds = UInt64(stepDuration * Double(max(step.length, 1)) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            guard !Task.isCancelled else { return }
            currentStep = nil
            isPlaying = false
            isPlayingLibraryPattern = false
        }
        return true
    }

    @discardableResult
    func play(_ document: HapticPatternDocument) -> Bool {
        stopPlayback()
        stopBuzz()
        guard enhancedAvailable else {
            lastMessage = "Enable Enhanced Mode before playing a pattern."
            return false
        }

        let validatedDocument: HapticPatternDocument
        do {
            validatedDocument = try document.validated()
        } catch {
            lastMessage = error.localizedDescription
            return false
        }

        let pulses = validatedDocument.events.enumerated().flatMap { eventIndex, event in
            (0..<event.oscillationCount).map { cycle in
                ScheduledPulse(
                    time: event.timeSeconds + (Double(cycle) / event.frequencyHz),
                    eventIndex: eventIndex,
                    feedback: event.feedback,
                    amplitude: event.amplitude
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.time == rhs.time { return lhs.eventIndex < rhs.eventIndex }
            return lhs.time < rhs.time
        }

        guard !pulses.isEmpty else {
            lastMessage = "The selected pattern contains no oscillations."
            return false
        }

        isPlaying = true
        isPlayingLibraryPattern = true
        playbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var previousTime: TimeInterval = 0
            for pulse in pulses {
                guard !Task.isCancelled else { break }
                let delay = max(0, pulse.time - previousTime)
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                guard !Task.isCancelled else { break }
                currentStep = pulse.eventIndex
                _ = perform(pulse.feedback, amplitude: pulse.amplitude)
                previousTime = pulse.time
            }
            guard !Task.isCancelled else { return }
            currentStep = nil
            isPlaying = false
            isPlayingLibraryPattern = false
        }
        return true
    }

    @discardableResult
    func playSingle(_ feedback: HapticFeedbackKind, amplitude: Double = 1) -> Bool {
        stopPlayback()
        stopBuzz()
        guard enhancedAvailable else {
            lastMessage = "Enable Enhanced Mode before testing a pulse."
            return false
        }
        return perform(feedback, amplitude: amplitude)
    }

    @discardableResult
    func startBuzz(_ feedback: HapticFeedbackKind, amplitude: Double, frequency: Double) -> Bool {
        stopPlayback()
        guard enhancedAvailable else {
            lastMessage = "Enable Enhanced Mode before starting a custom signal."
            return false
        }
        guard enhancedActuator?.startBuzz(
            feedback,
            amplitude: amplitude,
            frequency: frequency
        ) == true else {
            lastMessage = "No matching haptic trackpad is currently available."
            return false
        }
        return true
    }

    func stopBuzz() {
        enhancedActuator?.stopBuzz()
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        currentStep = nil
        isPlaying = false
        isPlayingLibraryPattern = false
    }

    func setActuationObserver(
        _ observer: (@Sendable (HapticCounterDevice) -> Void)?
    ) {
        actuationObserver = observer
        enhancedActuator?.setActuationObserver(observer)
    }

    func setFailureHandler(_ handler: ((String) -> Void)?) {
        failureHandler = handler
    }

    func shutDown() {
        stopPlayback()
        stopBuzz()
        enhancedActuator?.shutDown()
        enhancedActuator = nil
        enhancedDevices = []
        enhancedHapticsEnabled = false
    }

    private func perform(_ feedback: HapticFeedbackKind, amplitude: Double) -> Bool {
        guard amplitude > 0 else { return true }
        if enhancedActuator?.tick(feedback, amplitude: amplitude) == true {
            return true
        }
        lastMessage = target == .all
            ? "Enhanced playback failed; no haptic pulse was sent."
            : "The selected trackpad is unavailable; no haptic pulse was sent."
        failureHandler?(lastMessage ?? "Haptic playback failed.")
        return false
    }

    private struct ScheduledPulse: Sendable {
        let time: TimeInterval
        let eventIndex: Int
        let feedback: HapticFeedbackKind
        let amplitude: Double
    }
}
