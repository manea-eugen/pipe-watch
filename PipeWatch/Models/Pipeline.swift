import Foundation

// MARK: - Pipeline Status

enum PipelineStatus: String, Codable, Sendable {
    case created
    case waitingForResource = "waiting_for_resource"
    case preparing
    case pending
    case running
    case success
    case failed
    case canceled
    case skipped
    case manual
    case scheduled

    var isActive: Bool {
        switch self {
        case .created, .waitingForResource, .preparing, .pending, .running, .scheduled:
            return true
        case .success, .failed, .canceled, .skipped, .manual:
            return false
        }
    }

    var isTerminal: Bool {
        switch self {
        case .success, .failed, .canceled, .skipped:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .waitingForResource: return "Waiting"
        case .success: return "Passed"
        case .failed: return "Failed"
        case .canceled: return "Canceled"
        case .running: return "Running"
        case .pending: return "Pending"
        case .created: return "Created"
        case .preparing: return "Preparing"
        case .skipped: return "Skipped"
        case .manual: return "Manual"
        case .scheduled: return "Scheduled"
        }
    }

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .running: return "play.circle.fill"
        case .pending, .created, .waitingForResource, .preparing:
            return "clock.fill"
        case .canceled: return "minus.circle.fill"
        case .skipped: return "forward.fill"
        case .manual: return "hand.raised.fill"
        case .scheduled: return "calendar.circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .success: return "green"
        case .failed: return "red"
        case .running: return "blue"
        case .pending, .created, .waitingForResource, .preparing:
            return "orange"
        case .canceled, .skipped: return "gray"
        case .manual: return "purple"
        case .scheduled: return "indigo"
        }
    }

    /// Priority for sorting -- higher means more attention needed
    var priority: Int {
        switch self {
        case .failed: return 100
        case .running: return 90
        case .pending, .created, .waitingForResource, .preparing: return 80
        case .manual: return 70
        case .scheduled: return 60
        case .success: return 50
        case .canceled: return 40
        case .skipped: return 30
        }
    }
}

// MARK: - Pipeline

struct Pipeline: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let iid: Int?
    let projectID: Int?
    let status: PipelineStatus
    let source: String?
    let ref: String
    let sha: String
    let webURL: String
    let createdAt: Date?
    let updatedAt: Date?
    let startedAt: Date?
    let finishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case iid
        case projectID = "project_id"
        case status
        case source
        case ref
        case sha
        case webURL = "web_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }

    var shortSHA: String {
        String(sha.prefix(8))
    }

    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = finishedAt ?? Date()
        return end.timeIntervalSince(start)
    }

    var durationText: String {
        guard let duration else { return "--" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// MARK: - Pipeline Job

struct PipelineJob: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let name: String
    let stage: String
    let status: PipelineStatus

    enum CodingKeys: String, CodingKey {
        case id, name, stage, status
    }
}

// MARK: - Tracked Pipeline (enriched with project info)

struct TrackedPipeline: Identifiable, Sendable, Hashable {
    let pipeline: Pipeline
    let projectName: String
    let projectID: Int
    var currentJob: PipelineJob?
    var failedJob: PipelineJob?
    var retryCount: Int = 0
    var manualJobs: [PipelineJob] = []

    var id: Int { pipeline.id }

    /// True when the pipeline looks "success" but has pending manual actions.
    var isWaitingForManual: Bool {
        !manualJobs.isEmpty
    }

    /// The effective status considering manual jobs that GitLab hides behind "success".
    var effectiveStatus: PipelineStatus {
        if pipeline.status == .success && isWaitingForManual { return .manual }
        return pipeline.status
    }

    /// A short label describing the current step, e.g. "build" or "test › rspec"
    var currentStepLabel: String? {
        guard let job = currentJob else { return nil }
        return jobLabel(job)
    }

    /// A short label for the failed job, e.g. "test › rspec (2 retries)"
    var failedStepLabel: String? {
        guard let job = failedJob else { return nil }
        let base = jobLabel(job)
        if retryCount > 0 {
            let noun = retryCount == 1 ? "retry" : "retries"
            return "\(base) (\(retryCount) \(noun))"
        }
        return base
    }

    /// Label for pending manual jobs, e.g. "deploy-prd"
    var manualStepLabel: String? {
        guard !manualJobs.isEmpty else { return nil }
        let names = manualJobs.map { jobLabel($0) }
        return names.joined(separator: ", ")
    }

    private func jobLabel(_ job: PipelineJob) -> String {
        if job.stage.lowercased() == job.name.lowercased() {
            return job.stage
        }
        return "\(job.stage) › \(job.name)"
    }
}
