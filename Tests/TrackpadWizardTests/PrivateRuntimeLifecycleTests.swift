import Testing
@testable import TrackpadWizard

@MainActor
struct PrivateRuntimeLifecycleTests {
    @Test("Enhanced Mode does not load its private runtime while disabled")
    func privateTouchRuntimeStartsUnloaded() {
        let monitor = PrivateTouchMonitor()

        #expect(!monitor.isRuntimeLoaded)
        #expect(!monitor.isStreaming)
        monitor.shutDown()
        #expect(!monitor.isRuntimeLoaded)
    }
}
