import Fluent
import Vapor

/// Step 2: Safe Data Backfill
/// Iterates through all Orgs, creates a default hierarchy, and assigns existing orphaned tasks to it.
struct BackfillTasksToDefaultHierarchies: AsyncMigration {
    func prepare(on database: Database) async throws {
        let logger = database.logger
        
        // 1. Fetch all existing organizations
        let organizations = try await OrganizationModel.query(on: database).all()
        logger.info("Starting safe backfill for \(organizations.count) organizations.")
        
        for org in organizations {
            guard let orgId = org.id else { continue }
            
            // 2. Find orphaned tasks for this org
            let orphanedTasks = try await TaskItemModel.query(on: database)
                .filter(\.$organization.$id == orgId)
                // In raw SQL, list_id is currently NULL for old tasks
                .filter(.sql(raw: "list_id IS NULL"))
                .all()
            
            if orphanedTasks.isEmpty {
                logger.debug("No orphaned tasks found for Org: \(org.name). Skipping defaults.")
                continue
            }
            
            // 3. Create Default Hierarchy for this Org
            let defaultSpace = SpaceModel(orgId: orgId, name: "Default Space", description: "Auto-generated space for existing tasks.")
            try await defaultSpace.save(on: database)
            guard let spaceId = defaultSpace.id else { continue }
            
            let defaultProject = ProjectModel(spaceId: spaceId, name: "General Project", description: "Auto-generated project for exiting tasks.")
            try await defaultProject.save(on: database)
            guard let projectId = defaultProject.id else { continue }
            
            let defaultList = TaskListModel(projectId: projectId, name: "To Do List", color: "#4F46E5")
            try await defaultList.save(on: database)
            guard let listId = defaultList.id else { continue }
            
            // 4. Update orphaned tasks and set sequential positions
            for (index, task) in orphanedTasks.enumerated() {
                task.$list.id = listId
                task.position = Double(index * 1000) // Space out positions for easy drag-drop insertion later
                try await task.save(on: database)
            }
            
            logger.info("Successfully backfilled \(orphanedTasks.count) tasks into 'To Do List' for Org: \(org.name)")
        }
    }

    func revert(on database: Database) async throws {
        // Warning: This revert is destructive to the hierarchy but safe for Tasks.
        // Tasks will simply have their list_id nullified in revert of Migration 1.
        let logger = database.logger
        logger.warning("Reverting BackfillTasksToDefaultHierarchies. Note: Tasks will revert to orphaned state when list_id field is dropped in step 1.")
        
        // We delete the auto-generated spaces, which cascade deletes Projects and Lists.
        // It does NOT cascade delete Tasks because list_id is still nullable at this stage.
        try await SpaceModel.query(on: database)
            .filter(\.$name == "Default Space")
            .delete()
    }
}
