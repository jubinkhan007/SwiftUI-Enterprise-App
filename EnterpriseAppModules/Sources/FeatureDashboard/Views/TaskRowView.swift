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
                    Text(task.title)
                        .appFont(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    if let description = task.description, !description.isEmpty {
                        Text(description)
                            .appFont(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    
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
                }
            }
        }
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && task.status != .done
    }
}

// MARK: - Badges

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
        case .todo: return AppColors.surfaceElevated
        case .inProgress: return .blue
        case .inReview: return .orange
        case .done: return AppColors.statusSuccess
        case .cancelled: return .gray
        }
    }
    
    private var textColor: Color {
        switch status {
        case .todo: return AppColors.textSecondary
        case .inProgress: return .blue
        case .inReview: return .orange
        case .done: return AppColors.statusSuccess
        case .cancelled: return AppColors.textSecondary
        }
    }
}

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
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .critical: return "exclamationmark.3"
        }
    }
    
    private var backgroundColor: Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return AppColors.statusError
        }
    }
    
    private var textColor: Color {
        switch priority {
        case .low: return AppColors.textSecondary
        case .medium: return .blue
        case .high: return .orange
        case .critical: return AppColors.statusError
        }
    }
}
