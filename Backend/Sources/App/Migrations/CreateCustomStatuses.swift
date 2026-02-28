import Fluent
import Vapor
import SQLKit

/// Creates the `custom_statuses` table for per-project workflows.
struct CreateCustomStatuses: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(CustomStatusModel.schema)
            .id()
            .field("project_id", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("color", .string, .required, .sql(.default("#4F46E5")))
            .field("position", .double, .required, .sql(.default(0.0)))
            .field("category", .string, .required, .sql(.default("backlog")))
            .field("is_default", .bool, .required, .sql(.default(false)))
            .field("is_final", .bool, .required, .sql(.default(false)))
            .field("is_locked", .bool, .required, .sql(.default(false)))
            .field("legacy_status", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "project_id", "name")
            .create()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_custom_statuses_project_pos ON custom_statuses(project_id, position)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_custom_statuses_project_pos").run()
        }
        try await database.schema(CustomStatusModel.schema).delete()
    }
}
