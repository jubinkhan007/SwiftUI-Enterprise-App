import Foundation

// MARK: - Enums

public enum ScheduledMessageStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case scheduled
    case sending
    case sent
    case cancelled
    case failed
}

public enum TemplateScope: String, Codable, Sendable, CaseIterable, Hashable {
    case user
    case org
}

public enum ReminderStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case pending
    case fired
    case dismissed
    case snoozed
}

public enum ReminderSourceType: String, Codable, Sendable, CaseIterable, Hashable {
    case message
    case task
    case meeting
}

// MARK: - Drafts

public struct MessageDraftDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let userId: UUID
    public let conversationId: UUID
    public let parentId: UUID?
    public let body: String
    public let updatedAt: Date?

    public init(
        id: UUID,
        userId: UUID,
        conversationId: UUID,
        parentId: UUID? = nil,
        body: String,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.conversationId = conversationId
        self.parentId = parentId
        self.body = body
        self.updatedAt = updatedAt
    }
}

public struct UpsertDraftRequest: Codable, Sendable, Hashable {
    public let parentId: UUID?
    public let body: String

    public init(parentId: UUID? = nil, body: String) {
        self.parentId = parentId
        self.body = body
    }
}

// MARK: - Scheduled messages

public struct ScheduledMessageDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let userId: UUID
    public let orgId: UUID
    public let conversationId: UUID
    public let parentId: UUID?
    public let body: String
    public let messageType: String
    public let scheduledFor: Date
    public let status: ScheduledMessageStatus
    public let sentMessageId: UUID?
    public let error: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        userId: UUID,
        orgId: UUID,
        conversationId: UUID,
        parentId: UUID? = nil,
        body: String,
        messageType: String = "text",
        scheduledFor: Date,
        status: ScheduledMessageStatus,
        sentMessageId: UUID? = nil,
        error: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.orgId = orgId
        self.conversationId = conversationId
        self.parentId = parentId
        self.body = body
        self.messageType = messageType
        self.scheduledFor = scheduledFor
        self.status = status
        self.sentMessageId = sentMessageId
        self.error = error
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CreateScheduledMessageRequest: Codable, Sendable, Hashable {
    public let body: String
    public let parentId: UUID?
    public let messageType: String?
    public let scheduledFor: Date

    public init(body: String, parentId: UUID? = nil, messageType: String? = nil, scheduledFor: Date) {
        self.body = body
        self.parentId = parentId
        self.messageType = messageType
        self.scheduledFor = scheduledFor
    }
}

public struct UpdateScheduledMessageRequest: Codable, Sendable, Hashable {
    public let body: String?
    public let scheduledFor: Date?

    public init(body: String? = nil, scheduledFor: Date? = nil) {
        self.body = body
        self.scheduledFor = scheduledFor
    }
}

// MARK: - Templates

public struct MessageTemplateDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let orgId: UUID
    public let ownerUserId: UUID?
    public let scope: TemplateScope
    public let name: String
    public let shortcut: String?
    public let body: String
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        orgId: UUID,
        ownerUserId: UUID? = nil,
        scope: TemplateScope,
        name: String,
        shortcut: String? = nil,
        body: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.ownerUserId = ownerUserId
        self.scope = scope
        self.name = name
        self.shortcut = shortcut
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CreateTemplateRequest: Codable, Sendable, Hashable {
    public let scope: TemplateScope
    public let name: String
    public let shortcut: String?
    public let body: String

    public init(scope: TemplateScope, name: String, shortcut: String? = nil, body: String) {
        self.scope = scope
        self.name = name
        self.shortcut = shortcut
        self.body = body
    }
}

public struct UpdateTemplateRequest: Codable, Sendable, Hashable {
    public let name: String?
    public let shortcut: String?
    public let body: String?

    public init(name: String? = nil, shortcut: String? = nil, body: String? = nil) {
        self.name = name
        self.shortcut = shortcut
        self.body = body
    }
}

public struct RenderTemplateRequest: Codable, Sendable, Hashable {
    public let conversationId: UUID?

    public init(conversationId: UUID? = nil) {
        self.conversationId = conversationId
    }
}

public struct RenderedTemplateDTO: Codable, Sendable, Hashable {
    public let templateId: UUID
    public let body: String

    public init(templateId: UUID, body: String) {
        self.templateId = templateId
        self.body = body
    }
}

// MARK: - Reminders

public struct ReminderDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let userId: UUID
    public let orgId: UUID
    public let body: String
    public let remindAt: Date
    public let status: ReminderStatus
    public let sourceType: ReminderSourceType?
    public let sourceId: UUID?
    public let firedAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        userId: UUID,
        orgId: UUID,
        body: String,
        remindAt: Date,
        status: ReminderStatus,
        sourceType: ReminderSourceType? = nil,
        sourceId: UUID? = nil,
        firedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.orgId = orgId
        self.body = body
        self.remindAt = remindAt
        self.status = status
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.firedAt = firedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CreateReminderRequest: Codable, Sendable, Hashable {
    public let body: String
    public let remindAt: Date
    public let sourceType: ReminderSourceType?
    public let sourceId: UUID?

    public init(body: String, remindAt: Date, sourceType: ReminderSourceType? = nil, sourceId: UUID? = nil) {
        self.body = body
        self.remindAt = remindAt
        self.sourceType = sourceType
        self.sourceId = sourceId
    }
}

public struct UpdateReminderRequest: Codable, Sendable, Hashable {
    public let body: String?
    public let remindAt: Date?

    public init(body: String? = nil, remindAt: Date? = nil) {
        self.body = body
        self.remindAt = remindAt
    }
}

public struct SnoozeReminderRequest: Codable, Sendable, Hashable {
    public let minutes: Int

    public init(minutes: Int) {
        self.minutes = minutes
    }
}

public struct CreateMessageReminderRequest: Codable, Sendable, Hashable {
    public let remindAt: Date
    public let body: String?

    public init(remindAt: Date, body: String? = nil) {
        self.remindAt = remindAt
        self.body = body
    }
}
