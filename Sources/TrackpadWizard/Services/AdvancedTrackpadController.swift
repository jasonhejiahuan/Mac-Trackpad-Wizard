import Darwin
import Foundation

@MainActor
protocol AdvancedTrackpadControlling: AnyObject {
    var supportsSurfaceOrientation: Bool { get }
    var supportsSystemHaptics: Bool { get }

    func applySurfaceOrientation(
        _ orientation: ExperimentalSurfaceOrientation,
        target: HapticDeviceTarget,
        beforeApplying: (AdvancedTrackpadDeviceComposition) -> Void
    ) throws -> SurfaceOrientationSnapshot
    @discardableResult
    func restoreSurfaceOrientation(_ snapshot: SurfaceOrientationSnapshot) -> Bool
    @discardableResult
    func restoreDefaultSurfaceOrientation(
        target: HapticDeviceTarget?,
        requiredComposition: AdvancedTrackpadDeviceComposition?
    ) -> Bool

    func applySystemHaptics(
        enabled: Bool,
        target: HapticDeviceTarget,
        beforeApplying: (AdvancedTrackpadDeviceComposition) -> Void
    ) throws -> SystemHapticsSnapshot
    @discardableResult
    func restoreSystemHaptics(_ snapshot: SystemHapticsSnapshot) -> Bool
    @discardableResult
    func restoreDefaultSystemHaptics(
        target: HapticDeviceTarget?,
        requiredComposition: AdvancedTrackpadDeviceComposition?
    ) -> Bool

    func shutDown()
}

/// A narrow runtime bridge for the two explicitly user-enabled experimental
/// controls. Raw device identifiers never leave this process; recovery only
/// receives privacy-preserving built-in/external device counts.
@MainActor
final class AdvancedTrackpadController: AdvancedTrackpadControlling {
    private typealias DeviceListFunction = @convention(c) () -> Unmanaged<CFArray>?
    private typealias DeviceIDFunction = @convention(c) (
        UnsafeMutableRawPointer,
        UnsafeMutablePointer<UInt64>
    ) -> Int32
    private typealias DeviceBooleanFunction = @convention(c) (UnsafeMutableRawPointer) -> Bool
    private typealias DeviceGetReportFunction = @convention(c) (
        UnsafeMutableRawPointer,
        UInt32,
        UnsafeMutableRawPointer?,
        UInt32,
        UnsafeMutablePointer<UInt32>?
    ) -> Int32
    private typealias SetOrientationFunction = @convention(c) (
        UnsafeMutableRawPointer,
        UInt32
    ) -> Int32
    private typealias CreateActuatorFunction = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    private typealias OpenActuatorFunction = @convention(c) (UnsafeMutableRawPointer, UInt32) -> Int32
    private typealias CloseActuatorFunction = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias GetSystemActuationsFunction = @convention(c) (UnsafeMutableRawPointer) -> Bool
    private typealias SetSystemActuationsFunction = @convention(c) (
        UnsafeMutableRawPointer,
        Bool
    ) -> Int32

    private struct Device {
        let object: AnyObject
        let pointer: UnsafeMutableRawPointer
        let identifier: UInt64
        let isBuiltIn: Bool
    }

    private var libraryHandle: UnsafeMutableRawPointer?
    private var listDevices: DeviceListFunction?
    private var getDeviceID: DeviceIDFunction?
    private var deviceIsBuiltIn: DeviceBooleanFunction?
    private var getDeviceReport: DeviceGetReportFunction?
    private var setSurfaceOrientation: SetOrientationFunction?
    private var createActuator: CreateActuatorFunction?
    private var openActuator: OpenActuatorFunction?
    private var closeActuator: CloseActuatorFunction?
    private var getSystemActuations: GetSystemActuationsFunction?
    private var setSystemActuations: SetSystemActuationsFunction?
    private var managedSurfaceDeviceIDs: Set<UInt64> = []
    private var managedSystemHapticsDeviceIDs: Set<UInt64> = []
    private var didShutDown = false

    init() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else { return }
        libraryHandle = handle

