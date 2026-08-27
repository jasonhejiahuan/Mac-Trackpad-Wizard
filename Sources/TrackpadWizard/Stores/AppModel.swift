import Foundation
import Observation

enum TouchVisualizationMode: String, CaseIterable, Identifiable, Sendable {
    case contacts
    case trails
    case heatmap

    var id: Self { self }

    var title: String {
        switch self {
        case .contacts: "Contacts"
        case .trails: "Trails"
        case .heatmap: "Heatmap"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    var selection: AppSection = .overview
    var visualizationMode: TouchVisualizationMode = .contacts

    var devices: [TrackpadDevice] = []
    var trackpadSettings: [TrackpadSetting] = []
    var lastDeviceRefresh: Date?

    var currentContacts: [TouchContact] = []
    var trailPoints: [TouchTrailPoint] = []
    var heatmap = Array(repeating: 0.0, count: 24 * 16)
    var touchEventLog: [TouchEventLogEntry] = []
    var nativeGestureSamples: [NativeGestureSample] = []
    var recognizedGestures: [RecognizedGestureEvent] = []
    var latestTouchSource: TouchDataSource = .appKit
    var maximumContactCount = 0
    var estimatedSampleRate = 0.0
    var pressureProxy = 0.0
    var pressureStage = 0
    var liveMagnification = 0.0
    var liveRotation = 0.0
    var liveScrollX = 0.0
    var liveScrollY = 0.0

    var isRecording = false
    var sessionStartedAt: Date?
    var recordedFrames: [TouchFrame] = []
    var recordedGestures: [NativeGestureSample] = []

    var enhancedTouchEnabled = false
    var touchTarget: HapticDeviceTarget = .external
    var showRestingTouches: Bool {
        didSet { persistIfReady() }
    }

    var mappingsEnabled: Bool {
        didSet { persistIfReady() }
    }
    var mappings: [GestureMapping] {
        didSet { persistIfReady() }
    }
    var accessibilityGranted = false

    var selectedHapticPatternID = "heartbeat"
    var customHapticPattern: HapticPattern {
        didSet { persistIfReady() }
    }
    var hapticTempo = 120.0
    var continuousFeedback = HapticFeedbackKind.buzz
    var continuousFrequency = 80.0

    var statusMessage: String?

    @ObservationIgnored let hapticEngine = HapticEngine()
    @ObservationIgnored let privateTouchMonitor = PrivateTouchMonitor()
    @ObservationIgnored private let deviceService = TrackpadDeviceService()
    @ObservationIgnored private var nativeGestureInterpreter = NativeGestureInterpreter()
    @ObservationIgnored private var threeFingerInterpreter = ThreeFingerGestureInterpreter()
    @ObservationIgnored private var recentFrameTimes: [TimeInterval] = []
    @ObservationIgnored private var lastTriggerDates: [GestureTrigger: Date] = [:]
    @ObservationIgnored private var trailSequence = 0
    @ObservationIgnored private var persistenceReady = false

    private enum DefaultsKey {
        static let mappings = "gestureMappings"
        static let mappingsEnabled = "mappingsEnabled"
        static let customHaptic = "customHapticPattern"
        static let showResting = "showRestingTouches"
    }

    init() {
        let defaults = UserDefaults.standard
        mappingsEnabled = defaults.bool(forKey: DefaultsKey.mappingsEnabled)
        showRestingTouches = defaults.object(forKey: DefaultsKey.showResting) as? Bool ?? true
        mappings = Self.decode([GestureMapping].self, from: defaults.data(forKey: DefaultsKey.mappings))
            ?? GestureMapping.defaults
        customHapticPattern = Self.decode(
            HapticPattern.self,
            from: defaults.data(forKey: DefaultsKey.customHaptic)
        ) ?? .customDefault
        persistenceReady = true
        refreshDevices()
        refreshPermissions()
    }

    var visibleContacts: [TouchContact] {
        showRestingTouches ? currentContacts : currentContacts.filter { !$0.isResting }
    }

    var connectedTrackpadCount: Int { devices.count }
    var externalTrackpadCount: Int { devices.filter { !$0.isBuiltIn }.count }
    var activeContactCount: Int { visibleContacts.filter(\.phase.isActive).count }
    var hasForceTouchDevice: Bool { devices.contains { $0.forceSupported == true } }

    var selectedHapticPattern: HapticPattern {
        if selectedHapticPatternID == customHapticPattern.id { return customHapticPattern }
        return HapticPattern.presets.first { $0.id == selectedHapticPatternID }
            ?? HapticPattern.presets[0]
    }

    func refreshDevices() {
        let result = deviceService.scan()
        devices = result.devices
        trackpadSettings = result.settings
        lastDeviceRefresh = .now
        hapticEngine.refreshDevices()
    }

    func refreshPermissions() {
        accessibilityGranted = ShortcutService.isAccessibilityGranted
    }

    func requestAccessibility() {
        _ = ShortcutService.requestAccessibility()
        refreshPermissions()
        if !accessibilityGranted {
            statusMessage = "Approve Trackpad Wizard in System Settings, then return and refresh."
        }
    }

    func openAccessibilitySettings() {
        ShortcutService.openAccessibilitySettings()
    }

    @discardableResult
    func enableEnhancedTouch() -> Bool {
        let enabled = privateTouchMonitor.start(target: touchTarget) { [weak self] frame in
            self?.handleTouchFrame(frame)
        }
        enhancedTouchEnabled = enabled
        if enabled {
            statusMessage = "Enhanced raw touch data is active on \(privateTouchMonitor.activeDeviceTitle)."
        } else {
            statusMessage = privateTouchMonitor.lastError ?? "Enhanced touch data is unavailable."
        }
        return enabled
    }

    func disableEnhancedTouch() {
        privateTouchMonitor.stop()
        enhancedTouchEnabled = false
        currentContacts = []
        statusMessage = "Touch Lab is using the public AppKit event surface."
    }

    func restartEnhancedTouchIfNeeded() {
        guard enhancedTouchEnabled else { return }
        _ = enableEnhancedTouch()
    }

    func handleTouchFrame(_ frame: TouchFrame) {
        guard !(enhancedTouchEnabled && frame.source == .appKit) else { return }
        latestTouchSource = frame.source
        currentContacts = frame.contacts.filter(\.phase.isActive)
        maximumContactCount = max(maximumContactCount, currentContacts.count)

        trailSequence += 1
        for contact in currentContacts where !contact.isResting {
            trailPoints.append(
                TouchTrailPoint(
                    contactID: contact.id,
                    x: contact.x,
                    y: contact.y,
                    ageIndex: trailSequence
                )
            )
        }
        if trailPoints.count > 900 {
            trailPoints.removeFirst(trailPoints.count - 900)
        }

        updateHeatmap(with: currentContacts)
        if frame.source == .enhanced {
            pressureProxy = currentContacts.compactMap(\.pressureProxy).max() ?? 0
        } else if currentContacts.isEmpty {
            pressureProxy = 0
            pressureStage = 0
        }

        touchEventLog.insert(
            TouchEventLogEntry(timestamp: frame.timestamp, contacts: frame.contacts),
            at: 0
        )
        if touchEventLog.count > 120 { touchEventLog.removeLast(touchEventLog.count - 120) }

        recentFrameTimes.append(frame.timestamp)
        if recentFrameTimes.count > 120 { recentFrameTimes.removeFirst(recentFrameTimes.count - 120) }
        if let first = recentFrameTimes.first,
           let last = recentFrameTimes.last,
           last > first,
           recentFrameTimes.count > 1 {
            estimatedSampleRate = Double(recentFrameTimes.count - 1) / (last - first)
        }

        if isRecording, recordedFrames.count < 20_000 {
            recordedFrames.append(frame)
        }

        if let trigger = threeFingerInterpreter.process(frame) {
            recognize(trigger, source: frame.source)
        }
    }

    func handleGesture(_ sample: NativeGestureSample) {
        nativeGestureSamples.insert(sample, at: 0)
        if nativeGestureSamples.count > 100 {
            nativeGestureSamples.removeLast(nativeGestureSamples.count - 100)
        }
        if isRecording, recordedGestures.count < 10_000 {
            recordedGestures.append(sample)
        }

        switch sample.kind {
        case .gestureBegan:
            liveMagnification = 0
            liveRotation = 0
            liveScrollX = 0
            liveScrollY = 0
        case .magnify:
            liveMagnification += sample.primaryValue
        case .rotate:
            liveRotation += sample.primaryValue
        case .scroll:
            liveScrollX = sample.primaryValue
            liveScrollY = sample.secondaryValue
        case .pressure:
            pressureProxy = sample.primaryValue
            pressureStage = sample.stage
        case .gestureEnded, .swipe:
            break
        }

        if let trigger = nativeGestureInterpreter.process(sample) {
            recognize(trigger, source: .appKit)
        }
    }

    func startRecording() {
        recordedFrames = []
        recordedGestures = []
        maximumContactCount = 0
        sessionStartedAt = .now
        isRecording = true
        statusMessage = "Recording raw touch and gesture samples locally."
    }

    func stopRecording() {
        isRecording = false
        statusMessage = "Recording stopped with \(recordedFrames.count) touch frames."
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func clearSession() {
        currentContacts = []
        trailPoints = []
        heatmap = Array(repeating: 0, count: heatmap.count)
        touchEventLog = []
        nativeGestureSamples = []
        recognizedGestures = []
        recordedFrames = []
        recordedGestures = []
        recentFrameTimes = []
        maximumContactCount = 0
        estimatedSampleRate = 0
        pressureProxy = 0
        pressureStage = 0
        sessionStartedAt = nil
        isRecording = false
    }

    func exportSession() {
        let export = TouchSessionExport(
            schemaVersion: 1,
            exportedAt: .now,
            sessionStartedAt: sessionStartedAt,
            frames: recordedFrames,
            gestures: recordedGestures,
            maximumContactCount: maximumContactCount,
            estimatedSampleRate: estimatedSampleRate
        )
        do {
            if let url = try SessionExporter.export(export) {
                statusMessage = "Exported \(recordedFrames.count) frames to \(url.lastPathComponent)."
            }
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func playSelectedHaptic() {
        hapticEngine.play(selectedHapticPattern, beatsPerMinute: hapticTempo)
    }

    func addMapping() {
        mappings.append(
            GestureMapping(
                trigger: .swipeUp,
                shortcut: ShortcutDefinition(keyCode: 126, modifiers: [.control, .command], keyLabel: "↑")
            )
        )
    }

    func removeMapping(id: GestureMapping.ID) {
        mappings.removeAll { $0.id == id }
    }

    func persistMappings() {
        persistIfReady()
    }

    func shutDown() {
        privateTouchMonitor.stop()
        hapticEngine.shutDown()
    }

    private func recognize(_ trigger: GestureTrigger, source: TouchDataSource) {
        let now = Date()
        if let previous = lastTriggerDates[trigger], now.timeIntervalSince(previous) < 0.32 {
            return
        }
        lastTriggerDates[trigger] = now
        recognizedGestures.insert(
            RecognizedGestureEvent(trigger: trigger, date: now, source: source),
            at: 0
        )
        if recognizedGestures.count > 30 {
            recognizedGestures.removeLast(recognizedGestures.count - 30)
        }
        executeMapping(for: trigger)
    }

    private func executeMapping(for trigger: GestureTrigger) {
        guard mappingsEnabled,
              let mapping = mappings.first(where: { $0.isEnabled && $0.trigger == trigger }) else {
            return
        }
        switch mapping.actionKind {
        case .keyboardShortcut:
            if ShortcutService.post(mapping.shortcut) {
                statusMessage = "\(trigger.title) sent \(mapping.shortcut.displayName)."
            } else {
                refreshPermissions()
                statusMessage = "Accessibility permission is needed to send \(mapping.shortcut.displayName)."
            }
        case .hapticPattern:
            let pattern = mapping.hapticPatternID == customHapticPattern.id
                ? customHapticPattern
                : HapticPattern.presets.first { $0.id == mapping.hapticPatternID }
            if let pattern {
                hapticEngine.play(pattern, beatsPerMinute: hapticTempo)
                statusMessage = "\(trigger.title) played \(pattern.name)."
            }
        }
    }

    private func updateHeatmap(with contacts: [TouchContact]) {
        for index in heatmap.indices {
            heatmap[index] *= 0.992
        }
        for contact in contacts where !contact.isResting {
            let centerX = Int(min(max(contact.x, 0), 0.999) * 24)
            let centerY = Int(min(max(contact.y, 0), 0.999) * 16)
            let intensity = min(max(contact.pressureProxy ?? 0.55, 0.18), 1.5)
            for y in max(0, centerY - 2)...min(15, centerY + 2) {
                for x in max(0, centerX - 2)...min(23, centerX + 2) {
                    let distance = hypot(Double(x - centerX), Double(y - centerY))
                    let contribution = intensity * exp(-distance * distance / 2.2)
                    let index = y * 24 + x
                    heatmap[index] = min(1.5, heatmap[index] + contribution)
                }
            }
        }
    }

    private func persistIfReady() {
        guard persistenceReady else { return }
        let defaults = UserDefaults.standard
        defaults.set(mappingsEnabled, forKey: DefaultsKey.mappingsEnabled)
        defaults.set(showRestingTouches, forKey: DefaultsKey.showResting)
        defaults.set(Self.encode(mappings), forKey: DefaultsKey.mappings)
        defaults.set(Self.encode(customHapticPattern), forKey: DefaultsKey.customHaptic)
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
