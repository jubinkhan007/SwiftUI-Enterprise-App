import Fluent
import FluentSQL
import Vapor

/// Adds `workflow_version` to projects, used for workflow edits + automation evaluation context.
struct AddWorkflowVersionToProjects: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Add as an additive column (safe for SQLite/Postgres).
        try await database.schema(ProjectModel.schema)
            .field("workflow_version", .int, .required, .sql(.default(1)))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ProjectModel.schema)
            .deleteField("workflow_version")
            .update()
    }
}

