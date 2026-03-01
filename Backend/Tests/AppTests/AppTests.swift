@testable import App
import Fluent
import XCTVapor
import SharedModels

final class AppTests: XCTestCase {
    private func signToken(app: Application, userId: UUID, role: UserRole) throws -> String {
        let payload = JWTAuthPayload(
            subject: .init(value: userId.uuidString),
            expiration: .init(value: Date().addingTimeInterval(3600)),
            role: role.rawValue
        )
        return try app.jwt.signers.sign(payload)
    }

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

    func testMentionsCreateOneMentionAndNotification() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let actor = UserModel(email: "actor+\(UUID().uuidString)@example.com", displayName: "Actor", passwordHash: "x", role: .admin)
        let mentioned = UserModel(email: "mentioned+\(UUID().uuidString)@example.com", displayName: "Mentioned", passwordHash: "x", role: .member)
        try await actor.save(on: app.db)
        try await mentioned.save(on: app.db)
        let actorId = try actor.requireID()
        let mentionedId = try mentioned.requireID()

        let org = OrganizationModel(name: "Org-\(UUID().uuidString)", slug: "org-\(UUID().uuidString)", ownerId: actorId)
        try await org.save(on: app.db)
        let orgId = try org.requireID()

        try await OrganizationMemberModel(orgId: orgId, userId: actorId, role: .admin).save(on: app.db)
        try await OrganizationMemberModel(orgId: orgId, userId: mentionedId, role: .member).save(on: app.db)

        let space = SpaceModel(orgId: orgId, name: "Space", description: nil)
        try await space.save(on: app.db)
        let spaceId = try space.requireID()

        let project = ProjectModel(spaceId: spaceId, name: "Project", description: nil, workflowVersion: 1)
        try await project.save(on: app.db)
        let projectId = try project.requireID()

        let status = CustomStatusModel(
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
        try await status.save(on: app.db)

        let list = TaskListModel(projectId: projectId, name: "List", color: "#4F46E5")
        try await list.save(on: app.db)
        let listId = try list.requireID()

        let task = TaskItemModel(
            orgId: orgId,
            listId: listId,
            title: "T",
            description: nil,
            status: .todo,
            statusId: try status.requireID(),
            priority: .medium,
            taskType: .task
        )
        try await task.save(on: app.db)
        let taskId = try task.requireID()

        let token = try signToken(app: app, userId: actorId, role: .admin)
        let body = CreateCommentRequest(
            content: "Hello @[Mentioned](user:\(mentionedId.uuidString)) again @[Mentioned](user:\(mentionedId.uuidString))"
        )

        try await app.test(.POST, "api/tasks/\(taskId.uuidString)/comments", beforeRequest: { req in
            try req.content.encode(body)
            req.headers.add(name: .authorization, value: "Bearer \(token)")
            req.headers.add(name: "X-Org-Id", value: orgId.uuidString)
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try res.content.decode(APIResponse<TaskActivityDTO>.self)
            let commentIdStr = decoded.data?.metadata?["comment_id"]
            XCTAssertNotNil(commentIdStr)
            guard let commentIdStr, let commentId = UUID(uuidString: commentIdStr) else { return }

            let mentions = try await MentionModel.query(on: app.db)
                .filter(\.$comment.$id == commentId)
                .filter(\.$user.$id == mentionedId)
                .count()
            XCTAssertEqual(mentions, 1)

            let notifs = try await NotificationModel.query(on: app.db)
                .filter(\.$organization.$id == orgId)
                .filter(\.$user.$id == mentionedId)
                .filter(\.$entityType == "comment")
                .filter(\.$entityId == commentId)
                .filter(\.$type == "mention")
                .filter(\.$readAt == nil)
                .count()
            XCTAssertEqual(notifs, 1)
        }
    }

    func testAttachmentDownloadCrossOrgIsForbidden() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let user1 = UserModel(email: "u1+\(UUID().uuidString)@example.com", displayName: "U1", passwordHash: "x", role: .admin)
        let user2 = UserModel(email: "u2+\(UUID().uuidString)@example.com", displayName: "U2", passwordHash: "x", role: .admin)
        try await user1.save(on: app.db)
        try await user2.save(on: app.db)
        let user1Id = try user1.requireID()
        let user2Id = try user2.requireID()

        let org1 = OrganizationModel(name: "Org1-\(UUID().uuidString)", slug: "org1-\(UUID().uuidString)", ownerId: user1Id)
        let org2 = OrganizationModel(name: "Org2-\(UUID().uuidString)", slug: "org2-\(UUID().uuidString)", ownerId: user2Id)
        try await org1.save(on: app.db)
        try await org2.save(on: app.db)
        let org1Id = try org1.requireID()
        let org2Id = try org2.requireID()

        try await OrganizationMemberModel(orgId: org1Id, userId: user1Id, role: .admin).save(on: app.db)
        try await OrganizationMemberModel(orgId: org2Id, userId: user2Id, role: .admin).save(on: app.db)

        let space = SpaceModel(orgId: org1Id, name: "Space", description: nil)
        try await space.save(on: app.db)
        let spaceId = try space.requireID()

        let project = ProjectModel(spaceId: spaceId, name: "Project", description: nil, workflowVersion: 1)
        try await project.save(on: app.db)
        let projectId = try project.requireID()

        let status = CustomStatusModel(
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
        try await status.save(on: app.db)

        let list = TaskListModel(projectId: projectId, name: "List", color: "#4F46E5")
        try await list.save(on: app.db)
        let listId = try list.requireID()

        let task = TaskItemModel(
            orgId: org1Id,
            listId: listId,
            title: "T",
            description: nil,
            status: .todo,
            statusId: try status.requireID(),
            priority: .medium,
            taskType: .task
        )
        try await task.save(on: app.db)
        let taskId = try task.requireID()

        let attachment = AttachmentModel(
            taskId: taskId,
            orgId: org1Id,
            filename: "a.txt",
            fileType: "document",
            mimeType: "text/plain",
            size: 1,
            storageKey: "org/\(org1Id.uuidString)/tasks/\(taskId.uuidString)/x_a.txt"
        )
        try await attachment.save(on: app.db)
        let attachmentId = try attachment.requireID()

        let token2 = try signToken(app: app, userId: user2Id, role: .admin)
        try await app.test(.GET, "api/attachments/\(attachmentId.uuidString)/download", beforeRequest: { req in
            req.headers.add(name: .authorization, value: "Bearer \(token2)")
            req.headers.add(name: "X-Org-Id", value: org2Id.uuidString)
        }) { res async throws in
            XCTAssertEqual(res.status, .forbidden)
        }
    }
}
