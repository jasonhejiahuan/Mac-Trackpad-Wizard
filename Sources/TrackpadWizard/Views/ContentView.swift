import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $model.selection,
                deviceCount: model.connectedTrackpadCount,
                experimentalFeatureCount: model.advancedFeatures.enabledFeatureCount,
                showsHints: model.showInterfaceHints
            )
                .navigationSplitViewColumnWidth(min: 210, ideal: 238, max: 280)
        } detail: {
            VStack(spacing: 0) {
                EnhancedModeBar(model: model)
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 2)

                detail
            }
                .navigationTitle(model.selection.title)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            model.toggleRecording()
                        } label: {
                            Label(
                                model.isRecording ? "Stop Recording" : "Record Session",
                                systemImage: model.isRecording ? "stop.circle.fill" : "record.circle"
                            )
                        }
                        .help(model.isRecording ? "Stop the current recording" : "Record touch frames locally")
                    }

                    ToolbarSpacer(.fixed)

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            model.showInterfaceHints.toggle()
                        } label: {
                            Label(
                                model.showInterfaceHints ? "Hide Interface Hints" : "Show Interface Hints",
                                systemImage: model.showInterfaceHints ? "text.bubble.fill" : "text.bubble"
                            )
                        }
                        .help(model.showInterfaceHints ? "Hide interface hints" : "Show interface hints")
                    }

                    ToolbarSpacer(.fixed)

                    ToolbarItem(placement: .primaryAction) {
                        SettingsLink {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if let message = model.statusMessage {
                        StatusToast(message: message) {
                            model.statusMessage = nil
                        }
                        .padding(18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: model.statusMessage)
        }
        .sheet(item: pendingAdvancedConfirmation) { confirmation in
            AdvancedRecoveryDialog(
                confirmation: confirmation,
                restore: {
                    model.advancedFeatures.restorePendingChange()
                    model.statusMessage = model.advancedFeatures.lastMessage
                },
                continueUsing: {
                    model.advancedFeatures.confirmPendingChange()
                    model.statusMessage = model.advancedFeatures.lastMessage
                }
            )
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection {
        case .overview:
            OverviewView(model: model)
        case .touchLab:
            TouchLabView(model: model)
        case .gestureStudio:
            GestureStudioView(model: model)
        case .haptics:
            HapticsView(model: model)
        case .mappings:
            MappingsView(model: model)
        case .advanced:
            AdvancedFeaturesView(model: model)
        case .statistics:
            StatisticsView(model: model)
        case .devices:
            DevicesView(model: model)
        }
    }

    private var pendingAdvancedConfirmation: Binding<AdvancedFeatureConfirmation?> {
        Binding(
            get: { model.advancedFeatures.pendingConfirmation },
            set: { newValue in
                if newValue == nil, model.advancedFeatures.pendingConfirmation != nil {
                    model.advancedFeatures.restorePendingChange()
                }
            }
        )
    }
}

private struct StatusToast: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
            Button("Dismiss", action: dismiss)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .glassEffect(.regular.interactive(), in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }
}
