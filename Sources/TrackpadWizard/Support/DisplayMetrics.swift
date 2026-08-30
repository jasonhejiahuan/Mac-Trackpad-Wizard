import AppKit
import SwiftUI

struct DisplayMetrics: Equatable, Sendable {
    let pointsPerMillimeterX: Double
    let pointsPerMillimeterY: Double
    let displayName: String
    let isPhysicalSizeReported: Bool

    static let fallback = DisplayMetrics(
        pointsPerMillimeterX: 72 / 25.4,
        pointsPerMillimeterY: 72 / 25.4,
        displayName: "Current Display",
        isPhysicalSizeReported: false
    )
}

struct DisplayMetricsReader: NSViewRepresentable {
    let onChange: (DisplayMetrics) -> Void

    func makeNSView(context: Context) -> DisplayMetricsNSView {
        let view = DisplayMetricsNSView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: DisplayMetricsNSView, context: Context) {
        nsView.onChange = onChange
        nsView.reportMetrics()
    }
}

final class DisplayMetricsNSView: NSView {
    var onChange: ((DisplayMetrics) -> Void)?
    private var lastMetrics: DisplayMetrics?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        if let window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDisplayChanged),
                name: NSWindow.didChangeScreenNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDisplayChanged),
                name: NSWindow.didChangeBackingPropertiesNotification,
                object: window
            )
        }
        reportMetrics()
    }

    @objc private func windowDisplayChanged() {
        reportMetrics()
    }

    func reportMetrics() {
        guard let screen = window?.screen ?? NSScreen.main else {
            publish(.fallback)
            return
        }

        let numberKey = NSDeviceDescriptionKey("NSScreenNumber")
        let displayID = (screen.deviceDescription[numberKey] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) }
        var millimeters = displayID.map(CGDisplayScreenSize) ?? .zero
        if let displayID {
            let rotation = abs(CGDisplayRotation(displayID)).truncatingRemainder(dividingBy: 360)
            if rotation == 90 || rotation == 270 {
                millimeters = CGSize(width: millimeters.height, height: millimeters.width)
            }
        }
        let valid = millimeters.width > 0 && millimeters.height > 0
        let metrics = DisplayMetrics(
            pointsPerMillimeterX: valid
                ? Double(screen.frame.width / millimeters.width)
                : DisplayMetrics.fallback.pointsPerMillimeterX,
            pointsPerMillimeterY: valid
                ? Double(screen.frame.height / millimeters.height)
                : DisplayMetrics.fallback.pointsPerMillimeterY,
            displayName: screen.localizedName,
            isPhysicalSizeReported: valid
        )
        publish(metrics)
    }

    private func publish(_ metrics: DisplayMetrics) {
        guard lastMetrics != metrics else { return }
        lastMetrics = metrics
        DispatchQueue.main.async { [weak self] in
            self?.onChange?(metrics)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
