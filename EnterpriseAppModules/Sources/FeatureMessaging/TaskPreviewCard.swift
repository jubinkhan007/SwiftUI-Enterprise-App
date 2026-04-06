import SwiftUI
import SharedModels
import DesignSystem

public struct TaskPreviewCard: View {
    let task: TaskPreviewDTO

    public init(task: TaskPreviewDTO) {
        self.task = task
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(task.issueKey ?? "TASK")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.brandPrimary)
                Spacer()
                Text(task.status)
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(task.title)
                .appFont(AppTypography.subheadline)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)

            HStack(spacing: AppSpacing.sm) {
                if let assignee = task.assigneeDisplayName {
                    Label(assignee, systemImage: "person.crop.circle")
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                if let dueDate = task.dueDate {
                    Label {
                        Text(dueDate, style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.borderDefault, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
