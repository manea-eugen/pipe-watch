import SwiftUI

@main
struct PipelineNotificationsApp: App {
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
    }
}
