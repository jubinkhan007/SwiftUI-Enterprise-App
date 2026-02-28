import Fluent
import Vapor

/// Audit log + dedup history for automation rule execution.
final class AutomationExecutionModel: Model, Content, @unchecked Sendable {
    static let schema = "automation_executions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "rule_id")
    var rule: AutomationRuleModel

    @Parent(key: "task_id")
    var task: TaskItemModel

    /// Deduplication key (unique per rule+task).
    @Field(key: "event_id")
    var eventId: String

    /// Project.workflow_version at evaluation time.
    @Field(key: "workflow_version")
    var workflowVersion: Int

    /// "success" | "failure" | "skipped"
    @Field(key: "status")
    var status: String

    @OptionalField(key: "error")
    var error: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        ruleId: UUID,
        taskId: UUID,
        eventId: String,
        workflowVersion: Int,
        status: String,
        error: String? = nil
    ) {
        self.id = id
        self.$rule.id = ruleId
        self.$task.id = taskId
        self.eventId = eventId
        self.workflowVersion = workflowVersion
        self.status = status
        self.error = error
    }
}

