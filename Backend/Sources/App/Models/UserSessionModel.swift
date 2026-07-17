import Fluent
import Vapor

/// Model representing an active or historic user login session.
final class UserSessionModel: Model, Content, @unchecked Sendable {
    static let schema = "user_sessions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: UserModel

    @Field(key: "device_type")
    var deviceType: String

    @Field(key: "ip_address")
    var ipAddress: String

    @Field(key: "user_agent")
    var userAgent: String

    @Field(key: "is_revoked")
    var isRevoked: Bool

    @Field(key: "expires_at")
    var expiresAt: Date

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userId: UUID,
        deviceType: String,
        ipAddress: String,
        userAgent: String,
        isRevoked: Bool = false,
        expiresAt: Date
    ) {
        self.id = id
        self.$user.id = userId
        self.deviceType = deviceType
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.isRevoked = isRevoked
        self.expiresAt = expiresAt
    }
}
