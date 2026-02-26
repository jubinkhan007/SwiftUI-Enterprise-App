import Foundation
import SharedModels

public enum TaskEndpoint {
    // Core CRUD
    case getTasks(query: TaskQuery, configuration: APIConfiguration)
    case getTask(id: UUID, configuration: APIConfiguration)
    case createTask(payload: CreateTaskRequest, configuration: APIConfiguration)
    case updateTask(id: UUID, payload: UpdateTaskRequest, configuration: APIConfiguration)
    case deleteTask(id: UUID, configuration: APIConfiguration)
    case moveTask(id: UUID, payload: MoveTaskRequest, configuration: APIConfiguration)
    case moveMultiple(payload: BulkMoveTaskRequest, configuration: APIConfiguration)
    case getActivity(taskId: UUID, configuration: APIConfiguration)
    case createComment(taskId: UUID, payload: CreateCommentRequest, configuration: APIConfiguration)

    // Phase 8A: subtasks
    case getSubtasks(taskId: UUID, page: Int, configuration: APIConfiguration)

    // Phase 8B: relations
    case getRelations(taskId: UUID, configuration: APIConfiguration)
    case createRelation(taskId: UUID, payload: CreateRelationRequest, configuration: APIConfiguration)
    case deleteRelation(taskId: UUID, relationId: UUID, configuration: APIConfiguration)

    // Phase 8C: checklist
    case getChecklist(taskId: UUID, configuration: APIConfiguration)
    case createChecklistItem(taskId: UUID, payload: CreateChecklistItemRequest, configuration: APIConfiguration)
    case updateChecklistItem(taskId: UUID, itemId: UUID, payload: UpdateChecklistItemRequest, configuration: APIConfiguration)
    case deleteChecklistItem(taskId: UUID, itemId: UUID, configuration: APIConfiguration)
    case reorderChecklist(taskId: UUID, payload: ReorderChecklistRequest, configuration: APIConfiguration)
}

extension TaskEndpoint: APIEndpoint {
    public var baseURL: URL {
        configuration.baseURL
    }

    private var configuration: APIConfiguration {
        switch self {
        case .getTasks(_, let c), .getTask(_, let c), .createTask(_, let c),
             .updateTask(_, _, let c), .deleteTask(_, let c), .moveTask(_, _, let c),
             .moveMultiple(_, let c),
             .getActivity(_, let c), .createComment(_, _, let c),
             .getSubtasks(_, _, let c),
             .getRelations(_, let c), .createRelation(_, _, let c), .deleteRelation(_, _, let c),
             .getChecklist(_, let c), .createChecklistItem(_, _, let c),
             .updateChecklistItem(_, _, _, let c), .deleteChecklistItem(_, _, let c),
             .reorderChecklist(_, _, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .getTasks, .createTask:
            return "/api/tasks"
        case .getTask(let id, _), .updateTask(let id, _, _), .deleteTask(let id, _):
            return "/api/tasks/\(id.uuidString)"
        case .moveTask(let id, _, _):
            return "/api/tasks/\(id.uuidString)/move"
        case .moveMultiple:
            return "/api/tasks/move-multiple"
        case .getActivity(let taskId, _):
            return "/api/tasks/\(taskId.uuidString)/activity"
        case .createComment(let taskId, _, _):
            return "/api/tasks/\(taskId.uuidString)/comments"
        case .getSubtasks(let taskId, _, _):
            return "/api/tasks/\(taskId.uuidString)/subtasks"
        case .getRelations(let taskId, _), .createRelation(let taskId, _, _):
            return "/api/tasks/\(taskId.uuidString)/relations"
        case .deleteRelation(let taskId, let relationId, _):
            return "/api/tasks/\(taskId.uuidString)/relations/\(relationId.uuidString)"
        case .getChecklist(let taskId, _), .createChecklistItem(let taskId, _, _),
             .reorderChecklist(let taskId, _, _):
            return "/api/tasks/\(taskId.uuidString)/checklist"
        case .updateChecklistItem(let taskId, let itemId, _, _),
             .deleteChecklistItem(let taskId, let itemId, _):
            return "/api/tasks/\(taskId.uuidString)/checklist/\(itemId.uuidString)"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .getTasks, .getTask, .getActivity, .getSubtasks, .getRelations, .getChecklist:
            return .get
        case .createTask, .createComment, .createRelation, .createChecklistItem, .moveMultiple:
            return .post
        case .updateTask:
            return .put
        case .moveTask, .updateChecklistItem, .reorderChecklist:
            return .patch
        case .deleteTask, .deleteRelation, .deleteChecklistItem:
            return .delete
        }
    }

    public var queryParameters: [String: String]? {
        switch self {
        case .getTasks(let query, _):
            var params: [String: String] = [
                "page": "\(query.page)",
                "per_page": "\(query.perPage)",
                "include_subtasks": query.includeSubtasks ? "true" : "false"
            ]
            if let status = query.status { params["status"] = status.rawValue }
            if let priority = query.priority { params["priority"] = priority.rawValue }
            if let taskType = query.taskType { params["task_type"] = taskType.rawValue }
            if let parentId = query.parentId { params["parent_id"] = parentId.uuidString }
            if let search = query.search { params["search"] = search }
            if let spaceId = query.spaceId { params["space_id"] = spaceId.uuidString }
            if let projectId = query.projectId { params["project_id"] = projectId.uuidString }
            if let listId = query.listId { params["list_id"] = listId.uuidString }
            return params
        case .getSubtasks(_, let page, _):
            return ["page": "\(page)", "per_page": "50"]
        default:
            return nil
        }
    }

    public var headers: [String: String]? {
        var h = ["Content-Type": "application/json"]
        if let token = TokenStore.shared.token {
            h["Authorization"] = "Bearer \(token)"
        }
        if let orgId = OrganizationContext.shared.orgId {
            h["X-Org-Id"] = orgId.uuidString
        }
        return h
    }

    public var body: Data? {
        switch self {
        case .createTask(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updateTask(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .moveTask(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .moveMultiple(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .createComment(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .createRelation(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .createChecklistItem(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updateChecklistItem(_, _, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .reorderChecklist(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        default:
            return nil
        }
    }
}
