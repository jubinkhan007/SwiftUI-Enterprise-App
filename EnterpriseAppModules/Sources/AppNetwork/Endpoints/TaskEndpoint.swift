import Foundation
import SharedModels

public enum TaskEndpoint {
    case getTasks(query: TaskQuery, configuration: APIConfiguration)
    case getTask(id: UUID, configuration: APIConfiguration)
    case createTask(payload: CreateTaskRequest, configuration: APIConfiguration)
    case updateTask(id: UUID, payload: UpdateTaskRequest, configuration: APIConfiguration)
    case deleteTask(id: UUID, configuration: APIConfiguration)
    case moveTask(id: UUID, payload: MoveTaskRequest, configuration: APIConfiguration)
    case getActivity(taskId: UUID, configuration: APIConfiguration)
    case createComment(taskId: UUID, payload: CreateCommentRequest, configuration: APIConfiguration)
}

extension TaskEndpoint: APIEndpoint {
    public var baseURL: URL {
        switch self {
        case .getTasks(_, let config),
             .getTask(_, let config),
             .createTask(_, let config),
             .updateTask(_, _, let config),
             .deleteTask(_, let config),
             .moveTask(_, _, let config),
             .getActivity(_, let config),
             .createComment(_, _, let config):
            return config.baseURL
        }
    }

    public var path: String {
        switch self {
        case .getTasks, .createTask: return "/api/tasks"
        case .getTask(let id, _), .updateTask(let id, _, _), .deleteTask(let id, _): return "/api/tasks/\(id.uuidString)"
        case .moveTask(let id, _, _): return "/api/tasks/\(id.uuidString)/move"
        case .getActivity(let taskId, _): return "/api/tasks/\(taskId.uuidString)/activity"
        case .createComment(let taskId, _, _): return "/api/tasks/\(taskId.uuidString)/comments"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .getTasks, .getTask, .getActivity: return .get
        case .createTask, .createComment: return .post
        case .updateTask: return .put
        case .moveTask: return .patch
        case .deleteTask: return .delete
        }
    }

    public var queryParameters: [String: String]? {
        guard case .getTasks(let query, _) = self else { return nil }
        var params: [String: String] = [
            "page": "\(query.page)",
            "per_page": "\(query.perPage)"
        ]
        if let status = query.status { params["status"] = status.rawValue }
        if let priority = query.priority { params["priority"] = priority.rawValue }
        if let search = query.search { params["search"] = search }
        if let spaceId = query.spaceId { params["space_id"] = spaceId.uuidString }
        if let projectId = query.projectId { params["project_id"] = projectId.uuidString }
        if let listId = query.listId { params["list_id"] = listId.uuidString }
        return params
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
        // Assume JSONCoding.encoder is available from the AppNetwork module
        switch self {
        case .createTask(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updateTask(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .moveTask(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .createComment(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        default:
            return nil
        }
    }
}
