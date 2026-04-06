import SwiftUI
import SharedModels
import DesignSystem

public struct MessageBubbleView: View {
    let message: MessageDTO
    let isCurrentUser: Bool
    
    public init(message: MessageDTO, isCurrentUser: Bool) {
        self.message = message
        self.isCurrentUser = isCurrentUser
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
                
                Text(message.body)
                    .appFont(AppTypography.body)
                    .padding(12)
                    .background(isCurrentUser ? AppColors.brandPrimary : AppColors.surfaceElevated)
                    .foregroundColor(isCurrentUser ? .white : AppColors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                if let date = message.createdAt {
                    Text(date, style: .time)
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            if !isCurrentUser { Spacer(minLength: 40) }
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
