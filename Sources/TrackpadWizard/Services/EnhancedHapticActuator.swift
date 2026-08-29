import AppKit
import CryptoKit
import Darwin

/// Runtime-only access to the trackpad actuator. This is intentionally isolated
/// behind a failable type because private framework availability can change.
@MainActor
final class EnhancedHapticActuator {
    private typealias CreateFunction = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    private typealias OpenFunction = @convention(c) (UnsafeMutableRawPointer, UInt32) -> Int32
    private typealias CloseFunction = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias ActuateFunction = @convention(c) (
        UnsafeMutableRawPointer,
        Int32,
        UInt32,
        Float,
        Float
    ) -> Int32
    private typealias DeviceListFunction = @convention(c) () -> Unmanaged<CFArray>?
    private typealias DeviceIDFunction = @convention(c) (
        UnsafeMutableRawPointer,
        UnsafeMutablePointer<UInt64>
    ) -> Int32
    private typealias DeviceBooleanFunction = @convention(c) (UnsafeMutableRawPointer) -> Bool

    private struct Device {
        let identifier: UInt64
        let isBuiltIn: Bool
        let actuator: UnsafeMutableRawPointer
        let counterIdentity: HapticCounterDevice
        var isPresent: Bool
    }

    private let libraryHandle: UnsafeMutableRawPointer
    private let createActuator: CreateFunction
    private let openActuator: OpenFunction
    private let closeActuator: CloseFunction
    private let actuate: ActuateFunction
    private let listDevices: DeviceListFunction
    private let getDeviceID: DeviceIDFunction
    private let deviceIsBuiltIn: DeviceBooleanFunction
    private var devices: [Device] = []
    private let buzzer = Buzzer()
    private var didShutDown = false
    private var actuationObserver: (@Sendable (HapticCounterDevice) -> Void)?

    var target: HapticDeviceTarget = .all

    init?() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else { return nil }

        guard let createSymbol = dlsym(handle, "MTActuatorCreateFromDeviceID"),
              let openSymbol = dlsym(handle, "MTActuatorOpen"),
              let closeSymbol = dlsym(handle, "MTActuatorClose"),
              let actuateSymbol = dlsym(handle, "MTActuatorActuate"),
              let listSymbol = dlsym(handle, "MTDeviceCreateList"),
              let identifierSymbol = dlsym(handle, "MTDeviceGetDeviceID"),
              let builtInSymbol = dlsym(handle, "MTDeviceIsBuiltIn") else {
            dlclose(handle)
            return nil
        }

        libraryHandle = handle
        createActuator = unsafeBitCast(createSymbol, to: CreateFunction.self)
        openActuator = unsafeBitCast(openSymbol, to: OpenFunction.self)
        closeActuator = unsafeBitCast(closeSymbol, to: CloseFunction.self)
        actuate = unsafeBitCast(actuateSymbol, to: ActuateFunction.self)
        listDevices = unsafeBitCast(listSymbol, to: DeviceListFunction.self)
        getDeviceID = unsafeBitCast(identifierSymbol, to: DeviceIDFunction.self)
        deviceIsBuiltIn = unsafeBitCast(builtInSymbol, to: DeviceBooleanFunction.self)

