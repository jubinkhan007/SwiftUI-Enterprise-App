import Fluent
import SharedModels
import Vapor

/// Create/list sprints for a project (used by Sprint Velocity charts).
struct SprintController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let projects = routes.grouped("projects").grouped(OrgTenantMiddleware())
        let sprints = projects.grouped(":projectID", "sprints")

        sprints.get(use: list)
        sprints.post(use: create)

        let sprint = routes.grouped("sprints").grouped(OrgTenantMiddleware()).grouped(":sprintID")
        sprint.patch(use: update)
    }

    // MARK: - GET /api/projects/:projectID/sprints

    @Sendable
    func list(req: Request) async throws -> APIResponse<[SprintDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.projectsRead)
        let projectId = try requireProjectId(req)
        _ = try await requireProjectInOrg(req: req, projectId: projectId, orgId: ctx.orgId)

        let rows = try await SprintModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .sort(\.$startDate, .ascending)
            .all()

        return .success(rows.map { $0.toDTO() })
    }

    // MARK: - POST /api/projects/:projectID/sprints

    @Sendable
    func create(req: Request) async throws -> APIResponse<SprintDTO> {
        let ctx = try req.orgContext
        try req.requirePermission(.sprintsManage)
        let projectId = try requireProjectId(req)
        _ = try await requireProjectInOrg(req: req, projectId: projectId, orgId: ctx.orgId)

        let payload = try req.content.decode(CreateSprintRequest.self)
        let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw Abort(.badRequest, reason: "Sprint name is required.")
        }
        guard payload.startDate <= payload.endDate else {
            throw Abort(.badRequest, reason: "startDate must be <= endDate.")
        }

        let sprint = SprintModel(
            projectId: projectId,
            name: name,
            startDate: payload.startDate,
            endDate: payload.endDate,
            status: payload.status ?? .planned,
            capacity: payload.capacity
        )
        try await sprint.save(on: req.db)
        return .success(sprint.toDTO())
    }

    // MARK: - PATCH /api/sprints/:sprintID

    struct UpdateSprintRequest: Content {
        let status: SprintStatus?
        let capacity: Double?
    }

    @Sendable
    func update(req: Request) async throws -> APIResponse<SprintDTO> {
        let ctx = try req.orgContext
        try req.requirePermission(.sprintsManage)
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

        let payload = try req.content.decode(UpdateSprintRequest.self)
        if let status = payload.status {
            sprint.status = status
        }
        if payload.capacity != nil {
            sprint.capacity = payload.capacity
        }

        try await sprint.save(on: req.db)
        return .success(sprint.toDTO())
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
}
