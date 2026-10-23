@testable import App
import Fluent
import XCTVapor
import SharedModels

final class TaskOCCConflictTests: XCTestCase {
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
        let statusId: UUID
        let token: String
    }

    private func seedBasicProject(app: Application, userRole: UserRole = .admin, membershipRole: UserRole = .admin) async throws -> Seed {
        let user = UserModel(email: "occ+\(UUID().uuidString)@example.com", displayName: "OCC User", passwordHash: "x", role: userRole)
        try await user.save(on: app.db)
        let userId = try user.requireID()

        let org = OrganizationModel(name: "OCC-Org-\(UUID().uuidString)", slug: "occ-org-\(UUID().uuidString)", ownerId: userId)
        try await org.save(on: app.db)
        let orgId = try org.requireID()
        try await OrganizationMemberModel(orgId: orgId, userId: userId, role: membershipRole).save(on: app.db)

        let space = SpaceModel(orgId: orgId, name: "OCC Space", description: nil)
        try await space.save(on: app.db)
        let spaceId = try space.requireID()

        let project = ProjectModel(spaceId: spaceId, name: "OCC Project", description: nil, workflowVersion: 1)
        try await project.save(on: app.db)
        let projectId = try project.requireID()

        let status = CustomStatusModel(
            projectId: projectId,
            name: "In Progress",
            color: "#3B82F6",
            position: 100,
            category: .active,
            isDefault: true,
            isFinal: false,
            isLocked: true,
            legacyStatus: TaskStatus.inProgress.rawValue
        )
        try await status.save(on: app.db)

        let list = TaskListModel(projectId: projectId, name: "Default List", color: "#4F46E5")
        try await list.save(on: app.db)
        let listId = try list.requireID()

        let token = try signToken(app: app, userId: userId, role: membershipRole)
        return Seed(
            userId: userId,
            orgId: orgId,
            projectId: projectId,
            listId: listId,
            statusId: try status.requireID(),
            token: token
        )
    }

    private func createTask(app: Application, seed: Seed, title: String) async throws -> TaskItemDTO {
        var createdDTO: TaskItemDTO?
        try await app.test(.POST, "api/tasks", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            try req.content.encode(
                CreateTaskRequest(
                    title: title,
                    statusId: seed.statusId,
                    taskType: .task,
                    listId: seed.listId
                )
            )
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try res.content.decode(APIResponse<TaskItemDTO>.self)
            createdDTO = decoded.data
        })
        return try XCTUnwrap(createdDTO)
    }

    func testTaskUpdateRequiresVersionPrecondition() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app)
        let task = try await createTask(app: app, seed: seed, title: "Precondition Test")

        // Attempt PUT without expectedVersion or If-Match header
        try await app.test(.PUT, "api/tasks/\(task.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            try req.content.encode(UpdateTaskRequest(title: "New Title Without Version"))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testTaskUpdateSucceedsWithMatchingExpectedVersion() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app)
        let task = try await createTask(app: app, seed: seed, title: "Version Match Test")
        XCTAssertEqual(task.version, 1)

        // Attempt PUT with matching expectedVersion: 1
        try await app.test(.PUT, "api/tasks/\(task.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            var updateReq = UpdateTaskRequest(title: "Updated Title")
            updateReq.expectedVersion = 1
            try req.content.encode(updateReq)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .eTag), "\"v2\"")
            let decoded = try res.content.decode(APIResponse<TaskItemDTO>.self)
            let updated = try XCTUnwrap(decoded.data)
            XCTAssertEqual(updated.title, "Updated Title")
            XCTAssertEqual(updated.version, 2)
        })
    }

    func testTaskUpdateSucceedsWithMatchingIfMatchHeader() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app)
        let task = try await createTask(app: app, seed: seed, title: "If-Match Test")
        XCTAssertEqual(task.version, 1)

        // Attempt PUT with If-Match: "v1"
        try await app.test(.PUT, "api/tasks/\(task.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            req.headers.add(name: .ifMatch, value: "\"v1\"")
            try req.content.encode(UpdateTaskRequest(title: "Updated Via Header"))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .eTag), "\"v2\"")
            let decoded = try res.content.decode(APIResponse<TaskItemDTO>.self)
            let updated = try XCTUnwrap(decoded.data)
            XCTAssertEqual(updated.title, "Updated Via Header")
            XCTAssertEqual(updated.version, 2)
        })
    }

    func testTaskUpdateReturnsConflictWhenExpectedVersionIsStale() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app)
        let task = try await createTask(app: app, seed: seed, title: "Conflict Test")
        XCTAssertEqual(task.version, 1)

        // First update increments version to 2
        try await app.test(.PUT, "api/tasks/\(task.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            var updateReq = UpdateTaskRequest(title: "First Update")
            updateReq.expectedVersion = 1
            try req.content.encode(updateReq)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        // Second update with stale expectedVersion: 1 -> 409 Conflict
        try await app.test(.PUT, "api/tasks/\(task.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            var updateReq = UpdateTaskRequest(title: "Stale Update")
            updateReq.expectedVersion = 1
            try req.content.encode(updateReq)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .conflict)
            XCTAssertEqual(res.headers.first(name: .eTag), "\"v2\"")
            let decoded = try res.content.decode(APIResponse<TaskItemDTO>.self)
            let conflictPayload = try XCTUnwrap(decoded.data)
            XCTAssertEqual(conflictPayload.version, 2)
            XCTAssertEqual(conflictPayload.title, "First Update")
        })
    }

    func testConcurrentUpdateSimulationOCCConflictAndRecovery() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedBasicProject(app: app)
        let task = try await createTask(app: app, seed: seed, title: "Concurrent Race Test")
        XCTAssertEqual(task.version, 1)

        // Both Client A and Client B read task at version 1
        let clientABaseVersion = 1
        let clientBBaseVersion = 1

        // Client A pushes update first (expectedVersion = 1) -> Succeeds!
        try await app.test(.PUT, "api/tasks/\(task.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            var updateReq = UpdateTaskRequest(title: "Client A Title")
            updateReq.expectedVersion = clientABaseVersion
            try req.content.encode(updateReq)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try res.content.decode(APIResponse<TaskItemDTO>.self)
            XCTAssertEqual(decoded.data?.version, 2)
        })

        // Client B tries to push update with baseVersion = 1 -> 409 Conflict!
        var serverSnapshotFromConflict: TaskItemDTO?
        try await app.test(.PUT, "api/tasks/\(task.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            var updateReq = UpdateTaskRequest(title: "Client B Overwrite Attempt")
            updateReq.expectedVersion = clientBBaseVersion
            try req.content.encode(updateReq)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .conflict)
            let decoded = try res.content.decode(APIResponse<TaskItemDTO>.self)
            serverSnapshotFromConflict = decoded.data
        })

        let conflictServerTask = try XCTUnwrap(serverSnapshotFromConflict)
        XCTAssertEqual(conflictServerTask.version, 2)
        XCTAssertEqual(conflictServerTask.title, "Client A Title")

        // Client B resolves with "Keep Mine" (retrying with expectedVersion = 2)
        try await app.test(.PUT, "api/tasks/\(task.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: seed.token)
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
            var updateReq = UpdateTaskRequest(title: "Client B Wins Resolution")
            updateReq.expectedVersion = conflictServerTask.version
            try req.content.encode(updateReq)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try res.content.decode(APIResponse<TaskItemDTO>.self)
            let finalTask = try XCTUnwrap(decoded.data)
            XCTAssertEqual(finalTask.title, "Client B Wins Resolution")
            XCTAssertEqual(finalTask.version, 3)
        })
    }
}
