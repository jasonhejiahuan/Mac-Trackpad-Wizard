import Foundation
import Testing
@testable import TrackpadWizard

@MainActor
struct AdvancedFeaturesTests {
    @Test("Surface orientation keeps native and app-coordinate rotations distinct")
    func orientationMapping() {
        #expect(ExperimentalSurfaceOrientation.degrees0.privateOrientationCode == 0)
        #expect(ExperimentalSurfaceOrientation.degrees90.privateOrientationCode == 0)
        #expect(ExperimentalSurfaceOrientation.degrees180.privateOrientationCode == 2)
        #expect(ExperimentalSurfaceOrientation.degrees270.privateOrientationCode == 0)

        #expect(ExperimentalSurfaceOrientation.degrees0.previewRotationDegrees == 0)
        #expect(ExperimentalSurfaceOrientation.degrees90.previewRotationDegrees == 90)
        #expect(ExperimentalSurfaceOrientation.degrees180.previewRotationDegrees == 0)
        #expect(ExperimentalSurfaceOrientation.degrees270.previewRotationDegrees == 270)

        let point90 = ExperimentalSurfaceOrientation.degrees90.transformPoint(x: 0.2, y: 0.3)
        #expect(isClose(point90.x, 0.7))
        #expect(isClose(point90.y, 0.2))

        let point270 = ExperimentalSurfaceOrientation.degrees270.transformPoint(x: 0.2, y: 0.3)
        #expect(isClose(point270.x, 0.3))
        #expect(isClose(point270.y, 0.8))

        let vector90 = ExperimentalSurfaceOrientation.degrees90.transformVector(x: 0.2, y: 0.3)
        #expect(isClose(vector90.x, -0.3))
        #expect(isClose(vector90.y, 0.2))

        let vector270 = ExperimentalSurfaceOrientation.degrees270.transformVector(x: 0.2, y: 0.3)
        #expect(isClose(vector270.x, 0.3))
        #expect(isClose(vector270.y, -0.2))
    }

    @Test("Unconfirmed advanced changes restore their captured state automatically")
    func automaticRecovery() async throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let store = AdvancedFeaturesStore(
            defaults: environment.defaults,
            controller: environment.controller,
            recoveryInterval: 0.02
        )

        #expect(store.setSurfaceOrientationFeatureEnabled(true, target: .builtIn))
        #expect(store.requestSurfaceOrientation(.degrees180, target: .builtIn))
        #expect(store.selectedSurfaceOrientation == .degrees180)
        #expect(store.pendingConfirmation != nil)
        #expect(environment.controller.surfaceRequests.count == 1)
        #expect(environment.controller.surfaceRequests.first?.0 == .degrees180)
        #expect(environment.controller.surfaceRequests.first?.1 == .builtIn)

        try await Task.sleep(for: .milliseconds(80))

