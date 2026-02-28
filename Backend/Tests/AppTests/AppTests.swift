@testable import App
import Fluent
import XCTVapor
import SharedModels

final class AppTests: XCTestCase {
    func testHealthCheck() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        try configure(app)

        try await app.test(.GET, "health") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testAutomationIdempotencyDedupesByEventId() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        // Seed minimal hierarchy
        let user = UserModel(email: "a+\(UUID().uuidString)@example.com", displayName: "A", passwordHash: "x", role: .admin)
        try await user.save(on: app.db)
        let userId = try user.requireID()

        let org = OrganizationModel(name: "Org-\(UUID().uuidString)", slug: "org-\(UUID().uuidString)", ownerId: userId)
        try await org.save(on: app.db)
        let orgId = try org.requireID()

        let space = SpaceModel(orgId: orgId, name: "Space", description: nil)
        try await space.save(on: app.db)
        let spaceId = try space.requireID()

        let project = ProjectModel(spaceId: spaceId, name: "Project", description: nil, workflowVersion: 1)
        try await project.save(on: app.db)
        let projectId = try project.requireID()

        let todo = CustomStatusModel(
            projectId: projectId,
            name: "To Do",
            color: "#94A3B8",
            position: 0,
            category: .backlog,
            isDefault: true,
            isFinal: false,
            isLocked: true,
            legacyStatus: TaskStatus.todo.rawValue
        )
        let done = CustomStatusModel(
            projectId: projectId,
            name: "Done",
            color: "#22C55E",
            position: 1000,
            category: .completed,
            isDefault: false,
            isFinal: true,
            isLocked: true,
            legacyStatus: TaskStatus.done.rawValue
        )
        try await todo.save(on: app.db)
        try await done.save(on: app.db)

        let list = TaskListModel(projectId: projectId, name: "List", color: "#4F46E5")
        try await list.save(on: app.db)
        let listId = try list.requireID()

        let task = TaskItemModel(
            orgId: orgId,
            listId: listId,
            title: "T",
            description: nil,
            status: .todo,
            statusId: try todo.requireID(),
            priority: .medium,
            taskType: .task
        )
        try await task.save(on: app.db)
        let taskId = try task.requireID()

        let rule = AutomationRuleModel(
            projectId: projectId,
            name: "Set High Priority",
            isEnabled: true,
            triggerType: "task.status_changed",
            triggerConfigJson: nil,
            conditionsJson: nil,
            actionsJson: #"[{"type":"setPriority","value":"high"}]"#
        )
        try await rule.save(on: app.db)

        // Simulate a canonical "status changed" event and task state after the change.
        let eventId = UUID().uuidString
        task.$customStatus.id = try done.requireID()
        task.status = .done
        try await task.save(on: app.db)

        let event = AutomationService.TaskEvent(
            eventId: eventId,
            orgId: orgId,
            projectId: projectId,
            workflowVersion: project.workflowVersion,
            taskId: taskId,
            userId: userId,
            isCreated: false,
            statusIdChange: .init(from: try todo.requireID(), to: try done.requireID()),
            priorityChange: nil,
            typeChange: nil
        )

        await AutomationService.applyAutomations(event: event, task: task, db: app.db, logger: app.logger)
        await AutomationService.applyAutomations(event: event, task: task, db: app.db, logger: app.logger)

        let reloaded = try await TaskItemModel.find(taskId, on: app.db)
        XCTAssertEqual(reloaded?.priority, .high)

        let ruleId = try rule.requireID()
        let execCount = try await AutomationExecutionModel.query(on: app.db)
            .filter(\.$rule.$id == ruleId)
            .filter(\.$task.$id == taskId)
            .filter(\.$eventId == eventId)
            .count()
        XCTAssertEqual(execCount, 1)
    }

    func testAutomationSkipsNoopActions() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let user = UserModel(email: "b+\(UUID().uuidString)@example.com", displayName: "B", passwordHash: "x", role: .admin)
        try await user.save(on: app.db)
        let userId = try user.requireID()

        let org = OrganizationModel(name: "Org-\(UUID().uuidString)", slug: "org-\(UUID().uuidString)", ownerId: userId)
        try await org.save(on: app.db)
        let orgId = try org.requireID()

        let space = SpaceModel(orgId: orgId, name: "Space", description: nil)
        try await space.save(on: app.db)
        let spaceId = try space.requireID()

        let project = ProjectModel(spaceId: spaceId, name: "Project", description: nil, workflowVersion: 1)
        try await project.save(on: app.db)
        let projectId = try project.requireID()

        let todo = CustomStatusModel(
            projectId: projectId,
            name: "To Do",
            color: "#94A3B8",
            position: 0,
            category: .backlog,
            isDefault: true,
            isFinal: false,
            isLocked: true,
            legacyStatus: TaskStatus.todo.rawValue
        )
        try await todo.save(on: app.db)

        let list = TaskListModel(projectId: projectId, name: "List", color: "#4F46E5")
        try await list.save(on: app.db)
        let listId = try list.requireID()

        let task = TaskItemModel(
            orgId: orgId,
            listId: listId,
            title: "T",
            description: nil,
            status: .todo,
            statusId: try todo.requireID(),
            priority: .medium,
            taskType: .task
        )
        try await task.save(on: app.db)
        let taskId = try task.requireID()

        let rule = AutomationRuleModel(
            projectId: projectId,
            name: "No-op Priority",
            isEnabled: true,
            triggerType: "task.updated",
            triggerConfigJson: nil,
            conditionsJson: nil,
            actionsJson: #"[{"type":"setPriority","value":"medium"}]"#
        )
        try await rule.save(on: app.db)

        let eventId = UUID().uuidString
        let event = AutomationService.TaskEvent(
            eventId: eventId,
            orgId: orgId,
            projectId: projectId,
            workflowVersion: project.workflowVersion,
            taskId: taskId,
            userId: userId,
            isCreated: false,
            statusIdChange: nil,
            priorityChange: nil,
            typeChange: nil
        )

        await AutomationService.applyAutomations(event: event, task: task, db: app.db, logger: app.logger)

        let ruleId = try rule.requireID()
        let exec = try await AutomationExecutionModel.query(on: app.db)
            .filter(\.$rule.$id == ruleId)
            .filter(\.$task.$id == taskId)
            .filter(\.$eventId == eventId)
            .first()
        XCTAssertEqual(exec?.status, "skipped")

        let reloaded = try await TaskItemModel.find(taskId, on: app.db)
        XCTAssertEqual(reloaded?.priority, .medium)
    }
}
