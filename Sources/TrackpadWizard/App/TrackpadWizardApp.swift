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
                    appDelegate.onResignActive = {
                        model.handleAppDidResignActive()
                    }
                    appDelegate.onBecomeActive = {
                        model.handleAppDidBecomeActive()
                    }
                    model.startAutomaticUpdateCheckIfNeeded()
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

        Window("Touch Preview", id: "touch-preview") {
            TouchPreviewView(model: model)
                .frame(minWidth: 680, minHeight: 500)
        }
        .defaultSize(width: 1080, height: 760)
        .windowResizability(.contentMinSize)

        Window("About Trackpad Wizard", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?
    var onResignActive: (() -> Void)?
    var onBecomeActive: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
    }

    func applicationDidResignActive(_ notification: Notification) {
        onResignActive?()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        onBecomeActive?()
    }
}

struct TrackpadWizardCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Trackpad Wizard") {
                openWindow(id: "about")
            }
        }

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

            Divider()

            Button("Open Touch Preview") {
                openWindow(id: "touch-preview")
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
        }
    }
}
