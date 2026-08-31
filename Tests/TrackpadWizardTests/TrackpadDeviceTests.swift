import Foundation
import Testing
@testable import TrackpadWizard

struct TrackpadDeviceTests {
    @Test("Surface dimensions follow the selected device target without Enhanced Mode")
    func surfaceDimensionsFollowTarget() throws {
        let builtIn = device(name: "Built-in Trackpad", isBuiltIn: true, width: 124.8, height: 76.8)
        let external = device(name: "Magic Trackpad", isBuiltIn: false, width: 156, height: 110.4)

        #expect(TrackpadSurfaceSizeResolver.preferredSize(
            for: .builtIn,
            devices: [external, builtIn]
        ) == CGSize(width: 124.8, height: 76.8))
        #expect(TrackpadSurfaceSizeResolver.preferredSize(
            for: .external,
            devices: [external, builtIn]
        ) == CGSize(width: 156, height: 110.4))
        #expect(TrackpadSurfaceSizeResolver.preferredSize(
            for: .all,
            devices: [external, builtIn]
        ) == CGSize(width: 124.8, height: 76.8))
    }

    @Test("All-device dimensions fall back to a connected external surface")
    func allTargetFallsBackToExternal() {
        let unavailableBuiltIn = device(
            name: "Built-in Trackpad",
            isBuiltIn: true,
            width: nil,
            height: nil
        )
        let external = device(name: "Magic Trackpad", isBuiltIn: false, width: 156, height: 110.4)

        #expect(TrackpadSurfaceSizeResolver.preferredSize(
            for: .all,
            devices: [external, unavailableBuiltIn]
        ) == CGSize(width: 156, height: 110.4))
    }

    private func device(
        name: String,
        isBuiltIn: Bool,
        width: Double?,
        height: Double?
    ) -> TrackpadDevice {
        TrackpadDevice(
            id: name,
            name: name,
            manufacturer: "Apple",
            connection: isBuiltIn ? .builtIn : .bluetooth,
            batteryPercent: nil,
            reportIntervalMicroseconds: nil,
            vendorID: 1_452,
            productID: nil,
            isBuiltIn: isBuiltIn,
            forceSupported: true,
            surfaceWidthMM: width,
            surfaceHeightMM: height
        )
    }
}
