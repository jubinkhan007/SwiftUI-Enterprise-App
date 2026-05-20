import Fluent
import Vapor

/// Participant in a meeting. Either an org user (`user_id` set) or a guest
/// (`guest_email` set with `user_id` NULL). The pair (meeting_id, user_id)
/// is unique when user_id is non-null; same for (meeting_id, guest_email).
final class MeetingParticipantModel: Model, Content, @unchecked Sendable {
    static let schema = "meeting_participants"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "meeting_id")
    var meeting: MeetingModel

    @OptionalParent(key: "user_id")
    var user: UserModel?

    @OptionalField(key: "guest_email")
    var guestEmail: String?

    @OptionalField(key: "guest_name")
    var guestName: String?

    /// "host" / "co_host" / "presenter" / "attendee"
    @Field(key: "role")
    var role: String

    /// "pending" / "accepted" / "declined" / "tentative"
    @Field(key: "invite_status")
    var inviteStatus: String

    /// "not_joined" / "waiting" / "in_meeting" / "left" / "denied" / "removed"
    @Field(key: "join_state")
    var joinState: String

    @OptionalField(key: "waiting_since_at")
    var waitingSinceAt: Date?

    @OptionalField(key: "joined_at")
    var joinedAt: Date?

    @OptionalField(key: "left_at")
    var leftAt: Date?

    @OptionalField(key: "last_state_changed_at")
    var lastStateChangedAt: Date?

    @OptionalField(key: "invite_token")
    var inviteToken: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        meetingId: UUID,
        userId: UUID? = nil,
        guestEmail: String? = nil,
        guestName: String? = nil,
        role: String = "attendee",
        inviteStatus: String = "pending",
        joinState: String = "not_joined",
        inviteToken: String? = nil
    ) {
        self.id = id
        self.$meeting.id = meetingId
        if let userId { self.$user.id = userId }
        self.guestEmail = guestEmail
        self.guestName = guestName
        self.role = role
        self.inviteStatus = inviteStatus
        self.joinState = joinState
        self.inviteToken = inviteToken
    }
}
