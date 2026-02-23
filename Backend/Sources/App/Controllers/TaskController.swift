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
        let payload = try req.content.decode(CreateTaskRequest.self)

        guard !payload.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Task title is required.")
        }

        let task = TaskItemModel(
            title: payload.title,
            description: payload.description,
            status: payload.status ?? .todo,
            priority: payload.priority ?? .medium,
            dueDate: payload.dueDate,
            assigneeId: payload.assigneeId
        )
        try await task.save(on: req.db)

        return .success(task.toDTO())
    }

    // MARK: - PUT /api/tasks/:taskID

    @Sendable
    func update(req: Request) async throws -> APIResponse<TaskItemDTO> {
        guard let task = try await TaskItemModel.find(req.parameters.get("taskID"), on: req.db) else {
            throw Abort(.notFound, reason: "Task not found.")
        }

        let payload = try req.content.decode(UpdateTaskRequest.self)

        if let title = payload.title {
            task.title = title
        }
        if let description = payload.description {
            task.description = description
        }
        if let status = payload.status {
            task.status = status
        }
        if let priority = payload.priority {
            task.priority = priority
        }
        if let dueDate = payload.dueDate {
            task.dueDate = dueDate
        }
        if let assigneeId = payload.assigneeId {
            task.$assignee.id = assigneeId
        }

        try await task.save(on: req.db)

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
}
