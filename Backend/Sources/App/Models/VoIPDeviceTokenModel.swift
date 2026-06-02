import Fluent
import Vapor

/// Phase 4-B: APNs VoIP push device tokens, used by PushKit to wake the iOS
/// client into a CallKit screen on incoming calls. We only persist the token
/// here; actual dispatch needs the VoIP cert + APNs HTTP/2 client.
final class VoIPDeviceTokenModel: Model, Content, @unchecked Sendable {
    static let schema = "voip_device_tokens"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: UserModel

    @Field(key: "device_token")
    var deviceToken: String

    @Field(key: "bundle_id")
    var bundleId: String

    @Field(key: "environment")
    var environment: String  // "sandbox" / "production"

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userId: UUID,
        deviceToken: String,
        bundleId: String,
        environment: String
    ) {
        self.id = id
        self.$user.id = userId
        self.deviceToken = deviceToken
        self.bundleId = bundleId
        self.environment = environment
    }
}
