import Fluent

struct CreateSprintsAndStats: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sprints")
            .id()
            .field("project_id", .uuid, .required, .references("projects", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("start_date", .datetime, .required)
            .field("end_date", .datetime, .required)
            .field("status", .string, .required)
            .field("created_at", .datetime)
            .create()

        try await database.schema("project_daily_stats")
            .id()
            .field("project_id", .uuid, .required, .references("projects", "id", onDelete: .cascade))
            .field("date", .datetime, .required)
            .field("remaining_points", .double, .required)
            .field("completed_points", .double, .required)
            .field("completed_tasks", .int, .required)
            .field("created_tasks", .int, .required)
            .unique(on: "project_id", "date")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("project_daily_stats").delete()
        try await database.schema("sprints").delete()
    }
}
