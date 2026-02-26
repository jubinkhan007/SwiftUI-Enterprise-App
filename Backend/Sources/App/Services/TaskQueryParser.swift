import Fluent
import SharedModels
import Vapor

// MARK: - Domain Query Model

/// A parsed, validated query object used by all task-fetching endpoints.
/// Produced by `TaskQueryParser`, consumed by `TaskQueryApplier`.
struct ParsedTaskQuery {
    var filters: [TaskFilter] = []
    var sorts: [TaskSort] = []
}

/// A single typed filter clause.
enum TaskFilter {
    case status(TaskStatus)
    case statusIn([TaskStatus])
    case priority(TaskPriority)
    case priorityIn([TaskPriority])
    case taskType(TaskType)
    case assigneeId(UUID)
    case assigneeIsNull
    case label(String)
    case parentId(UUID)
    case listId(UUID)
    case projectId(UUID)
    case spaceId(UUID)
    case dueDateRange(from: Date?, to: Date?)
    case startDateRange(from: Date?, to: Date?)
    case dateOverlap(from: Date, to: Date)
    case archived(Bool)
    case includeSubtasks(Bool)
}

/// A single sort clause.
struct TaskSort {
    let field: TaskSortField
    let direction: SortDirection

    enum SortDirection: String, Codable {
        case asc, desc
    }
}

enum TaskSortField: String, Codable {
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case dueDate = "due_date"
    case priority
    case status
    case position
    case title
}

// MARK: - TaskQueryParser

/// Parses ViewConfig JSON or raw query parameters into a validated `ParsedTaskQuery`.
struct TaskQueryParser {

    // MARK: - Allow-listed fields & operators

    static let allowedFilterFields: Set<String> = [
        "status", "priority", "assignee_id", "task_type", "label",
        "due_date_range", "start_date_range", "date_overlap", "archived", "list_id",
        "project_id", "space_id", "parent_id", "include_subtasks"
    ]

    static let allowedOperators: Set<String> = [
        "eq", "in", "contains", "range", "is_null"
    ]

    static let maxClauses = 20

    // MARK: - Parse from ViewConfig JSON

    /// Parse filters and sorts from ViewConfig JSON strings.
    /// Throws 400 if JSON is invalid or exceeds complexity limits.
    static func parse(filtersJson: String?, sortsJson: String?) throws -> ParsedTaskQuery {
        var query = ParsedTaskQuery()

        if let filtersJson = filtersJson, !filtersJson.isEmpty {
            let filters = try parseFiltersJson(filtersJson)
            query.filters = filters
        }

        if let sortsJson = sortsJson, !sortsJson.isEmpty {
            let sorts = try parseSortsJson(sortsJson)
            query.sorts = sorts
        }

        return query
    }

    // MARK: - Parse from Request Query Parameters (backwards-compatible)

    /// Parse filters directly from URL query parameters (used by existing endpoints).
    static func parse(from req: Request) -> ParsedTaskQuery {
        var query = ParsedTaskQuery()

        if let status: TaskStatus = try? req.query.get(TaskStatus.self, at: "status") {
            query.filters.append(.status(status))
        }
        if let priority: TaskPriority = try? req.query.get(TaskPriority.self, at: "priority") {
            query.filters.append(.priority(priority))
        }
        if let taskType: TaskType = try? req.query.get(TaskType.self, at: "task_type") {
            query.filters.append(.taskType(taskType))
        }
        if let parentId: UUID = try? req.query.get(UUID.self, at: "parent_id") {
            query.filters.append(.parentId(parentId))
        }
        if let listId: UUID = try? req.query.get(UUID.self, at: "list_id") {
            query.filters.append(.listId(listId))
        }
        if let projectId: UUID = try? req.query.get(UUID.self, at: "project_id") {
            query.filters.append(.projectId(projectId))
        }
        if let spaceId: UUID = try? req.query.get(UUID.self, at: "space_id") {
            query.filters.append(.spaceId(spaceId))
        }

        let includeArchived = (try? req.query.get(Bool.self, at: "include_archived")) ?? false
        query.filters.append(.archived(includeArchived))

        let includeSubtasks = (try? req.query.get(Bool.self, at: "include_subtasks")) ?? false
        query.filters.append(.includeSubtasks(includeSubtasks))

        if let from = try? req.query.get(Date.self, at: "from"),
           let to = try? req.query.get(Date.self, at: "to") {
            query.filters.append(.dateOverlap(from: from, to: to))
        }

        return query
    }

