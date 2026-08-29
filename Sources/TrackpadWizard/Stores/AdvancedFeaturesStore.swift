import Foundation
import Observation

@MainActor
@Observable
final class AdvancedFeaturesStore {
    private(set) var surfaceOrientationFeatureEnabled: Bool
    private(set) var systemHapticsFeatureEnabled: Bool
    private(set) var selectedSurfaceOrientation: ExperimentalSurfaceOrientation = .degrees0
    private(set) var systemHapticFeedbackEnabled = true
    private(set) var pendingConfirmation: AdvancedFeatureConfirmation?
    private(set) var lastMessage: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let controller: any AdvancedTrackpadControlling
    @ObservationIgnored private let recoveryInterval: TimeInterval
    @ObservationIgnored private var recoveryTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRollback: PendingRollback?
    @ObservationIgnored private var surfaceHasActiveOverride = false
    @ObservationIgnored private var systemHapticsHasActiveOverride = false

    private enum DefaultsKey {
        static let surfaceOrientationFeature = "experimentalSurfaceOrientationFeatureEnabled"
        static let systemHapticsFeature = "experimentalSystemHapticsFeatureEnabled"
        static let surfaceRecoveryTarget = "experimentalSurfaceOrientationRecoveryTarget"
        static let systemHapticsRecoveryTarget = "experimentalSystemHapticsRecoveryTarget"
    }

    private enum PendingRollback {
        case surface(
            snapshot: SurfaceOrientationSnapshot,
            previous: ExperimentalSurfaceOrientation,
            previousHadOverride: Bool
        )
        case systemHaptics(
            snapshot: SystemHapticsSnapshot,
            previous: Bool,
            previousHadOverride: Bool
        )

        var feature: ExperimentalFeatureKind {
            switch self {
            case .surface: .surfaceOrientation
            case .systemHaptics: .systemHaptics
            }
        }
    }

    init(
        defaults: UserDefaults = .standard,
        controller: any AdvancedTrackpadControlling = AdvancedTrackpadController(),
        recoveryInterval: TimeInterval = 10
    ) {
        self.defaults = defaults
        self.controller = controller
        self.recoveryInterval = recoveryInterval
        surfaceOrientationFeatureEnabled = defaults.bool(forKey: DefaultsKey.surfaceOrientationFeature)
            && controller.supportsSurfaceOrientation
        systemHapticsFeatureEnabled = defaults.bool(forKey: DefaultsKey.systemHapticsFeature)
            && controller.supportsSystemHaptics
        recoverUncleanSessionIfNeeded()
    }

    var supportsSurfaceOrientation: Bool { controller.supportsSurfaceOrientation }
    var supportsSystemHaptics: Bool { controller.supportsSystemHaptics }

    var enabledFeatureCount: Int {
        (surfaceOrientationFeatureEnabled ? 1 : 0) + (systemHapticsFeatureEnabled ? 1 : 0)
    }

    var previewRotationDegrees: Int {
        selectedSurfaceOrientation.previewRotationDegrees
    }

    @discardableResult
    func setSurfaceOrientationFeatureEnabled(
        _ enabled: Bool,
        target: HapticDeviceTarget
    ) -> Bool {
        guard !enabled || supportsSurfaceOrientation else {
            lastMessage = "Surface Orientation is unavailable on this macOS version."
            return false
        }
        if !enabled {
            restorePendingChange(ifMatching: .surfaceOrientation, reason: "Pending orientation change restored.")
            let restored = restoreDefaultSurfaceOrientation(fallbackTarget: target)
            surfaceHasActiveOverride = !restored
            selectedSurfaceOrientation = .degrees0
            updateRecoveryMarker(
                for: .surfaceOrientation,
                target: target,
                recoveryIsNeeded: !restored
            )
            lastMessage = restored
                ? "Surface Orientation is off and the selected target is at the macOS default."
                : "Some trackpads did not restore their default orientation."
        }
        surfaceOrientationFeatureEnabled = enabled
        defaults.set(enabled, forKey: DefaultsKey.surfaceOrientationFeature)
        if enabled { lastMessage = "Surface Orientation controls are available in Advanced Features." }
        return true
    }

    @discardableResult
    func setSystemHapticsFeatureEnabled(
        _ enabled: Bool,
        target: HapticDeviceTarget
    ) -> Bool {
        guard !enabled || supportsSystemHaptics else {
            lastMessage = "System Haptic Feedback control is unavailable on this macOS version."
            return false
        }
        if !enabled {
            restorePendingChange(ifMatching: .systemHaptics, reason: "Pending haptic change restored.")
            let restored = restoreDefaultSystemHaptics(fallbackTarget: target)
            systemHapticsHasActiveOverride = !restored
            systemHapticFeedbackEnabled = true
            updateRecoveryMarker(
                for: .systemHaptics,
                target: target,
                recoveryIsNeeded: !restored
            )
            lastMessage = restored
                ? "System Haptic Feedback is off and the selected target is at the macOS default."
                : "Some trackpads did not restore system haptic feedback."
        }
        systemHapticsFeatureEnabled = enabled
        defaults.set(enabled, forKey: DefaultsKey.systemHapticsFeature)
        if enabled { lastMessage = "System Haptic Feedback control is available in Advanced Features." }
        return true
    }

