import Fluent
import Vapor

/// Phase 4: a scheduled meeting. Standalone or linked to an existing conversation.
/// Per-meeting chat is backed by an auto-created `type='meeting'` conversation
/// referenced by `meetingChatConversation`.
final class MeetingModel: Model, Content, @unchecked Sendable {
    static let schema = "meetings"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @OptionalParent(key: "conversation_id")
    var conversation: ConversationModel?

    @OptionalParent(key: "meeting_chat_conversation_id")
    var meetingChatConversation: ConversationModel?

    @Field(key: "title")
    var title: String

    @OptionalField(key: "description")
    var description: String?

    @OptionalField(key: "agenda")
    var agenda: String?

    @Field(key: "scheduled_start_at")
    var scheduledStartAt: Date

    @Field(key: "scheduled_end_at")
    var scheduledEndAt: Date

    @Field(key: "timezone")
    var timezone: String

    /// "scheduled" / "in_progress" / "ended" / "cancelled"
    @Field(key: "status")
    var status: String

    @OptionalField(key: "started_at")
    var startedAt: Date?

    @OptionalField(key: "ended_at")
    var endedAt: Date?

    @OptionalField(key: "cancelled_at")
    var cancelledAt: Date?

    @OptionalField(key: "cancel_reason")
    var cancelReason: String?

    @Parent(key: "host_id")
    var host: UserModel

    @Field(key: "requires_waiting_room")
    var requiresWaitingRoom: Bool

    @Field(key: "allow_guests")
    var allowGuests: Bool

    @Field(key: "join_code")
    var joinCode: String

    @Field(key: "access_token")
    var accessToken: String

    /// "internal" / "agora" / "livekit"
    @Field(key: "provider")
    var provider: String

    @OptionalField(key: "provider_session_id")
    var providerSessionId: String?

    /// JSON-encoded simple recurrence: {"freq":"weekly","interval":1,"byweekday":[1,3],"count":10,"until":"2026-12-31T..."}
    @OptionalField(key: "recurrence_rule")
    var recurrenceRule: String?

    @OptionalParent(key: "parent_meeting_id")
    var parentMeeting: MeetingModel?

    @Parent(key: "created_by")
    var createdBy: UserModel

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$meeting)
    var participants: [MeetingParticipantModel]

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID,
        conversationId: UUID? = nil,
        meetingChatConversationId: UUID? = nil,
        title: String,
        description: String? = nil,
        agenda: String? = nil,
        scheduledStartAt: Date,
        scheduledEndAt: Date,
        timezone: String,
        status: String = "scheduled",
        hostId: UUID,
        requiresWaitingRoom: Bool = true,
        allowGuests: Bool = false,
        joinCode: String,
        accessToken: String,
        provider: String = "internal",
        recurrenceRule: String? = nil,
        parentMeetingId: UUID? = nil,
        createdBy: UUID
    ) {
        self.id = id
        self.$organization.id = orgId
        if let conversationId { self.$conversation.id = conversationId }
        if let meetingChatConversationId { self.$meetingChatConversation.id = meetingChatConversationId }
        self.title = title
        self.description = description
        self.agenda = agenda
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.timezone = timezone
        self.status = status
        self.$host.id = hostId
        self.requiresWaitingRoom = requiresWaitingRoom
        self.allowGuests = allowGuests
        self.joinCode = joinCode
        self.accessToken = accessToken
        self.provider = provider
        self.recurrenceRule = recurrenceRule
        if let parentMeetingId { self.$parentMeeting.id = parentMeetingId }
        self.$createdBy.id = createdBy
    }
}
