import SwiftUI

struct TouchLabView: View {
    @Bindable var model: AppModel
    @State private var showEnhancedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    "Touch Lab",
                    subtitle: "See the surface as contacts, trails, pressure, or accumulated touch activity."
                ) {
                    HStack(spacing: 10) {
                        StatusPill(
                            text: model.latestTouchSource.title,
                            systemImage: model.enhancedTouchEnabled ? "waveform.badge.plus" : "checkmark.shield",
                            isActive: model.enhancedTouchEnabled
                        )
                        Button(model.enhancedTouchEnabled ? "Use AppKit" : "Enable Enhanced…") {
                            if model.enhancedTouchEnabled {
                                model.disableEnhancedTouch()
                            } else {
                                showEnhancedConfirmation = true
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Picker("Visualization", selection: $model.visualizationMode) {
                        ForEach(TouchVisualizationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 360)

                    Spacer()

                    Toggle("Resting Touches", isOn: $model.showRestingTouches)
                        .toggleStyle(.switch)

                    if model.enhancedTouchEnabled {
                        Picker("Device", selection: $model.touchTarget) {
                            ForEach(HapticDeviceTarget.allCases) { target in
                                Text(target.title).tag(target)
                            }
                        }
                        .frame(width: 190)
                        .onChange(of: model.touchTarget) {
                            model.restartEnhancedTouchIfNeeded()
                        }
                    }
                }

                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 14) {
                        InteractiveTrackpadSurface(model: model)

                        HStack(spacing: 12) {
                            MetricTile(
                                title: "Contacts",
                                value: "\(model.activeContactCount)",
                                systemImage: "hand.raised.fingers.spread",
                                detail: "Peak \(model.maximumContactCount)"
                            )
                            MetricTile(
                                title: "Observed Rate",
                                value: model.estimatedSampleRate > 0
                                    ? "\(Int(model.estimatedSampleRate.rounded())) Hz"
                                    : "—",
                                systemImage: "gauge.with.dots.needle.50percent",
                                detail: model.latestTouchSource.title
                            )
                            MetricTile(
                                title: "Pressure",
                                value: model.pressureProxy > 0
                                    ? model.pressureProxy.formatted(.number.precision(.fractionLength(2)))
                                    : "—",
                                systemImage: "circle.dotted.circle",
                                detail: model.latestTouchSource == .enhanced ? "Area proxy" : "AppKit force"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        sessionCard
                        contactInspector
                        if let contact = model.visibleContacts.first(where: { $0.source == .enhanced }) {
                            enhancedGeometryCard(contact)
                        }
                    }
                    .frame(width: 330)
                }

                GlassCard(padding: 15) {
                    InlineNotice(
                        systemImage: model.enhancedTouchEnabled ? "exclamationmark.triangle" : "cursorarrow.motionlines",
                        title: model.enhancedTouchEnabled ? "Private enhanced stream" : "Public AppKit surface",
                        message: model.enhancedTouchEnabled
                            ? "Raw touch runs globally for the selected device and exposes experimental contact geometry. Structure fields can change with macOS or firmware."
                            : "Keep the pointer over the visual surface while testing. This is an AppKit rule; the app does not trap or move your pointer."
                    )
                }
            }
            .pageLayout()
        }
        .alert("Enable Enhanced Touch?", isPresented: $showEnhancedConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Enable for This Session") {
                _ = model.enableEnhancedTouch()
            }
        } message: {
            Text("This opt-in mode loads Apple’s private MultitouchSupport framework at runtime. It enables global raw contacts and pressure proxies, but may break after a macOS update and is not suitable for a Mac App Store build.")
        }
    }

    private var sessionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Session", systemImage: "record.circle")
                        .font(.headline)
                    Spacer()
                    if model.isRecording {
                        StatusPill(text: "Recording", systemImage: "record.circle.fill", isActive: true)
                    }
                }

                LabeledContent("Frames", value: "\(model.recordedFrames.count)")
                LabeledContent("Gesture samples", value: "\(model.recordedGestures.count)")

                HStack {
                    if model.isRecording {
                        Button("Stop") { model.toggleRecording() }
                    } else {
                        Button("Record") { model.toggleRecording() }
                            .buttonStyle(.glassProminent)
                    }

                    Button("Export…") {
                        model.exportSession()
                    }
                    .disabled(model.recordedFrames.isEmpty && model.recordedGestures.isEmpty)

                    Spacer()

                    Button("Clear", role: .destructive) {
                        model.clearSession()
                    }
                }
            }
        }
    }

    private var contactInspector: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Live Contacts", systemImage: "list.bullet.rectangle")
                        .font(.headline)
                    Spacer()
                    Text("x / y")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }

                if model.visibleContacts.isEmpty {
                    ContentUnavailableView(
                        "No Contacts",
                        systemImage: "hand.raised",
                        description: Text("Touch the trackpad to inspect a frame.")
                    )
                    .frame(height: 165)
                } else {
                    ForEach(model.visibleContacts.prefix(8)) { contact in
                        HStack(spacing: 9) {
                            Text("\(contact.id)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .frame(width: 24, height: 24)
                                .background(.primary.opacity(0.08), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.phase.rawValue.capitalized)
                                    .font(.subheadline.weight(.medium))
                                Text(contact.isResting ? "Resting" : contact.source.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(contact.x, format: .number.precision(.fractionLength(2)))  \(contact.y, format: .number.precision(.fractionLength(2)))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if contact.id != model.visibleContacts.prefix(8).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func enhancedGeometryCard(_ contact: TouchContact) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Enhanced Geometry", systemImage: "ruler")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                    geometryRow("Area proxy", value(contact.pressureProxy, digits: 3))
                    geometryRow("Total pressure", value(contact.totalPressure, digits: 3))
                    geometryRow(
                        "Velocity",
                        "\(value(contact.velocityX, digits: 3)) / \(value(contact.velocityY, digits: 3))"
                    )
                    geometryRow(
                        "Major / minor",
                        "\(value(contact.majorAxis, digits: 2)) / \(value(contact.minorAxis, digits: 2))"
                    )
                    geometryRow("Angle", value(contact.angle, digits: 2))
                    geometryRow("Density", value(contact.density, digits: 2))
                    geometryRow(
                        "Surface",
                        "\(contact.deviceWidth.formatted(.number.precision(.fractionLength(1)))) × \(contact.deviceHeight.formatted(.number.precision(.fractionLength(1)))) mm"
                    )
                }

                Text("Field meanings are empirical and can vary by firmware.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func geometryRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .gridColumnAlignment(.trailing)
        }
    }

    private func value(_ number: Double?, digits: Int) -> String {
        number?.formatted(.number.precision(.fractionLength(digits))) ?? "—"
    }
}
