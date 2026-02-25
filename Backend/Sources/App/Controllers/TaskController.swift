import Fluent
import SharedModels
import Vapor

/// Handles full CRUD operations for tasks. All routes require JWT authentication.
struct TaskController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // Wrap all task routes in OrgTenantMiddleware to enforce X-Org-Id
        let tasks = routes.grouped("tasks").grouped(OrgTenantMiddleware())
        
        tasks.get(use: index)
        tasks.post(use: create)
        tasks.group(":taskID") { task in
            task.get(use: show)
            task.put(use: update)
            task.delete(use: delete)
            task.get("activity", use: getActivities)
            task.post("comments", use: createComment)
        }
    }

    // MARK: - GET /api/tasks

    @Sendable
    func index(req: Request) async throws -> APIResponse<[TaskItemDTO]> {
        let page = (try? req.query.get(Int.self, at: "page")) ?? 1
        let perPage = min((try? req.query.get(Int.self, at: "per_page")) ?? 20, 100)
        let statusFilter: TaskStatus? = try? req.query.get(TaskStatus.self, at: "status")
        let priorityFilter: TaskPriority? = try? req.query.get(TaskPriority.self, at: "priority")

        let ctx = try req.orgContext
        var query = TaskItemModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)

        // Apply filters
        if let status = statusFilter {
            query = query.filter(\.$status == status)
        }
        if let priority = priorityFilter {
            query = query.filter(\.$priority == priority)
        }

        // Get total count for pagination
        let total = try await query.count()

        // Fetch page
        let tasks = try await query
            .sort(\.$createdAt, .descending)
            .range(((page - 1) * perPage)..<(page * perPage))
            .all()

        let dtos = tasks.map { $0.toDTO() }
        let pagination = PaginationMeta(page: page, perPage: perPage, total: total)

        return .success(dtos, pagination: pagination)
    }

    // MARK: - GET /api/tasks/:taskID

    @Sendable
    func show(req: Request) async throws -> APIResponse<TaskItemDTO> {
        let ctx = try req.orgContext
        guard let task = try await TaskItemModel.query(on: req.db)
            .filter(\.$id == req.parameters.get("taskID", as: UUID.self) ?? UUID())
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }
        return .success(task.toDTO())
    }

    // MARK: - POST /api/tasks

    @Sendable
    func create(req: Request) async throws -> APIResponse<TaskItemDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(CreateTaskRequest.self)

        guard !payload.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Task title is required.")
        }

        let task = TaskItemModel(
            orgId: ctx.orgId,
            title: payload.title,
            description: payload.description,
            status: payload.status ?? .todo,
            priority: payload.priority ?? .medium,
            startDate: payload.startDate,
            dueDate: payload.dueDate,
            assigneeId: payload.assigneeId
        )

        try await req.db.transaction { db in
            try await task.save(on: db)
            let activity = TaskActivityModel(
                taskId: try task.requireID(),
                userId: ctx.userId,
                type: .created
            )
            try await activity.save(on: db)
            
            // Audit Log
            try await AuditLogModel.log(
                on: db, orgId: ctx.orgId, userId: ctx.userId,
                userEmail: "", action: "task.created",
                resourceType: "task", resourceId: task.id,
                details: "Created task: \(task.title)"
            )
        }

        return .success(task.toDTO())
    }

    // MARK: - PUT /api/tasks/:taskID

    @Sendable
    func update(req: Request) async throws -> APIResponse<TaskItemDTO> {
        let ctx = try req.orgContext
        guard let task = try await TaskItemModel.query(on: req.db)
            .filter(\.$id == req.parameters.get("taskID", as: UUID.self) ?? UUID())
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let payload = try req.content.decode(UpdateTaskRequest.self)

        // Optimistic Concurrency Control
        guard task.version == payload.expectedVersion else {
            throw Abort(.conflict, reason: "Task was modified by another user. Please refresh and try again.")
        }

        var activities: [TaskActivityModel] = []

        if let title = payload.title, task.title != title {
            task.title = title
        }
        if let description = payload.description, task.description != description {
            task.description = description
        }
        if let status = payload.status, task.status != status {
            let metadata = ["from": task.status.rawValue, "to": status.rawValue]
            activities.append(TaskActivityModel(taskId: try task.requireID(), userId: ctx.userId, type: .statusChanged, metadata: metadata))
            task.status = status
        }
        if let priority = payload.priority, task.priority != priority {
            let metadata = ["from": task.priority.rawValue, "to": priority.rawValue]
            activities.append(TaskActivityModel(taskId: try task.requireID(), userId: ctx.userId, type: .priorityChanged, metadata: metadata))
            task.priority = priority
        }
        if let startDate = payload.startDate {
            task.startDate = startDate
        }
        if let dueDate = payload.dueDate {
            task.dueDate = dueDate
        }
        if let assigneeId = payload.assigneeId, task.$assignee.id != assigneeId {
            let metadata = ["assignee_id": assigneeId.uuidString]
            activities.append(TaskActivityModel(taskId: try task.requireID(), userId: ctx.userId, type: .assigned, metadata: metadata))
            task.$assignee.id = assigneeId
        }

        // Increment local version for the save
        task.version += 1

        let finalActivities = activities // Capture immutably for closure
        try await req.db.transaction { db in
            try await task.save(on: db)
            for activity in finalActivities {
                try await activity.save(on: db)
            }
        }

        return .success(task.toDTO())
    }

    // MARK: - DELETE /api/tasks/:taskID

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let ctx = try req.orgContext
        guard let task = try await TaskItemModel.query(on: req.db)
            .filter(\.$id == req.parameters.get("taskID", as: UUID.self) ?? UUID())
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }
        try await req.db.transaction { db in
            // Audit Log
            try await AuditLogModel.log(
                on: db, orgId: ctx.orgId, userId: ctx.userId,
                userEmail: "", action: "task.deleted",
                resourceType: "task", resourceId: task.id,
                details: "Deleted task: \(task.title)"
            )
            try await task.delete(on: db)
        }
        return .noContent
    }

    // MARK: - GET /api/tasks/:taskID/activity

    @Sendable
    func getActivities(req: Request) async throws -> APIResponse<[TaskActivityDTO]> {
        let ctx = try req.orgContext
        guard let taskId = req.parameters.get("taskID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Task ID.")
        }
        
        let taskExists = try await TaskItemModel.query(on: req.db)
            .filter(\.$id == taskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0
            
        guard taskExists else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }
        
        let activities = try await TaskActivityModel.query(on: req.db)
            .filter(\.$task.$id == taskId)
            .sort(\.$createdAt, .descending)
            .all()
            
        let dtos = activities.map { $0.toDTO() }
        let pagination = PaginationMeta(page: 1, perPage: dtos.count, total: dtos.count)
        return .success(dtos, pagination: pagination)
    }

    // MARK: - POST /api/tasks/:taskID/comments

    @Sendable
    func createComment(req: Request) async throws -> APIResponse<TaskActivityDTO> {
        let ctx = try req.orgContext
        guard let task = try await TaskItemModel.query(on: req.db)
            .filter(\.$id == req.parameters.get("taskID", as: UUID.self) ?? UUID())
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }
        
        let payload = try req.content.decode(CreateCommentRequest.self)
        guard !payload.content.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Comment content cannot be empty.")
        }
        
        let activity = TaskActivityModel(
            taskId: try task.requireID(),
            userId: ctx.userId,
            type: .comment,
            content: payload.content
        )
        
        try await activity.save(on: req.db)
        return .success(activity.toDTO())
    }
}
