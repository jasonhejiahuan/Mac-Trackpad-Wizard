import Foundation
import Testing
@testable import TrackpadWizard

@MainActor
struct HapticStatisticsTests {
    @Test("Successful oscillations aggregate by pseudonymous device")
    func aggregation() throws {
        let suiteName = "HapticStatisticsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(true, forKey: "hapticStatisticsCollectionEnabled")
        let archiveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName).json")
        defer { try? FileManager.default.removeItem(at: archiveURL) }
        let store = HapticStatisticsStore(defaults: defaults, archiveURL: archiveURL)
        let observer = try #require(store.actuationObserver)

        let builtIn = HapticCounterDevice(
            id: "built-in-hash",
            displayName: "Built-in Trackpad",
            isBuiltIn: true
        )
        let external = HapticCounterDevice(
            id: "external-hash",
            displayName: "External Trackpad · 1234",
            isBuiltIn: false
        )
        observer(builtIn)
        observer(builtIn)
        observer(external)
        store.flushPendingCounts()

        #expect(store.totalCount == 3)
        #expect(store.devices.count == 2)
        #expect(store.devices.first { $0.id == builtIn.id }?.totalCount == 2)
        #expect(store.devices.first { $0.id == external.id }?.totalCount == 1)

        store.setCollectionEnabled(false)
        #expect(store.actuationObserver == nil)
        store.shutDown()

        let reloaded = HapticStatisticsStore(defaults: defaults, archiveURL: archiveURL)
        #expect(reloaded.totalCount == 3)
        #expect(reloaded.devices.count == 2)
        reloaded.shutDown()
        defaults.removePersistentDomain(forName: suiteName)
    }
}