        #expect(store.pendingConfirmation == nil)
        #expect(store.selectedSurfaceOrientation == .degrees0)
        #expect(environment.controller.restoredSurfaceSnapshots == [
            SurfaceOrientationSnapshot(valuesByDevice: [11: 0])
        ])
        #expect(store.lastMessage?.contains("restored automatically") == true)
        store.shutDown()
    }

    @Test("Disabling an experimental flag hides it and restores the managed macOS default")
    func flagOffRestoresDefault() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let store = AdvancedFeaturesStore(
            defaults: environment.defaults,
            controller: environment.controller
        )

        #expect(store.setSystemHapticsFeatureEnabled(true, target: .external))
        #expect(store.requestSystemHapticFeedback(enabled: false, target: .external))
        store.confirmPendingChange()
        #expect(!store.systemHapticFeedbackEnabled)
        #expect(store.enabledFeatureCount == 1)

        #expect(store.setSystemHapticsFeatureEnabled(false, target: .external))
        #expect(store.systemHapticFeedbackEnabled)
        #expect(!store.systemHapticsFeatureEnabled)
        #expect(store.enabledFeatureCount == 0)
        #expect(environment.controller.defaultSystemHapticsRestoreCount == 1)
        #expect(environment.controller.lastDefaultSystemHapticsTarget == .external)
        #expect(!environment.defaults.bool(forKey: "experimentalSystemHapticsFeatureEnabled"))
        store.shutDown()
    }

    @Test("Turning a feature flag off during its countdown restores default after snapshot rollback")
    func pendingFlagOffRestoresDefault() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let store = AdvancedFeaturesStore(
            defaults: environment.defaults,
            controller: environment.controller
        )

        #expect(store.setSurfaceOrientationFeatureEnabled(true, target: .all))
        #expect(store.requestSurfaceOrientation(.degrees180, target: .all))
        #expect(store.setSurfaceOrientationFeatureEnabled(false, target: .all))

        #expect(environment.controller.restoredSurfaceSnapshots.count == 1)
        #expect(environment.controller.defaultSurfaceRestoreCount == 1)
        #expect(environment.controller.lastDefaultSurfaceTarget == .all)
        #expect(store.pendingConfirmation == nil)
        #expect(store.selectedSurfaceOrientation == .degrees0)
        store.shutDown()
    }

    @Test("An unclean-session marker restores only the recorded target at next launch")
    func uncleanSessionRecovery() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        environment.defaults.set(
            HapticDeviceTarget.builtIn.rawValue,
            forKey: "experimentalSurfaceOrientationRecoveryTarget"
        )

        let store = AdvancedFeaturesStore(
            defaults: environment.defaults,
            controller: environment.controller
        )

        #expect(environment.controller.defaultSurfaceRestoreCount == 1)
        #expect(environment.controller.lastDefaultSurfaceTarget == .builtIn)
        #expect(environment.defaults.object(
            forKey: "experimentalSurfaceOrientationRecoveryTarget"
        ) == nil)
        #expect(store.lastMessage?.contains("Recovered macOS defaults") == true)
        store.shutDown()
    }

    private func isClose(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.000_001
    }
}

@MainActor
private final class TestAdvancedTrackpadController: AdvancedTrackpadControlling {
    var supportsSurfaceOrientation = true
    var supportsSystemHaptics = true
    var surfaceRequests: [(ExperimentalSurfaceOrientation, HapticDeviceTarget)] = []
    var systemHapticsRequests: [(Bool, HapticDeviceTarget)] = []
    var restoredSurfaceSnapshots: [SurfaceOrientationSnapshot] = []
    var restoredSystemHapticsSnapshots: [SystemHapticsSnapshot] = []
    var defaultSurfaceRestoreCount = 0
    var defaultSystemHapticsRestoreCount = 0
    var lastDefaultSurfaceTarget: HapticDeviceTarget?
    var lastDefaultSystemHapticsTarget: HapticDeviceTarget?
    var defaultSurfaceRestoreResult = true
    var defaultSystemHapticsRestoreResult = true
    var shutDownCount = 0

    func applySurfaceOrientation(
        _ orientation: ExperimentalSurfaceOrientation,
        target: HapticDeviceTarget
    ) throws -> SurfaceOrientationSnapshot {
        surfaceRequests.append((orientation, target))
        return SurfaceOrientationSnapshot(valuesByDevice: [11: 0])
    }

    func restoreSurfaceOrientation(_ snapshot: SurfaceOrientationSnapshot) -> Bool {
        restoredSurfaceSnapshots.append(snapshot)
        return true
    }

    func restoreDefaultSurfaceOrientation(target: HapticDeviceTarget?) -> Bool {
        defaultSurfaceRestoreCount += 1
        lastDefaultSurfaceTarget = target
        return defaultSurfaceRestoreResult
    }

    func applySystemHaptics(
        enabled: Bool,
        target: HapticDeviceTarget
    ) throws -> SystemHapticsSnapshot {
        systemHapticsRequests.append((enabled, target))
        return SystemHapticsSnapshot(valuesByDevice: [22: true])
    }

    func restoreSystemHaptics(_ snapshot: SystemHapticsSnapshot) -> Bool {
        restoredSystemHapticsSnapshots.append(snapshot)
        return true
    }

    func restoreDefaultSystemHaptics(target: HapticDeviceTarget?) -> Bool {
        defaultSystemHapticsRestoreCount += 1
        lastDefaultSystemHapticsTarget = target
        return defaultSystemHapticsRestoreResult
    }

    func shutDown() {
        shutDownCount += 1
    }
}

@MainActor
private struct TestEnvironment {
    let suiteName: String
    let defaults: UserDefaults
    let controller = TestAdvancedTrackpadController()

    init() throws {
        suiteName = "AdvancedFeaturesTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
