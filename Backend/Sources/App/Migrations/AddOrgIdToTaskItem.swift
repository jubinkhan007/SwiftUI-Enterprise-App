import Fluent

/// Adds `org_id` foreign key to `task_items` for multi-tenant scoping.
struct AddOrgIdToTaskItem: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("task_items")
            .field("org_id", .uuid, .references("organizations", "id", onDelete: .cascade))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("task_items")
            .deleteField("org_id")
            .update()
    }
}
