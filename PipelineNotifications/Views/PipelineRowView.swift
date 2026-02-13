import SwiftUI

struct PipelineRowView: View {
    let tracked: TrackedPipeline

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: tracked.pipeline.status.iconName)
                .foregroundStyle(color(for: tracked.pipeline.status))
                .font(.system(size: 14))
                .frame(width: 20)

            // Pipeline info
            VStack(alignment: .leading, spacing: 2) {
                Text(tracked.projectName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Branch
                    Label(tracked.pipeline.ref, systemImage: "arrow.triangle.branch")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    // Duration
                    Text(tracked.pipeline.durationText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    // Time ago
                    if let updated = tracked.pipeline.updatedAt {
                        Text(timeAgo(updated))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
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
        case .manual: return .purple
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