    @discardableResult
    func requestSurfaceOrientation(
        _ orientation: ExperimentalSurfaceOrientation,
        target: HapticDeviceTarget
    ) -> Bool {
        guard surfaceOrientationFeatureEnabled else {
            lastMessage = "Enable Surface Orientation in Experimental Settings first."
            return false
        }
        guard pendingConfirmation == nil else {
            lastMessage = "Resolve the current recovery countdown first."
            return false
        }
        guard orientation != selectedSurfaceOrientation else { return true }

        do {
            let snapshot = try controller.applySurfaceOrientation(
                orientation,
                target: target
            ) { composition in
                self.updateRecoveryMarker(
                    for: .surfaceOrientation,
                    target: target,
                    requiredComposition: composition,
                    recoveryIsNeeded: true
                )
            }
            let previous = selectedSurfaceOrientation
            let previousHadOverride = surfaceHasActiveOverride
            selectedSurfaceOrientation = orientation
            surfaceHasActiveOverride = true
            pendingRollback = .surface(
                snapshot: snapshot,
                previous: previous,
                previousHadOverride: previousHadOverride
            )
            beginRecoveryCountdown(
                feature: .surfaceOrientation,
                title: "Keep \(orientation.title) Orientation?",
                message: orientation.usesNativeOrientation
                    ? "The private surface-orientation report changed for \(target.title)."
                    : "The private runtime rejects quarter-turn surface reports, so Trackpad Wizard is rotating its own touch and gesture coordinates while the hardware remains at 0°."
            )
            return true
        } catch {
            surfaceHasActiveOverride = recoveryMarker(for: .surfaceOrientation) != nil
            lastMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func requestSystemHapticFeedback(
        enabled: Bool,
        target: HapticDeviceTarget
    ) -> Bool {
        guard systemHapticsFeatureEnabled else {
            lastMessage = "Enable System Haptic Feedback control in Experimental Settings first."
            return false
        }
        guard pendingConfirmation == nil else {
            lastMessage = "Resolve the current recovery countdown first."
            return false
        }
        guard enabled != systemHapticFeedbackEnabled else { return true }

        do {
            let snapshot = try controller.applySystemHaptics(
                enabled: enabled,
                target: target
            ) { composition in
                self.updateRecoveryMarker(
                    for: .systemHaptics,
                    target: target,
                    requiredComposition: composition,
                    recoveryIsNeeded: true
                )
            }
            let previous = systemHapticFeedbackEnabled
            let previousHadOverride = systemHapticsHasActiveOverride
            systemHapticFeedbackEnabled = enabled
            systemHapticsHasActiveOverride = true
            pendingRollback = .systemHaptics(
                snapshot: snapshot,
                previous: previous,
                previousHadOverride: previousHadOverride
            )
            beginRecoveryCountdown(
                feature: .systemHaptics,
                title: enabled ? "Keep System Haptics On?" : "Keep System Haptics Off?",
                message: "System click actuations changed for \(target.title). Trackpad Wizard's direct pattern output remains separate."
            )
            return true
        } catch {
            systemHapticsHasActiveOverride = recoveryMarker(for: .systemHaptics) != nil
            lastMessage = error.localizedDescription
            return false
        }
    }

    func confirmPendingChange() {
        guard let pendingConfirmation else { return }
        recoveryTask?.cancel()
        recoveryTask = nil
        pendingRollback = nil
        self.pendingConfirmation = nil
        lastMessage = "\(pendingConfirmation.feature.title) change kept for this app session."
    }

    func restorePendingChange() {
        restorePendingChange(reason: "The experimental change was restored.")
    }

    func restoreSurfaceOrientationDefault(target: HapticDeviceTarget) {
        restorePendingChange(ifMatching: .surfaceOrientation, reason: "Pending orientation change restored.")
        guard surfaceHasActiveOverride else {
            selectedSurfaceOrientation = .degrees0
            return
        }
        let restored = restoreDefaultSurfaceOrientation(fallbackTarget: target)
        surfaceHasActiveOverride = !restored
        selectedSurfaceOrientation = .degrees0
        updateRecoveryMarker(
            for: .surfaceOrientation,
            target: target,
            recoveryIsNeeded: !restored
        )
        lastMessage = restored
            ? "Surface orientation restored to the macOS default."
            : "Some trackpads did not restore their default orientation."
    }

    func restoreSystemHapticsDefault(target: HapticDeviceTarget) {
        restorePendingChange(ifMatching: .systemHaptics, reason: "Pending haptic change restored.")
        guard systemHapticsHasActiveOverride else {
            systemHapticFeedbackEnabled = true
            return
        }
        let restored = restoreDefaultSystemHaptics(fallbackTarget: target)
        systemHapticsHasActiveOverride = !restored
        systemHapticFeedbackEnabled = true
        updateRecoveryMarker(
            for: .systemHaptics,
            target: target,
            recoveryIsNeeded: !restored
        )
        lastMessage = restored
            ? "System haptic feedback restored to the macOS default."
            : "Some trackpads did not restore system haptic feedback."
    }

    func restoreDefaultsForTargetChange() {
        restorePendingChange(reason: "The pending experimental change was restored before changing target.")
        if surfaceHasActiveOverride {
            surfaceHasActiveOverride = !restoreDefaultSurfaceOrientation(fallbackTarget: nil)
            if !surfaceHasActiveOverride {
                defaults.removeObject(forKey: DefaultsKey.surfaceRecoveryTarget)
            }
        }
        if systemHapticsHasActiveOverride {
            systemHapticsHasActiveOverride = !restoreDefaultSystemHaptics(fallbackTarget: nil)
            if !systemHapticsHasActiveOverride {
                defaults.removeObject(forKey: DefaultsKey.systemHapticsRecoveryTarget)
            }
        }
        selectedSurfaceOrientation = .degrees0
        systemHapticFeedbackEnabled = true
    }

    func shutDown() {
        recoveryTask?.cancel()
        recoveryTask = nil
        restorePendingChange(reason: "Pending experimental change restored during shutdown.")
        if surfaceHasActiveOverride {
            if restoreDefaultSurfaceOrientation(fallbackTarget: nil) {
                defaults.removeObject(forKey: DefaultsKey.surfaceRecoveryTarget)
            }
        }
        if systemHapticsHasActiveOverride {
            if restoreDefaultSystemHaptics(fallbackTarget: nil) {
                defaults.removeObject(forKey: DefaultsKey.systemHapticsRecoveryTarget)
            }
        }
        surfaceHasActiveOverride = false
        systemHapticsHasActiveOverride = false
        selectedSurfaceOrientation = .degrees0
        systemHapticFeedbackEnabled = true
        controller.shutDown()
    }

    private func beginRecoveryCountdown(
        feature: ExperimentalFeatureKind,
        title: String,
        message: String
    ) {
        let confirmation = AdvancedFeatureConfirmation(
            feature: feature,
            title: title,
            message: message,
            deadline: .now.addingTimeInterval(recoveryInterval)
        )
        pendingConfirmation = confirmation
        recoveryTask?.cancel()
        recoveryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: UInt64(max(self?.recoveryInterval ?? 0, 0) * 1_000_000_000)
                )
            } catch {
                return
            }
            guard let self, self.pendingConfirmation?.id == confirmation.id else { return }
            self.restorePendingChange(reason: "No confirmation was received within 10 seconds, so the experimental change was restored automatically.")
        }
    }

    private func restorePendingChange(
        ifMatching feature: ExperimentalFeatureKind,
        reason: String
    ) {
        guard pendingRollback?.feature == feature else { return }
        restorePendingChange(reason: reason)
    }

    private func restorePendingChange(reason: String) {
        guard let pendingRollback else { return }
        recoveryTask?.cancel()
        recoveryTask = nil
        self.pendingRollback = nil
        pendingConfirmation = nil

        let restored: Bool
        switch pendingRollback {
        case .surface(let snapshot, let previous, let previousHadOverride):
            restored = controller.restoreSurfaceOrientation(snapshot)
            selectedSurfaceOrientation = previous
            surfaceHasActiveOverride = previousHadOverride || !restored
            if !surfaceHasActiveOverride {
                defaults.removeObject(forKey: DefaultsKey.surfaceRecoveryTarget)
            }
        case .systemHaptics(let snapshot, let previous, let previousHadOverride):
            restored = controller.restoreSystemHaptics(snapshot)
            systemHapticFeedbackEnabled = previous
            systemHapticsHasActiveOverride = previousHadOverride || !restored
            if !systemHapticsHasActiveOverride {
                defaults.removeObject(forKey: DefaultsKey.systemHapticsRecoveryTarget)
            }
        }
        lastMessage = restored ? reason : "Automatic recovery could not restore every selected trackpad."
    }

    private func recoverUncleanSessionIfNeeded() {
        var recoveredFeatures: [String] = []
        var pendingFeatures: [String] = []

        if let marker = recoveryMarker(for: .surfaceOrientation) {
            let restored = controller.restoreDefaultSurfaceOrientation(
                target: marker.target,
                requiredComposition: marker.requiredComposition
            )
            surfaceHasActiveOverride = !restored
            if restored {
                defaults.removeObject(forKey: DefaultsKey.surfaceRecoveryTarget)
                recoveredFeatures.append(ExperimentalFeatureKind.surfaceOrientation.title)
            } else {
                pendingFeatures.append(ExperimentalFeatureKind.surfaceOrientation.title)
            }
        }

        if let marker = recoveryMarker(for: .systemHaptics) {
            let restored = controller.restoreDefaultSystemHaptics(
                target: marker.target,
                requiredComposition: marker.requiredComposition
            )
            systemHapticsHasActiveOverride = !restored
            if restored {
                defaults.removeObject(forKey: DefaultsKey.systemHapticsRecoveryTarget)
                recoveredFeatures.append(ExperimentalFeatureKind.systemHaptics.title)
            } else {
                pendingFeatures.append(ExperimentalFeatureKind.systemHaptics.title)
            }
        }

        if !pendingFeatures.isEmpty {
            lastMessage = "Recovery is still pending for \(pendingFeatures.joined(separator: ", ")). Connect the target trackpad and turn its feature flag off to retry."
        } else if !recoveredFeatures.isEmpty {
            lastMessage = "Recovered macOS defaults after an unclean session: \(recoveredFeatures.joined(separator: ", "))."
        }
    }

    private func restoreDefaultSurfaceOrientation(
        fallbackTarget: HapticDeviceTarget?
    ) -> Bool {
        let marker = recoveryMarker(for: .surfaceOrientation)
        return controller.restoreDefaultSurfaceOrientation(
            target: marker?.target ?? fallbackTarget,
            requiredComposition: marker?.requiredComposition
        )
    }

    private func restoreDefaultSystemHaptics(
        fallbackTarget: HapticDeviceTarget?
    ) -> Bool {
        let marker = recoveryMarker(for: .systemHaptics)
        return controller.restoreDefaultSystemHaptics(
            target: marker?.target ?? fallbackTarget,
            requiredComposition: marker?.requiredComposition
        )
    }

    private func recoveryMarker(
        for feature: ExperimentalFeatureKind
    ) -> AdvancedTrackpadRecoveryMarker? {
        recoveryMarker(forKey: recoveryKey(for: feature))
    }

    private func recoveryMarker(forKey key: String) -> AdvancedTrackpadRecoveryMarker? {
        if let data = defaults.data(forKey: key),
           let marker = try? JSONDecoder().decode(AdvancedTrackpadRecoveryMarker.self, from: data),
           marker.schemaVersion == AdvancedTrackpadRecoveryMarker.currentSchemaVersion,
           marker.requiredComposition?.isValid != false {
            return marker
        }

        // Migrate markers written by version 0.2.0. They did not include a
        // composition, so recovery retains its previous target-only behavior.
        guard let rawValue = defaults.string(forKey: key) else { return nil }
        return AdvancedTrackpadRecoveryMarker(
            target: HapticDeviceTarget(rawValue: rawValue) ?? .all,
            requiredComposition: nil
        )
    }

    private func recoveryKey(for feature: ExperimentalFeatureKind) -> String {
        feature == .surfaceOrientation
            ? DefaultsKey.surfaceRecoveryTarget
            : DefaultsKey.systemHapticsRecoveryTarget
    }

    private func updateRecoveryMarker(
        for feature: ExperimentalFeatureKind,
        target: HapticDeviceTarget,
        requiredComposition: AdvancedTrackpadDeviceComposition? = nil,
        recoveryIsNeeded: Bool
    ) {
        let key = recoveryKey(for: feature)
        if recoveryIsNeeded {
            let marker: AdvancedTrackpadRecoveryMarker
            if requiredComposition == nil, let existing = recoveryMarker(forKey: key) {
                marker = existing
            } else {
                let existing = recoveryMarker(forKey: key)
                marker = AdvancedTrackpadRecoveryMarker(
                    target: combinedRecoveryTarget(existing?.target, target),
                    requiredComposition: requiredComposition.map { composition in
                        existing?.requiredComposition?.combined(with: composition) ?? composition
                    }
                )
            }
            guard let data = try? JSONEncoder().encode(marker) else { return }
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        _ = defaults.synchronize()
    }

    private func combinedRecoveryTarget(
        _ existing: HapticDeviceTarget?,
        _ requested: HapticDeviceTarget
    ) -> HapticDeviceTarget {
        guard let existing, existing != requested else { return requested }
        return .all
    }
}
