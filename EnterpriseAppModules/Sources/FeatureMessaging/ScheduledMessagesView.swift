import SwiftUI
import DesignSystem
import SharedModels

public struct ScheduledMessagesView: View {
    @StateObject private var store: ScheduledMessageStore = .shared
    @State private var statusFilter: String = "scheduled"

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Status", selection: $statusFilter) {
                Text("Scheduled").tag("scheduled")
                Text("Sent").tag("sent")
                Text("Failed").tag("failed")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, AppSpacing.sm)

            list
        }
        .navigationTitle("Scheduled Messages")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await store.load(status: statusFilter) }
        .onChange(of: statusFilter) { _, new in
            Task { await store.load(status: new) }
        }
        .refreshable { await store.load(status: statusFilter) }
        .background(AppColors.backgroundPrimary)
    }

    private var list: some View {
        Group {
            if store.items.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "clock.arrow.circlepath")
                        .appFont(AppTypography.title1)
                        .foregroundColor(AppColors.textSecondary)
                    Text("Nothing here.").appFont(AppTypography.subheadline).foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.items) { ScheduledRow(item: $0) }
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct ScheduledRow: View {
    let item: ScheduledMessageDTO
    @StateObject private var store: ScheduledMessageStore = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "paperplane")
                    .foregroundColor(AppColors.brandPrimary)
                Text(formatted(item.scheduledFor))
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(item.status.rawValue.uppercased())
                    .appFont(AppTypography.overline)
                    .foregroundColor(statusColor(item.status))
            }
            Text(item.body)
                .appFont(AppTypography.body)
                .lineLimit(3)
            if let err = item.error, item.status == .failed {
                Text(err).appFont(AppTypography.caption2).foregroundColor(.red)
            }
            if item.status == .scheduled {
                HStack(spacing: AppSpacing.md) {
                    Button("Send now") { Task { _ = await store.sendNow(item.id) } }
                        .appFont(AppTypography.caption1)
                    Button("Cancel", role: .destructive) {
                        Task { _ = await store.cancel(item.id) }
                    }
                    .appFont(AppTypography.caption1)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }

    private func statusColor(_ status: ScheduledMessageStatus) -> Color {
        switch status {
        case .scheduled: return AppColors.brandPrimary
        case .sending: return .orange
        case .sent: return .green
        case .cancelled: return AppColors.textSecondary
        case .failed: return .red
        }
    }
}
