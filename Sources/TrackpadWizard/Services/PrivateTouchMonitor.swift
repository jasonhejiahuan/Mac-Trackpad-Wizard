import AppKit
import Darwin
import Observation

private struct PrivateMTPoint: Sendable {
    var x: Float
    var y: Float
}

private struct PrivateMTVector: Sendable {
    var position: PrivateMTPoint
    var velocity: PrivateMTPoint
}

/// Common 96-byte layout used by MultitouchSupport contact callbacks.
private struct PrivateMTTouch: Sendable {
    var frame: Int32
    var timestamp: Double
    var pathIndex: Int32
    var state: UInt32
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: PrivateMTVector
    var size: Float
    var pressureBits: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: PrivateMTVector
    var field14: Int32
    var field15: Int32
    var density: Float

    var cumulativePressure: Float {
        Float(bitPattern: UInt32(bitPattern: pressureBits))
    }
}

private struct PrivateTouchSnapshot: Sendable {
    let sequence: UInt64
    let deviceAddress: UInt
    let timestamp: Double
    let touches: [PrivateMTTouch]
}

private final class PrivateTouchFrameBuffer: @unchecked Sendable {
    static let shared = PrivateTouchFrameBuffer()

    private let lock = NSLock()
    private var sequence: UInt64 = 0
    private var snapshots: [UInt: PrivateTouchSnapshot] = [:]

    func update(
        device: UnsafeMutableRawPointer?,
        touches: UnsafeMutableRawPointer?,
        count: Int32,
        timestamp: Double
    ) {
        guard count >= 0, count <= 32 else { return }
        let address = device.map { UInt(bitPattern: $0) } ?? 0
        var copied: [PrivateMTTouch] = []
        if let touches, count > 0 {
            let typed = touches.assumingMemoryBound(to: PrivateMTTouch.self)
            copied.reserveCapacity(Int(count))
            for index in 0..<Int(count) {
                copied.append(typed[index])
            }
        }
        lock.lock()
        sequence &+= 1
        snapshots[address] = PrivateTouchSnapshot(
            sequence: sequence,
            deviceAddress: address,
            timestamp: timestamp,
            touches: copied
        )
        lock.unlock()
    }

    func latest(for address: UInt) -> PrivateTouchSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return snapshots[address]
    }
}

private typealias PrivateContactCallback = @convention(c) (
    UnsafeMutableRawPointer?,
    UnsafeMutableRawPointer?,
    Int32,
    Double,
    Int32
) -> Int32

private let privateContactCallback: PrivateContactCallback = { device, touches, count, timestamp, _ in
    PrivateTouchFrameBuffer.shared.update(
        device: device,
        touches: touches,
        count: count,
        timestamp: timestamp
    )
    return 0
}

@MainActor
@Observable
final class PrivateTouchMonitor {
    private typealias DeviceListFunction = @convention(c) () -> Unmanaged<CFArray>?
    private typealias DeviceBooleanFunction = @convention(c) (UnsafeMutableRawPointer) -> Bool
    private typealias DeviceIDFunction = @convention(c) (
        UnsafeMutableRawPointer,
        UnsafeMutablePointer<UInt64>
    ) -> Int32
    private typealias DimensionsFunction = @convention(c) (
        UnsafeMutableRawPointer,
        UnsafeMutablePointer<Int32>,
        UnsafeMutablePointer<Int32>
    ) -> Int32
    private typealias RegisterFunction = @convention(c) (
        UnsafeMutableRawPointer,
        PrivateContactCallback
    ) -> Void
    private typealias StartFunction = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    private typealias StopFunction = @convention(c) (UnsafeMutableRawPointer) -> Void
    private typealias IsRunningFunction = @convention(c) (UnsafeMutableRawPointer) -> Bool

    private struct Device {
        let object: AnyObject
        let pointer: UnsafeMutableRawPointer
        let identifier: UInt64
        let isBuiltIn: Bool
        let widthMM: Double
        let heightMM: Double
    }

