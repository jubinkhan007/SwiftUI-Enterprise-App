import SwiftUI
import SharedModels
import DesignSystem

public struct TaskRowView: View {
    let task: TaskItemDTO
    let isSelected: Bool
    let selectionAction: () -> Void

    public init(task: TaskItemDTO, isSelected: Bool, selectionAction: @escaping () -> Void) {
        self.task = task
        self.isSelected = isSelected
        self.selectionAction = selectionAction
    }

    public var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                // Selection / Status Toggle
                Button(action: selectionAction) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? AppColors.brandPrimary : AppColors.borderDefault)
                        .frame(width: 32, height: 32)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    // Title row with type icon badge
                    HStack(spacing: AppSpacing.xs) {
                        TaskTypeBadge(taskType: task.taskType)

                        Text(task.title)
                            .appFont(AppTypography.headline)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)
                    }

                    if let description = task.description, !description.isEmpty {
                        Text(description)
                            .appFont(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }

                    // Status / Priority / Date row
                    HStack(spacing: AppSpacing.sm) {
                        StatusBadge(status: task.status)
                        PriorityBadge(priority: task.priority)

                        Spacer()

                        if let dueDate = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                Text(dueDate, style: .date)
                                    .appFont(AppTypography.caption1)
                            }
                            .foregroundColor(isOverdue(dueDate) ? AppColors.statusError : AppColors.textSecondary)
                        }
                    }
                    .padding(.top, AppSpacing.xs)

                    // Subtask progress bar (only when task has subtasks)
                    if task.subtaskCount > 0 {
                        SubtaskProgressBar(
                            completed: task.completedSubtaskCount,
                            total: task.subtaskCount
                        )
                        .padding(.top, 2)
                    }

                    // Label pills
                    if let labels = task.labels, !labels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.xs) {
                                ForEach(labels, id: \.self) { label in
                                    LabelPill(label: label)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && task.status != .done
    }
}

// MARK: - Task Type Badge

struct TaskTypeBadge: View {
    let taskType: TaskType

    var body: some View {
        Image(systemName: taskType.iconName)
            .font(.caption)
            .foregroundColor(typeColor)
            .frame(width: 16, height: 16)
    }

    private var typeColor: Color {
        switch taskType {
        case .task:    return .blue
        case .bug:     return .red
        case .story:   return .green
        case .epic:    return .purple
        case .subtask: return .gray
        }
    }
}

// MARK: - Subtask Progress Bar

struct SubtaskProgressBar: View {
    let completed: Int
    let total: Int

    private var fraction: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.borderSubtle)
                        .frame(height: 4)
                    Capsule()
                        .fill(AppColors.statusSuccess)
                        .frame(width: geo.size.width * fraction, height: 4)
                }
            }
            .frame(height: 4)

            Text("\(completed)/\(total)")
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize()
        }
    }
}

// MARK: - Label Pill

struct LabelPill: View {
    let label: String

    var body: some View {
        Text(label)
            .appFont(AppTypography.caption1)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColors.brandPrimary.opacity(0.1))
            .foregroundColor(AppColors.brandPrimary)
            .clipShape(Capsule())
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Text(status.displayName)
            .appFont(AppTypography.caption1)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.15))
            .foregroundColor(textColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .todo:       return AppColors.surfaceElevated
        case .inProgress: return .blue
        case .inReview:   return .orange
        case .done:       return AppColors.statusSuccess
        case .cancelled:  return .gray
        }
    }

    private var textColor: Color {
        switch status {
        case .todo:       return AppColors.textSecondary
        case .inProgress: return .blue
        case .inReview:   return .orange
        case .done:       return AppColors.statusSuccess
        case .cancelled:  return AppColors.textSecondary
        }
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            Text(priority.displayName)
        }
        .appFont(AppTypography.caption1)
        .fontWeight(.medium)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor.opacity(0.1))
        .foregroundColor(textColor)
        .clipShape(Capsule())
    }

    private var iconName: String {
        switch priority {
        case .low:      return "arrow.down"
        case .medium:   return "minus"
        case .high:     return "arrow.up"
        case .critical: return "exclamationmark.3"
        }
    }

    private var backgroundColor: Color {
        switch priority {
        case .low:      return .gray
        case .medium:   return .blue
        case .high:     return .orange
        case .critical: return AppColors.statusError
        }
    }

    private var textColor: Color {
        switch priority {
        case .low:      return AppColors.textSecondary
        case .medium:   return .blue
        case .high:     return .orange
        case .critical: return AppColors.statusError
        }
    }
}
