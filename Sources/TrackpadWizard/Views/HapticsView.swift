import SwiftUI

struct HapticsView: View {
    @Bindable var model: AppModel
    @State private var selectedStepID: UUID?
    @State private var isHoldingBuzz = false

    private var engine: HapticEngine { model.hapticEngine }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    "Haptic Composer",
                    subtitle: "Shape amplitude, pulse frequency, and rhythm with the opt-in actuator engine."
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
                        .disabled(!engine.enhancedHapticsEnabled)
                    }
                }

                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 14) {
                        actuatorCard
                        presetCard
                            .disabled(!engine.enhancedHapticsEnabled)
                            .opacity(engine.enhancedHapticsEnabled ? 1 : 0.42)
                        composerCard
                            .disabled(!engine.enhancedHapticsEnabled)
                            .opacity(engine.enhancedHapticsEnabled ? 1 : 0.42)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        playbackCard
                            .disabled(!engine.enhancedHapticsEnabled)
                            .opacity(engine.enhancedHapticsEnabled ? 1 : 0.42)
                        continuousCard
                            .disabled(!engine.enhancedHapticsEnabled)
                            .opacity(engine.enhancedHapticsEnabled ? 1 : 0.42)
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
        .onChange(of: model.continuousFeedback) { _, _ in
            refreshHeldSignal()
        }
        .onChange(of: model.continuousAmplitude) { _, _ in
            refreshHeldSignal()
        }
        .onChange(of: model.continuousFrequency) { _, _ in
            refreshHeldSignal()
        }
        .onChange(of: engine.target) { _, _ in
            refreshHeldSignal()
        }
    }

    private var actuatorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Enhanced Haptics", systemImage: "waveform.badge.plus")
                            .font(.headline)
                        Text("Global direct-actuator output")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(
                        "Enhanced Haptics",
                        isOn: Binding(
                            get: { engine.enhancedHapticsEnabled },
                            set: { setEnhancedHapticsEnabled($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Text(
                    engine.enhancedHapticsEnabled
                        ? "All haptic features now use the enhanced actuator for this session."
                        : "Haptic controls are unavailable. Turn on Enhanced Haptics to enable them."
                )
                .font(.caption)
                .foregroundStyle(engine.enhancedHapticsEnabled ? .secondary : .tertiary)

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
                .disabled(!engine.enhancedHapticsEnabled)
                .opacity(engine.enhancedHapticsEnabled ? 1 : 0.42)
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
                                    .opacity(step.isEnabled ? 0.35 + (step.amplitude * 0.65) : 1)
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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            Toggle(
                                "Pulse",
                                isOn: Binding(
                                    get: { model.customHapticPattern.steps[selectedIndex].isEnabled },
                                    set: { model.customHapticPattern.steps[selectedIndex].isEnabled = $0 }
                                )
                            )
                            .toggleStyle(.switch)

                            Spacer()
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
                                let step = model.customHapticPattern.steps[selectedIndex]
                                engine.playSingle(step.feedback, amplitude: step.amplitude)
                            }
                            .disabled(!model.customHapticPattern.steps[selectedIndex].isEnabled)
                        }

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

                        HStack(spacing: 12) {
                            Text("Amplitude")
                                .font(.subheadline)
                            Slider(
                                value: Binding(
                                    get: { model.customHapticPattern.steps[selectedIndex].amplitude },
                                    set: {
                                        model.customHapticPattern.steps[selectedIndex].amplitude =
                                            HapticStep.clampedAmplitude($0)
                                    }
                                ),
                                in: HapticStep.amplitudeRange,
                                step: 0.01
                            )
                            Text(amplitudeLabel(model.customHapticPattern.steps[selectedIndex].amplitude))
                                .font(.caption.monospacedDigit())
                                .frame(width: 42, alignment: .trailing)
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
                Label("Custom Signal", systemImage: "waveform.path.ecg")
                    .font(.headline)
                Text("Set amplitude and pulse frequency directly; no rhythm preset is involved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Impulse Shape", selection: $model.continuousFeedback) {
                    ForEach(HapticFeedbackKind.allCases) { feedback in
                        Text(feedback.title).tag(feedback)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Amplitude")
                        Spacer()
                        Text(amplitudeLabel(model.continuousAmplitude))
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    Slider(
                        value: $model.continuousAmplitude,
                        in: HapticStep.amplitudeRange,
                        step: 0.01
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Pulse Frequency")
                        Spacer()
                        Text("\(Int(model.continuousFrequency.rounded())) Hz")
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    Slider(value: $model.continuousFrequency, in: 8...120, step: 1)
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
                            isHoldingBuzz = startCustomSignal()
                            if !isHoldingBuzz { model.statusMessage = engine.lastMessage }
                        }
                        .onEnded { _ in
                            engine.stopBuzz()
                            isHoldingBuzz = false
                        }
                )
                .disabled(!engine.enhancedAvailable)

                if !engine.enhancedAvailable {
                    Text("Enable enhanced haptics to send continuous pulses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var capabilityCard: some View {
        Group {
            if model.showInterfaceHints {
                GlassCard(padding: 15) {
                    InlineNotice(
                        systemImage: "info.circle",
                        title: "What “intensity” means here",
                        message: "Enhanced amplitude is a near-stepless empirical waveform multiplier. Frequency controls pulse repetition, not the actuator’s carrier frequency; firmware still quantizes the physical result."
                    )
                }
            }
        }
    }

    private var selectedIndex: Int? {
        guard let selectedStepID else { return nil }
        return model.customHapticPattern.steps.firstIndex { $0.id == selectedStepID }
    }

    private func amplitudeLabel(_ amplitude: Double) -> String {
        "\(Int((HapticStep.clampedAmplitude(amplitude) * 100).rounded()))%"
    }

    private func startCustomSignal() -> Bool {
        engine.startBuzz(
            model.continuousFeedback,
            amplitude: model.continuousAmplitude,
            frequency: model.continuousFrequency
        )
    }

    private func refreshHeldSignal() {
        guard isHoldingBuzz else { return }
        if !startCustomSignal() {
            isHoldingBuzz = false
            model.statusMessage = engine.lastMessage
        }
    }

    private func setEnhancedHapticsEnabled(_ isEnabled: Bool) {
        if isEnabled {
            _ = engine.enableEnhancedHaptics()
        } else {
            engine.disableEnhancedHaptics()
            isHoldingBuzz = false
        }
        model.statusMessage = engine.lastMessage
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
