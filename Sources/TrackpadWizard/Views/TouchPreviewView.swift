import AppKit
import SwiftUI

struct TouchPreviewView: View {
    @Bindable var model: AppModel
    @State private var window: NSWindow?

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                TouchPreviewControls(model: model)

                Text(
                    "\(model.surfaceWidthMM.formatted(.number.precision(.fractionLength(1)))) × \(model.surfaceHeightMM.formatted(.number.precision(.fractionLength(1)))) mm"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                Button {
                    window?.toggleFullScreen(nil)
                } label: {
                    Label("Toggle Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .labelStyle(.iconOnly)
                .help("Toggle Full Screen")
            }

            InteractiveTrackpadSurface(
                model: model,
                showCaptureHint: true,
                presentation: .previewWindow
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(18)
        .background {
            WindowAccessor(window: $window)
                .frame(width: 0, height: 0)
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> WindowAccessorView {
        let view = WindowAccessorView()
        view.onWindowChange = { newWindow in
            DispatchQueue.main.async {
                window = newWindow
            }
        }
        return view
    }

    func updateNSView(_ nsView: WindowAccessorView, context: Context) {
        nsView.onWindowChange = { newWindow in
            DispatchQueue.main.async {
                window = newWindow
            }
        }
        nsView.publishWindow()
    }
}

private final class WindowAccessorView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        publishWindow()
    }

    func publishWindow() {
        onWindowChange?(window)
    }
}
