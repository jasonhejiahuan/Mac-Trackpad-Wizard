import AppKit
import SwiftUI

@main
struct TrackpadWizardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Trackpad Wizard", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 980, minHeight: 660)
                .onAppear {
                    appDelegate.onTerminate = {
                        model.shutDown()
                    }
                }
        }
        .defaultSize(width: 1240, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            TrackpadWizardCommands(model: model)
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
    }
}

struct TrackpadWizardCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Trackpad") {
            ForEach(AppSection.allCases) { section in
                Button("Open \(section.title)") {
                    model.selection = section
                }
                .keyboardShortcut(KeyEquivalent(section.keyboardNumber), modifiers: [.command])
            }

            Divider()

            Button(model.isRecording ? "Stop Recording" : "Start Recording") {
                model.toggleRecording()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Play Selected Haptic") {
                model.playSelectedHaptic()
            }
            .keyboardShortcut("h", modifiers: [.command, .option])

            Button("Clear Touch Session") {
                model.clearSession()
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
        }
    }
}
