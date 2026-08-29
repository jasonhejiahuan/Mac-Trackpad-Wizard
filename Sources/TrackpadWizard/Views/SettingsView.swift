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
                LabeledContent("Touch preview size") {
                    Picker("", selection: $model.touchSurfaceSizeMode) {
                        ForEach(TouchSurfaceSizeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
                Text("Physical Size uses the current display’s reported millimeters and scaled point resolution. Some monitors publish inaccurate physical dimensions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text("Enabled by default. Enhanced Mode always turns off when the app quits, regardless of this setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Enable gesture mappings", isOn: $model.mappingsEnabled)
                Text("Mappings remain independent from Enhanced Mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text("Accessibility is requested only when you choose Request Access. It is used for mapped keyboard shortcuts and the optional process-scoped system-gesture filter; touch inspection and haptics do not require it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text("Uses an Accessibility event tap only while Enhanced Mode is active. The tap disappears automatically after a crash or force-quit; system trackpad preferences are never edited. Continuous trackpad scrolling is paused, and a left-button drag is filtered while the enhanced stream reports three or more active contacts. A simultaneous physical mouse drag can therefore also be paused.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text("Shows the experimental 0°/90°/180°/270° control in Advanced Features. Turning this flag off hides the control and restores 0°.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(
                    "System Haptic Feedback",
                    isOn: Binding(
                        get: { model.advancedFeatures.systemHapticsFeatureEnabled },
                        set: { model.setSystemHapticsFeatureEnabled($0) }
                    )
                )
                .disabled(!model.advancedFeatures.supportsSystemHaptics)
                Text("Shows the private system-actuation switch in Advanced Features. Turning this flag off hides the control and restores system feedback to On.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Enabled flags") {
                    Text(model.advancedFeatures.enabledFeatureCount.formatted())
                        .monospacedDigit()
                }

                Text("Feature flags only expose controls. Custom private settings are not applied at launch and every change uses a 10-second recovery confirmation. If a prior session ended before cleanup, the app may restore the marked target to macOS defaults on the next launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text("One successful actuator oscillation equals one count. Counts are separated by a locally pseudonymized device identifier and persist like a shutter count.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text("When collection is off, the actuator callback and one-second flush timer are removed. The app never creates a sleep or power assertion. Counts cover only vibrations generated by Trackpad Wizard; normal clicks are not globally monitored because macOS cannot reliably attribute them to a trackpad instead of a mouse through public events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
}
