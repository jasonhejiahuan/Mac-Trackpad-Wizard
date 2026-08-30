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
    var heatmapUpdatedAt = ProcessInfo.processInfo.systemUptime
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

    private(set) var enhancedModeEnabled = false
    private(set) var systemGesturesSuppressed = false
    var touchTarget: HapticDeviceTarget {
        didSet {
            if persistenceReady {
                advancedFeatures.restoreDefaultsForTargetChange()
            }
            hapticEngine.target = touchTarget
            persistIfReady()
            restartEnhancedTouchIfNeeded()
        }
    }
    var suppressSystemGesturesInEnhancedMode: Bool {
        didSet {
            persistIfReady()
            configureGestureSuppression()
        }
    }
    var turnOffEnhancedModeWhenInactive: Bool {
        didSet { persistIfReady() }
    }
    var touchSurfaceSizeMode: TouchSurfaceSizeMode {
        didSet { persistIfReady() }
    }
    var trailLifetime: Double {
        didSet { persistIfReady() }
    }
    var heatmapHalfLife: Double {
        didSet { persistIfReady() }
    }
    var visualizationRefreshRate: Double {
        didSet { persistIfReady() }
    }
    private var rawSurfaceWidthMM = 160.0
    private var rawSurfaceHeightMM = 103.0

    var surfaceWidthMM: Double {
        advancedFeatures.previewRotationDegrees == 0
            ? rawSurfaceWidthMM
            : rawSurfaceHeightMM
    }

    var surfaceHeightMM: Double {
        advancedFeatures.previewRotationDegrees == 0
            ? rawSurfaceHeightMM
            : rawSurfaceWidthMM
    }

    var enhancedTouchEnabled: Bool {
        enhancedModeEnabled && privateTouchMonitor.isStreaming
    }
    var showInterfaceHints: Bool {
        didSet { persistIfReady() }
    }
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
    var savedHapticPatterns: [HapticPatternDocument] {
        didSet { persistIfReady() }
    }
    var selectedSavedHapticPatternID: UUID? {
        didSet { persistIfReady() }
    }
    var isRecordingHapticPattern = false
    var hapticRecordingEvents: [HapticPatternEvent] = []
    var hapticRecordingName = "Recorded Pattern"
    var hapticTempo = 120.0
    var continuousFeedback = HapticFeedbackKind.weakClick
    var continuousAmplitude = 0.35
    var continuousFrequency = 80.0

    var statusMessage: String?

    @ObservationIgnored let hapticEngine = HapticEngine()
    @ObservationIgnored let privateTouchMonitor = PrivateTouchMonitor()
    @ObservationIgnored let statisticsStore: HapticStatisticsStore
    let advancedFeatures: AdvancedFeaturesStore
    @ObservationIgnored private let deviceService = TrackpadDeviceService()
    @ObservationIgnored private let systemGestureSuppressor = SystemGestureSuppressor()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var nativeGestureInterpreter = NativeGestureInterpreter()
    @ObservationIgnored private var threeFingerInterpreter = ThreeFingerGestureInterpreter()
    @ObservationIgnored private var recentFrameTimes: [TimeInterval] = []
    @ObservationIgnored private var lastTriggerDates: [GestureTrigger: Date] = [:]
    @ObservationIgnored private var hapticRecordingStartedAt: TimeInterval?
    @ObservationIgnored private var persistenceReady = false

    private enum DefaultsKey {
        static let mappings = "gestureMappings"
        static let mappingsEnabled = "mappingsEnabled"
        static let customHaptic = "customHapticPattern"
        static let savedHaptics = "savedHapticPatterns"
        static let selectedSavedHaptic = "selectedSavedHapticPattern"
        static let showInterfaceHints = "showInterfaceHints"
        static let showResting = "showRestingTouches"
        static let enhancedTarget = "enhancedDeviceTarget"
        static let suppressSystemGestures = "suppressSystemGesturesInEnhancedMode"
        static let turnOffEnhancedWhenInactive = "turnOffEnhancedModeWhenInactive"
        static let surfaceSizeMode = "touchSurfaceSizeMode"
        static let trailLifetime = "touchTrailLifetime"
        static let heatmapHalfLife = "heatmapHalfLife"
        static let visualizationRefreshRate = "visualizationRefreshRate"
    }

    init(
        defaults: UserDefaults = .standard,
        advancedFeatures: AdvancedFeaturesStore? = nil
    ) {
        self.defaults = defaults
        self.advancedFeatures = advancedFeatures ?? AdvancedFeaturesStore(defaults: defaults)
        statisticsStore = HapticStatisticsStore(defaults: defaults)
        mappingsEnabled = defaults.bool(forKey: DefaultsKey.mappingsEnabled)
        showInterfaceHints = defaults.object(forKey: DefaultsKey.showInterfaceHints) as? Bool ?? true
        showRestingTouches = defaults.object(forKey: DefaultsKey.showResting) as? Bool ?? true
        touchTarget = defaults.string(forKey: DefaultsKey.enhancedTarget)
            .flatMap(HapticDeviceTarget.init(rawValue:)) ?? .all
        suppressSystemGesturesInEnhancedMode = defaults.object(
            forKey: DefaultsKey.suppressSystemGestures
        ) as? Bool ?? false
        turnOffEnhancedModeWhenInactive = defaults.object(
            forKey: DefaultsKey.turnOffEnhancedWhenInactive
        ) as? Bool ?? true
        touchSurfaceSizeMode = defaults.string(forKey: DefaultsKey.surfaceSizeMode)
            .flatMap(TouchSurfaceSizeMode.init(rawValue:)) ?? .fit
        trailLifetime = defaults.object(forKey: DefaultsKey.trailLifetime) as? Double ?? 2.5
        heatmapHalfLife = defaults.object(forKey: DefaultsKey.heatmapHalfLife) as? Double ?? 3.0
        visualizationRefreshRate = defaults.object(
            forKey: DefaultsKey.visualizationRefreshRate
        ) as? Double ?? 30
        mappings = Self.decode([GestureMapping].self, from: defaults.data(forKey: DefaultsKey.mappings))
            ?? GestureMapping.defaults
        customHapticPattern = Self.decode(
            HapticPattern.self,
            from: defaults.data(forKey: DefaultsKey.customHaptic)
        ) ?? .customDefault
        savedHapticPatterns = Self.decode(
            [HapticPatternDocument].self,
            from: defaults.data(forKey: DefaultsKey.savedHaptics)
        ) ?? []
        selectedSavedHapticPatternID = defaults.string(forKey: DefaultsKey.selectedSavedHaptic)
            .flatMap(UUID.init(uuidString:))
        persistenceReady = true
        hapticEngine.target = touchTarget
        hapticEngine.setActuationObserver(statisticsStore.actuationObserver)
        refreshDevices()
        refreshPermissions()
        statusMessage = self.advancedFeatures.lastMessage
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

    var selectedSavedHapticPattern: HapticPatternDocument? {
        guard let selectedSavedHapticPatternID else { return savedHapticPatterns.first }
        return savedHapticPatterns.first { $0.id == selectedSavedHapticPatternID }
            ?? savedHapticPatterns.first
    }

    var canSaveSelectedComposerPattern: Bool {
        selectedHapticPattern.steps.contains { $0.isEnabled }
    }

    var surfaceSizeMM: CGSize {
        CGSize(width: surfaceWidthMM, height: surfaceHeightMM)
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
        if enhancedModeEnabled && suppressSystemGesturesInEnhancedMode {
            configureGestureSuppression()
        }
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
    func setEnhancedModeEnabled(_ enabled: Bool) -> Bool {
        if !enabled {
            disableEnhancedMode(message: "Enhanced Mode is off.")
            return true
        }

        guard !enhancedModeEnabled else { return true }
        hapticEngine.target = touchTarget
        let touchEnabled = privateTouchMonitor.start(target: touchTarget) { [weak self] frame in
            self?.handleTouchFrame(frame)
        }
        guard touchEnabled else {
            statusMessage = privateTouchMonitor.lastError ?? "Enhanced touch data is unavailable."
            return false
        }
        updateSurfaceDimensionsFromEnhancedMonitor()

        guard hapticEngine.enableEnhancedHaptics() else {
            privateTouchMonitor.stop()
            statusMessage = hapticEngine.lastMessage ?? "The Enhanced Mode actuator is unavailable."
            return false
        }

        enhancedModeEnabled = true
        configureGestureSuppression()
        if !systemGesturesSuppressed || !suppressSystemGesturesInEnhancedMode {
            statusMessage = "Enhanced Mode is active on \(privateTouchMonitor.activeDeviceTitle)."
        }
        return true
    }

    @discardableResult
    func enableEnhancedTouch() -> Bool {
        setEnhancedModeEnabled(true)
    }

    func disableEnhancedTouch() {
        disableEnhancedMode(message: "Touch Lab is using the public AppKit event surface.")
    }

    func disableEnhancedMode(message: String? = nil) {
        systemGestureSuppressor.stop()
        systemGestureSuppressor.updateEnhancedTouchCount(0)
        systemGesturesSuppressed = false
        privateTouchMonitor.stop()
        hapticEngine.disableEnhancedHaptics()
        enhancedModeEnabled = false
        currentContacts = []
        if let message {
            statusMessage = message
        }
    }

    func restartEnhancedTouchIfNeeded() {
        hapticEngine.target = touchTarget
        guard enhancedModeEnabled else { return }
        privateTouchMonitor.stop()
        let restarted = privateTouchMonitor.start(target: touchTarget) { [weak self] frame in
            self?.handleTouchFrame(frame)
        }
        if restarted {
            updateSurfaceDimensionsFromEnhancedMonitor()
            hapticEngine.refreshDevices()
            statusMessage = "Enhanced Mode now targets \(touchTarget.title)."
        } else {
            disableEnhancedMode(
                message: privateTouchMonitor.lastError ?? "The selected trackpad is unavailable."
            )
        }
    }

    func handleAppDidResignActive() {
        guard turnOffEnhancedModeWhenInactive, enhancedModeEnabled else { return }
        disableEnhancedMode(message: "Enhanced Mode turned off while the app was inactive.")
    }

    func setStatisticsCollectionEnabled(_ enabled: Bool) {
        if enabled {
            statisticsStore.setCollectionEnabled(true)
            hapticEngine.setActuationObserver(statisticsStore.actuationObserver)
        } else {
            hapticEngine.setActuationObserver(nil)
            statisticsStore.setCollectionEnabled(false)
        }
        statusMessage = enabled
            ? "Haptic statistics collection is on."
            : "Haptic statistics collection is fully stopped."
    }

    func setSurfaceOrientationFeatureEnabled(_ enabled: Bool) {
        _ = advancedFeatures.setSurfaceOrientationFeatureEnabled(enabled, target: touchTarget)
        statusMessage = advancedFeatures.lastMessage
    }

    func setSystemHapticsFeatureEnabled(_ enabled: Bool) {
        _ = advancedFeatures.setSystemHapticsFeatureEnabled(enabled, target: touchTarget)
        statusMessage = advancedFeatures.lastMessage
    }

    func requestSurfaceOrientation(_ orientation: ExperimentalSurfaceOrientation) {
        _ = advancedFeatures.requestSurfaceOrientation(orientation, target: touchTarget)
        statusMessage = advancedFeatures.lastMessage
    }

    func requestSystemHapticFeedback(enabled: Bool) {
        _ = advancedFeatures.requestSystemHapticFeedback(enabled: enabled, target: touchTarget)
        statusMessage = advancedFeatures.lastMessage
    }

    func restoreSurfaceOrientationDefault() {
        advancedFeatures.restoreSurfaceOrientationDefault(target: touchTarget)
        statusMessage = advancedFeatures.lastMessage
    }

    func restoreSystemHapticsDefault() {
        advancedFeatures.restoreSystemHapticsDefault(target: touchTarget)
        statusMessage = advancedFeatures.lastMessage
    }

    func handleTouchFrame(_ incomingFrame: TouchFrame) {
        let frame = transformedFrame(incomingFrame)
        guard !(enhancedTouchEnabled && frame.source == .appKit) else { return }
        latestTouchSource = frame.source
        currentContacts = frame.contacts.filter(\.phase.isActive)
        systemGestureSuppressor.updateEnhancedTouchCount(currentContacts.count)
        maximumContactCount = max(maximumContactCount, currentContacts.count)

        if let dimensions = frame.contacts.first,
           dimensions.deviceWidth > 20,
           dimensions.deviceHeight > 20 {
            rawSurfaceWidthMM = advancedFeatures.previewRotationDegrees == 0
                ? dimensions.deviceWidth
                : dimensions.deviceHeight
            rawSurfaceHeightMM = advancedFeatures.previewRotationDegrees == 0
                ? dimensions.deviceHeight
                : dimensions.deviceWidth
        }

        let now = ProcessInfo.processInfo.systemUptime
        for contact in currentContacts where !contact.isResting {
            trailPoints.append(
                TouchTrailPoint(
                    contactID: contact.id,
                    x: contact.x,
                    y: contact.y,
                    timestamp: now
                )
            )
        }
        let oldestRetained = now - max(trailLifetime * 2, 1)
        trailPoints.removeAll { $0.timestamp < oldestRetained }
        if trailPoints.count > 2_000 {
            trailPoints.removeFirst(trailPoints.count - 2_000)
        }

        updateHeatmap(with: currentContacts, at: now)
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

    func handleGesture(_ incomingSample: NativeGestureSample) {
        let sample = transformedGesture(incomingSample)
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
        heatmapUpdatedAt = ProcessInfo.processInfo.systemUptime
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

    func saveSelectedComposerPattern() {
        let document = HapticPatternDocument.from(
            selectedHapticPattern,
            beatsPerMinute: hapticTempo,
            name: selectedHapticPattern.name
        )
        do {
            let validated = try document.validated()
            savedHapticPatterns.append(validated)
            selectedSavedHapticPatternID = validated.id
            statusMessage = "Saved \(validated.name) to the pattern library."
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func startHapticPatternRecording() {
        hapticRecordingEvents = []
        hapticRecordingStartedAt = ProcessInfo.processInfo.systemUptime
        isRecordingHapticPattern = true
        statusMessage = "Click the recording surface to capture timing and pressure."
    }

    func recordHapticClick(timestamp: TimeInterval, pressure: Double?) {
        guard isRecordingHapticPattern, let hapticRecordingStartedAt else { return }
        let time = max(0, timestamp - hapticRecordingStartedAt)
        if let previous = hapticRecordingEvents.last,
           time - previous.timeSeconds < 0.02 {
            return
        }
        let reportedPressure = pressure.flatMap { $0 > 0 ? $0 : nil }
        let amplitude = HapticStep.clampedAmplitude(reportedPressure ?? continuousAmplitude)
        let frequency = min(max(continuousFrequency, 8), 120)
        hapticRecordingEvents.append(
            HapticPatternEvent(
                timeSeconds: time,
                amplitude: amplitude,
                frequencyHz: frequency,
                durationSeconds: 1 / frequency,
                feedback: continuousFeedback
            )
        )
    }

    func stopHapticPatternRecording(save: Bool = true) {
        guard isRecordingHapticPattern else { return }
        isRecordingHapticPattern = false
        hapticRecordingStartedAt = nil
        guard save, !hapticRecordingEvents.isEmpty else {
            statusMessage = hapticRecordingEvents.isEmpty
                ? "No clicks were recorded."
                : "Pattern recording cancelled."
            return
        }

        let document = HapticPatternDocument(
            name: hapticRecordingName,
            events: hapticRecordingEvents
        )
        do {
            let validated = try document.validated()
            savedHapticPatterns.append(validated)
            selectedSavedHapticPatternID = validated.id
            statusMessage = "Saved \(validated.pulseCount) recorded oscillations."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func playSelectedSavedHapticPattern() {
        guard let pattern = selectedSavedHapticPattern else {
            statusMessage = "Choose or record a saved pattern first."
            return
        }
        hapticEngine.play(pattern)
    }

    func importHapticPattern() {
        do {
            guard let imported = try HapticPatternFileService.importPattern() else { return }
            let copy = HapticPatternDocument(
                id: UUID(),
                name: imported.name,
                createdAt: imported.createdAt,
                modifiedAt: .now,
                events: imported.events
            )
            savedHapticPatterns.append(copy)
            selectedSavedHapticPatternID = copy.id
            statusMessage = "Imported \(copy.name)."
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    func exportSelectedHapticPattern() {
        guard let pattern = selectedSavedHapticPattern else {
            statusMessage = "Choose a saved pattern to export."
            return
        }
        do {
            if let url = try HapticPatternFileService.exportPattern(pattern) {
                statusMessage = "Exported \(url.lastPathComponent)."
            }
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func deleteSelectedHapticPattern() {
        guard let id = selectedSavedHapticPattern?.id else { return }
        savedHapticPatterns.removeAll { $0.id == id }
        selectedSavedHapticPatternID = savedHapticPatterns.first?.id
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
        disableEnhancedMode()
        hapticEngine.setActuationObserver(nil)
        hapticEngine.shutDown()
        statisticsStore.shutDown()
        advancedFeatures.shutDown()
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

    private func configureGestureSuppression() {
        guard enhancedModeEnabled, suppressSystemGesturesInEnhancedMode else {
            systemGestureSuppressor.stop()
            systemGesturesSuppressed = false
            return
        }

        systemGesturesSuppressed = systemGestureSuppressor.start()
        if systemGesturesSuppressed {
            statusMessage = "Enhanced Mode is active and system gestures are temporarily suppressed."
        } else {
            refreshPermissionsWithoutReconfiguration()
            statusMessage = systemGestureSuppressor.lastError
        }
    }

    private func updateSurfaceDimensionsFromEnhancedMonitor() {
        if let width = privateTouchMonitor.activeSurfaceWidthMM,
           let height = privateTouchMonitor.activeSurfaceHeightMM,
           width > 20,
           height > 20 {
            rawSurfaceWidthMM = width
            rawSurfaceHeightMM = height
        }
    }

    private func transformedFrame(_ frame: TouchFrame) -> TouchFrame {
        let orientation = advancedFeatures.selectedSurfaceOrientation
        guard orientation.previewRotationDegrees != 0 else { return frame }
        let contacts = frame.contacts.map { contact in
            let point = orientation.transformPoint(x: contact.x, y: contact.y)
            let velocity = orientation.transformVector(
                x: contact.velocityX ?? 0,
                y: contact.velocityY ?? 0
            )
            let angle = contact.angle.map {
                ($0 + (Double(orientation.previewRotationDegrees) * .pi / 180))
                    .truncatingRemainder(dividingBy: 2 * .pi)
            }
            return TouchContact(
                id: contact.id,
                x: point.x,
                y: point.y,
                phase: contact.phase,
                isResting: contact.isResting,
                deviceWidth: contact.deviceHeight,
                deviceHeight: contact.deviceWidth,
                source: contact.source,
                pressureProxy: contact.pressureProxy,
                totalPressure: contact.totalPressure,
                velocityX: contact.velocityX == nil ? nil : velocity.x,
                velocityY: contact.velocityY == nil ? nil : velocity.y,
                majorAxis: contact.majorAxis,
                minorAxis: contact.minorAxis,
                angle: angle,
                density: contact.density
            )
        }
        return TouchFrame(timestamp: frame.timestamp, contacts: contacts, source: frame.source)
    }

    private func transformedGesture(_ sample: NativeGestureSample) -> NativeGestureSample {
        let orientation = advancedFeatures.selectedSurfaceOrientation
        guard orientation.previewRotationDegrees != 0,
              sample.kind == .swipe || sample.kind == .scroll else { return sample }
        let vector = orientation.transformVector(x: sample.primaryValue, y: sample.secondaryValue)
        return NativeGestureSample(
            id: sample.id,
            kind: sample.kind,
            timestamp: sample.timestamp,
            primaryValue: vector.x,
            secondaryValue: vector.y,
            stage: sample.stage,
            precise: sample.precise
        )
    }

    private func refreshPermissionsWithoutReconfiguration() {
        accessibilityGranted = ShortcutService.isAccessibilityGranted
    }

    private func updateHeatmap(with contacts: [TouchContact], at timestamp: TimeInterval) {
        let elapsed = max(0, timestamp - heatmapUpdatedAt)
        let decay = pow(0.5, elapsed / max(heatmapHalfLife, 0.1))
        for index in heatmap.indices {
            heatmap[index] *= decay
        }
        heatmapUpdatedAt = timestamp
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
        defaults.set(mappingsEnabled, forKey: DefaultsKey.mappingsEnabled)
        defaults.set(showInterfaceHints, forKey: DefaultsKey.showInterfaceHints)
        defaults.set(showRestingTouches, forKey: DefaultsKey.showResting)
        defaults.set(touchTarget.rawValue, forKey: DefaultsKey.enhancedTarget)
        defaults.set(
            suppressSystemGesturesInEnhancedMode,
            forKey: DefaultsKey.suppressSystemGestures
        )
        defaults.set(
            turnOffEnhancedModeWhenInactive,
            forKey: DefaultsKey.turnOffEnhancedWhenInactive
        )
        defaults.set(touchSurfaceSizeMode.rawValue, forKey: DefaultsKey.surfaceSizeMode)
        defaults.set(trailLifetime, forKey: DefaultsKey.trailLifetime)
        defaults.set(heatmapHalfLife, forKey: DefaultsKey.heatmapHalfLife)
        defaults.set(visualizationRefreshRate, forKey: DefaultsKey.visualizationRefreshRate)
        defaults.set(Self.encode(mappings), forKey: DefaultsKey.mappings)
        defaults.set(Self.encode(customHapticPattern), forKey: DefaultsKey.customHaptic)
        defaults.set(Self.encode(savedHapticPatterns), forKey: DefaultsKey.savedHaptics)
        defaults.set(
            selectedSavedHapticPatternID?.uuidString,
            forKey: DefaultsKey.selectedSavedHaptic
        )
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
