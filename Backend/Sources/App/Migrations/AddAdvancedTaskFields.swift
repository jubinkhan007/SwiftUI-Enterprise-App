import Fluent
import SharedModels

/// Phase 8A migration: adds task_type, parent_id, story_points, and labels to task_items.
/// Also extends the activity_type Fluent enum with the three new Phase 8 activity cases.
struct AddAdvancedTaskFields: AsyncMigration {

    func prepare(on database: Database) async throws {
        // 1. Register the task_type Fluent enum
        _ = try await database.enum("task_type")
            .case("task")
            .case("bug")
            .case("story")
            .case("epic")
            .case("subtask")
            .create()

        let taskTypeEnum = try await database.enum("task_type").read()

        // 2. Add new columns to task_items
        try await database.schema(TaskItemModel.schema)
            .field("task_type", taskTypeEnum, .required, .sql(.default("task")))
            .field("parent_id", .uuid)       // nullable self-ref FK; SQLite can't add FK via ALTER
            .field("story_points", .int)      // nullable
            .field("labels", .json)           // nullable [String] stored as JSON
            .update()

        // 3. Extend activity_type enum with new Phase 8 cases
        _ = try await database.enum("activity_type")
            .case("moved")
            .case("typeChanged")
            .case("parentChanged")
            .update()
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
