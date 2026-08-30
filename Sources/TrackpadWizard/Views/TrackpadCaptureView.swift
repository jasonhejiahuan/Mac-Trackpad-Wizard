import AppKit
import SwiftUI

/// A narrowly scoped AppKit bridge for the public indirect-touch and gesture APIs.
/// AppKit only sends these touches while the pointer is over this view.
struct TrackpadCaptureView: NSViewRepresentable {
    let onFrame: (TouchFrame) -> Void
    let onGesture: (NativeGestureSample) -> Void
    var onClick: ((TimeInterval, Double?) -> Void)?

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onFrame = onFrame
        view.onGesture = onGesture
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        nsView.onFrame = onFrame
        nsView.onGesture = onGesture
        nsView.onClick = onClick
    }
}

final class CaptureNSView: NSView {
    var onFrame: ((TouchFrame) -> Void)?
    var onGesture: ((NativeGestureSample) -> Void)?
    var onClick: ((TimeInterval, Double?) -> Void)?

    private var identifiers: [ObjectIdentifier: Int] = [:]
    private var nextIdentifier = 1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
        pressureConfiguration = NSPressureConfiguration(pressureBehavior: .primaryDeepClick)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?(
            event.timestamp,
            event.pressure > 0 ? Double(event.pressure) : nil
        )
        super.mouseDown(with: event)
    }

    override func touchesBegan(with event: NSEvent) { publishTouches(from: event) }
    override func touchesMoved(with event: NSEvent) { publishTouches(from: event) }
    override func touchesEnded(with event: NSEvent) { publishTouches(from: event) }
    override func touchesCancelled(with event: NSEvent) { publishTouches(from: event) }

    override func beginGesture(with event: NSEvent) {
        onGesture?(
            NativeGestureSample(kind: .gestureBegan, timestamp: event.timestamp)
        )
    }

    override func endGesture(with event: NSEvent) {
        onGesture?(
            NativeGestureSample(kind: .gestureEnded, timestamp: event.timestamp)
        )
    }

    override func magnify(with event: NSEvent) {
        onGesture?(
            NativeGestureSample(
                kind: .magnify,
                timestamp: event.timestamp,
                primaryValue: event.magnification
            )
        )
    }

    override func rotate(with event: NSEvent) {
        onGesture?(
            NativeGestureSample(
                kind: .rotate,
                timestamp: event.timestamp,
                primaryValue: Double(event.rotation)
            )
        )
    }

    override func swipe(with event: NSEvent) {
        onGesture?(
            NativeGestureSample(
                kind: .swipe,
                timestamp: event.timestamp,
                primaryValue: event.deltaX,
                secondaryValue: event.deltaY
            )
        )
    }

    override func scrollWheel(with event: NSEvent) {
        onGesture?(
            NativeGestureSample(
                kind: .scroll,
                timestamp: event.timestamp,
                primaryValue: event.scrollingDeltaX,
                secondaryValue: event.scrollingDeltaY,
                precise: event.hasPreciseScrollingDeltas
            )
        )
    }

    override func pressureChange(with event: NSEvent) {
        onGesture?(
            NativeGestureSample(
                kind: .pressure,
                timestamp: event.timestamp,
                primaryValue: Double(event.pressure),
                stage: event.stage
            )
        )
    }

    private func publishTouches(from event: NSEvent) {
        let touches = event.touches(matching: .any, in: self)
        let contacts = touches.map { touch in
            let identity = ObjectIdentifier(touch.identity as AnyObject)
            let identifier: Int
            if let known = identifiers[identity] {
                identifier = known
            } else {
                identifier = nextIdentifier
                identifiers[identity] = identifier
                nextIdentifier += 1
            }

            return TouchContact(
                id: identifier,
                x: touch.normalizedPosition.x,
                y: touch.normalizedPosition.y,
                phase: Self.phase(for: touch.phase),
                isResting: touch.isResting,
                deviceWidth: touch.deviceSize.width,
                deviceHeight: touch.deviceSize.height
            )
        }
        onFrame?(TouchFrame(timestamp: event.timestamp, contacts: contacts))

        for touch in touches where touch.phase == .ended || touch.phase == .cancelled {
            identifiers[ObjectIdentifier(touch.identity as AnyObject)] = nil
        }
    }

    private static func phase(for phase: NSTouch.Phase) -> TouchContactPhase {
        switch phase {
        case .began: .began
        case .moved: .moved
        case .stationary: .stationary
        case .ended: .ended
        case .cancelled: .cancelled
        default: .cancelled
        }
    }
}

enum TrackpadSurfacePresentation {
    case embedded
    case previewWindow
}

struct InteractiveTrackpadSurface: View {
    let model: AppModel
    var showCaptureHint = true
    var presentation: TrackpadSurfacePresentation = .embedded

    @Environment(\.scenePhase) private var scenePhase
    @State private var displayMetrics = DisplayMetrics.fallback

