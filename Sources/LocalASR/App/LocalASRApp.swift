import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct LocalASRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup("本地 ASR") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 620)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        appState.stopEngine()
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .textEditing) {
                Button("复制识别结果") {
                    appState.copyTranscript()
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView(llmStore: appState.llmStore)
                .environmentObject(appState)
        }
    }
}
