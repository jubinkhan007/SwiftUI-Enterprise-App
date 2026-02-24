import Fluent
import SharedModels
import Vapor

/// Handles full CRUD operations for tasks. All routes require JWT authentication.
struct TaskController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let tasks = routes.grouped("tasks")
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

        var query = TaskItemModel.query(on: req.db)

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
        guard let task = try await TaskItemModel.find(req.parameters.get("taskID"), on: req.db) else {
            throw Abort(.notFound, reason: "Task not found.")
        }
        return .success(task.toDTO())
    }

    // MARK: - POST /api/tasks

    @Sendable
    func create(req: Request) async throws -> APIResponse<TaskItemDTO> {
        let authPayload = try req.authPayload
        guard let userId = authPayload.userId else {
            throw Abort(.unauthorized, reason: "Invalid user ID in token.")
        }
        let payload = try req.content.decode(CreateTaskRequest.self)

        guard !payload.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Task title is required.")
        }

        let task = TaskItemModel(
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
                userId: userId,
                type: .created
            )
            try await activity.save(on: db)
        }

        return .success(task.toDTO())
    }

    // MARK: - PUT /api/tasks/:taskID

    @Sendable
    func update(req: Request) async throws -> APIResponse<TaskItemDTO> {
        let authPayload = try req.authPayload
        guard let userId = authPayload.userId else {
            throw Abort(.unauthorized, reason: "Invalid user ID in token.")
        }
        guard let task = try await TaskItemModel.find(req.parameters.get("taskID"), on: req.db) else {
            throw Abort(.notFound, reason: "Task not found.")
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
            activities.append(TaskActivityModel(taskId: try task.requireID(), userId: userId, type: .statusChanged, metadata: metadata))
            task.status = status
        }
        if let priority = payload.priority, task.priority != priority {
            let metadata = ["from": task.priority.rawValue, "to": priority.rawValue]
            activities.append(TaskActivityModel(taskId: try task.requireID(), userId: userId, type: .priorityChanged, metadata: metadata))
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
            activities.append(TaskActivityModel(taskId: try task.requireID(), userId: userId, type: .assigned, metadata: metadata))
            task.$assignee.id = assigneeId
        }

        // Increment local version for the save
        task.version += 1

        try await req.db.transaction { db in
            try await task.save(on: db)
            for activity in activities {
                try await activity.save(on: db)
            }
        }

        return .success(task.toDTO())
    }

    // MARK: - DELETE /api/tasks/:taskID

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let task = try await TaskItemModel.find(req.parameters.get("taskID"), on: req.db) else {
            throw Abort(.notFound, reason: "Task not found.")
        }
        try await task.delete(on: req.db)
        return .noContent
    }

    // MARK: - GET /api/tasks/:taskID/activity

    @Sendable
    func getActivities(req: Request) async throws -> APIResponse<[TaskActivityDTO]> {
        guard let taskId = req.parameters.get("taskID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Task ID.")
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
        let authPayload = try req.authPayload
        guard let userId = authPayload.userId else {
            throw Abort(.unauthorized, reason: "Invalid user ID in token.")
        }
        guard let task = try await TaskItemModel.find(req.parameters.get("taskID"), on: req.db) else {
            throw Abort(.notFound, reason: "Task not found.")
        }
        
        let payload = try req.content.decode(CreateCommentRequest.self)
        guard !payload.content.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Comment content cannot be empty.")
        }
        
        let activity = TaskActivityModel(
            taskId: try task.requireID(),
            userId: userId,
            type: .comment,
            content: payload.content
        )
        
        try await activity.save(on: req.db)
        return .success(activity.toDTO())
    }
}
