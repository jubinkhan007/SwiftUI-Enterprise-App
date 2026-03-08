import Fluent
import Vapor
import Foundation

/// Represents a programmatically generated API Key for an organization.
/// The raw key is only shown once to the user upon creation. We store a bcrypt hash for validation,
/// and a prefix for UI identification purposes.
final class APIKeyModel: Model, @unchecked Sendable {
    static let schema = "api_keys"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Parent(key: "user_id")
    var createdBy: UserModel

    @Field(key: "name")
    var name: String

    @Field(key: "key_hash")
    var keyHash: String

    @Field(key: "key_prefix")
    var keyPrefix: String

    @Field(key: "scopes")
    var scopes: [String]

    @OptionalField(key: "last_used_at")
    var lastUsedAt: Date?

    @OptionalField(key: "expires_at")
    var expiresAt: Date?

    @Field(key: "is_revoked")
    var isRevoked: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID,
        createdById: UUID,
        name: String,
        keyHash: String,
        keyPrefix: String,
        scopes: [String],
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.$organization.id = orgId
        self.$createdBy.id = createdById
        self.name = name
        self.keyHash = keyHash
        self.keyPrefix = keyPrefix
        self.scopes = scopes
        self.expiresAt = expiresAt
        self.isRevoked = false
    }
}
