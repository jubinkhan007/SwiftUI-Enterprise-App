import SwiftUI
import SharedModels
import DesignSystem

public struct MessageBubbleView: View {
    let message: MessageDTO
    let isCurrentUser: Bool
    let onDelete: (() -> Void)?
    let onEdit: (() -> Void)?
    
    public init(message: MessageDTO, isCurrentUser: Bool, onDelete: (() -> Void)? = nil, onEdit: (() -> Void)? = nil) {
        self.message = message
        self.isCurrentUser = isCurrentUser
        self.onDelete = onDelete
        self.onEdit = onEdit
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser { Spacer(minLength: 40) }
            else { avatarView }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isCurrentUser {
                    Text(message.senderName)
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                if message.deletedAt != nil {
                    Text("This message was deleted")
                        .appFont(AppTypography.body)
                        .italic()
                        .padding(12)
                        .background(AppColors.surfaceElevated)
                        .foregroundColor(AppColors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text(message.body)
                        .appFont(AppTypography.body)
                        .padding(12)
                        .background(isCurrentUser ? AppColors.brandPrimary : AppColors.surfaceElevated)
                        .foregroundColor(isCurrentUser ? .white : AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                HStack(spacing: 4) {
                    if message.editedAt != nil && message.deletedAt == nil {
                        Text("(edited)")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let date = message.createdAt {
                        Text(date, style: .time)
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            
            if !isCurrentUser { Spacer(minLength: 40) }
        }
        .contextMenu {
            if let onEdit = onEdit, message.deletedAt == nil {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete = onDelete, message.deletedAt == nil {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    private var avatarView: some View {
        Circle()
            .fill(AppColors.surfaceElevated)
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(message.senderName.prefix(1)).uppercased())
                    .appFont(AppTypography.caption1)
            )
    }
}
