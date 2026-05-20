import Foundation

// MARK: - Enums

public enum MeetingStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case scheduled
    case inProgress = "in_progress"
    case ended
    case cancelled
}

public enum MeetingRole: String, Codable, Sendable, CaseIterable, Hashable {
    case host
    case coHost = "co_host"
    case presenter
    case attendee
}

public enum MeetingInviteStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case pending
    case accepted
    case declined
    case tentative
}

public enum MeetingJoinState: String, Codable, Sendable, CaseIterable, Hashable {
    case notJoined = "not_joined"
    case waiting
    case inMeeting = "in_meeting"
    case left
    case denied
    case removed
}

public enum MeetingProvider: String, Codable, Sendable, CaseIterable, Hashable {
    case `internal`
    case agora
    case livekit
}

public enum MeetingRecurrenceFrequency: String, Codable, Sendable, CaseIterable, Hashable {
    case daily
    case weekly
    case monthly
}

// MARK: - Recurrence

/// Simple recurrence rule. Stored on the server as JSON.
/// Use `count` OR `until` (not both). `byweekday` is 0=Sun .. 6=Sat (only for weekly).
public struct MeetingRecurrenceDTO: Codable, Sendable, Hashable {
    public let freq: MeetingRecurrenceFrequency
    public let interval: Int
    public let byweekday: [Int]?
    public let count: Int?
    public let until: Date?

    public init(
        freq: MeetingRecurrenceFrequency,
        interval: Int = 1,
        byweekday: [Int]? = nil,
        count: Int? = nil,
        until: Date? = nil
    ) {
        self.freq = freq
        self.interval = interval
        self.byweekday = byweekday
        self.count = count
        self.until = until
    }
}

// MARK: - Requests

public struct CreateMeetingRequest: Codable, Sendable, Hashable {
    public let title: String
    public let description: String?
    public let agenda: String?
    public let scheduledStartAt: Date
    public let scheduledEndAt: Date
    public let timezone: String
    public let conversationId: UUID?
    public let memberIds: [UUID]
    public let guestEmails: [String]?
    public let requiresWaitingRoom: Bool?
    public let allowGuests: Bool?
    public let recurrence: MeetingRecurrenceDTO?

    public init(
        title: String,
        description: String? = nil,
        agenda: String? = nil,
        scheduledStartAt: Date,
        scheduledEndAt: Date,
        timezone: String,
        conversationId: UUID? = nil,
        memberIds: [UUID] = [],
        guestEmails: [String]? = nil,
        requiresWaitingRoom: Bool? = nil,
        allowGuests: Bool? = nil,
        recurrence: MeetingRecurrenceDTO? = nil
    ) {
        self.title = title
        self.description = description
        self.agenda = agenda
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.timezone = timezone
        self.conversationId = conversationId
        self.memberIds = memberIds
        self.guestEmails = guestEmails
        self.requiresWaitingRoom = requiresWaitingRoom
        self.allowGuests = allowGuests
        self.recurrence = recurrence
    }
}

public struct UpdateMeetingRequest: Codable, Sendable, Hashable {
    public let title: String?
    public let description: String?
    public let agenda: String?
    public let scheduledStartAt: Date?
    public let scheduledEndAt: Date?
    public let timezone: String?
    public let requiresWaitingRoom: Bool?
    public let allowGuests: Bool?

    public init(
        title: String? = nil,
        description: String? = nil,
        agenda: String? = nil,
        scheduledStartAt: Date? = nil,
        scheduledEndAt: Date? = nil,
        timezone: String? = nil,
        requiresWaitingRoom: Bool? = nil,
        allowGuests: Bool? = nil
    ) {
        self.title = title
        self.description = description
        self.agenda = agenda
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.timezone = timezone
        self.requiresWaitingRoom = requiresWaitingRoom
        self.allowGuests = allowGuests
    }
}

public struct CancelMeetingRequest: Codable, Sendable, Hashable {
    public let reason: String?

    public init(reason: String? = nil) {
        self.reason = reason
    }
}

public struct MeetingRSVPRequest: Codable, Sendable, Hashable {
    public let status: MeetingInviteStatus

    public init(status: MeetingInviteStatus) {
        self.status = status
    }
}

public struct AddMeetingParticipantsRequest: Codable, Sendable, Hashable {
    public let memberIds: [UUID]
    public let guestEmails: [String]?

    public init(memberIds: [UUID] = [], guestEmails: [String]? = nil) {
        self.memberIds = memberIds
        self.guestEmails = guestEmails
    }
}

public struct ChangeMeetingRoleRequest: Codable, Sendable, Hashable {
    public let role: MeetingRole

