import Fluent
import Vapor

/// Per-user state in a call session. Status moves
/// invited -> ringing -> connected -> disconnected
/// (or invited -> declined / disconnected -> ejected).
final class CallParticipantModel: Model, Content, @unchecked Sendable {
    static let schema = "call_participants"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "call_session_id")
    var callSession: CallSessionModel

    @Parent(key: "user_id")
    var user: UserModel

    /// "host" / "presenter" / "participant"
    @Field(key: "role")
    var role: String

    /// "invited" / "ringing" / "connected" / "declined" / "disconnected" / "ejected"
    @Field(key: "status")
    var status: String

    @Field(key: "is_audio_muted")
    var isAudioMuted: Bool

    @Field(key: "is_video_muted")
    var isVideoMuted: Bool

    @Field(key: "is_screen_sharing")
    var isScreenSharing: Bool

    @OptionalField(key: "joined_at")
    var joinedAt: Date?

    @OptionalField(key: "left_at")
    var leftAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        callSessionId: UUID,
        userId: UUID,
        role: String = "participant",
        status: String = "invited"
    ) {
        self.id = id
        self.$callSession.id = callSessionId
        self.$user.id = userId
        self.role = role
        self.status = status
        self.isAudioMuted = false
        self.isVideoMuted = false
        self.isScreenSharing = false
    }
}
