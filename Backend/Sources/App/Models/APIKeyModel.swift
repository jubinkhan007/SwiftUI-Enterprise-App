import Fluent
import Vapor
import SharedModels

final class APIKeyModel: Model, Content, @unchecked Sendable {
    static let schema = "api_keys"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "user_id")
    var userId: UUID

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

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID,
        userId: UUID,
        name: String,
        keyHash: String,
        keyPrefix: String,
        scopes: [String],
        expiresAt: Date? = nil,
        isRevoked: Bool = false
    ) {
        self.id = id
        self.$organization.id = orgId
        self.userId = userId
        self.name = name
        self.keyHash = keyHash
        self.keyPrefix = keyPrefix
        self.scopes = scopes
        self.expiresAt = expiresAt
        self.isRevoked = isRevoked
    }

    func toDTO() -> APIKeyDTO {
        let parsedScopes = scopes.compactMap(APIKeyScope.init(rawValue:))
        return APIKeyDTO(
            id: id ?? UUID(),
            orgId: $organization.id,
            userId: userId,
            name: name,
            keyPrefix: keyPrefix,
            scopes: parsedScopes,
            lastUsedAt: lastUsedAt,
            expiresAt: expiresAt,
            isRevoked: isRevoked,
            createdAt: createdAt
        )
    }
}

