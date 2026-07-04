import Fluent
import SharedModels
import Vapor

struct TimeLogController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let tenant = routes.grouped(OrgTenantMiddleware())
        
        tenant.post("tasks", ":taskID", "time-logs", use: logTime)
        tenant.get("tasks", ":taskID", "time-logs", use: listLogs)
        tenant.get("projects", ":projectID", "time-logs", "report", use: projectReport)
    }

    // MARK: - POST /api/tasks/:taskID/time-logs
    @Sendable
    func logTime(req: Request) async throws -> APIResponse<TimeLogDTO> {
        let ctx = try req.orgContext
        guard let task = try await TaskItemModel.query(on: req.db)
            .filter(\.$id == req.parameters.get("taskID", as: UUID.self) ?? UUID())
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let payload = try req.content.decode(LogTimeRequest.self)
        guard payload.hoursLogged > 0 else {
            throw Abort(.badRequest, reason: "Hours logged must be greater than zero.")
        }

        let taskId = try task.requireID()
        let logId = UUID()

        let timeLog = TimeLogModel(
            id: logId,
            taskId: taskId,
            userId: ctx.userId,
            orgId: ctx.orgId,
            hoursLogged: payload.hoursLogged,
            loggedAt: payload.loggedAt,
            description: payload.description
        )

        // Load current user for display name
        guard let currentUser = try await UserModel.find(ctx.userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        try await req.db.transaction { db in
            try await timeLog.save(on: db)
            
            let activity = TaskActivityModel(
                taskId: taskId,
                userId: ctx.userId,
                type: .timeLogged,
                content: payload.description ?? "Logged \(payload.hoursLogged) hours",
                metadata: ["hours": String(payload.hoursLogged), "log_id": logId.uuidString]
            )
            try await activity.save(on: db)
        }

        let dto = TimeLogDTO(
            id: logId,
            taskId: taskId,
            userId: ctx.userId,
            userDisplayName: currentUser.displayName ?? "Unknown User",
            hoursLogged: payload.hoursLogged,
            loggedAt: payload.loggedAt,
            description: payload.description,
            createdAt: Date()
        )

        return .success(dto)
    }

    // MARK: - GET /api/tasks/:taskID/time-logs
    @Sendable
    func listLogs(req: Request) async throws -> APIResponse<[TimeLogDTO]> {
        let ctx = try req.orgContext
        guard let task = try await TaskItemModel.query(on: req.db)
            .filter(\.$id == req.parameters.get("taskID", as: UUID.self) ?? UUID())
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let taskId = try task.requireID()
        let logs = try await TimeLogModel.query(on: req.db)
            .filter(\.$task.$id == taskId)
            .with(\.$user)
            .sort(\.$loggedAt, .descending)
            .all()

        let dtos = logs.map { log in
            TimeLogDTO(
                id: log.id ?? UUID(),
                taskId: taskId,
                userId: log.$user.id,
                userDisplayName: log.user.displayName ?? "Unknown User",
                hoursLogged: log.hoursLogged,
                loggedAt: log.loggedAt,
                description: log.description,
                createdAt: log.createdAt
            )
        }

        return .success(dtos)
    }

    // MARK: - GET /api/projects/:projectID/time-logs/report
    @Sendable
    func projectReport(req: Request) async throws -> APIResponse<ProjectTimeReportDTO> {
        let ctx = try req.orgContext
        guard let projectID = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID.")
        }

        // Verify project exists in org
        guard let project = try await ProjectModel.query(on: req.db)
            .filter(\.$id == projectID)
            .with(\.$space)
            .first() else {
            throw Abort(.notFound, reason: "Project not found.")
        }
        guard project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Project not found in this organization.")
        }

        // Fetch all task lists and their tasks in this project
        let lists = try await TaskListModel.query(on: req.db)
            .filter(\.$project.$id == projectID)
            .all()
        let listIds = lists.compactMap(\.id)

        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$list.$id ~~ listIds)
            .all()
        let taskIds = tasks.compactMap(\.id)

        // Fetch all logs for these tasks
        let logs = try await TimeLogModel.query(on: req.db)
            .filter(\.$task.$id ~~ taskIds)
            .with(\.$user)
            .all()

        let totalHours = logs.reduce(0.0) { $0 + $1.hoursLogged }

        // Group by user
        let userLogs = Dictionary(grouping: logs, by: { $0.$user.id })
        let userReports = userLogs.map { (userId, userLogs) -> ProjectTimeReportDTO.UserReport in
            let total = userLogs.reduce(0.0) { $0 + $1.hoursLogged }
            let name = userLogs.first?.user.displayName ?? "Unknown User"
            return ProjectTimeReportDTO.UserReport(userId: userId, userDisplayName: name, totalHours: total)
        }.sorted { $0.totalHours > $1.totalHours }

        // Group by task
        let taskLogs = Dictionary(grouping: logs, by: { $0.$task.id })
        let taskReports = taskLogs.map { (taskId, taskLogs) -> ProjectTimeReportDTO.TaskReport in
            let total = taskLogs.reduce(0.0) { $0 + $1.hoursLogged }
            let title = tasks.first(where: { $0.id == taskId })?.title ?? "Unknown Task"
            return ProjectTimeReportDTO.TaskReport(taskId: taskId, taskTitle: title, totalHours: total)
        }.sorted { $0.totalHours > $1.totalHours }

        let dto = ProjectTimeReportDTO(
            projectId: projectID,
            totalHours: totalHours,
            byUser: userReports,
            byTask: taskReports
        )

        return .success(dto)
    }
}
