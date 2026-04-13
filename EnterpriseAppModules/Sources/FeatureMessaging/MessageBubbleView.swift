import SwiftUI
import SharedModels
import DesignSystem

public struct MessageBubbleView: View {
    let message: MessageDTO
    let isCurrentUser: Bool
    let currentUserId: UUID
    let participantNames: [UUID: String]
    let onDelete: (() -> Void)?
    let onEdit: (() -> Void)?
    let onOpenThread: (() -> Void)?
    let onOpenActions: (() -> Void)?

    @ObservedObject private var store: MessageInteractionStore = MessageInteractionStore.shared
    @State private var reactionDetail: ReactionDetailItem?

    public init(
        message: MessageDTO,
        isCurrentUser: Bool,
        currentUserId: UUID = UUID(),
        participantNames: [UUID: String] = [:],
        onDelete: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onOpenThread: (() -> Void)? = nil,
        onOpenActions: (() -> Void)? = nil
    ) {
        self.message = message
        self.isCurrentUser = isCurrentUser
        self.currentUserId = currentUserId
        self.participantNames = participantNames
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
        .sheet(item: $reactionDetail) { detail in
            ReactionDetailView(
                emoji: detail.emoji,
                messageId: message.id,
                currentUserId: detail.currentUserId,
                interactionStore: store,
                participantNames: participantNames
            )
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: AppSpacing.sm) {
            // Pinned / Bookmarked badges
            let isPinned = store.pinnedMessages.contains(message.id)
            let isBookmarked = store.bookmarkedMessages.contains(message.id)
            if (isPinned || isBookmarked) && message.deletedAt == nil {
                HStack(spacing: AppSpacing.xs) {
                    if isPinned {
                        Label("Pinned", systemImage: "pin.fill")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.75) : AppColors.brandPrimary)
                    }
                    if isBookmarked {
                        Label("Saved", systemImage: "bookmark.fill")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.75) : AppColors.brandPrimary)
                    }
                }
                .labelStyle(.titleAndIcon)
            }

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

                let reactions = store.reactionSummary(for: message.id)
                if !reactions.isEmpty {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(reactions, id: \.emoji) { reaction in
                            Button {
                                reactionDetail = ReactionDetailItem(emoji: reaction.emoji, currentUserId: currentUserId)
                            } label: {
                                Text("\(reaction.emoji) \(reaction.count)")
                                    .appFont(AppTypography.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.backgroundPrimary.opacity(isCurrentUser ? 0.18 : 1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Remove my reaction", role: .destructive) {
                                    store.toggleReaction(reaction.emoji, for: message.id, userId: currentUserId)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(message.deletedAt == nil
            ? (isCurrentUser ? AppColors.brandPrimary : AppColors.surfaceElevated)
            : AppColors.surfaceElevated)
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

// MARK: - Supporting Types

struct ReactionDetailItem: Identifiable {
    let id = UUID()
    let emoji: String
    let currentUserId: UUID
}
