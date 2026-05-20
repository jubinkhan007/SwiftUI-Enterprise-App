import SwiftUI
import SharedModels
import DesignSystem

public struct MeetingSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: MeetingSessionStore
    let meeting: MeetingDTO

    @State private var newActionItemText: String = ""
    @State private var isGenerating = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let summary = session.summary {
                    summaryCard(summary)
                    actionItemsCard(summary)
                } else {
                    emptyCard
                }
                addActionItemCard
            }
            .padding()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Summary")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .task { await session.loadSummary() }
    }

    private var emptyCard: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "doc.text").appFont(AppTypography.title2).foregroundColor(AppColors.textSecondary)
            Text("No summary yet.").appFont(AppTypography.subheadline).foregroundColor(AppColors.textSecondary)
            Button {
                Task {
                    isGenerating = true
                    await session.generateSummary()
                    isGenerating = false
                }
            } label: {
                Label("Generate summary", systemImage: "wand.and.stars")
                    .appFont(AppTypography.buttonLabelSmall)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.surfaceElevated)
        .cornerRadius(12)
    }

    private func summaryCard(_ summary: MeetingSummaryDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Summary").appFont(AppTypography.headline)
                Spacer()
                Text(summary.source.uppercased())
                    .appFont(AppTypography.overline)
                    .foregroundColor(AppColors.textSecondary)
                Button {
                    Task { await session.generateSummary(regenerate: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            Text(summary.summaryText)
                .appFont(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding()
        .background(AppColors.surfaceElevated)
        .cornerRadius(12)
    }

    private func actionItemsCard(_ summary: MeetingSummaryDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Action items (\(summary.actionItems.count))").appFont(AppTypography.headline)
            if summary.actionItems.isEmpty {
                Text("None yet.").appFont(AppTypography.subheadline).foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(summary.actionItems) { item in
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(AppColors.brandPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.text).appFont(AppTypography.body)
                            if let due = item.dueAt {
                                Text("Due \(formattedDate(due))")
                                    .appFont(AppTypography.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            if item.linkedTaskId != nil {
                                Text("Linked to task").appFont(AppTypography.caption2).foregroundColor(.green)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(AppColors.surfaceElevated)
        .cornerRadius(12)
    }

    private var addActionItemCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Add action item").appFont(AppTypography.headline)
            TextField("Describe a follow-up…", text: $newActionItemText, axis: .vertical)
                .lineLimit(2...4)
            Button {
                let text = newActionItemText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                Task {
                    await session.addActionItem(text)
                    newActionItemText = ""
                }
            } label: {
                Label("Add", systemImage: "plus")
                    .appFont(AppTypography.buttonLabelSmall)
            }
            .disabled(newActionItemText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(AppColors.surfaceElevated)
        .cornerRadius(12)
    }

    private func formattedDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }
}