        refreshDevices()
        guard !devices.isEmpty else {
            dlclose(handle)
            return nil
        }
    }

    var summaries: [EnhancedTrackpadSummary] {
        devices.map { device in
            EnhancedTrackpadSummary(
                id: device.counterIdentity.id,
                isBuiltIn: device.isBuiltIn,
                isPresent: device.isPresent
            )
        }
    }

    var hasExternalDevice: Bool {
        devices.contains { $0.isPresent && !$0.isBuiltIn }
    }

    var hasBuiltInDevice: Bool {
        devices.contains { $0.isPresent && $0.isBuiltIn }
    }

    func refreshDevices() {
        guard !didShutDown,
              let array = listDevices()?.takeRetainedValue() else { return }
        let scanned = array as [AnyObject]

        var found: [(identifier: UInt64, isBuiltIn: Bool)] = []
        for device in scanned {
            let pointer = Unmanaged.passUnretained(device).toOpaque()
            var identifier: UInt64 = 0
            guard getDeviceID(pointer, &identifier) == 0, identifier != 0 else { continue }
            found.append((identifier, deviceIsBuiltIn(pointer)))
        }
        guard !found.isEmpty else {
            for index in devices.indices {
                devices[index].isPresent = false
            }
            return
        }

        let foundIdentifiers = Set(found.map(\.identifier))
        for index in devices.indices {
            devices[index].isPresent = foundIdentifiers.contains(devices[index].identifier)
        }

        let knownIdentifiers = Set(devices.map(\.identifier))
        for candidate in found where !knownIdentifiers.contains(candidate.identifier) {
            guard let actuator = createActuator(candidate.identifier) else { continue }
            if openActuator(actuator, 0) == 0 {
                devices.append(
                    Device(
                        identifier: candidate.identifier,
                        isBuiltIn: candidate.isBuiltIn,
                        actuator: actuator,
                        counterIdentity: Self.counterIdentity(
                            identifier: candidate.identifier,
                            isBuiltIn: candidate.isBuiltIn
                        ),
                        isPresent: true
                    )
                )
            } else {
                Unmanaged<AnyObject>.fromOpaque(actuator).release()
            }
        }
    }

    @discardableResult
    func tick(_ feedback: HapticFeedbackKind, amplitude: Double) -> Bool {
        let amplitude = Self.actuatorAmplitude(amplitude)
        guard amplitude > 0 else { return true }
        refreshDevices()
        let devices = targetDevices
        guard !devices.isEmpty else { return false }
        var allSucceeded = true
        for device in devices {
            if actuate(device.actuator, feedback.waveformID, 0, amplitude, 1) == 0 {
                actuationObserver?(device.counterIdentity)
            } else {
                allSucceeded = false
            }
        }
        return allSucceeded
    }

    @discardableResult
    func startBuzz(_ feedback: HapticFeedbackKind, amplitude: Double, frequency: Double) -> Bool {
        buzzer.stop()
        refreshDevices()
        let devices = targetDevices
        guard !devices.isEmpty else { return false }
        buzzer.start(
            targets: devices.map {
                Buzzer.Target(actuator: $0.actuator, identity: $0.counterIdentity)
            },
            actuate: actuate,
            waveformID: feedback.waveformID,
            amplitude: Self.actuatorAmplitude(amplitude),
            frequency: min(max(frequency, 8), 120),
            observer: actuationObserver
        )
        return true
    }

    func setActuationObserver(
        _ observer: (@Sendable (HapticCounterDevice) -> Void)?
    ) {
        actuationObserver = observer
        buzzer.setObserver(observer)
    }

    func stopBuzz() {
        buzzer.stop()
    }

    func shutDown() {
        guard !didShutDown else { return }
        didShutDown = true
        buzzer.stop()
        for device in devices {
            _ = closeActuator(device.actuator)
            Unmanaged<AnyObject>.fromOpaque(device.actuator).release()
        }
        devices.removeAll()
        dlclose(libraryHandle)
    }

    private var targetDevices: [Device] {
        let pool = devices.filter(\.isPresent)
        switch target {
        case .all:
            return pool
        case .builtIn:
            return pool.filter(\.isBuiltIn)
        case .external:
            return pool.filter { !$0.isBuiltIn }
        }
    }

    private static func counterIdentity(
        identifier: UInt64,
        isBuiltIn: Bool
    ) -> HapticCounterDevice {
        let input = Data("Trackpad Wizard statistics|\(identifier)".utf8)
        let digest = SHA256.hash(data: input)
        let hash = digest.prefix(12).map { String(format: "%02x", $0) }.joined()
        let suffix = hash.suffix(4).uppercased()
        return HapticCounterDevice(
            id: hash,
            displayName: isBuiltIn ? "Built-in Trackpad" : "External Trackpad · \(suffix)",
            isBuiltIn: isBuiltIn
        )
    }

    /// The private renderer accepts a floating-point multiplier and clamps it
    /// internally to 0...2. Trackpad Wizard intentionally exposes the safer
    /// normalized half of that range. A literal zero is a private-API legacy
    /// sentinel, so callers skip actuation instead of passing it through.
    private static func actuatorAmplitude(_ amplitude: Double) -> Float {
        Float(HapticStep.clampedAmplitude(amplitude))
    }

    private final class Buzzer: @unchecked Sendable {
        struct Target: @unchecked Sendable {
            let actuator: UnsafeMutableRawPointer
            let identity: HapticCounterDevice
        }

        private let queue = DispatchQueue(label: "cc.jasonstu.trackpadwizard.haptic-buzz", qos: .userInteractive)
        private var timer: DispatchSourceTimer?
        private var targets: [Target] = []
        private var actuate: ActuateFunction?
        private var waveformID: Int32 = 0
        private var amplitude: Float = 0
        private var observer: (@Sendable (HapticCounterDevice) -> Void)?

        func start(
            targets: [Target],
            actuate: @escaping ActuateFunction,
            waveformID: Int32,
            amplitude: Float,
            frequency: Double,
            observer: (@Sendable (HapticCounterDevice) -> Void)?
        ) {
            queue.sync {
                timer?.cancel()
                timer = nil
                self.targets = targets
                self.actuate = actuate
                self.waveformID = waveformID
                self.amplitude = amplitude
                self.observer = observer
                guard amplitude > 0 else { return }

                let timer = DispatchSource.makeTimerSource(queue: queue)
                let interval = DispatchTimeInterval.nanoseconds(Int(1_000_000_000 / frequency))
                timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))
                timer.setEventHandler { [weak self] in
                    guard let self, let actuate = self.actuate else { return }
                    guard self.amplitude > 0 else { return }
                    for target in self.targets {
                        if actuate(target.actuator, self.waveformID, 0, self.amplitude, 1) == 0 {
                            self.observer?(target.identity)
                        }
                    }
                }
                self.timer = timer
                timer.resume()
            }
        }

        func stop() {
            queue.sync {
                timer?.cancel()
                timer = nil
                targets.removeAll()
                actuate = nil
                amplitude = 0
            }
        }

        func setObserver(_ observer: (@Sendable (HapticCounterDevice) -> Void)?) {
            queue.sync {
                self.observer = observer
            }
        }
    }
}
