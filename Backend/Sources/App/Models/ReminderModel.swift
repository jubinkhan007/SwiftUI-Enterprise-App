import Fluent
import Vapor

/// Phase 4 (Productivity): a reminder. Standalone (source_type NULL) or bound
/// to a message/task/meeting. Status transitions:
/// pending -> fired (via background runner) -> dismissed
/// pending -> snoozed -> pending (with new remind_at)
final class ReminderModel: Model, Content, @unchecked Sendable {
    static let schema = "reminders"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: UserModel

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "body")
    var body: String

    @Field(key: "remind_at")
    var remindAt: Date

    /// "pending" / "fired" / "dismissed" / "snoozed"
    @Field(key: "status")
    var status: String

    /// "message" / "task" / "meeting" / nil
    @OptionalField(key: "source_type")
    var sourceType: String?

    @OptionalField(key: "source_id")
    var sourceId: UUID?

    @OptionalField(key: "fired_at")
    var firedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userId: UUID,
        orgId: UUID,
        body: String,
        remindAt: Date,
        status: String = "pending",
        sourceType: String? = nil,
        sourceId: UUID? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.$organization.id = orgId
        self.body = body
        self.remindAt = remindAt
        self.status = status
        self.sourceType = sourceType
        self.sourceId = sourceId
    }
}
