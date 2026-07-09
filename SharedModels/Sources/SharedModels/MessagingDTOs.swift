import Foundation

// MARK: - Requests

public struct CreateConversationRequest: Codable, Sendable, Hashable {
    public let type: String
    public let memberIds: [UUID]
    public let name: String?
    public let description: String?
    public let topic: String?

    public init(
        type: String,
        memberIds: [UUID],
        name: String? = nil,
        description: String? = nil,
        topic: String? = nil
    ) {
        self.type = type
        self.memberIds = memberIds
        self.name = name
        self.description = description
        self.topic = topic
    }
}

public struct UpdateConversationRequest: Codable, Sendable, Hashable {
    public let name: String?
    public let description: String?
    public let topic: String?
    public let isPrivate: Bool?

    public init(name: String? = nil, description: String? = nil, topic: String? = nil, isPrivate: Bool? = nil) {
        self.name = name
        self.description = description
        self.topic = topic
        self.isPrivate = isPrivate
    }
}

public struct AddConversationMembersRequest: Codable, Sendable, Hashable {
    public let memberIds: [UUID]

    public init(memberIds: [UUID]) {
        self.memberIds = memberIds
    }
}

public struct UpdateConversationMemberPreferencesRequest: Codable, Sendable, Hashable {
    public let notificationPreference: String?
    public let isMuted: Bool?

    public init(notificationPreference: String? = nil, isMuted: Bool? = nil) {
        self.notificationPreference = notificationPreference
        self.isMuted = isMuted
    }
}

public struct UpdateChannelMemberRoleRequest: Codable, Sendable, Hashable {
    public let role: String

    public init(role: String) {
        self.role = role
    }
}

public struct ApproveChannelMemberRequest: Codable, Sendable, Hashable {
    public let status: String // "active", "rejected"

    public init(status: String) {
        self.status = status
    }
}

public struct SendMessageRequest: Codable, Sendable, Hashable {
    public let body: String
    public let messageType: String?
    public let parentId: UUID?

    public init(body: String, messageType: String? = nil, parentId: UUID? = nil) {
        self.body = body
        self.messageType = messageType
        self.parentId = parentId
    }
}

public struct EditMessageRequest: Codable, Sendable, Hashable {
    public let body: String

    public init(body: String) {
        self.body = body
    }
}

public struct TypingIndicatorRequest: Codable, Sendable, Hashable {
    public let userId: UUID

    public init(userId: UUID) {
        self.userId = userId
    }
}

public struct MarkReadRequest: Codable, Sendable, Hashable {
    public let lastReadMessageId: UUID?

    public init(lastReadMessageId: UUID? = nil) {
        self.lastReadMessageId = lastReadMessageId
    }
}

// MARK: - Responses

public struct ConversationDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let type: String
    public let name: String?
    public let description: String?
    public let topic: String?
    public let isArchived: Bool
    public let isPrivate: Bool
    public let ownerId: UUID?
    public let lastMessageAt: Date?
    public let createdAt: Date?
    public let members: [ConversationMemberDTO]?

    public init(
        id: UUID,
        type: String,
        name: String?,
        description: String? = nil,
        topic: String? = nil,
        isArchived: Bool,
        isPrivate: Bool = true,
        ownerId: UUID? = nil,
        lastMessageAt: Date?,
        createdAt: Date?,
        members: [ConversationMemberDTO]?
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.topic = topic
        self.isArchived = isArchived
        self.isPrivate = isPrivate
        self.ownerId = ownerId
        self.lastMessageAt = lastMessageAt
        self.createdAt = createdAt
        self.members = members
    }
}

public struct ConversationListItemDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let type: String
    public let name: String?
    public let lastMessage: MessageDTO?
    public let unreadCount: Int
    public let lastMessageAt: Date?
    public let partnerId: UUID?

    public init(
        id: UUID,
        type: String,
        name: String?,
        lastMessage: MessageDTO?,
        unreadCount: Int,
        lastMessageAt: Date?,
        partnerId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.lastMessageAt = lastMessageAt
        self.partnerId = partnerId
    }
}

public struct ConversationMemberDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let userId: UUID
    public let displayName: String
    public let role: String
    public let status: String
    public let notificationPreference: String?
    public let lastReadAt: Date?
    public let lastSeenAt: Date?
    public let isMuted: Bool

    public init(
        id: UUID,
        userId: UUID,
        displayName: String,
        role: String,
        status: String = "active",
        notificationPreference: String? = nil,
        lastReadAt: Date?,
        lastSeenAt: Date? = nil,
        isMuted: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.role = role
        self.status = status
        self.notificationPreference = notificationPreference
        self.lastReadAt = lastReadAt
        self.lastSeenAt = lastSeenAt
        self.isMuted = isMuted
    }
}