    var isAvailable = false
    var isStreaming = false
    var activeDeviceTitle = "No enhanced device"
    var activeSurfaceWidthMM: Double?
    var activeSurfaceHeightMM: Double?
    var lastError: String?

    @ObservationIgnored private var libraryHandle: UnsafeMutableRawPointer?
    @ObservationIgnored private var listDevices: DeviceListFunction?
    @ObservationIgnored private var deviceIsBuiltIn: DeviceBooleanFunction?
    @ObservationIgnored private var getDeviceID: DeviceIDFunction?
    @ObservationIgnored private var getDimensions: DimensionsFunction?
    @ObservationIgnored private var registerCallback: RegisterFunction?
    @ObservationIgnored private var unregisterCallback: RegisterFunction?
    @ObservationIgnored private var startDevice: StartFunction?
    @ObservationIgnored private var stopDevice: StopFunction?
    @ObservationIgnored private var deviceIsRunning: IsRunningFunction?
    @ObservationIgnored private var devices: [Device] = []
    @ObservationIgnored private var activeDevice: Device?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastSequence: UInt64 = 0
    @ObservationIgnored private var retainedDeviceAddresses: Set<UInt> = []
    @ObservationIgnored private var onFrame: ((TouchFrame) -> Void)?

    init() {
        loadRuntime()
    }

    @discardableResult
    func start(
        target: HapticDeviceTarget,
        onFrame: @escaping (TouchFrame) -> Void
    ) -> Bool {
        stop()
        guard isAvailable else {
            lastError = "Enhanced touch symbols are unavailable on this macOS version."
            return false
        }
        scanDevices()
        guard let selected = selectDevice(for: target),
              let registerCallback,
              let startDevice else {
            lastError = "No matching multitouch device is connected."
            return false
        }

        activeDevice = selected
        activeDeviceTitle = selected.isBuiltIn ? "Built-in Trackpad" : "External Trackpad"
        activeSurfaceWidthMM = selected.widthMM
        activeSurfaceHeightMM = selected.heightMM
        self.onFrame = onFrame
        lastSequence = 0
        registerCallback(selected.pointer, privateContactCallback)
        startDevice(selected.pointer, 0)
        isStreaming = true

        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.publishLatestFrame()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        return true
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onFrame = nil

        if let device = activeDevice {
            unregisterCallback?(device.pointer, privateContactCallback)
            if deviceIsRunning?(device.pointer) == true {
                stopDevice?(device.pointer)
            }
        }
        activeDevice = nil
        isStreaming = false
        activeDeviceTitle = "No enhanced device"
        activeSurfaceWidthMM = nil
        activeSurfaceHeightMM = nil
    }

    func availableDeviceTargets() -> [HapticDeviceTarget] {
        scanDevices()
        var targets: [HapticDeviceTarget] = [.all]
        if devices.contains(where: \.isBuiltIn) { targets.append(.builtIn) }
        if devices.contains(where: { !$0.isBuiltIn }) { targets.append(.external) }
        return targets
    }