        listDevices = symbol("MTDeviceCreateList", from: handle, as: DeviceListFunction.self)
        getDeviceID = symbol("MTDeviceGetDeviceID", from: handle, as: DeviceIDFunction.self)
        deviceIsBuiltIn = symbol("MTDeviceIsBuiltIn", from: handle, as: DeviceBooleanFunction.self)
        getDeviceReport = symbol("MTDeviceGetReport", from: handle, as: DeviceGetReportFunction.self)
        setSurfaceOrientation = symbol(
            "MTDeviceSetSurfaceOrientation",
            from: handle,
            as: SetOrientationFunction.self
        )
        createActuator = symbol(
            "MTActuatorCreateFromDeviceID",
            from: handle,
            as: CreateActuatorFunction.self
        )
        openActuator = symbol("MTActuatorOpen", from: handle, as: OpenActuatorFunction.self)
        closeActuator = symbol("MTActuatorClose", from: handle, as: CloseActuatorFunction.self)
        getSystemActuations = symbol(
            "MTActuatorGetSystemActuationsEnabled",
            from: handle,
            as: GetSystemActuationsFunction.self
        )
        setSystemActuations = symbol(
            "MTActuatorSetSystemActuationsEnabled",
            from: handle,
            as: SetSystemActuationsFunction.self
        )
    }

    var supportsSurfaceOrientation: Bool {
        listDevices != nil && getDeviceID != nil && deviceIsBuiltIn != nil &&
            getDeviceReport != nil && setSurfaceOrientation != nil
    }

    var supportsSystemHaptics: Bool {
        listDevices != nil && getDeviceID != nil && deviceIsBuiltIn != nil &&
            createActuator != nil && openActuator != nil && closeActuator != nil &&
            getSystemActuations != nil && setSystemActuations != nil
    }

    func applySurfaceOrientation(
        _ orientation: ExperimentalSurfaceOrientation,
        target: HapticDeviceTarget,
        beforeApplying: (AdvancedTrackpadDeviceComposition) -> Void
    ) throws -> SurfaceOrientationSnapshot {
        guard supportsSurfaceOrientation, let setter = setSurfaceOrientation else {
            throw AdvancedTrackpadControllerError.unavailable("Surface orientation")
        }
        let selected = try matchingDevices(target: target)
        var snapshot: [UInt64: UInt32] = [:]
        for device in selected {
            snapshot[device.identifier] = try currentOrientation(for: device)
        }

        // Persist recovery composition after all restore values are captured,
        // but before the first private API mutation can occur.
        beforeApplying(Self.composition(of: selected))

        var changed: [Device] = []
        for device in selected {
            let result = setter(device.pointer, orientation.privateOrientationCode)
            guard result == 0 else {
                if !restoreOrientationValues(snapshot, devices: changed) {
                    managedSurfaceDeviceIDs.formUnion(changed.map(\.identifier))
                }
                throw AdvancedTrackpadControllerError.operationFailed(
                    "Surface orientation",
                    code: result
                )
            }
            changed.append(device)
        }
        managedSurfaceDeviceIDs.formUnion(selected.map(\.identifier))
        return SurfaceOrientationSnapshot(valuesByDevice: snapshot)
    }

    func restoreSurfaceOrientation(_ snapshot: SurfaceOrientationSnapshot) -> Bool {
        restoreOrientationValues(snapshot.valuesByDevice, devices: scanDevices())
    }

    func restoreDefaultSurfaceOrientation(
        target: HapticDeviceTarget?,
        requiredComposition: AdvancedTrackpadDeviceComposition?
    ) -> Bool {
        guard let setter = setSurfaceOrientation else { return false }
        let scannedDevices = scanDevices()
        let hasRequiredDevices = requiredComposition?.isSatisfied(
            by: Self.composition(of: scannedDevices)
        ) ?? true
        let devices = Dictionary(uniqueKeysWithValues: scannedDevices.map { ($0.identifier, $0) })
        var identifiers = managedSurfaceDeviceIDs
        if let target {
            let targetIdentifiers = Self.identifiers(for: target, in: scannedDevices)
            guard !targetIdentifiers.isEmpty else { return false }
            identifiers.formUnion(targetIdentifiers)
        }
        var remaining: Set<UInt64> = []
        for identifier in identifiers {
            guard let device = devices[identifier], setter(device.pointer, 0) == 0 else {
                remaining.insert(identifier)
                continue
            }
        }
        managedSurfaceDeviceIDs = remaining
        return remaining.isEmpty && hasRequiredDevices
    }

    func applySystemHaptics(
        enabled: Bool,
        target: HapticDeviceTarget,
        beforeApplying: (AdvancedTrackpadDeviceComposition) -> Void
    ) throws -> SystemHapticsSnapshot {
        guard supportsSystemHaptics else {
            throw AdvancedTrackpadControllerError.unavailable("System haptic feedback")
        }
        let selected = try matchingDevices(target: target)
        var snapshot: [UInt64: Bool] = [:]
        for device in selected {
            snapshot[device.identifier] = try withActuator(for: device) { actuator in
                guard let getter = getSystemActuations else {
                    throw AdvancedTrackpadControllerError.unavailable("System haptic feedback")
                }
                return getter(actuator)
            }
        }

        // See the orientation path above: the marker must reach persistent
        // storage before any actuator state is changed.
        beforeApplying(Self.composition(of: selected))

        var changed: [Device] = []
        do {
            for device in selected {
                try setSystemHaptics(enabled, for: device)
                changed.append(device)
            }
        } catch {
            if !restoreSystemHapticValues(snapshot, devices: changed) {
                managedSystemHapticsDeviceIDs.formUnion(changed.map(\.identifier))
            }
            throw error
        }
        managedSystemHapticsDeviceIDs.formUnion(selected.map(\.identifier))
        return SystemHapticsSnapshot(valuesByDevice: snapshot)
    }

    func restoreSystemHaptics(_ snapshot: SystemHapticsSnapshot) -> Bool {
        restoreSystemHapticValues(snapshot.valuesByDevice, devices: scanDevices())
    }

    func restoreDefaultSystemHaptics(
        target: HapticDeviceTarget?,
        requiredComposition: AdvancedTrackpadDeviceComposition?
    ) -> Bool {
        let scannedDevices = scanDevices()
        let hasRequiredDevices = requiredComposition?.isSatisfied(
            by: Self.composition(of: scannedDevices)
        ) ?? true
        let devices = Dictionary(uniqueKeysWithValues: scannedDevices.map { ($0.identifier, $0) })
        var identifiers = managedSystemHapticsDeviceIDs
        if let target {
            let targetIdentifiers = Self.identifiers(for: target, in: scannedDevices)
            guard !targetIdentifiers.isEmpty else { return false }
            identifiers.formUnion(targetIdentifiers)
        }
        var remaining: Set<UInt64> = []
        for identifier in identifiers {
            guard let device = devices[identifier],
                  (try? setSystemHaptics(true, for: device)) != nil else {
                remaining.insert(identifier)
                continue
            }
        }
        managedSystemHapticsDeviceIDs = remaining
        return remaining.isEmpty && hasRequiredDevices
    }

    func shutDown() {
        guard !didShutDown else { return }
        didShutDown = true
        if let libraryHandle {
            dlclose(libraryHandle)
        }
        managedSurfaceDeviceIDs.removeAll()
        managedSystemHapticsDeviceIDs.removeAll()
        libraryHandle = nil
    }

    private func currentOrientation(for device: Device) throws -> UInt32 {
        guard let getter = getDeviceReport else {
            throw AdvancedTrackpadControllerError.unavailable("Surface orientation")
        }
        var orientation: UInt8 = 0
        var actualLength: UInt32 = 0
        let result = withUnsafeMutablePointer(to: &orientation) { pointer in
            getter(device.pointer, 0xDC, UnsafeMutableRawPointer(pointer), 1, &actualLength)
        }
        guard result == 0, actualLength == 1, orientation == 0 || orientation == 2 else {
            throw AdvancedTrackpadControllerError.cannotCaptureRestoreState("Surface orientation")
        }
        return UInt32(orientation)
    }

    private func restoreOrientationValues(
        _ values: [UInt64: UInt32],
        devices: [Device]
    ) -> Bool {
        guard let setter = setSurfaceOrientation else { return false }
        let byID = Dictionary(uniqueKeysWithValues: devices.map { ($0.identifier, $0) })
        var succeeded = true
        for (identifier, value) in values {
            guard let device = byID[identifier], value == 0 || value == 2 else {
                succeeded = false
                continue
            }
            if setter(device.pointer, value) != 0 { succeeded = false }
        }
        return succeeded
    }

    private func restoreSystemHapticValues(
        _ values: [UInt64: Bool],
        devices: [Device]
    ) -> Bool {
        let byID = Dictionary(uniqueKeysWithValues: devices.map { ($0.identifier, $0) })
        var succeeded = true
        for (identifier, value) in values {
            guard let device = byID[identifier] else {
                succeeded = false
                continue
            }
            if (try? setSystemHaptics(value, for: device)) == nil { succeeded = false }
        }
        return succeeded
    }

    private func setSystemHaptics(_ enabled: Bool, for device: Device) throws {
        try withActuator(for: device) { actuator in
            guard let setter = setSystemActuations else {
                throw AdvancedTrackpadControllerError.unavailable("System haptic feedback")
            }
            let result = setter(actuator, enabled)
            guard result == 0 else {
                throw AdvancedTrackpadControllerError.operationFailed(
                    "System haptic feedback",
                    code: result
                )
            }
        }
    }

    private func withActuator<T>(
        for device: Device,
        operation: (UnsafeMutableRawPointer) throws -> T
    ) throws -> T {
        guard let createActuator,
              let openActuator,
              let closeActuator,
              let actuator = createActuator(device.identifier) else {
            throw AdvancedTrackpadControllerError.cannotOpenActuator
        }
        guard openActuator(actuator, 0) == 0 else {
            Unmanaged<AnyObject>.fromOpaque(actuator).release()
            throw AdvancedTrackpadControllerError.cannotOpenActuator
        }
        defer {
            _ = closeActuator(actuator)
            Unmanaged<AnyObject>.fromOpaque(actuator).release()
        }
        return try operation(actuator)
    }

    private func matchingDevices(target: HapticDeviceTarget) throws -> [Device] {
        let devices = scanDevices()
        let selected = Self.devices(for: target, in: devices)
        guard !selected.isEmpty else {
            throw AdvancedTrackpadControllerError.noMatchingDevice
        }
        return selected
    }

    private static func devices(for target: HapticDeviceTarget, in devices: [Device]) -> [Device] {
        switch target {
        case .all: devices
        case .builtIn: devices.filter(\.isBuiltIn)
        case .external: devices.filter { !$0.isBuiltIn }
        }
    }

    private static func identifiers(
        for target: HapticDeviceTarget,
        in devices: [Device]
    ) -> Set<UInt64> {
        Set(Self.devices(for: target, in: devices).map(\.identifier))
    }

    private static func composition(of devices: [Device]) -> AdvancedTrackpadDeviceComposition {
        AdvancedTrackpadDeviceComposition(
            builtInCount: devices.lazy.filter(\.isBuiltIn).count,
            externalCount: devices.lazy.filter { !$0.isBuiltIn }.count
        )
    }

    private func scanDevices() -> [Device] {
        guard !didShutDown,
              let listDevices,
              let getDeviceID,
              let deviceIsBuiltIn,
              let array = listDevices()?.takeRetainedValue() else { return [] }
        return (array as [AnyObject]).compactMap { object in
            let pointer = Unmanaged.passUnretained(object).toOpaque()
            var identifier: UInt64 = 0
            guard getDeviceID(pointer, &identifier) == 0, identifier != 0 else { return nil }
            return Device(
                object: object,
                pointer: pointer,
                identifier: identifier,
                isBuiltIn: deviceIsBuiltIn(pointer)
            )
        }
    }

    private func symbol<T>(_ name: String, from handle: UnsafeMutableRawPointer, as type: T.Type) -> T? {
        guard let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }
}

enum AdvancedTrackpadControllerError: LocalizedError {
    case unavailable(String)
    case noMatchingDevice
    case cannotCaptureRestoreState(String)
    case cannotOpenActuator
    case operationFailed(String, code: Int32)

    var errorDescription: String? {
        switch self {
        case .unavailable(let feature):
            "\(feature) is unavailable on this macOS version."
        case .noMatchingDevice:
            "No trackpad matches the selected target."
        case .cannotCaptureRestoreState(let feature):
            "\(feature) was not changed because its current restore state could not be read safely."
        case .cannotOpenActuator:
            "The selected trackpad actuator could not be opened."
        case .operationFailed(let feature, let code):
            "\(feature) failed with IOKit result 0x\(String(format: "%08X", UInt32(bitPattern: code)))."
        }
    }
}