    var body: some View {
        Group {
            if model.touchSurfaceSizeMode == .physical {
                ScrollView([.horizontal, .vertical]) {
                    surface
                        .frame(width: physicalSize.width, height: physicalSize.height)
                        .padding(4)
                        .frame(maxWidth: .infinity)
                }
                .frame(
                    height: presentation == .embedded ? physicalSize.height + 8 : nil
                )
                .frame(maxHeight: presentation == .previewWindow ? .infinity : nil)
            } else {
                surface
                    .aspectRatio(surfaceAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: presentation == .previewWindow ? .infinity : nil)
            }
        }
        .overlay {
            DisplayMetricsReader { metrics in
                if displayMetrics != metrics {
                    displayMetrics = metrics
                }
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        .accessibilityLabel("Interactive trackpad touch surface")
        .accessibilityValue(
            model.touchSurfaceSizeMode == .physical
                ? "Physical size on \(displayMetrics.displayName)"
                : model.touchSurfaceSizeMode.title
        )
    }

    private var surface: some View {
        ZStack {
            artwork

            TrackpadCaptureView(
                onFrame: model.handleTouchFrame,
                onGesture: model.handleGesture,
                onClick: nil
            )

            if showCaptureHint && model.activeContactCount == 0 {
                VStack(spacing: 8) {
                    Image(systemName: "hand.point.up.left")
                        .font(.system(size: 27, weight: .light))
                    Text("Move the pointer here, then touch the trackpad")
                        .font(.subheadline.weight(.medium))
                    Text(model.enhancedTouchEnabled
                         ? "Enhanced mode also listens outside this surface"
                         : "Public touch events are scoped to this surface")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
    }

    @ViewBuilder
    private var artwork: some View {
        if model.visualizationMode == .contacts || scenePhase != .active {
            trackpadArtwork(at: ProcessInfo.processInfo.systemUptime)
        } else {
            TimelineView(
                .periodic(
                    from: .now,
                    by: 1 / min(max(model.visualizationRefreshRate, 5), 60)
                )
            ) { _ in
                trackpadArtwork(at: ProcessInfo.processInfo.systemUptime)
            }
        }
    }

    private func trackpadArtwork(at time: TimeInterval) -> some View {
        TrackpadSurfaceArtwork(
            contacts: model.visibleContacts,
            trails: model.trailPoints,
            heatmap: model.heatmap,
            heatmapUpdatedAt: model.heatmapUpdatedAt,
            mode: model.visualizationMode,
            currentTime: time,
            trailLifetime: model.trailLifetime,
            heatmapHalfLife: model.heatmapHalfLife
        )
    }

    private var physicalSize: CGSize {
        CGSize(
            width: model.surfaceWidthMM * displayMetrics.pointsPerMillimeterX,
            height: model.surfaceHeightMM * displayMetrics.pointsPerMillimeterY
        )
    }

    private var surfaceAspectRatio: Double {
        guard model.surfaceHeightMM > 0 else { return 1.55 }
        return model.surfaceWidthMM / model.surfaceHeightMM
    }
}

private struct TrackpadSurfaceArtwork: View {
    let contacts: [TouchContact]
    let trails: [TouchTrailPoint]
    let heatmap: [Double]
    let heatmapUpdatedAt: TimeInterval
    let mode: TouchVisualizationMode
    let currentTime: TimeInterval
    let trailLifetime: Double
    let heatmapHalfLife: Double

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let shape = Path(roundedRect: rect, cornerRadius: 30)
            context.fill(shape, with: .color(Color(nsColor: .controlBackgroundColor).opacity(0.86)))

            switch mode {
            case .contacts:
                drawContacts(context: &context, size: size)
            case .trails:
                drawTrails(context: &context, size: size)
                drawContacts(context: &context, size: size)
            case .heatmap:
                drawHeatmap(context: &context, size: size)
                drawContacts(context: &context, size: size, labels: false)
            }
        }
        .background(.thinMaterial)
    }

    private func drawContacts(
        context: inout GraphicsContext,
        size: CGSize,
        labels: Bool = true
    ) {
        for contact in contacts where contact.phase.isActive {
            let point = screenPoint(x: contact.x, y: contact.y, size: size)
            let rawPressure = contact.pressureProxy ?? 0.35
            let radius = 12 + min(max(rawPressure, 0), 1.4) * 9
            let circle = Path(
                ellipseIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
            context.fill(circle, with: .color(.primary.opacity(contact.isResting ? 0.16 : 0.68)))
            context.stroke(circle, with: .color(.primary.opacity(0.85)), lineWidth: 1)
            if labels {
                context.draw(
                    Text("\(contact.id)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color(nsColor: .windowBackgroundColor)),
                    at: point
                )
            }
        }
    }

    private func drawTrails(context: inout GraphicsContext, size: CGSize) {
        for point in trails.suffix(1_000) {
            let age = max(0, currentTime - point.timestamp)
            guard age <= trailLifetime else { continue }
            let opacity = max(0.02, 0.48 * (1 - (age / max(trailLifetime, 0.1))))
            let position = screenPoint(x: point.x, y: point.y, size: size)
            let dot = Path(ellipseIn: CGRect(x: position.x - 2, y: position.y - 2, width: 4, height: 4))
            context.fill(dot, with: .color(.primary.opacity(opacity)))
        }
    }

    private func drawHeatmap(context: inout GraphicsContext, size: CGSize) {
        guard heatmap.count == 24 * 16 else { return }
        let elapsed = max(0, currentTime - heatmapUpdatedAt)
        let idleDecay = pow(0.5, elapsed / max(heatmapHalfLife, 0.1))
        let cellWidth = size.width / 24
        let cellHeight = size.height / 16
        for y in 0..<16 {
            for x in 0..<24 {
                let value = min(max(heatmap[y * 24 + x] * idleDecay, 0), 1)
                guard value > 0.015 else { continue }
                let center = CGPoint(
                    x: (CGFloat(x) + 0.5) * cellWidth,
                    y: size.height - (CGFloat(y) + 0.5) * cellHeight
                )
                let radius = max(cellWidth, cellHeight) * 2.4
                let blob = Path(
                    ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                )
                context.fill(blob, with: .color(.primary.opacity(value * 0.08)))
            }
        }
    }

    private func screenPoint(x: Double, y: Double, size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(x, 0), 1) * size.width,
            y: (1 - min(max(y, 0), 1)) * size.height
        )
    }
}
