import Fluent
import SharedModels
import Vapor

/// Handles full CRUD operations for tasks. All routes require JWT authentication.
struct TaskController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // Wrap all task routes in OrgTenantMiddleware to enforce X-Org-Id
        let tasks = routes.grouped("tasks").grouped(OrgTenantMiddleware())

        let lists = routes.grouped("lists").grouped(OrgTenantMiddleware())
        lists.get(":listID", "tasks", use: tasksByList)

        tasks.get(use: index)
        tasks.post(use: create)
        tasks.get("assigned", use: assignedTasks)
        tasks.get("calendar", use: calendarTasks)
        tasks.get("timeline", use: timelineTasks)

        let task = tasks.grouped(":taskID")
        task.get(use: show)
        task.put(use: update)
        task.patch(use: partialUpdate)
        task.patch("move", use: move)
        task.delete(use: delete)

        tasks.post("move-multiple", use: moveMultiple)
        task.get("activity", use: getActivities)
        task.post("comments", use: createComment)

        // Phase 8A: subtasks
        task.get("subtasks", use: listSubtasks)

        // Phase 8B: relations
        let relations = task.grouped("relations")
        relations.get(use: listRelations)
        relations.post(use: createRelation)
        relations.delete(":relationID", use: deleteRelation)

        // Phase 8C: checklist
        let checklist = task.grouped("checklist")
        checklist.get(use: listChecklist)
        checklist.post(use: createChecklistItem)
        checklist.patch("reorder", use: reorderChecklist)
        let checklistItem = checklist.grouped(":itemID")
        checklistItem.patch(use: updateChecklistItem)
        checklistItem.delete(use: deleteChecklistItem)
    }

    // MARK: - GET /api/tasks

    @Sendable
    func index(req: Request) async throws -> APIResponse<[TaskItemDTO]> {
        let page = (try? req.query.get(Int.self, at: "page")) ?? 1
        let perPage = min((try? req.query.get(Int.self, at: "per_page")) ?? 20, 100)
        let ctx = try req.orgContext
        
        let parsedQuery = TaskQueryParser.parse(from: req)

        var query = TaskItemModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)

        let cursor = try? req.query.get(String.self, at: "cursor")

        query = TaskQueryApplier.applyFilters(parsedQuery, to: query)

        // If cursor is provided, we override normal sorting to ensure cursor keyset stability
        if let cursor = cursor {
            let parts = cursor.split(separator: ",")
            if parts.count == 2,
               let timestamp = Double(parts[0]),
               let cursorId = UUID(uuidString: String(parts[1])) {
                let cursorDate = Date(timeIntervalSince1970: timestamp)

                // Keysets: WHERE (updated_at < cursorDate) OR (updated_at == cursorDate AND id < cursorId)
                query = query.group(.or) { or in
                    or.filter(\.$updatedAt < cursorDate)
                    or.group(.and) { and in
                        and.filter(\.$updatedAt == cursorDate)
                        and.filter(\.$id < cursorId)
                    }
                }
            }
            // Force sort by updated_at DESC, id DESC for cursor stability over the whole query
            // We ignore TaskQueryApplier.applySorts entirely when a cursor is used to prevent sort thrashing.
            query = query.sort(\.$updatedAt, .descending).sort(\.$id, .descending)
        } else {
            // Normal offset pagination fallback with default sorts or specified view sorts
            query = TaskQueryApplier.applySorts(parsedQuery, to: query)
        }

        let total = try await query.count()

        let taskModels: [TaskItemModel]
        if cursor != nil {
            // Cursor pagination just uses limit, ignoring offset page calculations
            taskModels = try await query.limit(perPage).all()
        } else {
            // Standard offset pagination
            taskModels = try await query
                .range(((page - 1) * perPage)..<(page * perPage))
                .all()
        }

        let dtos = try await withSubtaskCounts(tasks: taskModels, db: req.db)

        // Generate next cursor based on the last item for continuous pagination
        var nextCursor: String? = nil
        if let last = taskModels.last, let updatedAt = last.updatedAt, let id = last.id, taskModels.count == perPage {
            nextCursor = "\(updatedAt.timeIntervalSince1970),\(id.uuidString)"
        }

        let pagination = PaginationMeta(page: page, perPage: perPage, total: total, cursor: nextCursor)
        return .success(dtos, pagination: pagination)
    }

    // MARK: - GET /api/tasks/assigned

    @Sendable
    func assignedTasks(req: Request) async throws -> APIResponse<[TaskItemDTO]> {
        let ctx = try req.orgContext
        var parsedQuery = try await mergeViewConfig(into: TaskQueryParser.parse(from: req), req: req, ctx: ctx)

        let page = (try? req.query.get(Int.self, at: "page")) ?? 1
        let perPage = min((try? req.query.get(Int.self, at: "per_page")) ?? 50, 100)

        var query = TaskItemModel.query(on: req.db)
            .filter(\TaskItemModel.$organization.$id == ctx.orgId)
            .filter(\TaskItemModel.$assignee.$id == ctx.userId)

        query = TaskQueryApplier.applyFilters(parsedQuery, to: query)
        query = TaskQueryApplier.applySorts(parsedQuery, to: query)

        let total = try await query.count()
        let taskModels = try await query.paginate(PageRequest(page: page, per: perPage)).items

        let dtos = try await withSubtaskCounts(tasks: taskModels, db: req.db)
        return APIResponse(
            data: dtos,
            pagination: PaginationMeta(page: page, perPage: perPage, total: total)
        )
    }

    // MARK: - Phase 9D: Calendar & Timeline

    @Sendable
    func calendarTasks(req: Request) async throws -> APIResponse<[TaskItemDTO]> {
        let ctx = try req.orgContext
        var parsedQuery = try await mergeViewConfig(into: TaskQueryParser.parse(from: req), req: req, ctx: ctx)

        var query = TaskItemModel.query(on: req.db)
            .filter(\TaskItemModel.$organization.$id == ctx.orgId)

        query = TaskQueryApplier.applyFilters(parsedQuery, to: query)
        query = TaskQueryApplier.applySorts(parsedQuery, to: query)

        let taskModels = try await query.limit(500).all()
        let dtos = try await withSubtaskCounts(tasks: taskModels, db: req.db)
        return .success(dtos)
    }

    @Sendable
    func timelineTasks(req: Request) async throws -> APIResponse<TimelineResponseDTO> {
        let ctx = try req.orgContext
        var parsedQuery = try await mergeViewConfig(into: TaskQueryParser.parse(from: req), req: req, ctx: ctx)

        var query = TaskItemModel.query(on: req.db)
            .filter(\TaskItemModel.$organization.$id == ctx.orgId)

        query = TaskQueryApplier.applyFilters(parsedQuery, to: query)
        query = query.sort(\.$startDate, .ascending).sort(\.$id, .ascending)

        let taskModels = try await query.limit(500).all()
        let taskIds = taskModels.compactMap { $0.id }

        let relations = try await TaskRelationModel.query(on: req.db)
            .group(.and) { group in
                group.filter(\.$sourceTask.$id ~~ taskIds)
                group.filter(\.$targetTask.$id ~~ taskIds)
            }
            .all()

        let taskDTOs = try await withSubtaskCounts(tasks: taskModels, db: req.db)
        let relationDTOs = relations.map { $0.toDTO(viewingTaskId: $0.$sourceTask.id) }
        return .success(TimelineResponseDTO(tasks: taskDTOs, relations: relationDTOs))
    }

    // MARK: - Shared helper: merge ViewConfig filters into a ParsedTaskQuery

    /// If `?view_id=<UUID>` is present and accessible, merges its filters/sorts into `base`.
    private func mergeViewConfig(
        into base: ParsedTaskQuery,
        req: Request,
        ctx: OrgContext
    ) async throws -> ParsedTaskQuery {
        guard
            let viewIdStr = try? req.query.get(String.self, at: "view_id"),
            let viewId = UUID(uuidString: viewIdStr),
            let viewConfig = try? await ViewConfigModel.query(on: req.db)
                .filter(\.$id == viewId)
                .filter(\.$organization.$id == ctx.orgId)
                .first(),
            viewConfig.isPublic || viewConfig.ownerUserId == ctx.userId
        else {
            return base
        }

        let viewParsed = try TaskQueryParser.parse(
            filtersJson: viewConfig.filtersJson,
            sortsJson: viewConfig.sortsJson
        )

        var merged = base
        merged.filters.append(contentsOf: viewParsed.filters)
        if !viewParsed.sorts.isEmpty {
            merged.sorts = viewParsed.sorts
        }
        return merged
    }

    // MARK: - GET /api/tasks/:taskID

    @Sendable
    func show(req: Request) async throws -> APIResponse<TaskItemDTO> {
        let ctx = try req.orgContext
        let includeArchived = (try? req.query.get(Bool.self, at: "include_archived")) ?? false

        var query = TaskItemModel.query(on: req.db)
            .filter(\.$id == req.parameters.get("taskID", as: UUID.self) ?? UUID())
            .filter(\.$organization.$id == ctx.orgId)

        if !includeArchived {
            query = query.filter(\.$archivedAt == nil)
        }

        guard let task = try await query.first() else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let dtos = try await withSubtaskCounts(tasks: [task], db: req.db)
        return .success(dtos[0])
    }

    // MARK: - POST /api/tasks

    @Sendable
    func create(req: Request) async throws -> APIResponse<TaskItemDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(CreateTaskRequest.self)

        guard !payload.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Task title is required.")
        }

        guard let listId = payload.listId else {
            throw Abort(.badRequest, reason: "Task must belong to a list. Missing listId.")
        }

        // Validate List exists and belongs to this Org
        let listQuery = TaskListModel.query(on: req.db)
            .filter(\.$id == listId)
            .with(\.$project) { project in project.with(\.$space) }
        guard let list = try await listQuery.first(),
              list.project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "List not found in this organization.")
        }

        let taskType = payload.taskType ?? .task

        // Validate parentId constraints
        if let parentId = payload.parentId {
            guard parentId != (payload as AnyObject as? CreateTaskRequest)?.listId else {
                throw Abort(.badRequest, reason: "Invalid parentId.")
            }
            guard let parent = try await TaskItemModel.query(on: req.db)
                .filter(\.$id == parentId)
                .filter(\.$organization.$id == ctx.orgId)
                .first() else {
                throw Abort(.notFound, reason: "Parent task not found in this organization.")
            }
            // No grandchildren: parent must not itself be a subtask
            if parent.taskType == .subtask {
                throw Abort(.badRequest, reason: "Subtasks cannot have subtasks (no grandchildren allowed).")
            }
        }

        // Validate storyPoints range
        if let sp = payload.storyPoints, !(0...1000).contains(sp) {
            throw Abort(.badRequest, reason: "Story points must be between 0 and 1000.")
        }

        // Validate labels count
        if let labels = payload.labels, labels.count > 20 {
            throw Abort(.badRequest, reason: "A task can have at most 20 labels.")
        }

        let task = TaskItemModel(
            orgId: ctx.orgId,
            listId: listId,
            title: payload.title,
            description: payload.description,
            status: payload.status ?? .todo,
            priority: payload.priority ?? .medium,
            taskType: taskType,
            parentId: payload.parentId,
            storyPoints: payload.storyPoints,
            labels: payload.labels,
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

        guard task.version == payload.expectedVersion else {
            throw Abort(.conflict, reason: "Task was modified by another user. Please refresh and try again.")
        }

        // Validate storyPoints range
        if let sp = payload.storyPoints, !(0...1000).contains(sp) {
            throw Abort(.badRequest, reason: "Story points must be between 0 and 1000.")
        }

        // Validate labels count
        if let labels = payload.labels, labels.count > 20 {
            throw Abort(.badRequest, reason: "A task can have at most 20 labels.")
        }

        var activities: [TaskActivityModel] = []
        let taskId = try task.requireID()

        if let title = payload.title, task.title != title {
            task.title = title
        }
        if let description = payload.description, task.description != description {
            task.description = description
        }
        if let status = payload.status, task.status != status {
            let metadata = ["from": task.status.rawValue, "to": status.rawValue]
            activities.append(TaskActivityModel(taskId: taskId, userId: ctx.userId, type: .statusChanged, metadata: metadata))
            task.status = status
        }
        if let priority = payload.priority, task.priority != priority {
            let metadata = ["from": task.priority.rawValue, "to": priority.rawValue]
            activities.append(TaskActivityModel(taskId: taskId, userId: ctx.userId, type: .priorityChanged, metadata: metadata))
            task.priority = priority
        }
        if let taskType = payload.taskType, task.taskType != taskType {
            let metadata = ["from": task.taskType.rawValue, "to": taskType.rawValue]
            activities.append(TaskActivityModel(taskId: taskId, userId: ctx.userId, type: .typeChanged, metadata: metadata))
            task.taskType = taskType
        }
        if let sp = payload.storyPoints {
            task.storyPoints = sp
        }
        if let labels = payload.labels {
            task.labels = labels
        }
        if let startDate = payload.startDate {
            task.startDate = startDate
        }
        if let dueDate = payload.dueDate {
            task.dueDate = dueDate
        }
        if let assigneeId = payload.assigneeId, task.$assignee.id != assigneeId {
            let metadata = ["assignee_id": assigneeId.uuidString]
            activities.append(TaskActivityModel(taskId: taskId, userId: ctx.userId, type: .assigned, metadata: metadata))
            task.$assignee.id = assigneeId
        }
        if let listId = payload.listId, task.$list.id != listId {
            activities.append(TaskActivityModel(taskId: taskId, userId: ctx.userId, type: .moved, metadata: ["to_list": listId.uuidString]))
            task.$list.id = listId
        }
        if let position = payload.position {
            task.position = position
        }
        if let archivedAt = payload.archivedAt {
            task.archivedAt = archivedAt
        }

        task.version += 1

        let finalActivities = activities
        try await req.db.transaction { db in
            try await task.save(on: db)
            for activity in finalActivities {
                try await activity.save(on: db)
            }
        }

        let dtos = try await withSubtaskCounts(tasks: [task], db: req.db)
        return .success(dtos[0])
    }

    // MARK: - PATCH /api/tasks/:taskID
    // Partial update bypasses expectedVersion checks to allow rapid inline editing.

    @Sendable
    func partialUpdate(req: Request) async throws -> APIResponse<TaskItemDTO> {
        let ctx = try req.orgContext
        guard let task = try await TaskItemModel.query(on: req.db)
            .filter(\.$id == req.parameters.get("taskID", as: UUID.self) ?? UUID())
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let payload = try req.content.decode(UpdateTaskRequest.self)

        // Bypass expectedVersion validation for partialUpdate (inline table edits)
        // Validate storyPoints range
        if let sp = payload.storyPoints, !(0...1000).contains(sp) {
            throw Abort(.badRequest, reason: "Story points must be between 0 and 1000.")
        }

        // Validate labels count
        if let labels = payload.labels, labels.count > 20 {
            throw Abort(.badRequest, reason: "A task can have at most 20 labels.")
        }

        var activities: [TaskActivityModel] = []
        let taskId = try task.requireID()

        if let title = payload.title, task.title != title {
            task.title = title
        }
        if let description = payload.description, task.description != description {
            task.description = description
        }
        if let status = payload.status, task.status != status {
            let metadata = ["from": task.status.rawValue, "to": status.rawValue]
            activities.append(TaskActivityModel(taskId: taskId, userId: ctx.userId, type: .statusChanged, metadata: metadata))
            task.status = status
        }
        if let priority = payload.priority, task.priority != priority {
            let metadata = ["from": task.priority.rawValue, "to": priority.rawValue]
            activities.append(TaskActivityModel(taskId: taskId, userId: ctx.userId, type: .priorityChanged, metadata: metadata))
            task.priority = priority
        }
        if let taskType = payload.taskType, task.taskType != taskType {
            let metadata = ["from": task.taskType.rawValue, "to": taskType.rawValue]
            activities.append(TaskActivityModel(taskId: taskId, userId: ctx.userId, type: .typeChanged, metadata: metadata))
            task.taskType = taskType
        }
        if let sp = payload.storyPoints {
            task.storyPoints = sp
        }
        if let labels = payload.labels {
            task.labels = labels
        }
        if let startDate = payload.startDate {
            task.startDate = startDate
        }
        if let dueDate = payload.dueDate {
            task.dueDate = dueDate
        }
        if let assigneeId = payload.assigneeId, task.$assignee.id != assigneeId {
            let metadata = ["assignee_id": assigneeId.uuidString]
            activities.append(TaskActivityModel(taskId: taskId, userId: ctx.userId, type: .assigned, metadata: metadata))
            task.$assignee.id = assigneeId
        }
        if let listId = payload.listId, task.$list.id != listId {
            activities.append(TaskActivityModel(taskId: taskId, userId: ctx.userId, type: .moved, metadata: ["to_list": listId.uuidString]))
            task.$list.id = listId
        }
        if let position = payload.position {
            task.position = position
        }
        if let archivedAt = payload.archivedAt {
            task.archivedAt = archivedAt
        }

        // Only increment version if there are changes
        task.version += 1

        let finalActivities = activities
        try await req.db.transaction { db in
            try await task.save(on: db)
            for activity in finalActivities {
                try await activity.save(on: db)
            }
        }

        let dtos = try await withSubtaskCounts(tasks: [task], db: req.db)
        return .success(dtos[0])
    }

    // MARK: - PATCH /api/tasks/:taskID/move

    @Sendable
    func move(req: Request) async throws -> APIResponse<TaskItemDTO> {
        let ctx = try req.orgContext
        guard let task = try await TaskItemModel.query(on: req.db)
            .filter(\.$id == req.parameters.get("taskID", as: UUID.self) ?? UUID())
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let payload = try req.content.decode(MoveTaskRequest.self)

        if task.$list.id != payload.targetListId {
            let listExists = try await TaskListModel.query(on: req.db)
                .filter(\.$id == payload.targetListId)
                .with(\.$project) { project in project.with(\.$space) }
                .first()?.project.space.$organization.id == ctx.orgId

            guard listExists else {
                throw Abort(.notFound, reason: "Target list not found in this organization.")
            }
            task.$list.id = payload.targetListId
        }

        task.position = payload.position
        task.version += 1

        try await req.db.transaction { db in
            try await task.save(on: db)
            let activity = TaskActivityModel(
                taskId: try task.requireID(),
                userId: ctx.userId,
                type: .moved,
                metadata: ["to_list": payload.targetListId.uuidString, "position": String(payload.position)]
            )
            try await activity.save(on: db)
        }

        return .success(task.toDTO())
    }

    // MARK: - POST /api/tasks/move-multiple

    @Sendable
    func moveMultiple(req: Request) async throws -> APIResponse<[TaskItemDTO]> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(BulkMoveTaskRequest.self)
        
        guard !payload.moves.isEmpty else {
            return .success([]) // Nothing to do
        }
        
        let taskIds = payload.moves.map { $0.taskId }
        
        // Fetch all involved tasks and verify org ownership
        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$id ~~ taskIds)
            .filter(\.$organization.$id == ctx.orgId)
            .all()
            
        guard tasks.count == taskIds.count else {
            throw Abort(.notFound, reason: "One or more tasks not found in this organization.")
        }
        
        // If changing list, verify list ownership
        if let targetListId = payload.targetListId {
            let listExists = try await TaskListModel.query(on: req.db)
                .filter(\.$id == targetListId)
                .with(\.$project) { project in project.with(\.$space) }
                .first()?.project.space.$organization.id == ctx.orgId

            guard listExists else {
                throw Abort(.notFound, reason: "Target list not found in this organization.")
            }
        }
        
        // Use a dictionary for O(1) lookups during the update loop
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.compactMap { task -> (UUID, TaskItemModel)? in
            guard let id = task.id else { return nil }
            return (id, task)
        })
        
        var activities: [TaskActivityModel] = []
        
        try await req.db.transaction { db in
            for moveAction in payload.moves {
                guard let task = taskMap[moveAction.taskId] else { continue }
                
                var movedList = false
                var changedStatus = false
                
                if let targetListId = payload.targetListId, task.$list.id != targetListId {
                    task.$list.id = targetListId
                    movedList = true
                }
                
                if let targetStatus = payload.targetStatus, task.status != targetStatus {
                    let md = ["from": task.status.rawValue, "to": targetStatus.rawValue]
                    activities.append(TaskActivityModel(taskId: moveAction.taskId, userId: ctx.userId, type: .statusChanged, metadata: md))
                    task.status = targetStatus
                    changedStatus = true
                }
                
                task.position = moveAction.newPosition
                task.version += 1
                try await task.save(on: db)
                
                if movedList || changedStatus {
                    var md: [String: String] = [:]
                    if movedList { md["to_list"] = payload.targetListId?.uuidString }
                    md["position"] = String(moveAction.newPosition)
                    activities.append(TaskActivityModel(taskId: moveAction.taskId, userId: ctx.userId, type: .moved, metadata: md))
                }
            }
            
            for activity in activities {
                try await activity.save(on: db)
            }
        }
        
        let dtos = try await withSubtaskCounts(tasks: tasks, db: req.db)
        return .success(dtos)
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

    // MARK: - GET /api/lists/:listID/tasks

    @Sendable
    func tasksByList(req: Request) async throws -> APIResponse<[TaskItemDTO]> {
        let ctx = try req.orgContext
        let includeArchived = (try? req.query.get(Bool.self, at: "include_archived")) ?? false

        guard let listId = req.parameters.get("listID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid list ID.")
        }

        let listBelongsToOrg = try await TaskListModel.query(on: req.db)
            .filter(\.$id == listId)
            .with(\.$project) { project in project.with(\.$space) }
            .first()?.project.space.$organization.id == ctx.orgId

        guard listBelongsToOrg else {
            throw Abort(.notFound, reason: "List not found using current organization credentials.")
        }

        var query = TaskItemModel.query(on: req.db)
            .filter(\.$list.$id == listId)

        if !includeArchived {
            query = query.filter(\.$archivedAt == nil)
        }

        let taskModels = try await query
            .sort(\.$position, .ascending)
            .all()

        let dtos = try await withSubtaskCounts(tasks: taskModels, db: req.db)
        let pagination = PaginationMeta(page: 1, perPage: taskModels.count, total: taskModels.count)
        return .success(dtos, pagination: pagination)
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

    // MARK: - 8A: GET /api/tasks/:taskID/subtasks

    @Sendable
    func listSubtasks(req: Request) async throws -> APIResponse<[TaskItemDTO]> {
        let ctx = try req.orgContext
        guard let taskId = req.parameters.get("taskID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Task ID.")
        }
        let page = (try? req.query.get(Int.self, at: "page")) ?? 1
        let perPage = min((try? req.query.get(Int.self, at: "per_page")) ?? 50, 100)

        // Verify the parent task belongs to this org
        guard try await TaskItemModel.query(on: req.db)
            .filter(\.$id == taskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0 else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let total = try await TaskItemModel.query(on: req.db)
            .filter(\.$parent.$id == taskId)
            .count()

        let subtasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$parent.$id == taskId)
            .sort(\.$position, .ascending)
            .range(((page - 1) * perPage)..<(page * perPage))
            .all()

        // Subtasks never have their own subtasks (no grandchildren), so counts are 0
        let dtos = subtasks.map { $0.toDTO(subtaskCount: 0, completedSubtaskCount: 0) }
        let pagination = PaginationMeta(page: page, perPage: perPage, total: total)
        return .success(dtos, pagination: pagination)
    }

    // MARK: - 8B: GET /api/tasks/:taskID/relations

    @Sendable
    func listRelations(req: Request) async throws -> APIResponse<[TaskRelationDTO]> {
        let ctx = try req.orgContext
        guard let taskId = req.parameters.get("taskID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Task ID.")
        }

        guard try await TaskItemModel.query(on: req.db)
            .filter(\.$id == taskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0 else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        // Fetch forward relations (source == taskId)
        let forward = try await TaskRelationModel.query(on: req.db)
            .filter(\.$sourceTask.$id == taskId)
            .all()

        // Fetch inverse relations: another task blocks this one
        let inverse = try await TaskRelationModel.query(on: req.db)
            .filter(\.$targetTask.$id == taskId)
            .filter(\.$relationType == .blocks)
            .all()

        let dtos = (forward + inverse).map { $0.toDTO(viewingTaskId: taskId) }
        return .success(dtos)
    }

    // MARK: - 8B: POST /api/tasks/:taskID/relations

    @Sendable
    func createRelation(req: Request) async throws -> APIResponse<TaskRelationDTO> {
        let ctx = try req.orgContext
        guard let sourceTaskId = req.parameters.get("taskID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Task ID.")
        }

        guard try await TaskItemModel.query(on: req.db)
            .filter(\.$id == sourceTaskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0 else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let payload = try req.content.decode(CreateRelationRequest.self)
        let targetTaskId = payload.relatedTaskId

        // Cannot relate a task to itself
        guard sourceTaskId != targetTaskId else {
            throw Abort(.badRequest, reason: "A task cannot be related to itself.")
        }

        // Handle blockedBy: treat it as a `blocks` row with source/target swapped
        let (storedSource, storedTarget, storedType): (UUID, UUID, StoredRelationType)
        if payload.relationType == .blockedBy {
            guard let st = StoredRelationType.from(.blocks) else {
                throw Abort(.badRequest, reason: "Invalid relation type.")
            }
            storedSource = targetTaskId
            storedTarget = sourceTaskId
            storedType = st
        } else {
            guard let st = StoredRelationType.from(payload.relationType) else {
                throw Abort(.badRequest, reason: "Invalid relation type.")
            }
            storedSource = sourceTaskId
            storedTarget = targetTaskId
            storedType = st
        }

        // Target task must belong to the same org
        guard try await TaskItemModel.query(on: req.db)
            .filter(\.$id == targetTaskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0 else {
            throw Abort(.notFound, reason: "Related task not found in this organization.")
        }

        // Check for exact duplicate
        let exactDupe = try await TaskRelationModel.query(on: req.db)
            .filter(\.$sourceTask.$id == storedSource)
            .filter(\.$targetTask.$id == storedTarget)
            .filter(\.$relationType == storedType)
            .count() > 0
        if exactDupe {
            throw Abort(.conflict, reason: "This relation already exists.")
        }

        // For blocks/relatesTo: also check the inverse to prevent logical duplicates
        if storedType == .blocks {
            let inverseDupe = try await TaskRelationModel.query(on: req.db)
                .filter(\.$sourceTask.$id == storedTarget)
                .filter(\.$targetTask.$id == storedSource)
                .filter(\.$relationType == .blocks)
                .count() > 0
            if inverseDupe {
                throw Abort(.conflict, reason: "An inverse blocking relation already exists.")
            }
        }
        if storedType == .relatesTo {
            let inverseDupe = try await TaskRelationModel.query(on: req.db)
                .filter(\.$sourceTask.$id == storedTarget)
                .filter(\.$targetTask.$id == storedSource)
                .filter(\.$relationType == .relatesTo)
                .count() > 0
            if inverseDupe {
                throw Abort(.conflict, reason: "This relation already exists (symmetric).")
            }
        }

        let relation = TaskRelationModel(
            sourceTaskId: storedSource,
            targetTaskId: storedTarget,
            relationType: storedType
        )
        try await relation.save(on: req.db)

        return .success(relation.toDTO(viewingTaskId: sourceTaskId))
    }

    // MARK: - 8B: DELETE /api/tasks/:taskID/relations/:relationID

    @Sendable
    func deleteRelation(req: Request) async throws -> HTTPStatus {
        let ctx = try req.orgContext
        guard let taskId = req.parameters.get("taskID", as: UUID.self),
              let relationId = req.parameters.get("relationID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid IDs.")
        }

        // Verify task belongs to org
        guard try await TaskItemModel.query(on: req.db)
            .filter(\.$id == taskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0 else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        // Relation must involve this task as source or target
        guard let relation = try await TaskRelationModel.query(on: req.db)
            .filter(\.$id == relationId)
            .first(),
              relation.$sourceTask.id == taskId || relation.$targetTask.id == taskId else {
            throw Abort(.notFound, reason: "Relation not found.")
        }

        try await relation.delete(on: req.db)
        return .noContent
    }

    // MARK: - 8C: GET /api/tasks/:taskID/checklist

    @Sendable
    func listChecklist(req: Request) async throws -> APIResponse<[ChecklistItemDTO]> {
        let ctx = try req.orgContext
        guard let taskId = req.parameters.get("taskID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Task ID.")
        }

        guard try await TaskItemModel.query(on: req.db)
            .filter(\.$id == taskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0 else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let items = try await ChecklistItemModel.query(on: req.db)
            .filter(\.$task.$id == taskId)
            .sort(\.$position, .ascending)
            .all()

        return .success(items.map { $0.toDTO() })
    }

    // MARK: - 8C: POST /api/tasks/:taskID/checklist

    @Sendable
    func createChecklistItem(req: Request) async throws -> APIResponse<ChecklistItemDTO> {
        let ctx = try req.orgContext
        guard let taskId = req.parameters.get("taskID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Task ID.")
        }

        guard try await TaskItemModel.query(on: req.db)
            .filter(\.$id == taskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0 else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let payload = try req.content.decode(CreateChecklistItemRequest.self)
        guard !payload.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Checklist item title is required.")
        }

        // Append to end: find the current max position
        let maxPosition = try await ChecklistItemModel.query(on: req.db)
            .filter(\.$task.$id == taskId)
            .sort(\.$position, .descending)
            .first()?.position ?? 0.0

        let item = ChecklistItemModel(
            taskId: taskId,
            title: payload.title.trimmingCharacters(in: .whitespaces),
            position: maxPosition + 1.0,
            createdBy: ctx.userId
        )
        try await item.save(on: req.db)
        return .success(item.toDTO())
    }

    // MARK: - 8C: PATCH /api/tasks/:taskID/checklist/:itemID

    @Sendable
    func updateChecklistItem(req: Request) async throws -> APIResponse<ChecklistItemDTO> {
        let ctx = try req.orgContext
        guard let taskId = req.parameters.get("taskID", as: UUID.self),
              let itemId = req.parameters.get("itemID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid IDs.")
        }

        // Verify org ownership via the task
        guard try await TaskItemModel.query(on: req.db)
            .filter(\.$id == taskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0 else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        guard let item = try await ChecklistItemModel.query(on: req.db)
            .filter(\.$id == itemId)
            .filter(\.$task.$id == taskId)
            .first() else {
            throw Abort(.notFound, reason: "Checklist item not found.")
        }

        let payload = try req.content.decode(UpdateChecklistItemRequest.self)

        if let title = payload.title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            item.title = title.trimmingCharacters(in: .whitespaces)
        }
        if let isCompleted = payload.isCompleted {
            item.isCompleted = isCompleted
        }
        item.$updatedByUser.id = ctx.userId

        try await item.save(on: req.db)
        return .success(item.toDTO())
    }

    // MARK: - 8C: DELETE /api/tasks/:taskID/checklist/:itemID

    @Sendable
    func deleteChecklistItem(req: Request) async throws -> HTTPStatus {
        let ctx = try req.orgContext
        guard let taskId = req.parameters.get("taskID", as: UUID.self),
              let itemId = req.parameters.get("itemID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid IDs.")
        }

        guard try await TaskItemModel.query(on: req.db)
            .filter(\.$id == taskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0 else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        guard let item = try await ChecklistItemModel.query(on: req.db)
            .filter(\.$id == itemId)
            .filter(\.$task.$id == taskId)
            .first() else {
            throw Abort(.notFound, reason: "Checklist item not found.")
        }

        try await item.delete(on: req.db)
        return .noContent
    }

    // MARK: - 8C: PATCH /api/tasks/:taskID/checklist/reorder

    @Sendable
    func reorderChecklist(req: Request) async throws -> APIResponse<[ChecklistItemDTO]> {
        let ctx = try req.orgContext
        guard let taskId = req.parameters.get("taskID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Task ID.")
        }

        guard try await TaskItemModel.query(on: req.db)
            .filter(\.$id == taskId)
            .filter(\.$organization.$id == ctx.orgId)
            .count() > 0 else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }

        let payload = try req.content.decode(ReorderChecklistRequest.self)

        guard let movingItem = try await ChecklistItemModel.query(on: req.db)
            .filter(\.$id == payload.itemId)
            .filter(\.$task.$id == taskId)
            .first() else {
            throw Abort(.notFound, reason: "Checklist item not found.")
        }

        if let afterId = payload.afterId {
            guard let afterItem = try await ChecklistItemModel.query(on: req.db)
                .filter(\.$id == afterId)
                .filter(\.$task.$id == taskId)
                .first() else {
                throw Abort(.notFound, reason: "Reference checklist item not found.")
            }

            // Find the item after `afterItem` to compute a midpoint position
            let movingItemId = try movingItem.requireID()
            let nextItem = try await ChecklistItemModel.query(on: req.db)
                .filter(\.$task.$id == taskId)
                .filter(\.$position > afterItem.position)
                .filter(\.$id != movingItemId)
                .sort(\.$position, .ascending)
                .first()

            let newPosition: Double
            if let next = nextItem {
                newPosition = (afterItem.position + next.position) / 2.0
            } else {
                newPosition = afterItem.position + 1.0
            }
            movingItem.position = newPosition
        } else {
            // Move to top: find the minimum position and go below it
            let movingItemId = try movingItem.requireID()
            let firstItem = try await ChecklistItemModel.query(on: req.db)
                .filter(\.$task.$id == taskId)
                .filter(\.$id != movingItemId)
                .sort(\.$position, .ascending)
                .first()

            movingItem.position = (firstItem?.position ?? 1.0) - 1.0
        }

        movingItem.$updatedByUser.id = ctx.userId
        try await movingItem.save(on: req.db)

        let items = try await ChecklistItemModel.query(on: req.db)
            .filter(\.$task.$id == taskId)
            .sort(\.$position, .ascending)
            .all()

        return .success(items.map { $0.toDTO() })
    }

    // MARK: - Helpers

    /// Fetches subtask counts for a batch of tasks using a GROUP BY aggregate (no N+1).
    private func withSubtaskCounts(tasks: [TaskItemModel], db: any Database) async throws -> [TaskItemDTO] {
        guard !tasks.isEmpty else { return [] }

        let taskIds = tasks.compactMap { $0.id }

        // Count all subtasks per parent
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
