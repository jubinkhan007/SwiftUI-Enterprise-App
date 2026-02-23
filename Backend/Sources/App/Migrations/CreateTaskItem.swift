import Fluent
import SharedModels

/// Creates the `task_items` table.
struct CreateTaskItem: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("task_items")
            .id()
            .field("title", .string, .required)
            .field("description", .string)
            .field("status", .string, .required, .custom("DEFAULT 'todo'"))
            .field("priority", .string, .required, .custom("DEFAULT 'medium'"))
            .field("due_date", .datetime)
            .field("assignee_id", .uuid, .references("users", "id", onDelete: .setNull))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("task_items").delete()
    }
}
