import Foundation
@preconcurrency import UserNotifications
import AppKit

@MainActor
final class NotificationManager: NSObject {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    func requestPermission() async {
        do {
            try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error.localizedDescription)")
        }
    }

    func send(title: String, body: String, url: String? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "PIPELINE_STATUS"

        if let url {
            content.userInfo["url"] = url
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        do {
            try await center.add(request)
        } catch {
            print("Failed to deliver notification: \(error.localizedDescription)")
        }
    }

    private func registerCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_IN_BROWSER",
            title: "Open in GitLab",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: "PIPELINE_STATUS",
            actions: [openAction],
            intentIdentifiers: []
        )

        center.setNotificationCategories([category])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: @preconcurrency UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.actionIdentifier == "OPEN_IN_BROWSER"
            || response.actionIdentifier == UNNotificationDefaultActionIdentifier
        {
            if let urlString = userInfo["url"] as? String,
               let url = URL(string: urlString)
            {
                NSWorkspace.shared.open(url)
            }
        }

        completionHandler()
    }
}
