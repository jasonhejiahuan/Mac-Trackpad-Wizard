import Foundation
import Testing
@testable import TrackpadWizard

@MainActor
struct AppModelHapticLibraryTests {
    @Test("An empty composer pattern cannot be saved to the library")
    func emptyComposerPatternIsRejected() throws {
        let suiteName = "AppModelHapticLibraryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = AppModel(defaults: defaults)
        defer { model.shutDown() }

        var emptyPattern = model.customHapticPattern
        for index in emptyPattern.steps.indices {
            emptyPattern.steps[index].isEnabled = false
        }
        model.customHapticPattern = emptyPattern
        model.selectedHapticPatternID = emptyPattern.id
        let initialLibraryCount = model.savedHapticPatterns.count

        #expect(!model.canSaveSelectedComposerPattern)
        model.saveSelectedComposerPattern()

        #expect(model.savedHapticPatterns.count == initialLibraryCount)
        #expect(model.selectedSavedHapticPatternID == nil)
        #expect(model.statusMessage?.contains("unsupported number of events (0)") == true)
    }
}
