import Fluent

/// Adds the `version` column to the `task_items` table for optimistic concurrency control.
struct AddVersionToTaskItem: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("task_items")
            .field("version", .int, .required, .custom("DEFAULT 1"))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("task_items")
            .deleteField("version")
            .update()
    }
}