public struct TaskPreviewDTO: Codable, Sendable, Hashable {
    public let taskId: UUID
    public let issueKey: String?
    public let title: String
    public let status: String
    public let assigneeDisplayName: String?
    public let dueDate: Date?

    public init(
        taskId: UUID,
        issueKey: String? = nil,
        title: String,
        status: String,
        assigneeDisplayName: String? = nil,
        dueDate: Date? = nil
    ) {
        self.taskId = taskId
        self.issueKey = issueKey
        self.title = title
        self.status = status
        self.assigneeDisplayName = assigneeDisplayName
        self.dueDate = dueDate
    }
}

public struct MessageDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let conversationId: UUID
    public let senderId: UUID
    public let senderName: String
    public let body: String
    public let messageType: String
    public let parentId: UUID?
    public let replyCount: Int
    public let threadPreviewText: String?
    public let lastReplyAt: Date?
    public let linkedTask: TaskPreviewDTO?
    public let reactions: [MessageReactionGroupDTO]
    public let isPinned: Bool
    public let pinnedBy: UUID?
    public let pinnedAt: Date?
    public let isBookmarkedByMe: Bool
    public let editedAt: Date?
    public let deletedAt: Date?
    public let createdAt: Date?

    public init(
        id: UUID,
        conversationId: UUID,
        senderId: UUID,
        senderName: String,
        body: String,
        messageType: String,
        parentId: UUID? = nil,
        replyCount: Int = 0,
        threadPreviewText: String? = nil,
        lastReplyAt: Date? = nil,
        linkedTask: TaskPreviewDTO? = nil,
        reactions: [MessageReactionGroupDTO] = [],
        isPinned: Bool = false,
        pinnedBy: UUID? = nil,
        pinnedAt: Date? = nil,
        isBookmarkedByMe: Bool = false,
        editedAt: Date?,
        deletedAt: Date?,
        createdAt: Date?
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.body = body
        self.messageType = messageType
        self.parentId = parentId
        self.replyCount = replyCount
        self.threadPreviewText = threadPreviewText
        self.lastReplyAt = lastReplyAt
        self.linkedTask = linkedTask
        self.reactions = reactions
        self.isPinned = isPinned
        self.pinnedBy = pinnedBy
        self.pinnedAt = pinnedAt
        self.isBookmarkedByMe = isBookmarkedByMe
        self.editedAt = editedAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
    }
}

public struct MessageReactionGroupDTO: Codable, Sendable, Hashable {
    public let emoji: String
    public let count: Int
    public let userIds: [UUID]
    public let didReact: Bool

    public init(emoji: String, count: Int, userIds: [UUID], didReact: Bool) {
        self.emoji = emoji
        self.count = count
        self.userIds = userIds
        self.didReact = didReact
    }
}

public struct ReactionRequest: Codable, Sendable, Hashable {
    public let emoji: String

    public init(emoji: String) {
        self.emoji = emoji
    }
}

public struct BookmarkDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let messageId: UUID
    public let conversationId: UUID
    public let conversationName: String?
    public let message: MessageDTO
    public let createdAt: Date?

    public init(
        id: UUID,
        messageId: UUID,
        conversationId: UUID,
        conversationName: String? = nil,
        message: MessageDTO,
        createdAt: Date?
    ) {
        self.id = id
        self.messageId = messageId
        self.conversationId = conversationId
        self.conversationName = conversationName
        self.message = message
        self.createdAt = createdAt
    }
}

public struct ConvertMessageToTaskRequest: Codable, Sendable, Hashable {
    public let listId: UUID
    public let title: String?
    public let description: String?
    public let assigneeId: UUID?
    public let dueDate: Date?

    public init(
        listId: UUID,
        title: String? = nil,
        description: String? = nil,
        assigneeId: UUID? = nil,
        dueDate: Date? = nil
    ) {
        self.listId = listId
        self.title = title
        self.description = description
        self.assigneeId = assigneeId
        self.dueDate = dueDate
    }
}

public struct ConvertMessageToTaskResponse: Codable, Sendable, Hashable {
    public let task: TaskPreviewDTO
    public let message: MessageDTO

    public init(task: TaskPreviewDTO, message: MessageDTO) {
        self.task = task
        self.message = message
    }
}

public struct ThreadMessageBundleDTO: Codable, Sendable, Hashable {
    public let rootMessage: MessageDTO
    public let replies: [MessageDTO]

    public init(rootMessage: MessageDTO, replies: [MessageDTO]) {
        self.rootMessage = rootMessage
        self.replies = replies
    }
}

public struct MessageSearchResultDTO: Codable, Sendable, Hashable {
    public let message: MessageDTO
    public let conversationName: String

    public init(message: MessageDTO, conversationName: String) {
        self.message = message
        self.conversationName = conversationName
    }
}
