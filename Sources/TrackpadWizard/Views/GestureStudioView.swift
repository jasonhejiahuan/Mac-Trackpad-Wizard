import SwiftUI

struct GestureStudioView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    "Gesture Studio",
                    subtitle: "Inspect AppKit gesture events and test the recognizers used by mappings."
                ) {
                    Button("Clear Events") {
                        model.nativeGestureSamples = []
                        model.recognizedGestures = []
                    }
                }

                TouchPreviewControls(model: model, showsRestingTouches: true)

                GlassEffectContainer(spacing: 12) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 190), spacing: 12)],
                        spacing: 12
                    ) {
                        MetricTile(
                            title: "Magnification",
                            value: signed(model.liveMagnification, digits: 3),
                            systemImage: "arrow.up.left.and.arrow.down.right",
                            detail: "Accumulated"
                        )
                        MetricTile(
                            title: "Rotation",
                            value: "\(signed(model.liveRotation, digits: 1))°",
                            systemImage: "rotate.right",
                            detail: "Accumulated"
                        )
                        MetricTile(
                            title: "Scroll X / Y",
                            value: "\(signed(model.liveScrollX, digits: 0)) / \(signed(model.liveScrollY, digits: 0))",
                            systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                            detail: "Latest delta"
                        )
                        MetricTile(
                            title: "Force Stage",
                            value: "\(model.pressureStage)",
                            systemImage: "circle.dotted.circle",
                            detail: model.pressureProxy > 0
                                ? "\(model.pressureProxy.formatted(.number.precision(.fractionLength(2)))) pressure"
                                : "No event"
                        )
                    }
                }

                AdaptiveColumnsLayout(breakpoint: 900, spacing: 18, trailingWidth: 360) {
                    VStack(spacing: 14) {
                        InteractiveTrackpadSurface(model: model)

                        if model.showInterfaceHints {
                            GlassCard(padding: 15) {
                                InlineNotice(
                                    systemImage: "hand.draw",
                                    title: "Try it here",
                                    message: "Place the pointer over the surface, then pinch, rotate, swipe, scroll, or Force Click. Three-finger swipes are also derived from contact centroids when available."
                                )
                            }
                        }
                    }

                    VStack(spacing: 14) {
                        recognizedCard
                        eventStreamCard
                    }
                }
            }
            .pageLayout()
        }
    }

    private var recognizedCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Recognized", systemImage: "sparkles.rectangle.stack")
                        .font(.headline)
                    Spacer()
                    Text("\(model.recognizedGestures.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if model.recognizedGestures.isEmpty {
                    Text("Completed gestures appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .center)
                } else {
                    ForEach(model.recognizedGestures.prefix(5)) { event in
                        HStack(spacing: 10) {
                            Image(systemName: event.trigger.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text(event.trigger.title)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(event.source.title)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private var eventStreamCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Native Event Stream", systemImage: "waveform.path.ecg")
                        .font(.headline)
                    Spacer()
                    Text("latest")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if model.nativeGestureSamples.isEmpty {
                    ContentUnavailableView(
                        "Waiting for a Gesture",
                        systemImage: "waveform.path",
                        description: Text("AppKit events will appear live.")
                    )
                    .frame(height: 220)
                } else {
                    ForEach(model.nativeGestureSamples.prefix(10)) { sample in
                        HStack(spacing: 10) {
                            Image(systemName: sample.kind.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sample.kind.title)
                                    .font(.subheadline.weight(.medium))
                                Text(detail(for: sample))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func signed(_ value: Double, digits: Int) -> String {
        value.formatted(
            .number
                .sign(strategy: .always(includingZero: false))
                .precision(.fractionLength(digits))
        )
    }

    private func detail(for sample: NativeGestureSample) -> String {
        switch sample.kind {
        case .magnify, .rotate:
            signed(sample.primaryValue, digits: 3)
        case .swipe, .scroll:
            "x \(signed(sample.primaryValue, digits: 1))  y \(signed(sample.secondaryValue, digits: 1))"
        case .pressure:
            "pressure \(sample.primaryValue.formatted(.number.precision(.fractionLength(2))))  stage \(sample.stage)"
        case .gestureBegan, .gestureEnded:
            "gesture lifecycle"
        }
    }
}
