import Foundation

// MARK: - Requests

/// Request to create a new conversation.
public struct CreateConversationRequest: Codable, Sendable, Hashable {
    /// Conversation type: "direct" (Phase 1), "group" or "channel" (Phase 2).
    public let type: String
    /// For DM: exactly 1 other user ID. For groups: 1+ user IDs.
    public let memberIds: [UUID]
    /// Optional name (required for groups/channels, ignored for DMs).
    public let name: String?

    public init(type: String, memberIds: [UUID], name: String? = nil) {
        self.type = type
        self.memberIds = memberIds
        self.name = name
    }
}

/// Request to send a message in a conversation.
public struct SendMessageRequest: Codable, Sendable, Hashable {
    public let body: String
    /// Defaults to "text". Other values: "system", "file".
    public let messageType: String?

    public init(body: String, messageType: String? = nil) {
        self.body = body
        self.messageType = messageType
    }
}

/// Request to mark a conversation as read.
public struct MarkReadRequest: Codable, Sendable, Hashable {
    public let lastReadMessageId: UUID?

    public init(lastReadMessageId: UUID? = nil) {
        self.lastReadMessageId = lastReadMessageId
    }
}

// MARK: - Responses

/// Full conversation details including members.
public struct ConversationDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let type: String
    public let name: String?
    public let isArchived: Bool
    public let lastMessageAt: Date?
    public let createdAt: Date?
    public let members: [ConversationMemberDTO]?

    public init(
        id: UUID,
        type: String,
        name: String?,
        isArchived: Bool,
        lastMessageAt: Date?,
        createdAt: Date?,
        members: [ConversationMemberDTO]?
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.isArchived = isArchived
        self.lastMessageAt = lastMessageAt
        self.createdAt = createdAt
        self.members = members
    }
}

/// Conversation list item with last message preview and unread count.
public struct ConversationListItemDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let type: String
    /// For DMs this is the other user's display name. For groups, the group name.
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

/// A member of a conversation.
public struct ConversationMemberDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let userId: UUID
    public let displayName: String
    public let role: String
    public let lastReadAt: Date?

    public init(id: UUID, userId: UUID, displayName: String, role: String, lastReadAt: Date?) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.role = role
        self.lastReadAt = lastReadAt
    }
}

/// A single message.
public struct MessageDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let conversationId: UUID
    public let senderId: UUID
    public let senderName: String
    public let body: String
    public let messageType: String
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
        self.editedAt = editedAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
    }
}
