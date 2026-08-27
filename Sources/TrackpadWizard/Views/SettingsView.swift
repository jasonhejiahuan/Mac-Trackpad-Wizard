import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            Form {
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
                }

                Section("Actions") {
                    Toggle("Enable gesture mappings", isOn: $model.mappingsEnabled)
                    LabeledContent("Haptic tempo") {
                        HStack {
                            Slider(value: $model.hapticTempo, in: 40...240, step: 1)
                                .frame(width: 180)
                            Text("\(Int(model.hapticTempo)) BPM")
                                .font(.caption.monospacedDigit())
                                .frame(width: 62, alignment: .trailing)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section("Accessibility") {
                    LabeledContent("Keyboard shortcut actions") {
                        Label(
                            model.accessibilityGranted ? "Allowed" : "Not allowed",
                            systemImage: model.accessibilityGranted ? "checkmark.circle.fill" : "circle"
                        )
                    }
                    Text("Accessibility is requested only when you choose Request Access. Touch inspection and haptics do not require it.")
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
            .tabItem { Label("Permissions", systemImage: "lock.shield") }

            Form {
                Section("Private Runtime Features") {
                    LabeledContent("Enhanced Touch") {
                        Text(model.enhancedTouchEnabled ? "Active this session" : "Off")
                    }
                    LabeledContent("Enhanced Haptics") {
                        Text(model.hapticEngine.outputMode == .enhanced ? "Active this session" : "Off")
                    }
                    Text("These modes are never enabled automatically and are not persisted. They load private MultitouchSupport symbols at runtime, can break after system updates, and should be disabled for Mac App Store distribution.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Disable Enhanced Touch") { model.disableEnhancedTouch() }
                            .disabled(!model.enhancedTouchEnabled)
                        Button("Use System Haptics") { model.hapticEngine.useSystemMode() }
                            .disabled(model.hapticEngine.outputMode == .system)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Experimental", systemImage: "testtube.2") }

            VStack(spacing: 16) {
                Image(systemName: "rectangle.and.hand.point.up.left")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(.secondary)
                VStack(spacing: 4) {
                    Text("Trackpad Wizard")
                        .font(.title2.weight(.semibold))
                    Text("Version 0.1.0")
                        .foregroundStyle(.secondary)
                }
                Text("A native macOS laboratory for touch contacts, gestures, Force Touch, haptic composition, mappings, and live device diagnostics.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 390)
                Divider().frame(maxWidth: 390)
                Text("No touch session leaves this Mac unless you explicitly export it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 660, height: 470)
        .onAppear { model.refreshPermissions() }
    }
}
