import Fluent
import SharedModels

/// Creates the `task_activities` table for audit logs and comments.
struct CreateTaskActivity: AsyncMigration {
    func prepare(on database: Database) async throws {
        _ = try await database.enum("activity_type")
            .case("created")
            .case("statusChanged")
            .case("comment")
            .case("assigned")
            .case("priorityChanged")
            .create()
            
        let activityType = try await database.enum("activity_type").read()

        try await database.schema("task_activities")
            .id()
            .field("task_id", .uuid, .required, .references("task_items", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("type", activityType, .required)
            .field("content", .string)
            .field("metadata", .dictionary)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("task_activities").delete()
        try await database.enum("activity_type").delete()
    }
}
