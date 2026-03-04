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
    }

    // MARK: - GET /api/projects/:projectID/sprints

    @Sendable
    func list(req: Request) async throws -> APIResponse<[SprintDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.analyticsView)
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
        try req.requirePermission(.projectsEdit)
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
            status: payload.status ?? .planned
        )
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

