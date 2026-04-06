import Fluent
import Vapor

/// Represents a conversation — either a 1-on-1 DM or a group/channel.
final class ConversationModel: Model, Content, @unchecked Sendable {
    static let schema = "conversations"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "type")
    var type: String  // "direct", "group", "channel"

    @OptionalField(key: "name")
    var name: String?

    @OptionalField(key: "description")
    var description: String?

    @OptionalField(key: "topic")
    var topic: String?

    @Field(key: "is_archived")
    var isArchived: Bool

    @Field(key: "is_private")
    var isPrivate: Bool

    @OptionalParent(key: "created_by")
    var createdBy: UserModel?

    @OptionalParent(key: "owner_id")
    var owner: UserModel?

    @OptionalField(key: "last_message_at")
    var lastMessageAt: Date?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$conversation)
    var members: [ConversationMemberModel]

    @Children(for: \.$conversation)
    var messages: [MessageModel]

    init() {}

    init(
        id: UUID? = nil,
        type: String = "direct",
        name: String? = nil,
        description: String? = nil,
        topic: String? = nil,
        isArchived: Bool = false,
        isPrivate: Bool = true,
        createdBy: UUID? = nil,
        ownerId: UUID? = nil,
        orgId: UUID
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.topic = topic
        self.isArchived = isArchived
        self.isPrivate = isPrivate
        if let createdBy { self.$createdBy.id = createdBy }
        if let ownerId { self.$owner.id = ownerId }
        self.$organization.id = orgId
    }
}
