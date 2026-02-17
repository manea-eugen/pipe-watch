import SwiftUI
import ServiceManagement

@main
struct PipeWatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            menuContent
        } label: {
            Label("Pipelines", systemImage: appDelegate.appState.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuContent: some View {
        if appDelegate.appState.showingSettings {
            SettingsView(appState: appDelegate.appState) {
                appDelegate.monitor.restart()
            }
        } else {
            PipelineListView(appState: appDelegate.appState) {
                appDelegate.monitor.pollNow()
            }
        }
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let notificationManager = NotificationManager()
    private(set) lazy var monitor = PipelineMonitor(
        appState: appState,
        notificationManager: notificationManager
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        notificationManager.requestPermission()
        monitor.start()
        promptLaunchAtLoginIfNeeded()
    }

    private func promptLaunchAtLoginIfNeeded() {
        let hasPrompted = UserDefaults.standard.bool(forKey: "hasPromptedLaunchAtLogin")
        guard !hasPrompted else { return }

        UserDefaults.standard.set(true, forKey: "hasPromptedLaunchAtLogin")

        let alert = NSAlert()
        alert.messageText = "Launch at Login?"
        alert.informativeText = "Would you like PipeWatch to start automatically when you log in?"
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        alert.alertStyle = .informational

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            appState.launchAtLogin = true
        }
    }
}
