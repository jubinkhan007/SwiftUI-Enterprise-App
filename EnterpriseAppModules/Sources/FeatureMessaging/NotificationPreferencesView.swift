import SwiftUI
import SharedModels
import Domain
import FeatureInbox

public struct ChannelNotificationPreferencesView: View {
    let conversation: ConversationDTO
    let currentMember: ConversationMemberDTO?
    let messagingRepository: MessagingRepositoryProtocol
    let onUpdated: (ConversationMemberDTO) -> Void

    public init(
        conversation: ConversationDTO,
        currentMember: ConversationMemberDTO?,
        messagingRepository: MessagingRepositoryProtocol,
        onUpdated: @escaping (ConversationMemberDTO) -> Void = { _ in }
    ) {
        self.conversation = conversation
        self.currentMember = currentMember
        self.messagingRepository = messagingRepository
        self.onUpdated = onUpdated
    }

    public var body: some View {
        FeatureInbox.NotificationPreferencesView(
            conversation: conversation,
            currentMember: currentMember,
            messagingRepository: messagingRepository,
            onUpdated: onUpdated
        )
    }
}
