import SwiftUI

struct OverviewView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    "Make the surface visible.",
                    subtitle: "Explore contacts, gestures, pressure, haptics, and mappings with native macOS tools."
                ) {
                    Button {
                        model.selection = .touchLab
                    } label: {
                        Label("Open Touch Lab", systemImage: "hand.point.up.left.fill")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }

                GlassEffectContainer(spacing: 14) {
                    HStack(spacing: 14) {
                        MetricTile(
                            title: "Trackpads",
                            value: "\(model.connectedTrackpadCount)",
                            systemImage: "rectangle.connected.to.line.below",
                            detail: model.externalTrackpadCount > 0
                                ? "\(model.externalTrackpadCount) external"
                                : "Built-in only"
                        )
                        MetricTile(
                            title: "Live Contacts",
                            value: "\(model.activeContactCount)",
                            systemImage: "hand.raised.fingers.spread",
                            detail: model.latestTouchSource.title
                        )
                        MetricTile(
                            title: "Sample Rate",
                            value: model.estimatedSampleRate > 0
                                ? "\(Int(model.estimatedSampleRate.rounded())) Hz"
                                : "—",
                            systemImage: "gauge.with.dots.needle.50percent",
                            detail: "Observed UI stream"
                        )
                        MetricTile(
                            title: "Force Touch",
                            value: model.hasForceTouchDevice ? "Ready" : "Unknown",
                            systemImage: "circle.dotted.circle",
                            detail: model.hasForceTouchDevice ? "Haptic device found" : "Refresh Devices"
                        )
                    }
                }

                HStack(alignment: .top, spacing: 18) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Trackpad, as an instrument")
                                        .font(.title2.weight(.semibold))
                                    Text("A small laboratory for the hardware already under your fingers.")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "hand.point.up.left.fill")
                                    .font(.system(size: 46, weight: .light))
                                    .foregroundStyle(.tertiary)
                            }

                            Divider()

                            Grid(alignment: .leading, horizontalSpacing: 26, verticalSpacing: 18) {
                                GridRow {
                                    FeatureRow(
                                        systemImage: "point.3.connected.trianglepath.dotted",
                                        title: "Touch Debugger",
                                        detail: "See each contact, phase, resting state, trajectory, and heat accumulation."
                                    )
                                    FeatureRow(
                                        systemImage: "waveform.path.ecg",
                                        title: "Pressure Lab",
                                        detail: "Inspect Force Click stages or opt into raw pressure and contact geometry."
                                    )
                                }
                                GridRow {
                                    FeatureRow(
                                        systemImage: "waveform",
                                        title: "Haptic Composer",
                                        detail: "Build tactile phrases from timed pulses and real actuator waveforms."
                                    )
                                    FeatureRow(
                                        systemImage: "command.square",
                                        title: "Gesture Mapping",
                                        detail: "Map swipes, pinches, rotation, and Force Click to shortcuts or haptics."
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        QuickAction(
                            title: "Compose a haptic",
                            detail: model.hapticEngine.enhancedAvailable
                                ? "Enhanced actuator active"
                                : "Enhanced actuator not enabled",
                            systemImage: "waveform",
                            action: { model.selection = .haptics }
                        )
                        QuickAction(
                            title: "Create a mapping",
                            detail: model.mappingsEnabled ? "Mappings enabled" : "Mappings paused",
                            systemImage: "arrow.triangle.branch",
                            action: { model.selection = .mappings }
                        )
                        QuickAction(
                            title: "Inspect devices",
                            detail: "Live IOKit and system settings",
                            systemImage: "info.circle",
                            action: { model.selection = .devices }
                        )
                    }
                    .frame(width: 310)
                }

                if model.showInterfaceHints {
                    GlassCard(padding: 15) {
                        InlineNotice(
                            systemImage: "lock.shield",
                            title: "Local by design",
                            message: "Touch frames, mappings, and exports stay on this Mac. Enhanced touch and haptics are optional, clearly labeled, and active only for the current session."
                        )
                    }
                }
            }
            .pageLayout()
        }
    }
}

private struct QuickAction: View {
    let title: String
    let detail: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(padding: 15) {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 23)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
