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

    struct PatchSprintPayload: Content {
        let name: String?
        let startDate: Date?
        let endDate: Date?
        let status: SprintStatus?
        let capacity: Double?
        let rolloverUncompletedTo: String?
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

        let payload = try req.content.decode(PatchSprintPayload.self)
        let oldStatus = sprint.status
        if let rawName = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty {
            sprint.name = rawName
        }
        if let startDate = payload.startDate {
            sprint.startDate = startDate
        }
        if let endDate = payload.endDate {
            sprint.endDate = endDate
        }
        guard sprint.startDate <= sprint.endDate else {
            throw Abort(.badRequest, reason: "startDate must be <= endDate.")
        }
        if let status = payload.status {
            sprint.status = status
        }
        if payload.capacity != nil {
            sprint.capacity = payload.capacity
        }

        try await sprint.save(on: req.db)

        let didTransitionToClosed = !oldStatus.isClosedLike && sprint.status.isClosedLike
        if didTransitionToClosed {
            let sprintID = try sprint.requireID()
            if let rollover = payload.rolloverUncompletedTo?.lowercased(), !rollover.isEmpty {
                await rolloverIncompleteTasks(
                    fromSprintId: sprintID,
                    projectId: sprint.$project.id,
                    destination: rollover,
                    actorId: ctx.userId,
                    db: req.db,
                    logger: req.logger
                )
            }
            await AutomationService.triggerSprintCompleted(
                sprintId: sprintID,
                projectId: sprint.$project.id,
                db: req.db,
                logger: req.logger
            )
        }

        return .success(sprint.toDTO())
    }

    private func rolloverIncompleteTasks(
        fromSprintId: UUID,
        projectId: UUID,
        destination: String,
        actorId: UUID,
        db: Database,
        logger: Logger
    ) async {
        do {
            let allSprintTasks = try await TaskItemModel.query(on: db)
                .filter(\.$sprint.$id == fromSprintId)
                .with(\.$customStatus)
                .all()

            let incompleteTasks = allSprintTasks.filter { task in
                if let cs = task.customStatus {
                    return !cs.isFinal
                }
                return task.status != .done && task.status != .cancelled
            }
            guard !incompleteTasks.isEmpty else { return }

            if destination == "backlog" {
                for (index, task) in incompleteTasks.enumerated() {
                    task.$sprint.id = nil
                    task.sprintPosition = nil
                    task.backlogPosition = Double((index + 1) * 1000)
                    task.version += 1
                    try await task.save(on: db)
                    let activity = TaskActivityModel(
                        taskId: try task.requireID(),
                        userId: actorId,
                        type: .moved,
                        content: "Returned to product backlog on sprint completion",
                        metadata: ["from_sprint": fromSprintId.uuidString, "rollover": "backlog"]
                    )
                    try await activity.save(on: db)
                }
            } else if destination == "next_sprint" {
                let nextSprint = try await SprintModel.query(on: db)
                    .filter(\.$project.$id == projectId)
                    .filter(\.$status ~~ [.active, .planned])
                    .filter(\.$id != fromSprintId)
                    .sort(\.$startDate, .ascending)
                    .first()

                let targetSprintId = nextSprint?.id
                for (index, task) in incompleteTasks.enumerated() {
                    task.$sprint.id = targetSprintId
                    if targetSprintId != nil {
                        task.sprintPosition = Double((index + 1) * 1000)
                    } else {
                        task.sprintPosition = nil
                        task.backlogPosition = Double((index + 1) * 1000)
                    }
                    task.version += 1
                    try await task.save(on: db)
                    let activity = TaskActivityModel(
                        taskId: try task.requireID(),
                        userId: actorId,
                        type: .moved,
                        content: nextSprint != nil
                            ? "Rolled over to \(nextSprint!.name) on sprint completion"
                            : "Returned to product backlog on sprint completion (no next sprint)",
                        metadata: [
                            "from_sprint": fromSprintId.uuidString,
                            "to_sprint": targetSprintId?.uuidString ?? "backlog"
                        ]
                    )
                    try await activity.save(on: db)
                }
            }
        } catch {
            logger.warning("SprintController: failed to rollover incomplete tasks for sprint \(fromSprintId): \(error)")
        }
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