    public init(role: MeetingRole) {
        self.role = role
    }
}

public struct UpdateMeetingNotesRequest: Codable, Sendable, Hashable {
    public let body: String
    public let expectedVersion: Int

    public init(body: String, expectedVersion: Int) {
        self.body = body
        self.expectedVersion = expectedVersion
    }
}

public struct GenerateMeetingSummaryRequest: Codable, Sendable, Hashable {
    public let regenerate: Bool?

    public init(regenerate: Bool? = nil) {
        self.regenerate = regenerate
    }
}

public struct CreateMeetingActionItemRequest: Codable, Sendable, Hashable {
    public let text: String
    public let assigneeUserId: UUID?
    public let dueAt: Date?
    public let createTaskInListId: UUID?

    public init(text: String, assigneeUserId: UUID? = nil, dueAt: Date? = nil, createTaskInListId: UUID? = nil) {
        self.text = text
        self.assigneeUserId = assigneeUserId
        self.dueAt = dueAt
        self.createTaskInListId = createTaskInListId
    }
}

public struct MeetingHeartbeatRequest: Codable, Sendable, Hashable {
    public init() {}
}

// MARK: - Response DTOs

public struct MeetingParticipantDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let meetingId: UUID
    public let userId: UUID?
    public let guestEmail: String?
    public let guestName: String?
    public let displayName: String
    public let role: MeetingRole
    public let inviteStatus: MeetingInviteStatus
    public let joinState: MeetingJoinState
    public let waitingSinceAt: Date?
    public let joinedAt: Date?
    public let leftAt: Date?
    public let lastStateChangedAt: Date?

    public init(
        id: UUID,
        meetingId: UUID,
        userId: UUID? = nil,
        guestEmail: String? = nil,
        guestName: String? = nil,
        displayName: String,
        role: MeetingRole,
        inviteStatus: MeetingInviteStatus,
        joinState: MeetingJoinState,
        waitingSinceAt: Date? = nil,
        joinedAt: Date? = nil,
        leftAt: Date? = nil,
        lastStateChangedAt: Date? = nil
    ) {
        self.id = id
        self.meetingId = meetingId
        self.userId = userId
        self.guestEmail = guestEmail
        self.guestName = guestName
        self.displayName = displayName
        self.role = role
        self.inviteStatus = inviteStatus
        self.joinState = joinState
        self.waitingSinceAt = waitingSinceAt
        self.joinedAt = joinedAt
        self.leftAt = leftAt
        self.lastStateChangedAt = lastStateChangedAt
    }
}

public struct MeetingDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let orgId: UUID
    public let conversationId: UUID?
    public let meetingChatConversationId: UUID?
    public let title: String
    public let description: String?
    public let agenda: String?
    public let scheduledStartAt: Date
    public let scheduledEndAt: Date
    public let timezone: String
    public let status: MeetingStatus
    public let startedAt: Date?
    public let endedAt: Date?
    public let cancelledAt: Date?
    public let cancelReason: String?
    public let hostId: UUID
    public let hostDisplayName: String?
    public let requiresWaitingRoom: Bool
    public let allowGuests: Bool
    public let joinCode: String
    public let shareUrl: String?
    public let icsUrl: String?
    public let provider: MeetingProvider
    public let recurrence: MeetingRecurrenceDTO?
    public let parentMeetingId: UUID?
    public let participants: [MeetingParticipantDTO]
    public let myParticipant: MeetingParticipantDTO?
    public let waitingCount: Int
    public let createdBy: UUID
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        orgId: UUID,
        conversationId: UUID? = nil,
        meetingChatConversationId: UUID? = nil,
        title: String,
        description: String? = nil,
        agenda: String? = nil,
        scheduledStartAt: Date,
        scheduledEndAt: Date,
        timezone: String,
        status: MeetingStatus,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        cancelledAt: Date? = nil,
        cancelReason: String? = nil,
        hostId: UUID,
        hostDisplayName: String? = nil,
        requiresWaitingRoom: Bool,
        allowGuests: Bool,
        joinCode: String,
        shareUrl: String? = nil,
        icsUrl: String? = nil,
        provider: MeetingProvider,
        recurrence: MeetingRecurrenceDTO? = nil,
        parentMeetingId: UUID? = nil,
        participants: [MeetingParticipantDTO] = [],
        myParticipant: MeetingParticipantDTO? = nil,
        waitingCount: Int = 0,
        createdBy: UUID,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.conversationId = conversationId
        self.meetingChatConversationId = meetingChatConversationId
        self.title = title
        self.description = description
        self.agenda = agenda
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.timezone = timezone
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.cancelledAt = cancelledAt
        self.cancelReason = cancelReason
        self.hostId = hostId
        self.hostDisplayName = hostDisplayName
        self.requiresWaitingRoom = requiresWaitingRoom
        self.allowGuests = allowGuests
        self.joinCode = joinCode
        self.shareUrl = shareUrl
        self.icsUrl = icsUrl
        self.provider = provider
        self.recurrence = recurrence
        self.parentMeetingId = parentMeetingId
        self.participants = participants
        self.myParticipant = myParticipant
        self.waitingCount = waitingCount
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct MeetingListItemDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let scheduledStartAt: Date
    public let scheduledEndAt: Date
    public let timezone: String
    public let status: MeetingStatus
    public let hostId: UUID
    public let hostDisplayName: String?
    public let participantCount: Int
    public let myInviteStatus: MeetingInviteStatus?
    public let myRole: MeetingRole?
    public let waitingCount: Int

    public init(
        id: UUID,
        title: String,
        scheduledStartAt: Date,
        scheduledEndAt: Date,
        timezone: String,
        status: MeetingStatus,
        hostId: UUID,
        hostDisplayName: String? = nil,
        participantCount: Int,
        myInviteStatus: MeetingInviteStatus? = nil,
        myRole: MeetingRole? = nil,
        waitingCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.timezone = timezone
        self.status = status
        self.hostId = hostId
        self.hostDisplayName = hostDisplayName
        self.participantCount = participantCount
        self.myInviteStatus = myInviteStatus
        self.myRole = myRole
        self.waitingCount = waitingCount
    }
}

