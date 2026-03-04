import Fluent
import SharedModels
import Vapor

/// Phase 13: Scrum backlog and sprint issue queries.
struct AgileController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let orgScoped = routes.grouped(OrgTenantMiddleware())

        let projects = orgScoped.grouped("projects")
        projects.get(":projectID", "backlog", use: backlog)

        let sprints = orgScoped.grouped("sprints")
        sprints.get(":sprintID", "issues", use: sprintIssues)
    }

    // MARK: - GET /api/projects/:projectID/backlog

    @Sendable
    func backlog(req: Request) async throws -> APIResponse<[TaskItemDTO]> {
        let ctx = try req.orgContext
        let projectId = try requireProjectId(req)
        _ = try await requireProjectInOrg(req: req, projectId: projectId, orgId: ctx.orgId)

        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$project.$id == projectId)
            .filter(\.$sprint.$id == nil)
            .filter(\.$archivedAt == nil)
            .filter(\.$completedAt == nil)
            .sort(\.$backlogPosition, .ascending)
            .sort(\.$position, .ascending)
            .all()

        let dtos = try await withSubtaskCounts(tasks: tasks, db: req.db)
        return .success(dtos)
    }

    // MARK: - GET /api/sprints/:sprintID/issues

    @Sendable
    func sprintIssues(req: Request) async throws -> APIResponse<[TaskItemDTO]> {
        let ctx = try req.orgContext
        guard let sprintId = req.parameters.get("sprintID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid sprint ID.")
        }

        let sprints = try await SprintModel.query(on: req.db)
            .filter(\.$id == sprintId)
            .with(\.$project) { project in project.with(\.$space) }
            .limit(1)
            .all()
        guard let sprint = sprints.first else {
            throw Abort(.notFound, reason: "Sprint not found.")
        }

        guard sprint.project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Sprint not found.")
        }

        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$project.$id == sprint.$project.id)
            .filter(\.$sprint.$id == sprintId)
            .filter(\.$archivedAt == nil)
            .sort(\.$sprintPosition, .ascending)
            .sort(\.$position, .ascending)
            .all()

        let dtos = try await withSubtaskCounts(tasks: tasks, db: req.db)
        return .success(dtos)
    }

    // MARK: - Helpers

    private func requireProjectId(_ req: Request) throws -> UUID {
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        return projectId
    }

    private func requireProjectInOrg(req: Request, projectId: UUID, orgId: UUID) async throws -> ProjectModel {
        let project = try await ProjectModel.query(on: req.db)
            .filter(\.$id == projectId)
            .with(\.$space)
            .first()
        guard let project, project.space.$organization.id == orgId else {
            throw Abort(.notFound, reason: "Project not found.")
        }
        return project
    }

    /// Fetches subtask counts for a batch of tasks using a GROUP BY aggregate (no N+1).
    private func withSubtaskCounts(tasks: [TaskItemModel], db: any Database) async throws -> [TaskItemDTO] {
        guard !tasks.isEmpty else { return [] }

        let taskIds = tasks.compactMap { $0.id }
        let allSubtasks = try await TaskItemModel.query(on: db)
            .filter(\.$parent.$id ~~ taskIds)
            .all()

        var totalCounts: [UUID: Int] = [:]
        var doneCounts: [UUID: Int] = [:]

        for sub in allSubtasks {
            guard let pid = sub.$parent.id else { continue }
            totalCounts[pid, default: 0] += 1
            if sub.status == .done {
                doneCounts[pid, default: 0] += 1
            }
        }

        return tasks.map { task in
            let tid = task.id ?? UUID()
            return task.toDTO(
                subtaskCount: totalCounts[tid] ?? 0,
                completedSubtaskCount: doneCounts[tid] ?? 0
            )
        }
    }
}
