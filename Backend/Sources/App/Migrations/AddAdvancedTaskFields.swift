import Fluent
import SharedModels

/// Phase 8A migration: adds task_type, parent_id, story_points, and labels to task_items.
/// Also extends the activity_type Fluent enum with the three new Phase 8 activity cases.
struct AddAdvancedTaskFields: AsyncMigration {

    func prepare(on database: Database) async throws {
        // 1. We treat task_type as a string in the schema since SQLite enum support can be brittle across migrations
        let taskTypeField: DatabaseSchema.DataType = .string

        // 2. Add new columns to task_items
        // SQLite has limitations with multiple ADD COLUMN in one statement via Fluent, so we do them individually or via raw SQL if needed, but let's try individual updates.
        try await database.schema(TaskItemModel.schema)
            .field("task_type", taskTypeField, .required, .sql(.default("task")))
            .update()

        try await database.schema(TaskItemModel.schema)
            .field("parent_id", .uuid)       // nullable self-ref FK
            .update()

        try await database.schema(TaskItemModel.schema)
            .field("story_points", .int)      // nullable
            .update()

        try await database.schema(TaskItemModel.schema)
            .field("labels", .json)           // nullable [String] stored as JSON
            .update()

        // 3. Extend activity_type enum with new Phase 8 cases safely
        do {
            _ = try await database.enum("activity_type").read()
            // If it exists, add the cases. Fluent handles "already exists" for `.case()` in SQLite by ignoring or erroring if not supported properly. In SQLite, altering an enum isn't strictly necessary for schema validation if the column is string.
            // But if we want to add cases to an existing tracked enum in Fluent SQLite:
            // Activity cases might already be strings, but let's try updating anyway.
            do {
                _ = try await database.enum("activity_type")
                    .case("moved")
                    .case("typeChanged")
                    .case("parentChanged")
                    .update()
            } catch {
                // Ignore if cases already exist or update is not supported here
                database.logger.warning("Could not update activity_type enum, might already exist or be unsupported: \(error)")
            }
        } catch {
            database.logger.warning("activity_type enum not tracked, skipping extension.")
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema(TaskItemModel.schema)
            .deleteField("task_type")
            .deleteField("parent_id")
            .deleteField("story_points")
            .deleteField("labels")
            .update()

        try await database.enum("task_type").delete()
        // Note: we don't roll back the activity_type additions to avoid data loss
    }
}
