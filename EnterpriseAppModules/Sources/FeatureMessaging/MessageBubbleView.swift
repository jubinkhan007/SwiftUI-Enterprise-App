import SwiftUI
import SharedModels
import DesignSystem

public struct MessageBubbleView: View {
    let message: MessageDTO
    let isCurrentUser: Bool
    let onDelete: (() -> Void)?
    let onEdit: (() -> Void)?
    let onOpenThread: (() -> Void)?
    let onOpenActions: (() -> Void)?

    public init(
        message: MessageDTO,
        isCurrentUser: Bool,
        onDelete: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onOpenThread: (() -> Void)? = nil,
        onOpenActions: (() -> Void)? = nil
    ) {
        self.message = message
        self.isCurrentUser = isCurrentUser
        self.onDelete = onDelete
        self.onEdit = onEdit
        self.onOpenThread = onOpenThread
        self.onOpenActions = onOpenActions
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 40)
            } else {
                avatarView
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: AppSpacing.xs) {
                if !isCurrentUser {
                    Text(message.senderName)
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }

                bubbleContent
                messageFooter
            }

            if !isCurrentUser {
                Spacer(minLength: 40)
            }
        }
        .contextMenu {
            if let onOpenThread, message.deletedAt == nil {
                Button(action: onOpenThread) {
                    Label("Reply in Thread", systemImage: "arrowshape.turn.up.left")
                }
            }
            if let onOpenActions {
                Button(action: onOpenActions) {
                    Label("More Actions", systemImage: "ellipsis.circle")
                }
            }
            if let onEdit, message.deletedAt == nil {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete, message.deletedAt == nil {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: AppSpacing.sm) {
            if message.deletedAt != nil {
                Text("This message was deleted")
                    .appFont(AppTypography.body)
                    .italic()
                    .foregroundColor(AppColors.textSecondary)
            } else {
                Text(message.body)
                    .appFont(AppTypography.body)
                    .foregroundColor(isCurrentUser ? .white : AppColors.textPrimary)

                if let linkedTask = message.linkedTask {
                    TaskPreviewCard(task: linkedTask)
                }

                if message.replyCount > 0, let onOpenThread {
                    Button(action: onOpenThread) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "text.bubble")
                            Text(threadPreviewText)
                                .lineLimit(1)
                        }
                        .appFont(AppTypography.caption1)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.9) : AppColors.brandPrimary)
                    }
                    .buttonStyle(.plain)
                }

                let reactions = MessageInteractionStore.shared.reactionSummary(for: message.id)
                if !reactions.isEmpty {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(reactions, id: \.emoji) { reaction in
                            Text("\(reaction.emoji) \(reaction.count)")
                                .appFont(AppTypography.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.backgroundPrimary.opacity(isCurrentUser ? 0.18 : 1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(message.deletedAt == nil ? (isCurrentUser ? AppColors.brandPrimary : AppColors.surfaceElevated) : AppColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var messageFooter: some View {
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

    private var threadPreviewText: String {
        if let preview = message.threadPreviewText, !preview.isEmpty {
            return "\(message.replyCount) repl\(message.replyCount == 1 ? "y" : "ies"): \(preview)"
        }
        return "\(message.replyCount) repl\(message.replyCount == 1 ? "y" : "ies")"
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
