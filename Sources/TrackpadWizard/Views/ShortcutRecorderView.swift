import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var shortcut: ShortcutDefinition
    @State private var isRecording = false

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "keyboard")
                Text(isRecording ? "Type Shortcut…" : shortcut.displayName)
                    .monospaced()
                    .frame(minWidth: 74)
            }
        }
        .buttonStyle(.bordered)
        .background {
            KeyCaptureRepresentable(
                isActive: isRecording,
                onCapture: { event in
                    shortcut = ShortcutDefinition(
                        keyCode: event.keyCode,
                        modifiers: ShortcutModifiers(eventFlags: event.modifierFlags),
                        keyLabel: KeyLabelFormatter.label(for: event)
                    )
                    isRecording = false
                },
                onCancel: { isRecording = false }
            )
            .frame(width: 1, height: 1)
        }
        .help("Click, then press the keyboard shortcut to assign")
    }
}

private struct KeyCaptureRepresentable: NSViewRepresentable {
    let isActive: Bool
    let onCapture: (NSEvent) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        nsView.isActive = isActive
        guard isActive else { return }
        DispatchQueue.main.async { [weak nsView] in
            guard let nsView, nsView.isActive else { return }
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyCaptureNSView: NSView {
    var isActive = false
    var onCapture: ((NSEvent) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { isActive }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            onCapture?(event)
        }
    }

    override func resignFirstResponder() -> Bool {
        if isActive { onCancel?() }
        return super.resignFirstResponder()
    }
}
