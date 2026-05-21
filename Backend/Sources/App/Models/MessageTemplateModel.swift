import Fluent
import Vapor

/// Phase 4 (Productivity): a canned response template.
/// `scope='user'` rows have `owner_user_id` set; `scope='org'` rows have it NULL
/// and are visible to everyone in the org but editable only by org admins.
final class MessageTemplateModel: Model, Content, @unchecked Sendable {
    static let schema = "message_templates"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @OptionalParent(key: "owner_user_id")
    var ownerUser: UserModel?

    /// "user" or "org"
    @Field(key: "scope")
    var scope: String

    @Field(key: "name")
    var name: String

    @OptionalField(key: "shortcut")
    var shortcut: String?

    @Field(key: "body")
    var body: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID,
        ownerUserId: UUID? = nil,
        scope: String,
        name: String,
        shortcut: String? = nil,
        body: String
    ) {
        self.id = id
        self.$organization.id = orgId
        if let ownerUserId { self.$ownerUser.id = ownerUserId }
        self.scope = scope
        self.name = name
        self.shortcut = shortcut
        self.body = body
    }
}
