import Fluent
import Vapor

/// Step 1: Add new tables and nullable relationships to existing tasks.
/// This is the safe additive phase of the migration.
struct AddTaskListHierarchy: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Recover from prior partial run
        try? await database.schema(TaskListModel.schema).delete()
        try? await database.schema(ProjectModel.schema).delete()
        try? await database.schema(SpaceModel.schema).delete()
        
        // 1. Create Spaces Table
        try await database.schema(SpaceModel.schema)
            .id()
            .field("org_id", .uuid, .required, .references(OrganizationModel.schema, "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("description", .string)
            .field("position", .double, .required, .sql(.default(0.0)))
            .field("archived_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // 2. Create Projects Table
        try await database.schema(ProjectModel.schema)
            .id()
            .field("space_id", .uuid, .required, .references(SpaceModel.schema, "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("description", .string)
            .field("position", .double, .required, .sql(.default(0.0)))
            .field("archived_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // 3. Create TaskLists Table
        try await database.schema(TaskListModel.schema)
            .id()
            .field("project_id", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("color", .string)
            .field("position", .double, .required, .sql(.default(0.0)))
            .field("archived_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // 4. Update TaskItems Table (list_id is NULLABLE initially)
        // Note: SQLite does not support adding foreign key constraints via ALTER TABLE.
        // The list_id is added as a plain UUID.
        try await database.schema(TaskItemModel.schema)
            .field("list_id", .uuid)
            .update()
            
        try await database.schema(TaskItemModel.schema)
            .field("position", .double, .required, .sql(.default(0.0)))
            .update()
            
        try await database.schema(TaskItemModel.schema)
            .field("archived_at", .datetime)
            .update()
    }

    func revert(on database: Database) async throws {
        // 1. Revert TaskItems Table
        try await database.schema(TaskItemModel.schema)
            .deleteField("list_id")
            .update()
            
        try await database.schema(TaskItemModel.schema)
            .deleteField("position")
            .update()
            
        try await database.schema(TaskItemModel.schema)
            .deleteField("archived_at")
            .update()

        // 2. Drop New Tables
        try await database.schema(TaskListModel.schema).delete()
        try await database.schema(ProjectModel.schema).delete()
        try await database.schema(SpaceModel.schema).delete()
    }
}
