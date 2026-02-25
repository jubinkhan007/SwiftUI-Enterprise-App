import Fluent

/// Phase 8B migration: creates the task_relations table.
struct CreateTaskRelation: AsyncMigration {
    func prepare(on database: Database) async throws {
        _ = try await database.enum("relation_type")
            .case("blocks")
            .case("relatesTo")
            .case("duplicateOf")
            .create()

        let relationType = try await database.enum("relation_type").read()

        try await database.schema(TaskRelationModel.schema)
            .id()
            .field("source_task_id", .uuid, .required, .references("task_items", "id", onDelete: .cascade))
            .field("target_task_id", .uuid, .required, .references("task_items", "id", onDelete: .cascade))
            .field("relation_type", relationType, .required)
            .field("created_at", .datetime)
            // UNIQUE(source_task_id, target_task_id, relation_type) enforced below
            .unique(on: "source_task_id", "target_task_id", "relation_type")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(TaskRelationModel.schema).delete()
        try await database.enum("relation_type").delete()
    }
}
