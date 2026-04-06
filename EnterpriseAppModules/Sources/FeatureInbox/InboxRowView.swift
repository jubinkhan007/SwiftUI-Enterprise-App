import SwiftUI
import SharedModels
import DesignSystem

public struct InboxRowView: View {
    let notification: NotificationDTO
    let onMarkRead: () -> Void
    
    public init(notification: NotificationDTO, onMarkRead: @escaping () -> Void) {
        self.notification = notification
        self.onMarkRead = onMarkRead
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Circle()
                .fill(notification.readAt == nil ? AppColors.brandPrimary : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(titleForType(notification.type))
                        .appFont(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    if let createdAt = notification.createdAt {
                        Text(createdAt, style: .relative)
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                if let payloadStr = notification.payloadJson,
                   let payloadData = payloadStr.data(using: .utf8),
                   let payloadDict = try? JSONSerialization.jsonObject(with: payloadData) as? [String: String],
                   let message = payloadDict["message"] {
                    Text(message)
                        .appFont(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .swipeActions(edge: .leading) {
            if notification.readAt == nil {
                Button {
                    onMarkRead()
                } label: {
                    Label("Mark Read", systemImage: "envelope.open.fill")
                }
                .tint(AppColors.brandPrimary)
            }
        }
    }
    
    private func titleForType(_ type: String) -> String {
        switch type {
        case "task.assigned": return "New Assignment"
        case "task.updated": return "Task Updated"
        case "mention": return "You were mentioned"
        default: return "Notification"
        }
    }
}
