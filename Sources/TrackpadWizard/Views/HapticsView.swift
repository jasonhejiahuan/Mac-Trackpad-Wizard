import SwiftUI

struct HapticsView: View {
    @Bindable var model: AppModel
    @State private var showEnhancedConfirmation = false
    @State private var selectedStepID: UUID?
    @State private var isHoldingBuzz = false

    private var engine: HapticEngine { model.hapticEngine }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    "Haptic Composer",
                    subtitle: "Audition Apple’s system feedback or compose opt-in actuator waveforms."
                ) {
                    HStack(spacing: 10) {
                        Button("Stop") {
                            engine.stopPlayback()
                            engine.stopBuzz()
                            isHoldingBuzz = false
                        }
                        .disabled(!engine.isPlaying && !isHoldingBuzz)

                        Button {
                            model.playSelectedHaptic()
                        } label: {
                            Label("Play Pattern", systemImage: "play.fill")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }

                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 14) {
                        outputModeCard
                        presetCard
                        composerCard
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        playbackCard
                        continuousCard
                        capabilityCard
                    }
                    .frame(width: 330)
                }
            }
            .pageLayout()
        }
        .onDisappear {
            engine.stopBuzz()
            isHoldingBuzz = false
        }
        .alert("Enable Enhanced Haptics?", isPresented: $showEnhancedConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Enable for This Session") {
                _ = engine.enableEnhancedMode()
                model.statusMessage = engine.lastMessage
            }
        } message: {
            Text("Enhanced mode loads Apple’s private MultitouchSupport actuator at runtime. It adds waveform selection and direct built-in/external routing, but is experimental, may change with macOS or trackpad firmware, and is not suitable for Mac App Store distribution.")
        }
    }

    private var outputModeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Output Engine", systemImage: "speaker.wave.2")
                        .font(.headline)
                    Spacer()
                    StatusPill(
                        text: engine.outputMode.title,
                        systemImage: engine.outputMode == .enhanced ? "waveform.badge.plus" : "checkmark.shield",
                        isActive: engine.outputMode == .enhanced
                    )
                }

                HStack(spacing: 12) {
                    OutputModeButton(
                        title: "System",
                        detail: "Public API · system routed",
                        systemImage: "checkmark.shield",
                        isSelected: engine.outputMode == .system
                    ) {
                        engine.useSystemMode()
                        model.statusMessage = engine.lastMessage
                    }
                    OutputModeButton(
                        title: "Enhanced",
                        detail: "Private runtime · direct actuator",
                        systemImage: "waveform.badge.plus",
                        isSelected: engine.outputMode == .enhanced
                    ) {
                        if engine.outputMode != .enhanced {
                            showEnhancedConfirmation = true
                        }
                    }
                }

                if engine.outputMode == .enhanced {
                    Divider()
                    Picker(
                        "Play On",
                        selection: Binding(
                            get: { engine.target },
                            set: { engine.target = $0 }
                        )
                    ) {
                        ForEach(HapticDeviceTarget.allCases) { target in
                            Text(target.title).tag(target)
                        }
                    }
                }
            }
        }
    }

    private var presetCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Patterns", systemImage: "square.grid.2x2")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(model.hapticTempo)) BPM")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                    spacing: 10
                ) {
                    ForEach(HapticPattern.presets) { pattern in
                        PatternButton(
                            pattern: pattern,
                            isSelected: model.selectedHapticPatternID == pattern.id,
                            isPlaying: engine.isPlaying &&
                                model.selectedHapticPatternID == pattern.id
                        ) {
                            model.selectedHapticPatternID = pattern.id
                        }
                    }
                    PatternButton(
                        pattern: model.customHapticPattern,
                        isSelected: model.selectedHapticPatternID == model.customHapticPattern.id,
                        isPlaying: engine.isPlaying &&
                            model.selectedHapticPatternID == model.customHapticPattern.id
                    ) {
                        model.selectedHapticPatternID = model.customHapticPattern.id
                    }
                }
            }
        }
    }

    private var composerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Sixteen-Step Composer", systemImage: "slider.horizontal.3")
                            .font(.headline)
                        Text("Each cell is one sixteenth-note; disabled cells are rests.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Use Custom") {
                        model.selectedHapticPatternID = model.customHapticPattern.id
                    }
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                    spacing: 8
                ) {
                    ForEach(Array(model.customHapticPattern.steps.enumerated()), id: \.element.id) { index, step in
                        Button {
                            selectedStepID = step.id
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: step.isEnabled ? step.feedback.systemImage : "minus")
                                    .font(.body)
                                Text("\(index + 1)")
                                    .font(.caption2.monospacedDigit())
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(step.isEnabled ? .primary : .tertiary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            selectedStepID == step.id ? .regular.interactive() : .regular,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(alignment: .topTrailing) {
                            if engine.currentStep == index &&
                                model.selectedHapticPatternID == model.customHapticPattern.id {
                                Circle()
                                    .fill(.primary)
                                    .frame(width: 6, height: 6)
                                    .padding(7)
                            }
                        }
                    }
                }

                if let selectedIndex {
                    Divider()
                    HStack(spacing: 18) {
                        Toggle(
                            "Pulse",
                            isOn: Binding(
                                get: { model.customHapticPattern.steps[selectedIndex].isEnabled },
                                set: { model.customHapticPattern.steps[selectedIndex].isEnabled = $0 }
                            )
                        )
                        .toggleStyle(.switch)

                        Picker(
                            "Waveform",
                            selection: Binding(
                                get: { model.customHapticPattern.steps[selectedIndex].feedback },
                                set: { model.customHapticPattern.steps[selectedIndex].feedback = $0 }
                            )
                        ) {
                            ForEach(HapticFeedbackKind.allCases) { feedback in
                                Text(feedback.title).tag(feedback)
                            }
                        }
                        .disabled(!model.customHapticPattern.steps[selectedIndex].isEnabled)

                        Stepper(
                            "Length \(model.customHapticPattern.steps[selectedIndex].length)",
                            value: Binding(
                                get: { model.customHapticPattern.steps[selectedIndex].length },
                                set: { model.customHapticPattern.steps[selectedIndex].length = $0 }
                            ),
                            in: 1...4
                        )
                        .frame(width: 120)

                        Button("Test") {
                            engine.playSingle(model.customHapticPattern.steps[selectedIndex].feedback)
                        }
                        .disabled(!model.customHapticPattern.steps[selectedIndex].isEnabled)
                    }
                }
            }
        }
    }

    private var playbackCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Playback", systemImage: "metronome")
                    .font(.headline)
                HStack {
                    Text("40")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Slider(value: $model.hapticTempo, in: 40...240, step: 1)
                    Text("240")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("\(model.selectedHapticPattern.name) · \(model.selectedHapticPattern.steps.filter(\.isEnabled).count) pulses")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var continuousCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Hold to Vibrate", systemImage: "hand.tap")
                    .font(.headline)

                Picker("Waveform", selection: $model.continuousFeedback) {
                    ForEach(HapticFeedbackKind.allCases) { feedback in
                        Text(feedback.title).tag(feedback)
                    }
                }
                Slider(value: $model.continuousFrequency, in: 8...120, step: 1) {
                    Text("Pulse Rate")
                } minimumValueLabel: {
                    Text("8")
                } maximumValueLabel: {
                    Text("120 Hz")
                }

                Label(
                    isHoldingBuzz ? "Release to stop" : "Press and hold",
                    systemImage: isHoldingBuzz ? "waveform" : "hand.point.up.left"
                )
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .glassEffect(
                    isHoldingBuzz ? .regular.interactive() : .regular,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isHoldingBuzz else { return }
                            isHoldingBuzz = engine.startBuzz(
                                model.continuousFeedback,
                                frequency: model.continuousFrequency
                            )
                            if !isHoldingBuzz { model.statusMessage = engine.lastMessage }
                        }
                        .onEnded { _ in
                            engine.stopBuzz()
                            isHoldingBuzz = false
                        }
                )
                .disabled(engine.outputMode != .enhanced)

                if engine.outputMode != .enhanced {
                    Text("Continuous pulses require Enhanced mode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var capabilityCard: some View {
        GlassCard(padding: 15) {
            InlineNotice(
                systemImage: "info.circle",
                title: "What “intensity” means here",
                message: engine.outputMode == .system
                    ? "Apple’s public API offers only Alignment, Level Change, and Generic patterns. macOS chooses the device and physical strength."
                    : "Enhanced waveform IDs are empirical and firmware-dependent. The composer varies waveform, rhythm, and repetition—not actuator voltage."
            )
        }
    }

    private var selectedIndex: Int? {
        guard let selectedStepID else { return nil }
        return model.customHapticPattern.steps.firstIndex { $0.id == selectedStepID }
    }
}

private struct OutputModeButton: View {
    let title: String
    let detail: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.interactive() : .regular,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

private struct PatternButton: View {
    let pattern: HapticPattern
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: pattern.systemImage)
                        .font(.title3)
                    Spacer()
                    if isPlaying {
                        Image(systemName: "waveform")
                            .symbolEffect(.variableColor.iterative, isActive: true)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                    }
                }
                Text(pattern.name)
                    .font(.headline)
                Text(pattern.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .padding(13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.interactive() : .regular,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}
