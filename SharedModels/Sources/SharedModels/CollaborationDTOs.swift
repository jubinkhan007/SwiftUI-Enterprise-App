import Foundation

// MARK: - Comments

public struct CommentDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let taskId: UUID
    public let userId: UUID
    public let orgId: UUID
    public let body: String
    public let editedAt: Date?
    public let deletedAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        taskId: UUID,
        userId: UUID,
        orgId: UUID,
        body: String,
        editedAt: Date? = nil,
        deletedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.userId = userId
        self.orgId = orgId
        self.body = body
        self.editedAt = editedAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Attachments

public struct AttachmentDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let taskId: UUID
    public let orgId: UUID
    public let filename: String
    public let fileType: String
    public let mimeType: String
    public let size: Int64
    public let createdAt: Date?

    public init(
        id: UUID,
        taskId: UUID,
        orgId: UUID,
        filename: String,
        fileType: String,
        mimeType: String,
        size: Int64,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.orgId = orgId
        self.filename = filename
        self.fileType = fileType
        self.mimeType = mimeType
        self.size = size
        self.createdAt = createdAt
    }
}

// MARK: - Notifications

public struct NotificationDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let userId: UUID
    public let orgId: UUID
    public let actorUserId: UUID
    public let entityType: String
    public let entityId: UUID
    public let type: String
    public let payloadJson: String?
    public let readAt: Date?
    public let createdAt: Date?

    public init(
        id: UUID,
        userId: UUID,
        orgId: UUID,
        actorUserId: UUID,
        entityType: String,
        entityId: UUID,
        type: String,
        payloadJson: String? = nil,
        readAt: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.orgId = orgId
        self.actorUserId = actorUserId
        self.entityType = entityType
        self.entityId = entityId
        self.type = type
        self.payloadJson = payloadJson
        self.readAt = readAt
        self.createdAt = createdAt
    }
}

