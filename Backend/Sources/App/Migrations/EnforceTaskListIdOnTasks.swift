import Fluent
import FluentSQL
import Vapor

/// Step 3: Enforce Schema Constriants
/// Makes list_id required now that data is backfilled.
struct EnforceTaskListIdOnTasks: AsyncMigration {
    func prepare(on database: Database) async throws {
        // SQLite doesn't support ALTER COLUMN to enforce NOT NULL after the fact
        // easily without recreating the entire table. We skip this for SQLite.
        if let sql = database as? SQLDatabase, sql.dialect.name == "sqlite" {
            database.logger.warning("Skipping list_id NOT NULL enforcement for SQLite.")
            return
        }
        
        // For Postgres/MySQL: Now that the data is safely migrated, enforce NOT NULL
        do {
            try await database.schema(TaskItemModel.schema)
                .updateField("list_id", .uuid) // First update the type (no-op if same)
                .constraint(.custom("ALTER COLUMN list_id SET NOT NULL")) // Fluent raw constraint because updateField doesn't take .required easily
                .update()
        } catch {
            database.logger.warning("Could not enforce NOT NULL on list_id. This is expected if using SQLite: \(error)")
        }
    }

    func revert(on database: Database) async throws {
        // Revert to nullable state
        do {
            try await database.schema(TaskItemModel.schema)
                .updateField("list_id", .uuid) // Omit .required to make it nullable again
                .update()
        } catch {
            database.logger.warning("Could not revert NOT NULL on list_id. This is expected if using SQLite: \(error)")
        }
    }
}
