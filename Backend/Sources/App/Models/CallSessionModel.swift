import Fluent
import Vapor

/// Phase 4-B (Calls): an SFU room session. Either ad-hoc (initiated from a
/// conversation) or attached to a scheduled meeting via `meeting_id`.
/// `room_name` is the SFU-side identifier (sent in LiveKit tokens / Agora channels).
final class CallSessionModel: Model, Content, @unchecked Sendable {
    static let schema = "call_sessions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "conversation_id")
    var conversation: ConversationModel

    @OptionalParent(key: "meeting_id")
    var meeting: MeetingModel?

    @Parent(key: "host_id")
    var host: UserModel

    @Parent(key: "org_id")
    var organization: OrganizationModel

    /// "initiated" / "active" / "ended" / "cancelled"
    @Field(key: "status")
    var status: String

    @Field(key: "room_name")
    var roomName: String

    @Field(key: "has_video")
    var hasVideo: Bool

    @Field(key: "is_locked")
    var isLocked: Bool

    /// "internal" / "livekit" / "agora"
    @Field(key: "provider")
    var provider: String

    @Timestamp(key: "started_at", on: .create)
    var startedAt: Date?

    @OptionalField(key: "ended_at")
    var endedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$callSession)
    var participants: [CallParticipantModel]

    init() {}

    init(
        id: UUID? = nil,
        conversationId: UUID,
        meetingId: UUID? = nil,
        hostId: UUID,
        orgId: UUID,
        roomName: String,
        hasVideo: Bool = true,
        provider: String = "livekit",
        status: String = "initiated"
    ) {
        self.id = id
        self.$conversation.id = conversationId
        if let meetingId { self.$meeting.id = meetingId }
        self.$host.id = hostId
        self.$organization.id = orgId
        self.roomName = roomName
        self.hasVideo = hasVideo
        self.isLocked = false
        self.provider = provider
        self.status = status
    }
}
