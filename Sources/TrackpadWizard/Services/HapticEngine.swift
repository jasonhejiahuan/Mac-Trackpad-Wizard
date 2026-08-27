import AppKit
import Observation

@MainActor
@Observable
final class HapticEngine {
    var outputMode: HapticOutputMode = .system
    var target: HapticDeviceTarget = .all {
        didSet { enhancedActuator?.target = target }
    }
    var isPlaying = false
    var currentStep: Int?
    var enhancedDevices: [EnhancedTrackpadSummary] = []
    var lastMessage: String?

    @ObservationIgnored private let systemPerformer = NSHapticFeedbackManager.defaultPerformer
    @ObservationIgnored private var enhancedActuator: EnhancedHapticActuator?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?

    var enhancedAvailable: Bool { enhancedActuator != nil }

    @discardableResult
    func enableEnhancedMode() -> Bool {
        stopPlayback()
        stopBuzz()
        if enhancedActuator == nil {
            enhancedActuator = EnhancedHapticActuator()
        }
        guard let enhancedActuator else {
            outputMode = .system
            enhancedDevices = []
            lastMessage = "The enhanced actuator is unavailable. System haptics remain active."
            return false
        }
        enhancedActuator.target = target
        enhancedActuator.refreshDevices()
        enhancedDevices = enhancedActuator.summaries
        outputMode = .enhanced
        lastMessage = "Enhanced waveforms are active for this session."
        return true
    }

    func useSystemMode() {
        stopPlayback()
        stopBuzz()
        enhancedActuator?.shutDown()
        enhancedActuator = nil
        enhancedDevices = []
        outputMode = .system
        lastMessage = "Using Apple’s public, system-routed haptic engine."
    }

    func refreshDevices() {
        enhancedActuator?.refreshDevices()
        enhancedDevices = enhancedActuator?.summaries ?? []
    }

    func play(_ pattern: HapticPattern, beatsPerMinute: Double) {
        stopPlayback()
        stopBuzz()
        isPlaying = true
        let stepDuration = 60 / min(max(beatsPerMinute, 40), 240) / 4

        playbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for (index, step) in pattern.steps.enumerated() {
                guard !Task.isCancelled else { break }
                currentStep = index
                if step.isEnabled {
                    perform(step.feedback)
                }
                let nanoseconds = UInt64(stepDuration * Double(max(step.length, 1)) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            guard !Task.isCancelled else { return }
            currentStep = nil
            isPlaying = false
        }
    }

    func playSingle(_ feedback: HapticFeedbackKind) {
        stopPlayback()
        stopBuzz()
        perform(feedback)
    }

    @discardableResult
    func startBuzz(_ feedback: HapticFeedbackKind, frequency: Double) -> Bool {
        stopPlayback()
        guard outputMode == .enhanced else {
            lastMessage = "Continuous vibration needs the opt-in enhanced engine."
            return false
        }
        guard enhancedActuator?.startBuzz(feedback, frequency: frequency) == true else {
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
        outputMode = .system
    }

    private func perform(_ feedback: HapticFeedbackKind) {
        if outputMode == .enhanced, enhancedActuator?.tick(feedback) == true {
            return
        }
        if outputMode == .enhanced {
            if target != .all {
                lastMessage = "The selected trackpad is unavailable; no pulse was sent to another device."
                return
            }
            lastMessage = "Enhanced playback failed, so this pulse used the system fallback."
        }
        systemPerformer.perform(feedback.systemPattern, performanceTime: .now)
    }
}

private extension HapticFeedbackKind {
    var systemPattern: NSHapticFeedbackManager.FeedbackPattern {
        switch self {
        case .weakClick, .lightTap, .softThud:
            .alignment
        case .buzz, .mediumTap:
            .generic
        case .strongClick, .strongTap, .strongThud:
            .levelChange
        }
    }
}
