import Fluent
import Vapor

/// Model representing a time log entry logged against a task.
final class TimeLogModel: Model, Content, @unchecked Sendable {
    static let schema = "time_logs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "task_id")
    var task: TaskItemModel

    @Parent(key: "user_id")
    var user: UserModel

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "hours_logged")
    var hoursLogged: Double

    @Field(key: "logged_at")
    var loggedAt: Date

    @OptionalField(key: "description")
    var description: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, taskId: UUID, userId: UUID, orgId: UUID, hoursLogged: Double, loggedAt: Date, description: String? = nil) {
        self.id = id
        self.$task.id = taskId
        self.$user.id = userId
        self.$organization.id = orgId
        self.hoursLogged = hoursLogged
        self.loggedAt = loggedAt
        self.description = description
    }
}
