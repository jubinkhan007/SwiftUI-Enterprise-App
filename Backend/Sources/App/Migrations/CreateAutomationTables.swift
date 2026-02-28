import Fluent
import SQLKit
import Vapor

/// Creates automation rule + execution tables.
struct CreateAutomationTables: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(AutomationRuleModel.schema)
            .id()
            .field("project_id", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("is_enabled", .bool, .required, .sql(.default(true)))
            .field("trigger_type", .string, .required)
            .field("trigger_config_json", .string)
            .field("conditions_json", .string)
            .field("actions_json", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        try await database.schema(AutomationExecutionModel.schema)
            .id()
            .field("rule_id", .uuid, .required, .references(AutomationRuleModel.schema, "id", onDelete: .cascade))
            .field("task_id", .uuid, .required, .references(TaskItemModel.schema, "id", onDelete: .cascade))
            .field("event_id", .string, .required)
            .field("workflow_version", .int, .required)
            .field("status", .string, .required)
            .field("error", .string)
            .field("created_at", .datetime)
            .create()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE UNIQUE INDEX IF NOT EXISTS uq_automation_exec_rule_task_event ON automation_executions(rule_id, task_id, event_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_automation_rules_project ON automation_rules(project_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_automation_exec_task ON automation_executions(task_id)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS uq_automation_exec_rule_task_event").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_automation_rules_project").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_automation_exec_task").run()
        }

        try await database.schema(AutomationExecutionModel.schema).delete()
        try await database.schema(AutomationRuleModel.schema).delete()
    }
}

