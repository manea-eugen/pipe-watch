import SwiftUI

struct PipelineListView: View {
    let appState: AppState
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            if !appState.isConfigured {
                notConfiguredView
            } else if let error = appState.lastError {
                errorView(error)
            } else if appState.trackedPipelines.isEmpty {
                emptyView
            } else {
                pipelineList
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 360)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if let user = appState.currentUser {
                Text("Hi, \(user.name)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("PipeWatch")
                    .font(.system(size: 12, weight: .medium))
            }

            Spacer()

            if appState.isPolling {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .disabled(appState.isPolling)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Pipeline List

    private var pipelineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedPipelines) { tracked in
                    PipelineRowView(tracked: tracked)
                    if tracked.id != sortedPipelines.last?.id {
                        Divider()
                            .padding(.leading, 34)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(maxHeight: 400)
    }

    private var sortedPipelines: [TrackedPipeline] {
        appState.trackedPipelines.sorted { lhs, rhs in
            let lhsDate = lhs.pipeline.createdAt ?? .distantPast
            let rhsDate = rhs.pipeline.createdAt ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    // MARK: - Empty / Error States

    private var notConfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemName: "gear.badge.questionmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Not configured")
                .font(.system(size: 13, weight: .medium))
            Text("Open settings to add your GitLab token.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text("Connection Error")
                .font(.system(size: 13, weight: .medium))
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No recent pipelines")
                .font(.system(size: 13, weight: .medium))
            Text("Push some commits and they'll appear here.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let lastRefresh = appState.lastRefresh {
                Text("Updated \(lastRefresh, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                appState.showingSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
