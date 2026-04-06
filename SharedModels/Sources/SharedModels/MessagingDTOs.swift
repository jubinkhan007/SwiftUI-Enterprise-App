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

    public init(name: String? = nil, description: String? = nil, topic: String? = nil) {
        self.name = name
        self.description = description
        self.topic = topic
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

    public init(
        id: UUID,
        type: String,
        name: String?,
        lastMessage: MessageDTO?,
        unreadCount: Int,
        lastMessageAt: Date?
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.lastMessageAt = lastMessageAt
    }
}

public struct ConversationMemberDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let userId: UUID
    public let displayName: String
    public let role: String
    public let notificationPreference: String?
    public let lastReadAt: Date?
    public let lastSeenAt: Date?
    public let isMuted: Bool

    public init(
        id: UUID,
        userId: UUID,
        displayName: String,
        role: String,
        notificationPreference: String? = nil,
        lastReadAt: Date?,
        lastSeenAt: Date? = nil,
        isMuted: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.role = role
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
    public let linkedTask: TaskPreviewDTO?
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
        linkedTask: TaskPreviewDTO? = nil,
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
        self.linkedTask = linkedTask
        self.editedAt = editedAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
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
