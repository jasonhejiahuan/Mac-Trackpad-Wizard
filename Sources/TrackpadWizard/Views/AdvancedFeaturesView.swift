import SwiftUI

struct AdvancedFeaturesView: View {
    @Bindable var model: AppModel

    var body: some View {
        AdvancedFeaturesContent(model: model, store: model.advancedFeatures)
    }
}

private struct AdvancedFeaturesContent: View {
    @Bindable var model: AppModel
    @Bindable var store: AdvancedFeaturesStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    "Advanced Features",
                    subtitle: "Explicitly enabled private controls with automatic recovery."
                ) {
                    StatusPill(
                        text: "\(store.enabledFeatureCount) Enabled",
                        systemImage: "slider.horizontal.3",
                        isActive: store.enabledFeatureCount > 0
                    )
                }

                HStack {
                    Label("Target", systemImage: "scope")
                        .font(.headline)
                    Picker("Target", selection: $model.touchTarget) {
                        ForEach(HapticDeviceTarget.allCases) { target in
                            Text(target.title).tag(target)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                    Spacer()
                    Text("Changing target restores active overrides first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if store.enabledFeatureCount == 0 {
                    GlassCard {
                        ContentUnavailableView(
                            "No Experimental Controls Enabled",
                            systemImage: "slider.horizontal.3",
                            description: Text(
                                "Enable a feature flag in Settings › Experimental. Disabled flags keep their controls hidden and do not load the private controller unless recovery is required."
                            )
                        )
                        .frame(minHeight: 270)
                    }
                } else {
                    AdaptiveColumnsLayout(breakpoint: 900, spacing: 18, trailingWidth: 350) {
                        VStack(spacing: 14) {
                            if store.surfaceOrientationFeatureEnabled {
                                surfaceOrientationCard
                            }
                            if store.systemHapticsFeatureEnabled {
                                systemHapticsCard
                            }
                        }

                        safetyCard
                    }
                }
            }
            .pageLayout()
        }
    }

    private var surfaceOrientationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Label("Surface Orientation", systemImage: "rotate.right")
                        .font(.headline)
                    Spacer()
                    Text("Experimental")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Picker("Orientation", selection: orientationBinding) {
                    ForEach(ExperimentalSurfaceOrientation.allCases) { orientation in
                        Text(orientation.title).tag(orientation)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(store.pendingConfirmation != nil)

                Text(
                    "0° and 180° use MTDeviceSetSurfaceOrientation. The available private runtime accepts only those native orientations, so 90° and 270° rotate Trackpad Wizard's touch and directional-gesture coordinates without claiming a system-wide quarter turn."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Label(
                        store.selectedSurfaceOrientation.usesNativeOrientation
                            ? "Private device report"
                            : "App coordinate rotation",
                        systemImage: store.selectedSurfaceOrientation.usesNativeOrientation
                            ? "checkmark.seal"
                            : "rectangle.on.rectangle.angled"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restore 0°") {
                        model.restoreSurfaceOrientationDefault()
                    }
                    .disabled(store.selectedSurfaceOrientation == .degrees0)
                }
            }
        }
    }

    private var systemHapticsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Label("System Haptic Feedback", systemImage: "waveform")
                        .font(.headline)
                    Spacer()
                    Text("Experimental")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Toggle("Allow macOS system click actuations", isOn: systemHapticsBinding)
                    .toggleStyle(.switch)
                    .disabled(store.pendingConfirmation != nil)

                Text(
                    "Uses MTActuatorSetSystemActuationsEnabled for the selected target. Direct Trackpad Wizard patterns remain a separate actuator path."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack {
                    Label(
                        systemHapticStatus,
                        systemImage: store.systemHapticsMixedState
                            ? "circle.lefthalf.filled"
                            : (store.systemHapticFeedbackEnabled ? "speaker.wave.2" : "speaker.slash")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer()
                    if store.hasManagedSystemHapticsOverride {
                        Button("Restore macOS Default") {
                            model.restoreSystemHapticsDefault()
                        }
                        .disabled(store.pendingConfirmation != nil)
                    }
                }
            }
        }
    }

    private var safetyCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                InlineNotice(
                    systemImage: "timer",
                    title: "10-second recovery",
                    message: "Every change opens a confirmation dialog. If Continue is not clicked within 10 seconds, the exact captured pre-change state is written back."
                )
                Divider()
                InlineNotice(
                    systemImage: "arrow.uturn.backward.circle",
                    title: "Session scoped",
                    message: "Native private overrides are restored when their flag is disabled, the target changes, or the app quits. App-only 90° and 270° coordinates can persist without changing macOS. An incomplete-session marker can only trigger recovery for a previously managed target."
                )
                Divider()
                InlineNotice(
                    systemImage: "exclamationmark.triangle",
                    title: "Private API boundary",
                    message: "A hard power loss or SIGKILL cannot run app cleanup after a confirmed change. Use Restore before force-quitting if an override is active."
                )
            }
        }
    }

    private var orientationBinding: Binding<ExperimentalSurfaceOrientation> {
        Binding(
            get: { store.selectedSurfaceOrientation },
            set: { model.requestSurfaceOrientation($0) }
        )
    }

    private var systemHapticsBinding: Binding<Bool> {
        Binding(
            get: { store.systemHapticFeedbackEnabled },
            set: { model.requestSystemHapticFeedback(enabled: $0) }
        )
    }

    private var systemHapticStatus: String {
        if store.systemHapticsMixedState {
            return "Mixed across selected trackpads"
        }
        return store.systemHapticFeedbackEnabled ? "System feedback on" : "System feedback paused"
    }
}

struct AdvancedRecoveryDialog: View {
    let confirmation: AdvancedFeatureConfirmation
    let restore: () -> Void
    let continueUsing: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = max(0, Int(ceil(confirmation.deadline.timeIntervalSince(context.date))))
            VStack(spacing: 18) {
                Image(systemName: "timer")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text(confirmation.title)
                        .font(.title2.weight(.semibold))
                    Text(confirmation.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Restoring automatically in \(remaining) s")
                    .font(.headline.monospacedDigit())

                HStack(spacing: 12) {
                    Button("Restore Now", role: .cancel, action: restore)
                    Button("Continue", action: continueUsing)
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
            .frame(width: 460)
        }
    }
}
