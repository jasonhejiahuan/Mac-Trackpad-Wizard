import Observation

@MainActor
@Observable
final class HapticEngine {
    var target: HapticDeviceTarget = .all {
        didSet { enhancedActuator?.target = target }
    }
    var isPlaying = false
    var currentStep: Int?
    var enhancedDevices: [EnhancedTrackpadSummary] = []
    private(set) var enhancedHapticsEnabled = false
    var lastMessage: String?

    @ObservationIgnored private var enhancedActuator: EnhancedHapticActuator?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?

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
        lastMessage = "Enhanced haptics are off."
    }

    func refreshDevices() {
        enhancedActuator?.refreshDevices()
        enhancedDevices = enhancedActuator?.summaries ?? []
    }

    func play(_ pattern: HapticPattern, beatsPerMinute: Double) {
        stopPlayback()
        stopBuzz()
        guard enhancedAvailable else {
            lastMessage = "Enable enhanced haptics before playing a pattern."
            return
        }
        isPlaying = true
        let stepDuration = 60 / min(max(beatsPerMinute, 40), 240) / 4

        playbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for (index, step) in pattern.steps.enumerated() {
                guard !Task.isCancelled else { break }
                currentStep = index
                if step.isEnabled {
                    perform(step.feedback, amplitude: step.amplitude)
                }
                let nanoseconds = UInt64(stepDuration * Double(max(step.length, 1)) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            guard !Task.isCancelled else { return }
            currentStep = nil
            isPlaying = false
        }
    }

    func playSingle(_ feedback: HapticFeedbackKind, amplitude: Double = 1) {
        stopPlayback()
        stopBuzz()
        guard enhancedAvailable else {
            lastMessage = "Enable enhanced haptics before testing a pulse."
            return
        }
        perform(feedback, amplitude: amplitude)
    }

    @discardableResult
    func startBuzz(_ feedback: HapticFeedbackKind, amplitude: Double, frequency: Double) -> Bool {
        stopPlayback()
        guard enhancedAvailable else {
            lastMessage = "Enable enhanced haptics before starting a custom signal."
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
    }

    func shutDown() {
        stopPlayback()
        stopBuzz()
        enhancedActuator?.shutDown()
        enhancedActuator = nil
        enhancedDevices = []
        enhancedHapticsEnabled = false
    }

    private func perform(_ feedback: HapticFeedbackKind, amplitude: Double) {
        guard amplitude > 0 else { return }
        if enhancedActuator?.tick(feedback, amplitude: amplitude) == true {
            return
        }
        lastMessage = target == .all
            ? "Enhanced playback failed; no haptic pulse was sent."
            : "The selected trackpad is unavailable; no haptic pulse was sent."
    }
}
