import Foundation
import SwiftUI

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

    var menuBarIcon: String {
        if !isConfigured { return "gear.badge.questionmark" }
        if !isConnected { return "network.slash" }

        let active = trackedPipelines.map(\.pipeline.status)
        if active.contains(.failed) { return "xmark.circle.fill" }
        if active.contains(.running) { return "play.circle.fill" }
        if active.contains(.pending) || active.contains(.created) { return "clock.fill" }
        if active.contains(.success) { return "checkmark.circle.fill" }
        return "circle.fill"
    }

    var menuBarColor: Color {
        if !isConfigured || !isConnected { return .secondary }

        let active = trackedPipelines.map(\.pipeline.status)
        if active.contains(.failed) { return .red }
        if active.contains(.running) { return .blue }
        if active.contains(.pending) || active.contains(.created) { return .orange }
        if active.contains(.success) { return .green }
        return .secondary
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        self.gitlabInstanceURL = defaults.string(forKey: "gitlabInstanceURL") ?? "https://gitlab.com"
        self.pollingInterval = defaults.double(forKey: "pollingInterval").nonZero ?? 30.0
        self.notifyOnSuccess = defaults.object(forKey: "notifyOnSuccess") as? Bool ?? true
        self.notifyOnFailure = defaults.object(forKey: "notifyOnFailure") as? Bool ?? true
    }
}

// MARK: - Helpers

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
