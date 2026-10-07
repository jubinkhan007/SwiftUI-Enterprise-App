import Fluent
import Vapor
import SharedModels

final class DeviceTokenModel: Model, Content, @unchecked Sendable {
    static let schema = "device_tokens"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: UserModel

    @Field(key: "token")
    var token: String

    @Field(key: "platform")
    var platform: String // "ios", "android", "web"

    @OptionalField(key: "environment")
    var environment: String? // "development", "production", "sandbox"

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userId: UUID,
        token: String,
        platform: String,
        environment: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.token = token
        self.platform = platform
        self.environment = environment
    }

    func toDTO() throws -> DeviceTokenDTO {
        DeviceTokenDTO(
            id: try requireID(),
            userId: $user.id,
            token: token,
            platform: platform,
            environment: environment,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
