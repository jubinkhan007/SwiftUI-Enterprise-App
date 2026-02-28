import Fluent
import FluentSQL
import Vapor

/// Step 3: Enforce `status_id` NOT NULL and (when supported) foreign key integrity.
struct EnforceStatusIdOnTasks: AsyncMigration {
    func prepare(on database: Database) async throws {
        // SQLite doesn't support ALTER COLUMN SET NOT NULL without table rebuild.
        if let sql = database as? SQLDatabase, sql.dialect.name == "sqlite" {
            database.logger.warning("Skipping status_id NOT NULL enforcement for SQLite.")
            return
        }

        do {
            try await database.schema(TaskItemModel.schema)
                .updateField("status_id", .uuid)
                .constraint(.custom("ALTER COLUMN status_id SET NOT NULL"))
                .update()
        } catch {
            database.logger.warning("Could not enforce NOT NULL on status_id: \(error)")
        }

        // Best-effort FK constraint for SQL dialects that support it.
        if let sql = database as? SQLDatabase, sql.dialect.name != "sqlite" {
            do {
                try await sql.raw(
                    "ALTER TABLE task_items ADD CONSTRAINT fk_task_items_status_id FOREIGN KEY (status_id) REFERENCES custom_statuses(id) ON DELETE RESTRICT"
                ).run()
            } catch {
                database.logger.warning("Could not add FK constraint for status_id (may already exist): \(error)")
            }
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase, sql.dialect.name == "sqlite" {
            database.logger.warning("Skipping status_id NOT NULL revert for SQLite.")
            return
        }

        if let sql = database as? SQLDatabase, sql.dialect.name != "sqlite" {
            do {
                try await sql.raw("ALTER TABLE task_items DROP CONSTRAINT IF EXISTS fk_task_items_status_id").run()
            } catch {
                database.logger.warning("Could not drop FK constraint for status_id: \(error)")
            }
        }

        do {
            try await database.schema(TaskItemModel.schema)
                .updateField("status_id", .uuid)
                .update()
        } catch {
            database.logger.warning("Could not revert NOT NULL on status_id: \(error)")
        }
    }
}

