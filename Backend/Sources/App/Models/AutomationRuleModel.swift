import Fluent
import Vapor

/// Stores an automation rule using Trigger -> Conditions -> Actions (all JSON).
final class AutomationRuleModel: Model, Content, @unchecked Sendable {
    static let schema = "automation_rules"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: ProjectModel

    @Field(key: "name")
    var name: String

    @Field(key: "is_enabled")
    var isEnabled: Bool

    @Field(key: "trigger_type")
    var triggerType: String

    @OptionalField(key: "trigger_config_json")
    var triggerConfigJson: String?

    @OptionalField(key: "conditions_json")
    var conditionsJson: String?

    @OptionalField(key: "actions_json")
    var actionsJson: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        projectId: UUID,
        name: String,
        isEnabled: Bool = true,
        triggerType: String,
        triggerConfigJson: String? = nil,
        conditionsJson: String? = nil,
        actionsJson: String? = nil
    ) {
        self.id = id
        self.$project.id = projectId
        self.name = name
        self.isEnabled = isEnabled
        self.triggerType = triggerType
        self.triggerConfigJson = triggerConfigJson
        self.conditionsJson = conditionsJson
        self.actionsJson = actionsJson
    }
}