    private func loadRuntime() {
        guard MemoryLayout<PrivateMTTouch>.size == 96 else {
            lastError = "Unexpected touch structure layout."
            return
        }
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else { return }
        guard let listSymbol = dlsym(handle, "MTDeviceCreateList"),
              let builtInSymbol = dlsym(handle, "MTDeviceIsBuiltIn"),
              let identifierSymbol = dlsym(handle, "MTDeviceGetDeviceID"),
              let dimensionsSymbol = dlsym(handle, "MTDeviceGetSensorSurfaceDimensions"),
              let registerSymbol = dlsym(handle, "MTRegisterContactFrameCallback"),
              let unregisterSymbol = dlsym(handle, "MTUnregisterContactFrameCallback"),
              let startSymbol = dlsym(handle, "MTDeviceStart"),
              let stopSymbol = dlsym(handle, "MTDeviceStop"),
              let runningSymbol = dlsym(handle, "MTDeviceIsRunning") else {
            dlclose(handle)
            return
        }
        libraryHandle = handle
        listDevices = unsafeBitCast(listSymbol, to: DeviceListFunction.self)
        deviceIsBuiltIn = unsafeBitCast(builtInSymbol, to: DeviceBooleanFunction.self)
        getDeviceID = unsafeBitCast(identifierSymbol, to: DeviceIDFunction.self)
        getDimensions = unsafeBitCast(dimensionsSymbol, to: DimensionsFunction.self)
        registerCallback = unsafeBitCast(registerSymbol, to: RegisterFunction.self)
        unregisterCallback = unsafeBitCast(unregisterSymbol, to: RegisterFunction.self)
        startDevice = unsafeBitCast(startSymbol, to: StartFunction.self)
        stopDevice = unsafeBitCast(stopSymbol, to: StopFunction.self)
        deviceIsRunning = unsafeBitCast(runningSymbol, to: IsRunningFunction.self)
        isAvailable = true
    }

    private func scanDevices() {
        guard let listDevices,
              let deviceIsBuiltIn,
              let getDeviceID,
              let getDimensions,
              let array = listDevices()?.takeRetainedValue() else {
            devices = []
            return
        }
        let scanned = array as [AnyObject]

        devices = scanned.compactMap { object in
            let pointer = Unmanaged.passUnretained(object).toOpaque()
            var identifier: UInt64 = 0
            guard getDeviceID(pointer, &identifier) == 0, identifier != 0 else { return nil }
            var width: Int32 = 0
            var height: Int32 = 0
            _ = getDimensions(pointer, &width, &height)
            let address = UInt(bitPattern: pointer)
            if !retainedDeviceAddresses.contains(address) {
                _ = Unmanaged.passUnretained(object).retain()
                retainedDeviceAddresses.insert(address)
            }
            return Device(
                object: object,
                pointer: pointer,
                identifier: identifier,
                isBuiltIn: deviceIsBuiltIn(pointer),
                widthMM: width > 0 ? Double(width) / 100 : 160,
                heightMM: height > 0 ? Double(height) / 100 : 110
            )
        }
    }

    private func selectDevice(for target: HapticDeviceTarget) -> Device? {
        switch target {
        case .builtIn:
            devices.first(where: \.isBuiltIn)
        case .external:
            devices.first(where: { !$0.isBuiltIn })
        case .all:
            devices.first(where: { !$0.isBuiltIn }) ?? devices.first
        }
    }

    private func publishLatestFrame() {
        guard let device = activeDevice else { return }
        let address = UInt(bitPattern: device.pointer)
        guard let snapshot = PrivateTouchFrameBuffer.shared.latest(for: address),
              snapshot.sequence != lastSequence else { return }
        lastSequence = snapshot.sequence

        let contacts = snapshot.touches.map { touch in
            TouchContact(
                id: Int(touch.pathIndex),
                x: Double(touch.normalizedVector.position.x),
                y: Double(touch.normalizedVector.position.y),
                phase: touchPhase(for: touch.state),
                isResting: touch.state == 2 || touch.state == 6,
                deviceWidth: device.widthMM,
                deviceHeight: device.heightMM,
                source: .enhanced,
                pressureProxy: Double(touch.size),
                totalPressure: Double(touch.cumulativePressure),
                velocityX: Double(touch.normalizedVector.velocity.x),
                velocityY: Double(touch.normalizedVector.velocity.y),
                majorAxis: Double(touch.majorAxis),
                minorAxis: Double(touch.minorAxis),
                angle: Double(touch.angle),
                density: Double(touch.density)
            )
        }
        onFrame?(
            TouchFrame(timestamp: snapshot.timestamp, contacts: contacts, source: .enhanced)
        )
    }

    private func touchPhase(for state: UInt32) -> TouchContactPhase {
        switch state {
        case 1, 3: .began
        case 2, 6: .stationary
        case 4: .moved
        case 5, 7: .ended
        default: .cancelled
        }
    }
}
