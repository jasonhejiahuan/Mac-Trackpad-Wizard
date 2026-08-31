import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var showStatisticsResetConfirmation = false

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gearshape") }

            permissionSettings
                .tabItem { Label("Permissions", systemImage: "hand.raised") }

            updateSettings
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }

            experimentalSettings
                .tabItem { Label("Experimental", systemImage: "flask") }

            statisticsSettings
                .tabItem { Label("Statistics", systemImage: "chart.xyaxis.line") }
        }
        .frame(width: 720, height: 560)
        .onAppear { model.refreshPermissions() }
        .alert("Reset All Haptic Statistics?", isPresented: $showStatisticsResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                model.statisticsStore.reset()
            }
        } message: {
            Text("Lifetime and daily vibration counts for every trackpad will be permanently removed.")
        }
    }

    private var generalSettings: some View {
        Form {
            Section("Interface") {
                Toggle("Show interface hints", isOn: $model.showInterfaceHints)
                Toggle("Show explanatory text in Settings", isOn: $model.showSettingsHints)
                LabeledContent("Touch preview size") {
                    Picker("", selection: $model.touchSurfaceSizeMode) {
                        ForEach(TouchSurfaceSizeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
                settingsHint("Physical Size uses the current display’s reported millimeters and scaled point resolution. Some monitors publish inaccurate physical dimensions.")
            }

            Section("Touch Lab") {
                Toggle("Show resting contacts", isOn: $model.showRestingTouches)
                LabeledContent("Default visualization") {
                    Picker("", selection: $model.visualizationMode) {
                        ForEach(TouchVisualizationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                durationSlider(
                    "Trail lifetime",
                    value: $model.trailLifetime,
                    range: 0.25...10,
                    suffix: "s"
                )
                durationSlider(
                    "Heatmap half-life",
                    value: $model.heatmapHalfLife,
                    range: 0.25...15,
                    suffix: "s"
                )
                LabeledContent("Fade refresh") {
                    HStack {
                        Slider(value: $model.visualizationRefreshRate, in: 5...60, step: 5)
                            .frame(width: 190)
                        Text("\(Int(model.visualizationRefreshRate)) Hz")
                            .font(.caption.monospacedDigit())
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }

            Section("Behavior") {
                Toggle(
                    "Turn off Enhanced Mode when Trackpad Wizard becomes inactive",
                    isOn: $model.turnOffEnhancedModeWhenInactive
                )
                Toggle(
                    "Restore Enhanced Mode when Trackpad Wizard becomes active again",
                    isOn: $model.restoreEnhancedModeAfterRefocus
                )
                .disabled(!model.turnOffEnhancedModeWhenInactive)
                settingsHint("Enhanced Mode always turns off when the app quits. Optional refocus restoration applies only when this app paused an active session after losing focus.")
                Toggle("Enable gesture mappings", isOn: $model.mappingsEnabled)
                settingsHint("Mappings remain independent from Enhanced Mode.")
            }

            Section {
                Button("Open About Trackpad Wizard") {
                    openWindow(id: "about")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var permissionSettings: some View {
        Form {
            Section("Accessibility") {
                LabeledContent("Keyboard shortcuts and gesture suppression") {
                    Label(
                        model.accessibilityGranted ? "Allowed" : "Not allowed",
                        systemImage: model.accessibilityGranted ? "checkmark.circle.fill" : "circle"
                    )
                }
                settingsHint("Accessibility is requested only when you choose Request Access. It is used for mapped keyboard shortcuts and the optional process-scoped system-gesture filter; touch inspection and haptics do not require it.")
                HStack {
                    Button("Refresh") { model.refreshPermissions() }
                    Button("Open System Settings") { model.openAccessibilitySettings() }
                    if !model.accessibilityGranted {
                        Button("Request Access…") { model.requestAccessibility() }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var updateSettings: some View {
        Form {
            Section("Release Updates") {
                Toggle(
                    "Check for updates automatically",
                    isOn: $model.automaticallyCheckForUpdates
                )
                Toggle(
                    "Download verified updates automatically",
                    isOn: $model.automaticallyDownloadUpdates
                )
                .disabled(!model.automaticallyCheckForUpdates)

                LabeledContent("Installed") {
                    Text(AppReleaseVersion.current.description)
                        .monospacedDigit()
                }
                LabeledContent("Status") {
                    Text(model.updateService.statusText)
                        .foregroundStyle(updateStatusColor)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Button("Check Now") { model.checkForUpdates() }
                        .disabled(model.updateService.isBusy)

                    if model.updateService.downloadedInstallerURL != nil {
                        Button("Open Installer…") { model.openAvailableUpdate() }
                            .buttonStyle(.glassProminent)
                    } else if model.updateService.availableRelease != nil {
                        Button("Download and Verify") { model.downloadAvailableUpdate() }
                            .buttonStyle(.glassProminent)
                            .disabled(model.updateService.isBusy)
                    }

                    if model.updateService.availableRelease != nil {
                        Button("View Release") { model.updateService.openReleasePage() }
                    }
                }

                settingsHint("Automatic checks run at most once per day. Downloads are accepted only when the notarized DMG matches the SHA-256 checksum published with the GitHub Release. macOS still asks you to confirm installation.")
            }
        }
        .formStyle(.grouped)
    }

    private var experimentalSettings: some View {
        Form {
            Section("Enhanced Mode") {
                LabeledContent("Private runtime") {
                    Text(model.enhancedModeEnabled ? "Active this session" : "Off")
                }
                Toggle(
                    "Temporarily suppress system trackpad gestures",
                    isOn: $model.suppressSystemGesturesInEnhancedMode
                )
                settingsHint("Uses an Accessibility event tap only while Enhanced Mode is active. The tap disappears automatically after a crash or force-quit; system trackpad preferences are never edited. Continuous trackpad scrolling is paused, and a left-button drag is filtered while the enhanced stream reports three or more active contacts. A simultaneous physical mouse drag can therefore also be paused.")
                Button("Disable Enhanced Mode") {
                    _ = model.setEnhancedModeEnabled(false)
                }
                .disabled(!model.enhancedModeEnabled)
            }

            Section("Advanced Feature Flags") {
                Toggle(
                    "Surface Orientation",
                    isOn: Binding(
                        get: { model.advancedFeatures.surfaceOrientationFeatureEnabled },
                        set: { model.setSurfaceOrientationFeatureEnabled($0) }
                    )
                )
                .disabled(!model.advancedFeatures.supportsSurfaceOrientation)
                settingsHint("Shows the experimental 0°/90°/180°/270° control in Advanced Features. Turning this flag off hides the control and restores 0°. Quarter turns rotate only Trackpad Wizard coordinates because the macOS runtime accepts native 0° and 180° reports.")

                Toggle(
                    "System Haptic Feedback",
                    isOn: Binding(
                        get: { model.advancedFeatures.systemHapticsFeatureEnabled },
                        set: { model.setSystemHapticsFeatureEnabled($0) }
                    )
                )
                .disabled(!model.advancedFeatures.supportsSystemHaptics)
                settingsHint("Shows the private system-actuation switch in Advanced Features. Turning this flag off restores feedback only if Trackpad Wizard changed it; otherwise your current System Settings value is left untouched.")

                LabeledContent("Enabled flags") {
                    Text(model.advancedFeatures.enabledFeatureCount.formatted())
                        .monospacedDigit()
                }

                settingsHint("Feature flags only expose controls. When both flags are off, the private controller is not loaded. Every change uses a 10-second recovery confirmation. If a prior session ended before cleanup, the app may restore the marked target to macOS defaults on the next launch.")
            }
        }
        .formStyle(.grouped)
    }

    private var statisticsSettings: some View {
        Form {
            Section("Haptic Counter") {
                Toggle(
                    "Collect app-generated vibration counts",
                    isOn: Binding(
                        get: { model.statisticsStore.isCollectionEnabled },
                        set: { model.setStatisticsCollectionEnabled($0) }
                    )
                )
                settingsHint("One successful actuator oscillation equals one count. Counts are separated by a locally pseudonymized device identifier and persist like a shutter count.")
                LabeledContent("Graph range") {
                    Picker(
                        "",
                        selection: Binding(
                            get: { model.statisticsStore.graphRange },
                            set: { model.statisticsStore.graphRange = $0 }
                        )
                    ) {
                        ForEach(StatisticsGraphRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                LabeledContent("Lifetime total") {
                    Text(model.statisticsStore.totalCount.formatted())
                        .monospacedDigit()
                }
            }

            Section("Performance and Privacy") {
                settingsHint("When collection is off, the actuator callback and one-second flush timer are removed. The app never creates a sleep or power assertion. Counts cover only vibrations generated by Trackpad Wizard; normal clicks are not globally monitored because macOS cannot reliably attribute them to a trackpad instead of a mouse through public events.")
                Button("Reset All Statistics…", role: .destructive) {
                    showStatisticsResetConfirmation = true
                }
                .disabled(model.statisticsStore.devices.isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    private func durationSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String
    ) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range, step: 0.25)
                    .frame(width: 190)
                Text("\(value.wrappedValue, format: .number.precision(.fractionLength(2))) \(suffix)")
                    .font(.caption.monospacedDigit())
                    .frame(width: 62, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func settingsHint(_ message: String) -> some View {
        if model.showSettingsHints {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var updateStatusColor: Color {
        if case .failed = model.updateService.state {
            return .red
        }
        return .secondary
    }
}
