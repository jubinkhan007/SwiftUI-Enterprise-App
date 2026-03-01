import Fluent
import FluentSQL

struct CreateAttachments: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("attachments")
            .id()
            .field("task_id", .uuid, .required, .references("task_items", "id", onDelete: .cascade))
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("filename", .string, .required)
            .field("file_type", .string, .required)
            .field("mime_type", .string, .required)
            .field("size", .int64, .required)
            .field("storage_key", .string, .required)
            .field("created_at", .datetime)
            .create()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_attachments_task_created ON attachments(task_id, created_at)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_attachments_org_task ON attachments(org_id, task_id)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_attachments_task_created").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_attachments_org_task").run()
        }
        try await database.schema("attachments").delete()
    }
}

