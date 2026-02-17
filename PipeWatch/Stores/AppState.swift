import Foundation
import SwiftUI
import ServiceManagement

@Observable
@MainActor
final class AppState {
    // MARK: - Settings (persisted in UserDefaults)

    var gitlabInstanceURL: String {
        didSet { UserDefaults.standard.set(gitlabInstanceURL, forKey: "gitlabInstanceURL") }
    }

    var pollingInterval: TimeInterval {
        didSet { UserDefaults.standard.set(pollingInterval, forKey: "pollingInterval") }
    }

    var notifyOnSuccess: Bool {
        didSet { UserDefaults.standard.set(notifyOnSuccess, forKey: "notifyOnSuccess") }
    }

    var notifyOnFailure: Bool {
        didSet { UserDefaults.standard.set(notifyOnFailure, forKey: "notifyOnFailure") }
    }

    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("[AppState] Failed to update login item: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - Runtime State

    var currentUser: GitLabUser?
    var trackedPipelines: [TrackedPipeline] = []
    var isConnected: Bool = false
    var isPolling: Bool = false
    var lastError: String?
    var lastRefresh: Date?
    var showingSettings: Bool = false


    // MARK: - Token (Keychain)

    private static let tokenKey = "gitlab_pat"

    var token: String {
        get { KeychainHelper.load(key: Self.tokenKey) ?? "" }
        set {
            if newValue.isEmpty {
                KeychainHelper.delete(key: Self.tokenKey)
            } else {
                try? KeychainHelper.save(key: Self.tokenKey, value: newValue)
            }
        }
    }

    var isConfigured: Bool {
        !token.isEmpty && !gitlabInstanceURL.isEmpty
    }

    // MARK: - Computed

    /// Only considers the latest pipeline per project+branch to avoid
    /// stale failures overshadowing a newer passing pipeline.
    /// Uses the highest pipeline ID (most recently created) as the source of truth.
    private var latestStatuses: [PipelineStatus] {
        var seen: [String: TrackedPipeline] = [:]
        for tracked in trackedPipelines {
            let key = "\(tracked.projectID)/\(tracked.pipeline.ref)"
            let existing = seen[key]
            if existing == nil || tracked.pipeline.id > existing!.pipeline.id {
                seen[key] = tracked
            }
        }
        return seen.values.map(\.effectiveStatus)
    }

    var menuBarIcon: String {
        if !isConfigured { return "gear.badge.questionmark" }
        if !isConnected { return "network.slash" }

        let statuses = latestStatuses
        if statuses.contains(.failed) { return "xmark.circle.fill" }
        if statuses.contains(.running) { return "play.circle.fill" }
        if statuses.contains(.pending) || statuses.contains(.created) { return "clock.fill" }
        if statuses.contains(.manual) { return "hand.raised.fill" }
        if statuses.contains(.success) { return "checkmark.circle.fill" }
        return "circle.fill"
    }

    var menuBarColor: Color {
        if !isConfigured || !isConnected { return .secondary }

        let statuses = latestStatuses
        if statuses.contains(.failed) { return .red }
        if statuses.contains(.running) { return .blue }
        if statuses.contains(.pending) || statuses.contains(.created) { return .orange }
        if statuses.contains(.manual) { return .purple }
        if statuses.contains(.success) { return .green }
        return .secondary
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        self.gitlabInstanceURL = defaults.string(forKey: "gitlabInstanceURL") ?? "https://gitlab.com"
        self.pollingInterval = defaults.double(forKey: "pollingInterval").nonZero ?? 30.0
        self.notifyOnSuccess = defaults.object(forKey: "notifyOnSuccess") as? Bool ?? true
        self.notifyOnFailure = defaults.object(forKey: "notifyOnFailure") as? Bool ?? true
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Helpers

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
