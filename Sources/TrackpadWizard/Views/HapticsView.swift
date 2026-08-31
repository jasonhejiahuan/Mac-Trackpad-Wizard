import AppKit
import SwiftUI

struct HapticsView: View {
    @Bindable var model: AppModel
    @State private var selectedStepID: UUID?
    @State private var isHoldingBuzz = false
    @State private var showDeleteConfirmation = false

    private var engine: HapticEngine { model.hapticEngine }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    "Haptic Composer",
                    subtitle: "Shape amplitude, pulse frequency, and rhythm with the opt-in actuator engine."
                ) {
                    StatusPill(
                        text: model.enhancedModeEnabled ? "Actuator Ready" : "Enhanced Mode Off",
                        systemImage: TrackpadSymbols.device(enhanced: model.enhancedModeEnabled),
                        isActive: model.enhancedModeEnabled
                    )
                }

                AdaptiveColumnsLayout(breakpoint: 940, spacing: 18, trailingWidth: 340) {
                    VStack(spacing: 14) {
                        playbackCard
                        presetCard
                            .disabled(!model.enhancedModeEnabled)
                            .opacity(model.enhancedModeEnabled ? 1 : 0.42)
                        composerCard
                            .disabled(!model.enhancedModeEnabled)
                            .opacity(model.enhancedModeEnabled ? 1 : 0.42)
                        patternLibraryCard
                    }

                    VStack(spacing: 14) {
                        continuousCard
                            .disabled(!model.enhancedModeEnabled)
                            .opacity(model.enhancedModeEnabled ? 1 : 0.42)
                        capabilityCard
                    }
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

    private var presetCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Patterns", systemImage: "square.grid.2x2")
                        .font(.headline)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                    spacing: 10
                ) {
                    ForEach(HapticPattern.presets) { pattern in
                        PatternButton(
                            pattern: pattern,
                            isSelected: model.selectedHapticPatternID == pattern.id,
                            isPlaying: engine.isPlaying && !engine.isPlayingLibraryPattern &&
                                model.selectedHapticPatternID == pattern.id
                        ) {
                            model.selectedHapticPatternID = pattern.id
                        }
                    }
                    PatternButton(
                        pattern: model.customHapticPattern,
                        isSelected: model.selectedHapticPatternID == model.customHapticPattern.id,
                        isPlaying: engine.isPlaying && !engine.isPlayingLibraryPattern &&
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
                            if !engine.isPlayingLibraryPattern &&
                                engine.currentStep == index &&
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
                                if !engine.playSingle(step.feedback, amplitude: step.amplitude) {
                                    model.reportError(
                                        .hapticPlayback,
                                        engine.lastMessage ?? "The test pulse could not be sent."
                                    )
                                }
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
                HStack {
                    Label("Playback", systemImage: "play.square.stack")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(model.hapticTempo)) BPM")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
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

                HStack(spacing: 10) {
                    Button {
                        engine.stopPlayback()
                        engine.stopBuzz()
                        isHoldingBuzz = false
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .disabled(!engine.isPlaying && !isHoldingBuzz)

                    Button {
                        model.playSelectedHaptic()
                    } label: {
                        Label("Play Pattern", systemImage: "play.fill")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!model.enhancedModeEnabled)

                    Spacer()

                    Button {
                        model.saveSelectedComposerPattern()
                    } label: {
                        Label("Save to Library", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!model.canSaveSelectedComposerPattern)
                }
            }
        }
    }

    private var patternLibraryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Pattern Library", systemImage: "books.vertical")
                            .font(.headline)
                        Text("Trackpad Haptic Pattern schema v1 · time, amplitude, and pulse frequency")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Import…") { model.importHapticPattern() }
                    Button("Export…") { model.exportSelectedHapticPattern() }
                        .disabled(model.selectedSavedHapticPattern == nil)
                }

                HStack(spacing: 10) {
                    Picker("Saved Pattern", selection: savedPatternBinding) {
                        if model.savedHapticPatterns.isEmpty {
                            Text("No saved patterns").tag(Optional<UUID>.none)
                        }
                        ForEach(model.savedHapticPatterns) { pattern in
                            Text(pattern.name).tag(Optional(pattern.id))
                        }
                    }
                    .frame(maxWidth: 310)

                    Button {
                        model.playSelectedSavedHapticPattern()
                    } label: {
                        Label("Replay", systemImage: "play.fill")
                    }
                    .disabled(!model.enhancedModeEnabled || model.selectedSavedHapticPattern == nil)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(model.selectedSavedHapticPattern == nil)

                    Spacer()

                    if model.isRecordingHapticPattern {
                        Button("Stop & Save") {
                            model.stopHapticPatternRecording()
                        }
                        .buttonStyle(.glassProminent)
                    } else {
                        Button {
                            model.startHapticPatternRecording()
                        } label: {
                            Label("Record Clicks", systemImage: "record.circle")
                        }
                    }
                }

                if model.isRecordingHapticPattern {
                    TextField("Pattern Name", text: $model.hapticRecordingName)

                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.primary.opacity(0.035))
                        VStack(spacing: 7) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.title2)
                            Text("Click here with the trackpad")
                                .font(.headline)
                            Text(
                                "\(model.hapticRecordingEvents.count) oscillations · \(Int(model.continuousFrequency)) Hz · \(Int(model.continuousAmplitude * 100))% fallback amplitude"
                            )
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }
                        .allowsHitTesting(false)

                        HapticClickRecorderView { timestamp, pressure in
                            model.recordHapticClick(timestamp: timestamp, pressure: pressure)
                        }
                    }
                    .frame(height: 125)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.primary.opacity(0.12))
                    }
                } else if let pattern = model.selectedSavedHapticPattern {
                    HStack {
                        LabeledContent("Events", value: pattern.events.count.formatted())
                        Divider().frame(height: 18)
                        LabeledContent("Oscillations", value: pattern.pulseCount.formatted())
                        Divider().frame(height: 18)
                        LabeledContent(
                            "Duration",
                            value: pattern.duration.formatted(.number.precision(.fractionLength(2))) + " s"
                        )
                    }
                    .font(.caption)

                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                        GridRow {
                            Text("Time")
                            Text("Amplitude")
                            Text("Frequency")
                            Text("Waveform")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                        ForEach(pattern.events.prefix(6)) { event in
                            GridRow {
                                Text(event.timeSeconds, format: .number.precision(.fractionLength(3)))
                                Text(event.amplitude, format: .percent.precision(.fractionLength(0)))
                                Text("\(Int(event.frequencyHz.rounded())) Hz")
                                Text(event.feedback.title)
                            }
                            .font(.caption.monospacedDigit())
                        }
                    }
                } else {
                    Text("Record physical clicks or import a schema-v1 JSON pattern to create a reusable library entry.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert("Delete Saved Pattern?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                model.deleteSelectedHapticPattern()
            }
        } message: {
            Text("This removes the selected saved pattern from this Mac. Export it first if you want a portable copy.")
        }
    }

    private var savedPatternBinding: Binding<UUID?> {
        Binding(
            get: { model.selectedSavedHapticPattern?.id },
            set: { model.selectedSavedHapticPatternID = $0 }
        )
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
                            if !isHoldingBuzz {
                                model.reportError(
                                    .hapticPlayback,
                                    engine.lastMessage ?? "The custom signal could not start."
                                )
                            }
                        }
                        .onEnded { _ in
                            engine.stopBuzz()
                            isHoldingBuzz = false
                        }
                )
                .disabled(!engine.enhancedAvailable)

                if !engine.enhancedAvailable {
                    Text("Enable Enhanced Mode to send continuous pulses.")
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
            model.reportError(
                .hapticPlayback,
                engine.lastMessage ?? "The custom signal could not be refreshed."
            )
        }
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

private struct HapticClickRecorderView: NSViewRepresentable {
    let onClick: (TimeInterval, Double?) -> Void

    func makeNSView(context: Context) -> HapticClickRecorderNSView {
        let view = HapticClickRecorderNSView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: HapticClickRecorderNSView, context: Context) {
        nsView.onClick = onClick
    }
}

private final class HapticClickRecorderNSView: NSView {
    var onClick: ((TimeInterval, Double?) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onClick?(
            event.timestamp,
            event.pressure > 0 ? Double(event.pressure) : nil
        )
    }
}
