import Fluent

/// Phase 8C migration: creates the checklist_items table.
struct CreateChecklistItem: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(ChecklistItemModel.schema)
            .id()
            .field("task_id", .uuid, .required, .references("task_items", "id", onDelete: .cascade))
            .field("title", .string, .required)
            .field("is_completed", .bool, .required, .sql(.default(false)))
            .field("position", .double, .required, .sql(.default(0.0)))
            .field("created_by", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("updated_by", .uuid, .references("users", "id", onDelete: .setNull))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ChecklistItemModel.schema).delete()
    }
}
