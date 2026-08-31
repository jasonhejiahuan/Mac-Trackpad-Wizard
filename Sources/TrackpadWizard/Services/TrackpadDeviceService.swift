import Foundation
import IOKit
import IOKit.hid

struct TrackpadDeviceService {
    func scan() -> (devices: [TrackpadDevice], settings: [TrackpadSetting]) {
        let multitouchProperties = properties(forClass: "AppleMultitouchDevice")
        let eventProperties = properties(forClass: "AppleDeviceManagementHIDEventService")

        var batteryByProduct: [String: Int] = [:]
        for properties in eventProperties {
            guard let battery = integer(properties["BatteryPercent"]) else { continue }
            batteryByProduct[identityKey(properties)] = battery
        }

        let devices = multitouchProperties.enumerated().compactMap { index, properties -> TrackpadDevice? in
            guard let product = properties["Product"] as? String else { return nil }
            let builtIn = boolean(properties["MT Built-In"]) ?? boolean(properties["Built-In"]) ?? false
            let transport = (properties["Transport"] as? String ?? "").lowercased()
            let connection: TrackpadConnection
            if builtIn {
                connection = .builtIn
            } else if transport.contains("bluetooth") {
                connection = .bluetooth
            } else if transport.contains("usb") {
                connection = .usb
            } else {
                connection = .unknown
            }
            let productID = integer(properties["ProductID"])
            let battery = batteryByProduct[identityKey(properties)] ?? eventProperties.compactMap { event -> Int? in
                guard productID != nil, integer(event["ProductID"]) == productID else { return nil }
                return integer(event["BatteryPercent"])
            }.first

            return TrackpadDevice(
                id: "\(builtIn ? "built-in" : "external")-\(productID ?? -1)-\(index)",
                name: product,
                manufacturer: product.localizedCaseInsensitiveContains("apple") ||
                    product.localizedCaseInsensitiveContains("magic trackpad") ? "Apple" : nil,
                connection: connection,
                batteryPercent: battery,
                reportIntervalMicroseconds: integer(properties["ReportInterval"]),
                vendorID: integer(properties["VendorID"]),
                productID: productID,
                isBuiltIn: builtIn,
                forceSupported: boolean(properties["ForceSupported"]),
                surfaceWidthMM: surfaceDimension(properties["Sensor Surface Width"]),
                surfaceHeightMM: surfaceDimension(properties["Sensor Surface Height"])
            )
        }
        .sorted { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        return (devices, trackpadSettings())
    }

    private func properties(forClass className: String) -> [[String: Any]] {
        guard let matching = IOServiceMatching(className) else { return [] }
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var result: [[String: Any]] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var unmanaged: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let properties = unmanaged?.takeRetainedValue() as? [String: Any] {
                result.append(properties)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return result
    }

    private func trackpadSettings() -> [TrackpadSetting] {
        let definitions: [(key: String, title: String, formatter: (Any) -> String?)] = [
            ("Clicking", "Tap to Click", { boolString($0) }),
            ("TrackpadRightClick", "Secondary Click", { boolString($0) }),
            ("TrackpadScroll", "Two-Finger Scroll", { boolString($0) }),
            ("TrackpadPinch", "Pinch to Zoom", { boolString($0) }),
            ("TrackpadRotate", "Rotate", { boolString($0) }),
            ("TrackpadThreeFingerDrag", "Three-Finger Drag", { boolString($0) }),
            ("TrackpadThreeFingerHorizSwipeGesture", "Three-Finger Horizontal Swipe", { gestureString($0) }),
            ("TrackpadFourFingerVertSwipeGesture", "Four-Finger Vertical Swipe", { gestureString($0) }),
            ("FirstClickThreshold", "Click Pressure", { thresholdString($0) }),
            ("SecondClickThreshold", "Force Click Pressure", { thresholdString($0) }),
            ("ActuationStrength", "Haptic Click Strength", { thresholdString($0) })
        ]
        let domains = [
            "com.apple.AppleMultitouchTrackpad",
            "com.apple.driver.AppleBluetoothMultitouch.trackpad"
        ]

        var values: [String: TrackpadSetting] = [:]
        for definition in definitions {
            for domain in domains {
                guard let raw = preference(definition.key, domain: domain),
                      let formatted = definition.formatter(raw) else { continue }
                values[definition.key] = TrackpadSetting(
                    key: definition.key,
                    title: definition.title,
                    value: formatted
                )
                break
            }
        }

        if let forceClick = preference("com.apple.trackpad.forceClick", domain: ".GlobalPreferences"),
           let formatted = boolString(forceClick) {
            values["com.apple.trackpad.forceClick"] = TrackpadSetting(
                key: "com.apple.trackpad.forceClick",
                title: "Force Click and Haptic Feedback",
                value: formatted
            )
        }
        if let natural = preference("com.apple.swipescrolldirection", domain: ".GlobalPreferences"),
           let formatted = boolString(natural) {
            values["com.apple.swipescrolldirection"] = TrackpadSetting(
                key: "com.apple.swipescrolldirection",
                title: "Natural Scrolling",
                value: formatted
            )
        }

        return values.values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func preference(_ key: String, domain: String) -> Any? {
        let applicationID = domain as CFString
        if let value = CFPreferencesCopyValue(
            key as CFString,
            applicationID,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) {
            return value
        }
        return CFPreferencesCopyValue(
            key as CFString,
            applicationID,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }

    private func identityKey(_ properties: [String: Any]) -> String {
        let product = properties["Product"] as? String ?? "Trackpad"
        let productID = integer(properties["ProductID"]) ?? -1
        return "\(product)-\(productID)"
    }

    private func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func boolean(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return nil
    }

    private func surfaceDimension(_ value: Any?) -> Double? {
        guard let hundredthsOfAMillimeter = integer(value), hundredthsOfAMillimeter > 0 else {
            return nil
        }
        return Double(hundredthsOfAMillimeter) / 100
    }

    private func boolString(_ value: Any) -> String? {
        guard let enabled = boolean(value) else { return nil }
        return enabled ? "On" : "Off"
    }

    private func gestureString(_ value: Any) -> String? {
        guard let raw = integer(value) else { return nil }
        return raw == 0 ? "Off" : "On (mode \(raw))"
    }

    private func thresholdString(_ value: Any) -> String? {
        guard let raw = integer(value) else { return nil }
        switch raw {
        case 0: return "Light"
        case 1: return "Medium"
        case 2: return "Firm"
        default: return "Level \(raw)"
        }
    }
}
