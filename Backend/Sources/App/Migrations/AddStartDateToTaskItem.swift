import Fluent

struct AddStartDateToTaskItem: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("task_items")
            .field("start_date", .datetime)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("task_items")
            .deleteField("start_date")
            .update()
    }
}
