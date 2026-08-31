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

    @Test("Recovery composition requires every previously affected device class and count")
    func recoveryComposition() {
        let builtInAndExternal = AdvancedTrackpadDeviceComposition(
            builtInCount: 1,
            externalCount: 1
        )
        #expect(!builtInAndExternal.isSatisfied(by: AdvancedTrackpadDeviceComposition(
            builtInCount: 1,
            externalCount: 0
        )))
        #expect(builtInAndExternal.isSatisfied(by: AdvancedTrackpadDeviceComposition(
            builtInCount: 1,
            externalCount: 1
        )))
        #expect(!AdvancedTrackpadDeviceComposition(
            builtInCount: 1,
            externalCount: 2
        ).isSatisfied(by: builtInAndExternal))
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

    @Test("Turning a feature flag off during its countdown restores the captured snapshot once")
    func pendingFlagOffRestoresSnapshot() throws {
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
        #expect(environment.controller.defaultSurfaceRestoreCount == 0)
        #expect(store.pendingConfirmation == nil)
        #expect(store.selectedSurfaceOrientation == .degrees0)
        store.shutDown()
    }

    @Test("System haptics reflects an existing off state without writing when its flag is disabled")
    func systemHapticsFlagDoesNotOverwriteExistingState() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        environment.controller.currentSystemHaptics = false
        let store = AdvancedFeaturesStore(
            defaults: environment.defaults,
            controller: environment.controller
        )

        #expect(store.setSystemHapticsFeatureEnabled(true, target: .builtIn))
        #expect(!store.systemHapticFeedbackEnabled)
        #expect(environment.controller.systemHapticsRequests.isEmpty)

        #expect(store.setSystemHapticsFeatureEnabled(false, target: .builtIn))
        #expect(environment.controller.defaultSystemHapticsRestoreCount == 0)
        #expect(environment.controller.systemHapticsRequests.isEmpty)
        store.shutDown()
    }

    @Test("Disabled experimental features never instantiate their private controller")
    func disabledFeaturesDoNotLoadController() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        var factoryCalls = 0
        let store = AdvancedFeaturesStore(
            defaults: environment.defaults,
            controllerFactory: {
                factoryCalls += 1
                return environment.controller
            }
        )

        #expect(factoryCalls == 0)
        #expect(store.enabledFeatureCount == 0)
        store.shutDown()
        #expect(factoryCalls == 0)
    }

    @Test("Confirmed quarter-turn app coordinates survive a clean relaunch")
    func quarterTurnPersists() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let firstStore = AdvancedFeaturesStore(
            defaults: environment.defaults,
            controller: environment.controller
        )
        #expect(firstStore.setSurfaceOrientationFeatureEnabled(true, target: .builtIn))
        #expect(firstStore.requestSurfaceOrientation(.degrees90, target: .builtIn))
        firstStore.confirmPendingChange()
        firstStore.shutDown()

        let relaunchedStore = AdvancedFeaturesStore(
            defaults: environment.defaults,
            controller: environment.controller
        )
        #expect(relaunchedStore.selectedSurfaceOrientation == .degrees90)
        relaunchedStore.shutDown()
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

    @Test("Advanced changes persist the exact target composition before mutation")
    func recoveryMarkerCapturesComposition() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let store = AdvancedFeaturesStore(
            defaults: environment.defaults,
            controller: environment.controller
        )

        #expect(store.setSurfaceOrientationFeatureEnabled(true, target: .all))
        #expect(store.requestSurfaceOrientation(.degrees180, target: .all))

        let data = try #require(environment.defaults.data(
            forKey: "experimentalSurfaceOrientationRecoveryTarget"
        ))
        let marker = try JSONDecoder().decode(AdvancedTrackpadRecoveryMarker.self, from: data)
        #expect(marker.target == .all)
        #expect(marker.requiredComposition == AdvancedTrackpadDeviceComposition(
            builtInCount: 1,
            externalCount: 1
        ))

        store.confirmPendingChange()
        environment.controller.availableComposition = AdvancedTrackpadDeviceComposition(
            builtInCount: 1,
            externalCount: 0
        )
        #expect(store.requestSurfaceOrientation(.degrees90, target: .all))
        let updatedData = try #require(environment.defaults.data(
            forKey: "experimentalSurfaceOrientationRecoveryTarget"
        ))
        let updatedMarker = try JSONDecoder().decode(
            AdvancedTrackpadRecoveryMarker.self,
            from: updatedData
        )
        #expect(updatedMarker.requiredComposition == marker.requiredComposition)

        environment.controller.availableComposition = marker.requiredComposition
            ?? environment.controller.availableComposition
        store.restorePendingChange()
        store.restoreSurfaceOrientationDefault(target: .all)
        store.shutDown()
    }

    @Test("All-device recovery remains pending while an affected device class is disconnected")
    func allDeviceRecoveryWaitsForDisconnectedClass() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let requiredComposition = AdvancedTrackpadDeviceComposition(
            builtInCount: 1,
            externalCount: 1
        )
        let markerData = try JSONEncoder().encode(AdvancedTrackpadRecoveryMarker(
            target: .all,
            requiredComposition: requiredComposition
        ))
        environment.defaults.set(
            markerData,
            forKey: "experimentalSurfaceOrientationRecoveryTarget"
        )
        environment.defaults.set(
            markerData,
            forKey: "experimentalSystemHapticsRecoveryTarget"
        )
        environment.controller.availableComposition = AdvancedTrackpadDeviceComposition(
            builtInCount: 1,
            externalCount: 0
        )

        let store = AdvancedFeaturesStore(
            defaults: environment.defaults,
            controller: environment.controller
        )

        #expect(environment.controller.lastDefaultSurfaceTarget == .all)
        #expect(environment.controller.lastDefaultSystemHapticsTarget == .all)
        #expect(environment.controller.lastRequiredSurfaceComposition == requiredComposition)
        #expect(environment.controller.lastRequiredSystemHapticsComposition == requiredComposition)
        #expect(environment.defaults.object(
            forKey: "experimentalSurfaceOrientationRecoveryTarget"
        ) != nil)
        #expect(environment.defaults.object(
            forKey: "experimentalSystemHapticsRecoveryTarget"
        ) != nil)
        #expect(store.lastMessage?.contains("Recovery is still pending") == true)

        environment.controller.availableComposition = requiredComposition
        #expect(store.setSurfaceOrientationFeatureEnabled(false, target: .all))
        #expect(store.setSystemHapticsFeatureEnabled(false, target: .all))
        #expect(environment.defaults.object(
            forKey: "experimentalSurfaceOrientationRecoveryTarget"
        ) == nil)
        #expect(environment.defaults.object(
            forKey: "experimentalSystemHapticsRecoveryTarget"
        ) == nil)
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
    var currentSystemHaptics: Bool? = true
    var surfaceRequests: [(ExperimentalSurfaceOrientation, HapticDeviceTarget)] = []
    var systemHapticsRequests: [(Bool, HapticDeviceTarget)] = []
    var restoredSurfaceSnapshots: [SurfaceOrientationSnapshot] = []
    var restoredSystemHapticsSnapshots: [SystemHapticsSnapshot] = []
    var defaultSurfaceRestoreCount = 0
    var defaultSystemHapticsRestoreCount = 0
    var lastDefaultSurfaceTarget: HapticDeviceTarget?
    var lastDefaultSystemHapticsTarget: HapticDeviceTarget?
    var lastRequiredSurfaceComposition: AdvancedTrackpadDeviceComposition?
    var lastRequiredSystemHapticsComposition: AdvancedTrackpadDeviceComposition?
    var availableComposition = AdvancedTrackpadDeviceComposition(
        builtInCount: 1,
        externalCount: 1
    )
    var defaultSurfaceRestoreResult = true
    var defaultSystemHapticsRestoreResult = true
    var shutDownCount = 0

    func applySurfaceOrientation(
        _ orientation: ExperimentalSurfaceOrientation,
        target: HapticDeviceTarget,
        beforeApplying: (AdvancedTrackpadDeviceComposition) -> Void
    ) throws -> SurfaceOrientationSnapshot {
        surfaceRequests.append((orientation, target))
        beforeApplying(composition(for: target))
        return SurfaceOrientationSnapshot(valuesByDevice: [11: 0])
    }

    func restoreSurfaceOrientation(_ snapshot: SurfaceOrientationSnapshot) -> Bool {
        restoredSurfaceSnapshots.append(snapshot)
        return true
    }

    func restoreDefaultSurfaceOrientation(
        target: HapticDeviceTarget?,
        requiredComposition: AdvancedTrackpadDeviceComposition?
    ) -> Bool {
        defaultSurfaceRestoreCount += 1
        lastDefaultSurfaceTarget = target
        lastRequiredSurfaceComposition = requiredComposition
        return defaultSurfaceRestoreResult
            && (requiredComposition?.isSatisfied(by: availableComposition) ?? true)
    }

    func applySystemHaptics(
        enabled: Bool,
        target: HapticDeviceTarget,
        beforeApplying: (AdvancedTrackpadDeviceComposition) -> Void
    ) throws -> SystemHapticsSnapshot {
        systemHapticsRequests.append((enabled, target))
        beforeApplying(composition(for: target))
        return SystemHapticsSnapshot(valuesByDevice: [22: true])
    }

    func readSystemHaptics(target: HapticDeviceTarget) throws -> Bool? {
        currentSystemHaptics
    }

    func restoreSystemHaptics(_ snapshot: SystemHapticsSnapshot) -> Bool {
        restoredSystemHapticsSnapshots.append(snapshot)
        return true
    }

    func restoreDefaultSystemHaptics(
        target: HapticDeviceTarget?,
        requiredComposition: AdvancedTrackpadDeviceComposition?
    ) -> Bool {
        defaultSystemHapticsRestoreCount += 1
        lastDefaultSystemHapticsTarget = target
        lastRequiredSystemHapticsComposition = requiredComposition
        return defaultSystemHapticsRestoreResult
            && (requiredComposition?.isSatisfied(by: availableComposition) ?? true)
    }

    func shutDown() {
        shutDownCount += 1
    }

    private func composition(
        for target: HapticDeviceTarget
    ) -> AdvancedTrackpadDeviceComposition {
        switch target {
        case .all:
            availableComposition
        case .builtIn:
            AdvancedTrackpadDeviceComposition(
                builtInCount: availableComposition.builtInCount,
                externalCount: 0
            )
        case .external:
            AdvancedTrackpadDeviceComposition(
                builtInCount: 0,
                externalCount: availableComposition.externalCount
            )
        }
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
