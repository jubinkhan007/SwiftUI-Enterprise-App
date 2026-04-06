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

    private struct Seed {
        let userId: UUID
        let orgId: UUID
        let projectId: UUID
        let listId: UUID
        let todoStatusId: UUID
        let doneStatusId: UUID
        let token: String
    }

    private func seedBasicProject(app: Application, userRole: UserRole = .admin, membershipRole: UserRole = .admin) async throws -> Seed {
        let user = UserModel(email: "seed+\(UUID().uuidString)@example.com", displayName: "Seed", passwordHash: "x", role: userRole)
        try await user.save(on: app.db)
        let userId = try user.requireID()

        let org = OrganizationModel(name: "Org-\(UUID().uuidString)", slug: "org-\(UUID().uuidString)", ownerId: userId)
        try await org.save(on: app.db)
        let orgId = try org.requireID()
        try await OrganizationMemberModel(orgId: orgId, userId: userId, role: membershipRole).save(on: app.db)

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

        let token = try signToken(app: app, userId: userId, role: membershipRole)
        return Seed(
            userId: userId,
            orgId: orgId,
            projectId: projectId,
            listId: listId,
            todoStatusId: try todo.requireID(),
            doneStatusId: try done.requireID(),
            token: token
        )
    }

    func testHealthCheck() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        try configure(app)

        try await app.test(.GET, "health") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testGetWorkflowReturnsOK() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app)
        try await app.test(.GET, "api/projects/\(seed.projectId.uuidString)/workflow") { req async in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            do {
                let decoded = try res.content.decode(APIResponse<WorkflowBundleDTO>.self)
                XCTAssertEqual(decoded.data?.projectId, seed.projectId)
            } catch {
                XCTFail("Failed to decode workflow response: \(error)")
            }
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

    func testBurndownAggregationRespectsUTCDateBoundaries() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let user = UserModel(email: "utc+\(UUID().uuidString)@example.com", displayName: "UTC", passwordHash: "x", role: .admin)
        try await user.save(on: app.db)
        let userId = try user.requireID()

        let org = OrganizationModel(name: "Org-\(UUID().uuidString)", slug: "org-\(UUID().uuidString)", ownerId: userId)
        try await org.save(on: app.db)
        let orgId = try org.requireID()
        try await OrganizationMemberModel(orgId: orgId, userId: userId, role: .admin).save(on: app.db)

        let space = SpaceModel(orgId: orgId, name: "Space", description: nil)
        try await space.save(on: app.db)
        let spaceId = try space.requireID()

        let project = ProjectModel(spaceId: spaceId, name: "Project", description: nil, workflowVersion: 1)
        try await project.save(on: app.db)
        let projectId = try project.requireID()

        let backlog = CustomStatusModel(
            projectId: projectId,
            name: "Backlog",
            color: "#94A3B8",
            position: 0,
            category: .backlog,
            isDefault: true,
            isFinal: false,
            isLocked: true,
            legacyStatus: TaskStatus.todo.rawValue
        )
        try await backlog.save(on: app.db)
        let backlogId = try backlog.requireID()

        let list = TaskListModel(projectId: projectId, name: "List", color: "#4F46E5")
        try await list.save(on: app.db)
        let listId = try list.requireID()

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let created1 = try XCTUnwrap(iso.date(from: "2026-03-01T23:59:50Z"))
        let created2 = try XCTUnwrap(iso.date(from: "2026-03-02T00:00:10Z"))

        let task1 = TaskItemModel(orgId: orgId, listId: listId, title: "T1", status: .todo, statusId: backlogId, storyPoints: 3)
        let task2 = TaskItemModel(orgId: orgId, listId: listId, title: "T2", status: .todo, statusId: backlogId, storyPoints: 5)
        try await task1.save(on: app.db)
        try await task2.save(on: app.db)

        task1.createdAt = created1
        task2.createdAt = created2
        try await task1.save(on: app.db)
        try await task2.save(on: app.db)

        let token = try signToken(app: app, userId: userId, role: .admin)
        let start = "2026-03-01T12:00:00Z"
        let end = "2026-03-02T12:00:00Z"

        try await app.test(.GET, "api/projects/\(projectId.uuidString)/analytics/burndown?start_date=\(start)&end_date=\(end)") { req async in
            req.headers.bearerAuthorization = .init(token: token)
            req.headers.add(name: "X-Org-Id", value: orgId.uuidString)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            do {
                let decoded = try res.content.decode(APIResponse<[ProjectDailyStatsDTO]>.self)
                let stats = decoded.data ?? []

                // Expect entries for Mar 1 and Mar 2 (UTC).
                XCTAssertEqual(stats.count, 2)
                XCTAssertEqual(stats[0].remainingPoints, 3, accuracy: 0.0001)
                XCTAssertEqual(stats[1].remainingPoints, 8, accuracy: 0.0001)
            } catch {
                XCTFail("Failed to decode burndown response: \(error)")
            }
        }
    }

    func testAnalyticsExportRBACIsEnforced() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let user = UserModel(email: "viewer+\(UUID().uuidString)@example.com", displayName: "Viewer", passwordHash: "x", role: .viewer)
        try await user.save(on: app.db)
        let userId = try user.requireID()

        let org = OrganizationModel(name: "Org-\(UUID().uuidString)", slug: "org-\(UUID().uuidString)", ownerId: userId)
        try await org.save(on: app.db)
        let orgId = try org.requireID()
        try await OrganizationMemberModel(orgId: orgId, userId: userId, role: .viewer).save(on: app.db)

        let space = SpaceModel(orgId: orgId, name: "Space", description: nil)
        try await space.save(on: app.db)
        let spaceId = try space.requireID()

        let project = ProjectModel(spaceId: spaceId, name: "Project", description: nil, workflowVersion: 1)
        try await project.save(on: app.db)
        let projectId = try project.requireID()

        let token = try signToken(app: app, userId: userId, role: .viewer)
        try await app.test(.GET, "api/projects/\(projectId.uuidString)/analytics/export/burndown") { req async in
            req.headers.bearerAuthorization = .init(token: token)
            req.headers.add(name: "X-Org-Id", value: orgId.uuidString)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        }
    }

    func testAnalyticsViewRBACIsEnforced() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let user = UserModel(email: "guest+\(UUID().uuidString)@example.com", displayName: "Guest", passwordHash: "x", role: .guest)
        try await user.save(on: app.db)
        let userId = try user.requireID()

        let org = OrganizationModel(name: "Org-\(UUID().uuidString)", slug: "org-\(UUID().uuidString)", ownerId: userId)
        try await org.save(on: app.db)
        let orgId = try org.requireID()
        try await OrganizationMemberModel(orgId: orgId, userId: userId, role: .guest).save(on: app.db)

        let space = SpaceModel(orgId: orgId, name: "Space", description: nil)
        try await space.save(on: app.db)
        let spaceId = try space.requireID()

        let project = ProjectModel(spaceId: spaceId, name: "Project", description: nil, workflowVersion: 1)
        try await project.save(on: app.db)
        let projectId = try project.requireID()

        let token = try signToken(app: app, userId: userId, role: .guest)
        try await app.test(.GET, "api/projects/\(projectId.uuidString)/analytics/lead-time") { req async in
            req.headers.bearerAuthorization = .init(token: token)
            req.headers.add(name: "X-Org-Id", value: orgId.uuidString)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        }
    }

    func testCycleTimeUsesWorkflowCategoryNotStatusName() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let user = UserModel(email: "cycle+\(UUID().uuidString)@example.com", displayName: "Cycle", passwordHash: "x", role: .admin)
        try await user.save(on: app.db)
        let userId = try user.requireID()

        let org = OrganizationModel(name: "Org-\(UUID().uuidString)", slug: "org-\(UUID().uuidString)", ownerId: userId)
        try await org.save(on: app.db)
        let orgId = try org.requireID()
        try await OrganizationMemberModel(orgId: orgId, userId: userId, role: .admin).save(on: app.db)

        let space = SpaceModel(orgId: orgId, name: "Space", description: nil)
        try await space.save(on: app.db)
        let spaceId = try space.requireID()

        let project = ProjectModel(spaceId: spaceId, name: "Project", description: nil, workflowVersion: 1)
        try await project.save(on: app.db)
        let projectId = try project.requireID()

        let backlog = CustomStatusModel(
            projectId: projectId,
            name: "Backlog",
            color: "#94A3B8",
            position: 0,
            category: .backlog,
            isDefault: true,
            isFinal: false,
            isLocked: true,
            legacyStatus: TaskStatus.todo.rawValue
        )
        let active = CustomStatusModel(
            projectId: projectId,
            name: "In Progress",
            color: "#3B82F6",
            position: 100,
            category: .active,
            isDefault: false,
            isFinal: false,
            isLocked: false,
            legacyStatus: TaskStatus.inProgress.rawValue
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
        try await backlog.save(on: app.db)
        try await active.save(on: app.db)
        try await done.save(on: app.db)

        let list = TaskListModel(projectId: projectId, name: "List", color: "#4F46E5")
        try await list.save(on: app.db)
        let listId = try list.requireID()

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let createdAt = try XCTUnwrap(iso.date(from: "2026-03-01T10:00:00Z"))
        let startedAt = try XCTUnwrap(iso.date(from: "2026-03-01T12:00:00Z"))
        let completedAt = try XCTUnwrap(iso.date(from: "2026-03-02T10:00:00Z"))

        let task = TaskItemModel(orgId: orgId, listId: listId, title: "T", status: .done, statusId: try done.requireID(), storyPoints: 1)
        try await task.save(on: app.db)
        let taskId = try task.requireID()

        task.createdAt = createdAt
        task.completedAt = completedAt
        try await task.save(on: app.db)

        let activity = TaskActivityModel(
            taskId: taskId,
            userId: userId,
            type: .statusChanged,
            metadata: [
                "to_status_id": try active.requireID().uuidString
            ]
        )
        try await activity.save(on: app.db)
        activity.createdAt = startedAt
        try await activity.save(on: app.db)

        // Rename the active status — analytics should remain stable because it keys off category/id, not name.
        active.name = "Working"
        try await active.save(on: app.db)

        let token = try signToken(app: app, userId: userId, role: .admin)
        try await app.test(.GET, "api/projects/\(projectId.uuidString)/analytics/cycle-time?start_date=2026-03-01T00:00:00Z&end_date=2026-03-02T00:00:00Z") { req async in
            req.headers.bearerAuthorization = .init(token: token)
            req.headers.add(name: "X-Org-Id", value: orgId.uuidString)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            do {
                let decoded = try res.content.decode(APIResponse<AnalyticsResponseDTO<Double>>.self)
                let dto = try XCTUnwrap(decoded.data)
                XCTAssertEqual(dto.sampleSize, 1)
                XCTAssertEqual(dto.value, completedAt.timeIntervalSince(startedAt), accuracy: 0.01)
            } catch {
                XCTFail("Failed to decode cycle-time response: \(error)")
            }
        }
    }

    func testSprintRulesMovingIntoClosedSprintReturns400() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app, membershipRole: .admin)

        let sprint = SprintModel(
            projectId: seed.projectId,
            name: "Sprint 1",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            status: .closed,
            capacity: 10
        )
        try await sprint.save(on: app.db)
        let sprintId = try sprint.requireID()

        let task = TaskItemModel(
            orgId: seed.orgId,
            listId: seed.listId,
            title: "T",
            description: nil,
            status: .todo,
            statusId: seed.todoStatusId,
            priority: .medium,
            taskType: .task,
            storyPoints: 1
        )
        try await task.save(on: app.db)
        let taskId = try task.requireID()

        try await app.test(.PATCH, "api/tasks/\(taskId.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            try req.content.encode(UpdateTaskRequest(sprintId: sprintId, sprintPosition: 1000))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testEpicRollupsUpdateOnChildCreateStatusAndDelete() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app, membershipRole: .admin)

        let epic = TaskItemModel(
            orgId: seed.orgId,
            listId: seed.listId,
            title: "Epic",
            description: nil,
            status: .todo,
            statusId: seed.todoStatusId,
            priority: .medium,
            taskType: .epic
        )
        try await epic.save(on: app.db)
        let epicId = try epic.requireID()

        // Create child (storyPoints=5)
        var childId: UUID? = nil
        try await app.test(.POST, "api/tasks", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            try req.content.encode(
                CreateTaskRequest(
                    title: "Child",
                    statusId: seed.todoStatusId,
                    taskType: .story,
                    parentId: epicId,
                    storyPoints: 5,
                    listId: seed.listId
                )
            )
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try res.content.decode(APIResponse<TaskItemDTO>.self)
            let dto = try XCTUnwrap(decoded.data)
            childId = dto.id
        })

        let childTaskId = try XCTUnwrap(childId)
        let epicAfterCreate = try await TaskItemModel.find(epicId, on: app.db)
        XCTAssertEqual(epicAfterCreate?.epicChildrenCount, 1)
        XCTAssertEqual(epicAfterCreate?.epicChildrenDoneCount, 0)
        XCTAssertEqual(epicAfterCreate?.epicTotalPoints, 5)
        XCTAssertEqual(epicAfterCreate?.epicCompletedPoints, 0)

        // Mark child done
        try await app.test(.PATCH, "api/tasks/\(childTaskId.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            try req.content.encode(UpdateTaskRequest(statusId: seed.doneStatusId))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        let epicAfterDone = try await TaskItemModel.find(epicId, on: app.db)
        XCTAssertEqual(epicAfterDone?.epicChildrenCount, 1)
        XCTAssertEqual(epicAfterDone?.epicChildrenDoneCount, 1)
        XCTAssertEqual(epicAfterDone?.epicTotalPoints, 5)
        XCTAssertEqual(epicAfterDone?.epicCompletedPoints, 5)

        // Delete child
        try await app.test(.DELETE, "api/tasks/\(childTaskId.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .noContent)
        })

        let epicAfterDelete = try await TaskItemModel.find(epicId, on: app.db)
        XCTAssertEqual(epicAfterDelete?.epicChildrenCount ?? 0, 0)
        XCTAssertEqual(epicAfterDelete?.epicChildrenDoneCount ?? 0, 0)
        XCTAssertEqual(epicAfterDelete?.epicTotalPoints ?? 0, 0)
        XCTAssertEqual(epicAfterDelete?.epicCompletedPoints ?? 0, 0)
    }

    func testIssueKeyIsSequentialPerProject() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app, membershipRole: .admin)

        func createTask(title: String) async throws -> TaskItemDTO {
            var created: TaskItemDTO? = nil
            try await app.test(.POST, "api/tasks", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: seed.token)
                req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
                try req.content.encode(CreateTaskRequest(title: title, statusId: seed.todoStatusId, listId: seed.listId))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let decoded = try res.content.decode(APIResponse<TaskItemDTO>.self)
                created = decoded.data
            })
            return try XCTUnwrap(created)
        }

        let t1 = try await createTask(title: "A")
        let t2 = try await createTask(title: "B")

        XCTAssertEqual(t1.issueKey, "PROJE-1")
        XCTAssertEqual(t2.issueKey, "PROJE-2")
    }

    func testMessagingCreateDirectConversationIsIdempotent() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app)
        let otherUser = UserModel(email: "peer+\(UUID().uuidString)@example.com", displayName: "Peer", passwordHash: "x", role: .member)
        try await otherUser.save(on: app.db)
        let otherUserId = try otherUser.requireID()
        try await OrganizationMemberModel(orgId: seed.orgId, userId: otherUserId, role: .member).save(on: app.db)

        let request = CreateConversationRequest(type: "direct", memberIds: [otherUserId], name: nil)

        let firstConversationID = try await createConversation(app: app, seed: seed, request: request)
        let secondConversationID = try await createConversation(app: app, seed: seed, request: request)

        XCTAssertEqual(firstConversationID, secondConversationID)

        let memberships = try await ConversationMemberModel.query(on: app.db)
            .filter(\.$conversation.$id == firstConversationID)
            .count()
        XCTAssertEqual(memberships, 2)
    }

    func testMessagingSendAndFetchMessages() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app)
        let otherUser = UserModel(email: "peer+\(UUID().uuidString)@example.com", displayName: "Peer", passwordHash: "x", role: .member)
        try await otherUser.save(on: app.db)
        let otherUserId = try otherUser.requireID()
        try await OrganizationMemberModel(orgId: seed.orgId, userId: otherUserId, role: .member).save(on: app.db)

        let conversationID = try await createConversation(
            app: app,
            seed: seed,
            request: CreateConversationRequest(type: "direct", memberIds: [otherUserId], name: nil)
        )

        try await app.test(.POST, "api/conversations/\(conversationID.uuidString)/messages", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            try req.content.encode(SendMessageRequest(body: "hello"))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try res.content.decode(APIResponse<MessageDTO>.self)
            XCTAssertEqual(decoded.data?.body, "hello")
        })

        try await app.test(.GET, "api/conversations/\(conversationID.uuidString)/messages?limit=20", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try res.content.decode(APIResponse<[MessageDTO]>.self)
            XCTAssertEqual(decoded.data?.count, 1)
            XCTAssertEqual(decoded.data?.first?.body, "hello")
        })
    }

    private func createConversation(app: Application, seed: Seed, request: CreateConversationRequest) async throws -> UUID {
        var conversationID: UUID?

        try await app.test(.POST, "api/conversations", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            try req.content.encode(request)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try res.content.decode(APIResponse<ConversationDTO>.self)
            conversationID = decoded.data?.id
        })

        return try XCTUnwrap(conversationID)
    }
}
