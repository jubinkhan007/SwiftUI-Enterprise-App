import Fluent

struct AddCompletedAtToTaskItem: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("task_items")
            .field("completed_at", .datetime)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("task_items")
            .deleteField("completed_at")
            .update()
    }
}
