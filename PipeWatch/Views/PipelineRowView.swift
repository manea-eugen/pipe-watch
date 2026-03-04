import SwiftUI

struct PipelineRowView: View {
    let tracked: TrackedPipeline
    var showBranch: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Status icon — use effective status to reflect manual actions
            Image(systemName: tracked.effectiveStatus.iconName)
                .foregroundStyle(color(for: tracked.effectiveStatus))
                .font(.system(size: 14))
                .frame(width: 20)

            // Pipeline info
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tracked.projectName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)

                        if showBranch {
                            Label(tracked.pipeline.ref, systemImage: "arrow.triangle.branch")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        if tracked.pipeline.duration != nil {
                            Text(tracked.pipeline.durationText)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }

                        if let updated = tracked.pipeline.updatedAt {
                            Text(timeAgo(updated))
                                .font(.system(size: 9))
                                .foregroundStyle(.quaternary)
                        }
                    }
                }

                if tracked.pipeline.status.isActive, let progress = tracked.progress {
                    HStack(spacing: 6) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(color(for: tracked.pipeline.status).opacity(0.15))
                                .frame(height: 2)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(color(for: tracked.pipeline.status).opacity(0.5))
                                        .frame(width: geo.size.width * progress, height: 2)
                                }
                        }
                        .frame(height: 2)

                        if let eta = tracked.etaText {
                            Text(eta)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                    }
                }

                // Current step for active pipelines
                if let step = tracked.currentStepLabel {
                    Label(step, systemImage: "gear")
                        .font(.system(size: 10))
                        .foregroundStyle(color(for: tracked.pipeline.status).opacity(0.8))
                        .lineLimit(1)
                }

                // Failed job info
                if let step = tracked.failedStepLabel {
                    Label(step, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.8))
                        .lineLimit(1)
                }

                // Manual action waiting
                if let step = tracked.manualStepLabel {
                    Label("Waiting: \(step)", systemImage: "hand.raised.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: tracked.pipeline.webURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func color(for status: PipelineStatus) -> Color {
        switch status {
        case .success: return .green
        case .failed: return .red
        case .running: return .blue
        case .pending, .created, .waitingForResource, .preparing: return .orange
        case .canceled, .skipped: return .secondary
        case .manual: return .orange
        case .scheduled: return .indigo
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
