import SwiftUI

struct EnhancedModeBar: View {
    @Bindable var model: AppModel
    @State private var showConfirmation = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: TrackpadSymbols.device(enhanced: model.enhancedModeEnabled))
                .font(.title3)
                .foregroundStyle(model.enhancedModeEnabled ? .primary : .secondary)
                .frame(width: 25)

            VStack(alignment: .leading, spacing: 1) {
                Text("Enhanced Mode")
                    .font(.subheadline.weight(.semibold))
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            if model.systemGesturesSuppressed {
                Label("Gestures Paused", systemImage: "hand.raised.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Target", selection: $model.touchTarget) {
                ForEach(HapticDeviceTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .labelsHidden()
            .frame(width: 165)

            Toggle("Enhanced Mode", isOn: enhancedModeBinding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .alert("Enable Enhanced Mode?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Enable for This Session") {
                _ = model.setEnhancedModeEnabled(true)
            }
        } message: {
            Text("Enhanced Mode loads private MultitouchSupport touch and actuator symbols. It is never restored automatically after launch, always turns off when the app quits, and may change after a macOS update.")
        }
    }

    private var enhancedModeBinding: Binding<Bool> {
        Binding(
            get: { model.enhancedModeEnabled },
            set: { enabled in
                if enabled {
                    showConfirmation = true
                } else {
                    _ = model.setEnhancedModeEnabled(false)
                }
            }
        )
    }

    private var statusDetail: String {
        if model.enhancedModeEnabled {
            return "Raw touch and direct actuator · \(model.touchTarget.title)"
        }
        return "Public AppKit touch · actuator output off"
    }
}
