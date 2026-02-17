import Foundation

@MainActor
final class PipelineMonitor {
    private let appState: AppState
    private let notificationManager: NotificationManager
    private var service: GitLabService?
    private var timer: Timer?

    /// Tracks previously known pipeline statuses for diffing
    private var knownStatuses: [Int: PipelineStatus] = [:]

    init(appState: AppState, notificationManager: NotificationManager) {
        self.appState = appState
        self.notificationManager = notificationManager
    }

    // MARK: - Lifecycle

    func start() {
        guard appState.isConfigured else { return }
        rebuildService()
        scheduleTimer()
        Task { await poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        appState.isPolling = false
    }

    func restart() {
        stop()
        knownStatuses.removeAll()
        start()
    }

    func pollNow() {
        Task { await poll() }
    }

    // MARK: - Service Management

    private func rebuildService() {
        guard let url = URL(string: appState.gitlabInstanceURL),
              !appState.token.isEmpty
        else {
            service = nil
            return
        }
        service = GitLabService(baseURL: url, token: appState.token)
    }

    // MARK: - Timer

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = max(appState.pollingInterval, 10) // minimum 10s
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.poll()
            }
        }
    }

    // MARK: - Polling

    private func poll() async {
        guard let service else {
            appState.isConnected = false
            appState.lastError = "Not configured"
            return
        }

        appState.isPolling = true
        defer { appState.isPolling = false }

        do {
            // 1. Fetch current user (cache after first call)
            if appState.currentUser == nil {
                let user = try await service.fetchCurrentUser()
                appState.currentUser = user
                NSLog("[PipelineMonitor] Logged in as: %@ (%@)", user.name, user.username)
            }

            guard let username = appState.currentUser?.username else {
                NSLog("[PipelineMonitor] No username available, skipping poll")
                return
            }

            // 2. Fetch recently active projects
            let oneDayAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
            let projects = try await service.fetchProjects(lastActivityAfter: oneDayAgo)
            NSLog("[PipelineMonitor] Fetched %d projects active in last 24h", projects.count)
            for project in projects {
                NSLog("[PipelineMonitor]   - [%d] %@", project.id, project.pathWithNamespace)
            }

            let ibexFound = projects.contains { $0.pathWithNamespace.contains("ibex") }
            NSLog("[PipelineMonitor] ibex project found in list: %@", ibexFound ? "YES" : "NO")

            // 3. Fetch pipelines for each project (concurrently)
            let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!

            var allTracked: [TrackedPipeline] = []

            await withTaskGroup(of: (GitLabProject, [Pipeline])?.self) { group in
                for project in projects {
                    group.addTask {
                        do {
                            let pipelines = try await service.fetchPipelines(
                                projectID: project.id,
                                username: username,
                                updatedAfter: oneHourAgo
                            )
                            if !pipelines.isEmpty {
                                NSLog("[PipelineMonitor] %@: %d pipelines", project.pathWithNamespace, pipelines.count)
                                for p in pipelines {
                                    NSLog("[PipelineMonitor]   #%d %@ on %@ (%@)", p.id, p.status.rawValue, p.ref, p.shortSHA)
                                }
                            }
                            return pipelines.isEmpty ? nil : (project, pipelines)
                        } catch {
                            NSLog("[PipelineMonitor] Error fetching pipelines for %@ [%d]: %@", project.pathWithNamespace, project.id, error.localizedDescription)
                            return nil
                        }
                    }
                }

                for await result in group {
                    guard let (project, pipelines) = result else { continue }
                    for pipeline in pipelines {
                        allTracked.append(TrackedPipeline(
                            pipeline: pipeline,
                            projectName: project.name,
                            projectID: project.id
                        ))
                    }
                }
            }

            NSLog("[PipelineMonitor] Total tracked pipelines: %d", allTracked.count)

            // 4. For branches where my latest pipeline failed, check if
            //    someone else has since fixed it (newer pipeline by anyone)
            var latestByRef: [String: TrackedPipeline] = [:]
            for tracked in allTracked {
                let key = "\(tracked.projectID)/\(tracked.pipeline.ref)"
                if latestByRef[key] == nil || tracked.pipeline.id > latestByRef[key]!.pipeline.id {
                    latestByRef[key] = tracked
                }
            }

            let failedRefs = latestByRef.values.filter { $0.pipeline.status == .failed }
            if !failedRefs.isEmpty {
                await withTaskGroup(of: TrackedPipeline?.self) { group in
                    for tracked in failedRefs {
                        group.addTask {
                            guard let latest = try? await service.fetchLatestPipeline(
                                projectID: tracked.projectID,
                                ref: tracked.pipeline.ref
                            ) else { return nil }
                            // Only add if it's newer than our failed pipeline
                            guard latest.id > tracked.pipeline.id else { return nil }
                            return TrackedPipeline(
                                pipeline: latest,
                                projectName: tracked.projectName,
                                projectID: tracked.projectID
                            )
                        }
                    }
                    for await result in group {
                        guard let fixed = result else { continue }
                        allTracked.append(fixed)
                    }
                }
            }

            // 5. Fetch jobs for all pipelines to detect current step, failures, and manual actions
            if !allTracked.isEmpty {
                await withTaskGroup(of: (Int, [PipelineJob]).self) { group in
                    for idx in allTracked.indices {
                        let tracked = allTracked[idx]
                        group.addTask {
                            let jobs = (try? await service.fetchJobs(
                                projectID: tracked.projectID,
                                pipelineID: tracked.pipeline.id
                            )) ?? []
                            return (idx, jobs)
                        }
                    }
                    for await (idx, jobs) in group {
                        let status = allTracked[idx].pipeline.status

                        if status.isActive {
                            allTracked[idx].currentJob = jobs.first(where: { $0.status == .running })
                                ?? jobs.first(where: { $0.status == .pending })
                                ?? jobs.first(where: { $0.status == .created })
                        }

                        if status == .failed {
                            if let failed = jobs.first(where: { $0.status == .failed }) {
                                allTracked[idx].failedJob = failed
                                let attempts = jobs.filter { $0.name == failed.name }.count
                                allTracked[idx].retryCount = max(0, attempts - 1)
                            }
                        }

                        // Detect manual jobs (pipeline may report "success" but still have pending manual actions)
                        let manualJobs = jobs.filter { $0.status == .manual }
                        if !manualJobs.isEmpty {
                            allTracked[idx].manualJobs = manualJobs
                        }
                    }
                }
            }

            // 6. Sort by newest pipeline first (highest ID = most recent)
            allTracked.sort { $0.pipeline.id > $1.pipeline.id }

            // 7. Detect state transitions and notify
            for tracked in allTracked {
                let pid = tracked.pipeline.id
                let newStatus = tracked.pipeline.status

                if let oldStatus = knownStatuses[pid], oldStatus != newStatus,
                   newStatus.isTerminal || newStatus == .manual {
                    sendNotification(for: tracked, from: oldStatus, to: newStatus)
                }

                knownStatuses[pid] = newStatus
            }

            // 8. Clean up old entries from knownStatuses
            let activeIDs = Set(allTracked.map(\.pipeline.id))
            knownStatuses = knownStatuses.filter { activeIDs.contains($0.key) }

            // 9. Update state
            appState.trackedPipelines = allTracked
            appState.isConnected = true
            appState.lastError = nil
            appState.lastRefresh = Date()

        } catch {
            NSLog("[PipelineMonitor] Poll error: %@", error.localizedDescription)
            appState.isConnected = false
            appState.lastError = error.localizedDescription
        }
    }

    // MARK: - Notifications

    private func sendNotification(for tracked: TrackedPipeline, from oldStatus: PipelineStatus, to newStatus: PipelineStatus) {
        switch newStatus {
        case .success where appState.notifyOnSuccess:
            notificationManager.send(
                title: "\(tracked.projectName)",
                body: "Pipeline #\(tracked.pipeline.id) passed on \(tracked.pipeline.ref)",
                url: tracked.pipeline.webURL
            )
        case .failed where appState.notifyOnFailure:
            notificationManager.send(
                title: "\(tracked.projectName)",
                body: "Pipeline #\(tracked.pipeline.id) failed on \(tracked.pipeline.ref)",
                url: tracked.pipeline.webURL
            )
        case .canceled:
            notificationManager.send(
                title: "\(tracked.projectName)",
                body: "Pipeline #\(tracked.pipeline.id) was canceled on \(tracked.pipeline.ref)",
                url: tracked.pipeline.webURL
            )
        case .manual:
            notificationManager.send(
                title: "\(tracked.projectName)",
                body: "Pipeline on \(tracked.pipeline.ref) is waiting for a manual action",
                url: tracked.pipeline.webURL
            )
        default:
            break
        }
    }
}