public struct MeetingJoinTicketDTO: Codable, Sendable, Hashable {
    public let meetingId: UUID
    public let joinState: MeetingJoinState
    public let role: MeetingRole
    public let chatConversationId: UUID?
    public let provider: MeetingProvider
    public let providerToken: String?
    public let providerSessionId: String?

    public init(
        meetingId: UUID,
        joinState: MeetingJoinState,
        role: MeetingRole,
        chatConversationId: UUID? = nil,
        provider: MeetingProvider,
        providerToken: String? = nil,
        providerSessionId: String? = nil
    ) {
        self.meetingId = meetingId
        self.joinState = joinState
        self.role = role
        self.chatConversationId = chatConversationId
        self.provider = provider
        self.providerToken = providerToken
        self.providerSessionId = providerSessionId
    }
}

public struct MeetingNotesDTO: Codable, Sendable, Hashable {
    public let meetingId: UUID
    public let body: String
    public let version: Int
    public let updatedBy: UUID?
    public let updatedAt: Date?

    public init(meetingId: UUID, body: String, version: Int, updatedBy: UUID? = nil, updatedAt: Date? = nil) {
        self.meetingId = meetingId
        self.body = body
        self.version = version
        self.updatedBy = updatedBy
        self.updatedAt = updatedAt
    }
}

public struct MeetingActionItemDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let text: String
    public let assigneeUserId: UUID?
    public let assigneeDisplayName: String?
    public let dueAt: Date?
    public let linkedTaskId: UUID?

    public init(
        id: UUID,
        text: String,
        assigneeUserId: UUID? = nil,
        assigneeDisplayName: String? = nil,
        dueAt: Date? = nil,
        linkedTaskId: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.assigneeUserId = assigneeUserId
        self.assigneeDisplayName = assigneeDisplayName
        self.dueAt = dueAt
        self.linkedTaskId = linkedTaskId
    }
}

public struct MeetingSummaryDTO: Codable, Sendable, Hashable {
    public let meetingId: UUID
    public let summaryText: String
    public let actionItems: [MeetingActionItemDTO]
    public let highlights: [String]
    public let generatedBy: UUID?
    public let source: String
    public let generatedAt: Date?

    public init(
        meetingId: UUID,
        summaryText: String,
        actionItems: [MeetingActionItemDTO] = [],
        highlights: [String] = [],
        generatedBy: UUID? = nil,
        source: String,
        generatedAt: Date? = nil
    ) {
        self.meetingId = meetingId
        self.summaryText = summaryText
        self.actionItems = actionItems
        self.highlights = highlights
        self.generatedBy = generatedBy
        self.source = source
        self.generatedAt = generatedAt
    }
}

public struct MeetingShareLinkDTO: Codable, Sendable, Hashable {
    public let meetingId: UUID
    public let joinCode: String
    public let shareUrl: String
    public let icsUrl: String

    public init(meetingId: UUID, joinCode: String, shareUrl: String, icsUrl: String) {
        self.meetingId = meetingId
        self.joinCode = joinCode
        self.shareUrl = shareUrl
        self.icsUrl = icsUrl
    }
}