    // MARK: - Private JSON Parsers

    private static func parseFiltersJson(_ json: String) throws -> [TaskFilter] {
        guard let data = json.data(using: .utf8) else {
            throw Abort(.badRequest, reason: "Invalid filter JSON encoding.")
        }

        let clauses: [[String: Any]]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw Abort(.badRequest, reason: "Filters must be a JSON array of objects.")
            }
            clauses = parsed
        } catch let error as AbortError {
            throw error
        } catch {
            throw Abort(.badRequest, reason: "Invalid filter JSON: \(error.localizedDescription)")
        }

        guard clauses.count <= maxClauses else {
            throw Abort(.badRequest, reason: "Too many filter clauses. Maximum is \(maxClauses).")
        }

        var filters: [TaskFilter] = []

        for clause in clauses {
            guard let field = clause["field"] as? String else {
                throw Abort(.badRequest, reason: "Each filter must have a 'field' key.")
            }
            guard let op = clause["op"] as? String else {
                throw Abort(.badRequest, reason: "Each filter must have an 'op' key.")
            }
            guard allowedFilterFields.contains(field) else {
                throw Abort(.badRequest, reason: "Unknown filter field: '\(field)'.")
            }
            guard allowedOperators.contains(op) else {
                throw Abort(.badRequest, reason: "Unknown operator: '\(op)'.")
            }

            let value = clause["value"]

            switch (field, op) {
            case ("status", "eq"):
                guard let raw = value as? String, let s = TaskStatus(rawValue: raw) else {
                    throw Abort(.badRequest, reason: "Invalid status value.")
                }
                filters.append(.status(s))

            case ("status", "in"):
                guard let arr = value as? [String] else {
                    throw Abort(.badRequest, reason: "status 'in' requires an array of strings.")
                }
                let statuses = try arr.map { raw -> TaskStatus in
                    guard let s = TaskStatus(rawValue: raw) else {
                        throw Abort(.badRequest, reason: "Invalid status value: '\(raw)'.")
                    }
                    return s
                }
                filters.append(.statusIn(statuses))

            case ("priority", "eq"):
                guard let raw = value as? String, let p = TaskPriority(rawValue: raw) else {
                    throw Abort(.badRequest, reason: "Invalid priority value.")
                }
                filters.append(.priority(p))

            case ("task_type", "eq"):
                guard let raw = value as? String, let t = TaskType(rawValue: raw) else {
                    throw Abort(.badRequest, reason: "Invalid task_type value.")
                }
                filters.append(.taskType(t))

            case ("assignee_id", "eq"):
                guard let raw = value as? String, let id = UUID(uuidString: raw) else {
                    throw Abort(.badRequest, reason: "Invalid assignee_id UUID.")
                }
                filters.append(.assigneeId(id))

            case ("assignee_id", "is_null"):
                filters.append(.assigneeIsNull)

            case ("archived", "eq"):
                let flag = (value as? Bool) ?? false
                filters.append(.archived(flag))

            default:
                // Other field/op combos can be added as needed; skip for now
                break
            }
        }

        return filters
    }

    private static func parseSortsJson(_ json: String) throws -> [TaskSort] {
        guard let data = json.data(using: .utf8) else {
            throw Abort(.badRequest, reason: "Invalid sort JSON encoding.")
        }

        let clauses: [[String: Any]]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw Abort(.badRequest, reason: "Sorts must be a JSON array of objects.")
            }
            clauses = parsed
        } catch let error as AbortError {
            throw error
        } catch {
            throw Abort(.badRequest, reason: "Invalid sort JSON.")
        }

        return try clauses.map { clause in
            guard let fieldRaw = clause["field"] as? String,
                  let field = TaskSortField(rawValue: fieldRaw) else {
                throw Abort(.badRequest, reason: "Invalid sort field.")
            }
            let dirRaw = (clause["direction"] as? String) ?? "asc"
            let direction: TaskSort.SortDirection = dirRaw == "desc" ? .desc : .asc
            return TaskSort(field: field, direction: direction)
        }
    }
}
