import SwiftUI

struct MappingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    "Mappings",
                    subtitle: "Turn recognized gestures into keyboard shortcuts or tactile cues."
                ) {
                    HStack(spacing: 10) {
                        Toggle("Enable Mappings", isOn: $model.mappingsEnabled)
                            .toggleStyle(.switch)
                        Button {
                            model.addMapping()
                        } label: {
                            Label("Add Mapping", systemImage: "plus")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }

                permissionCard

                VStack(spacing: 12) {
                    if model.mappings.isEmpty {
                        GlassCard {
                            ContentUnavailableView(
                                "No Mappings",
                                systemImage: "command.square",
                                description: Text("Add a gesture mapping to begin.")
                            )
                            .frame(minHeight: 180)
                        }
                    } else {
                        ForEach($model.mappings) { $mapping in
                            MappingRow(
                                mapping: $mapping,
                                patterns: HapticPattern.presets + [model.customHapticPattern],
                                remove: { model.removeMapping(id: mapping.id) }
                            )
                            .disabled(!model.mappingsEnabled)
                        }
                    }
                }

                if model.showInterfaceHints {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 300), spacing: 14)],
                        spacing: 14
                    ) {
                        GlassCard(padding: 15) {
                            InlineNotice(
                                systemImage: "scope",
                                title: "Input scope",
                                message: model.enhancedModeEnabled
                                    ? "Enhanced Mode can recognize three-finger directional swipes while this app is running. Pinch, rotation, Force Click, and AppKit swipe events are tested on the app’s capture surfaces."
                                    : "Public AppKit gestures are delivered only over the Touch Lab and Gesture Studio surfaces. Enable Enhanced Mode for experimental global three-finger directional swipes."
                            )
                        }
                        GlassCard(padding: 15) {
                            InlineNotice(
                                systemImage: "rectangle.on.rectangle.slash",
                                title: "System gesture conflicts",
                                message: model.systemGesturesSuppressed
                                    ? "The process-scoped gesture filter is active. It disappears automatically when Enhanced Mode stops or the app exits."
                                    : "Mission Control, app switching, and other macOS gestures may consume the same input first. Trackpad Wizard never rewrites your System Settings."
                            )
                        }
                    }
                }
            }
            .pageLayout()
        }
        .onAppear { model.refreshPermissions() }
    }

    private var permissionCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: model.accessibilityGranted ? "checkmark.circle.fill" : "lock.trianglebadge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.accessibilityGranted ? "Accessibility Ready" : "Accessibility Is Off")
                        .font(.headline)
                    Text(
                        model.accessibilityGranted
                            ? "Keyboard shortcut actions can be posted to the active app."
                            : "Only keyboard actions need Accessibility. Haptic actions work without it."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if model.accessibilityGranted {
                    Button("Refresh") { model.refreshPermissions() }
                } else {
                    Button("Open Settings") { model.openAccessibilitySettings() }
                    Button("Request Access…") { model.requestAccessibility() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
    }
}

private struct MappingRow: View {
    @Binding var mapping: GestureMapping
    let patterns: [HapticPattern]
    let remove: () -> Void

    var body: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 15) {
                Toggle("", isOn: $mapping.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)

                Image(systemName: mapping.trigger.systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                Picker("Gesture", selection: $mapping.trigger) {
                    ForEach(GestureTrigger.allCases) { trigger in
                        Label(trigger.title, systemImage: trigger.systemImage)
                            .tag(trigger)
                    }
                }
                .labelsHidden()
                .frame(width: 190)

                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)

                Picker("Action", selection: $mapping.actionKind) {
                    ForEach(MappingActionKind.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }
                .labelsHidden()
                .frame(width: 160)

                actionEditor
                    .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Button("Delete Mapping", role: .destructive, action: remove)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    @ViewBuilder
    private var actionEditor: some View {
        switch mapping.actionKind {
        case .keyboardShortcut:
            ShortcutRecorderView(shortcut: $mapping.shortcut)
        case .hapticPattern:
            Picker("Pattern", selection: $mapping.hapticPatternID) {
                ForEach(patterns) { pattern in
                    Label(pattern.name, systemImage: pattern.systemImage)
                        .tag(pattern.id)
                }
            }
            .labelsHidden()
            .frame(width: 165)
        }
    }
}
