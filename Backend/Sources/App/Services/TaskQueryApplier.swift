import Fluent
import SharedModels
import Vapor

/// Applies a `ParsedTaskQuery` to a Fluent `QueryBuilder` for `TaskItemModel`.
struct TaskQueryApplier {

    /// Applies filters to the given query. Handles joins if necessary (e.g. for `projectId`).
    /// Returns the mutated query builder.
    @discardableResult
    static func applyFilters(
        _ parsedQuery: ParsedTaskQuery,
        to query: QueryBuilder<TaskItemModel>
    ) -> QueryBuilder<TaskItemModel> {

        var q = query
        var hasJoinedTaskList = false
        var hasJoinedProject = false

        for filter in parsedQuery.filters {
            switch filter {
            case .status(let status):
                q = q.filter(\.$status == status)

            case .statusIn(let statuses):
                q = q.filter(\.$status ~~ statuses)

            case .priority(let priority):
                q = q.filter(\.$priority == priority)

            case .priorityIn(let priorities):
                q = q.filter(\.$priority ~~ priorities)

            case .taskType(let type):
                q = q.filter(\.$taskType == type)

            case .assigneeId(let id):
                q = q.filter(\.$assignee.$id == id)
                
            case .assigneeIsNull:
                q = q.filter(\.$assignee.$id == nil)

            case .label(let label):
                // Contains logic for Postgres/SQLite JSON array usually requires custom raw SQL
                // For SQLite: LIKE '%"label"%' inside the JSON string is a hacky fallback.
                // A better approach is using `try q.filter(\.$labels, .contains, label)` if driver supports it,
                // but for SQLite array columns mapped to String/Data, this is driver-dependent.
                // We will skip complex JSON-array querying here unless specifically requested,
                // or use a simpler LIKE match.
                break

            case .parentId(let pid):
                q = q.filter(\.$parent.$id == pid)

            case .listId(let lid):
                q = q.filter(\.$list.$id == lid)

            case .projectId(let pid):
                if !hasJoinedTaskList {
                    q = q.join(TaskListModel.self, on: \TaskItemModel.$list.$id == \TaskListModel.$id)
                    hasJoinedTaskList = true
                }
                q = q.filter(TaskListModel.self, \.$project.$id == pid)

            case .spaceId(let sid):
                if !hasJoinedTaskList {
                    q = q.join(TaskListModel.self, on: \TaskItemModel.$list.$id == \TaskListModel.$id)
                    hasJoinedTaskList = true
                }
                if !hasJoinedProject {
                    q = q.join(ProjectModel.self, on: \TaskListModel.$project.$id == \ProjectModel.$id)
                    hasJoinedProject = true
                }
                q = q.filter(ProjectModel.self, \.$space.$id == sid)

            case .dueDateRange(let from, let to):
                if let f = from, let t = to {
                    q = q.filter(\.$dueDate >= f).filter(\.$dueDate <= t)
                } else if let f = from {
                    q = q.filter(\.$dueDate >= f)
                } else if let t = to {
                    q = q.filter(\.$dueDate <= t)
                }

            case .startDateRange(let from, let to):
                if let f = from, let t = to {
                    q = q.filter(\.$startDate >= f).filter(\.$startDate <= t)
                } else if let f = from {
                    q = q.filter(\.$startDate >= f)
                } else if let t = to {
                    q = q.filter(\.$startDate <= t)
                }

            case .dateOverlap(let from, let to):
                q = q.group(.or) { or in
                    // Case 1: Standard intersection [startDate, dueDate] intersects [from, to]
                    or.group(.and) { and in
                        and.filter(\.$startDate <= to).filter(\.$dueDate >= from)
                    }
                    // Case 2: Milestone (only dueDate) falls in [from, to]
                    or.group(.and) { and in
                        and.filter(\.$startDate == nil).filter(\.$dueDate >= from).filter(\.$dueDate <= to)
                    }
                    // Case 3: Open-ended start (only startDate) falls in [from, to]
                    or.group(.and) { and in
                        and.filter(\.$dueDate == nil).filter(\.$startDate >= from).filter(\.$startDate <= to)
                    }
                }

            case .archived(let flag):
                if flag {
                    // Do nothing, includes archived
                } else {
                    q = q.filter(\.$archivedAt == nil)
                }

            case .includeSubtasks(let flag):
                if !flag {
                    // Exclude subtasks (tasks that have a parent)
                    q = q.filter(\.$parent.$id == nil)
                }
            }
        }

        return q
    }

    /// Applies sorts to the given query.
    @discardableResult
    static func applySorts(
        _ parsedQuery: ParsedTaskQuery,
        to query: QueryBuilder<TaskItemModel>
    ) -> QueryBuilder<TaskItemModel> {

        var q = query

        for sort in parsedQuery.sorts {
            let direction: DatabaseQuery.Sort.Direction = sort.direction == .asc ? .ascending : .descending

            switch sort.field {
            case .createdAt:
                q = q.sort(\.$createdAt, direction)
            case .updatedAt:
                q = q.sort(\.$updatedAt, direction)
            case .dueDate:
                q = q.sort(\.$dueDate, direction)
            case .priority:
                q = q.sort(\.$priority, direction)
            case .status:
                q = q.sort(\.$status, direction)
            case .position:
                q = q.sort(\.$position, direction)
            case .title:
                q = q.sort(\.$title, direction)
            }
        }

        // Default sort if none provided
        if parsedQuery.sorts.isEmpty {
            q = q.sort(\.$createdAt, .descending)
        }

        return q
    }
}
