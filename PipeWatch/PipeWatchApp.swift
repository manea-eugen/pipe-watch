import SwiftUI
import ServiceManagement

@main
struct PipeWatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                appState: appDelegate.appState,
                onRefresh: { appDelegate.monitor.pollNow() },
                onRestart: { appDelegate.monitor.restart() }
            )
        } label: {
            Label("Pipelines", systemImage: appDelegate.appState.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

}

// MARK: - Menu Content

private struct MenuContentView: View {
    let appState: AppState
    let onRefresh: () -> Void
    let onRestart: () -> Void

    var body: some View {
        if appState.showingSettings {
            SettingsView(appState: appState, onSave: onRestart)
        } else {
            PipelineListView(appState: appState, onRefresh: onRefresh)
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
