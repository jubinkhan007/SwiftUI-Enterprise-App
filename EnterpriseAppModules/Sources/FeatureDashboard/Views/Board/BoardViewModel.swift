import Foundation
import SwiftUI
import Combine
import Domain
import SharedModels

/// Represents a single column in the Kanban board
public struct BoardColumn: Identifiable, Equatable {
    public let id: String // The group value (e.g., "todo", "high", "assignee_uuid")
    public let title: String
    public let items: [TaskItemDTO]
    public let wipLimit: Int?
    
    public init(id: String, title: String, items: [TaskItemDTO], wipLimit: Int? = nil) {
        self.id = id
        self.title = title
        self.items = items
        self.wipLimit = wipLimit
    }
}

@MainActor
public final class BoardViewModel: ObservableObject {
    @Published public private(set) var columns: [BoardColumn] = []
    @Published public var config: BoardColumnConfigDTO
    @Published public private(set) var isMoving: Bool = false
    @Published public var error: Error?
    
    private let taskRepository: TaskRepositoryProtocol
    private var allTasks: [TaskItemDTO] = []
    private var workflowStatuses: [WorkflowStatusDTO] = []
    
    public init(taskRepository: TaskRepositoryProtocol, initialConfig: BoardColumnConfigDTO = BoardColumnConfigDTO()) {
        self.taskRepository = taskRepository
        self.config = initialConfig
    }

    public func updateWorkflowStatuses(_ statuses: [WorkflowStatusDTO]) {
        self.workflowStatuses = statuses.sorted { $0.position < $1.position }
        rebuildColumns()
    }
    
    /// Re-groups the provided tasks according to the current `config.groupBy`.
    public func updateTasks(_ newTasks: [TaskItemDTO]) {
        self.allTasks = newTasks
        rebuildColumns()
    }
    
    private func rebuildColumns() {
        var groups: [String: [TaskItemDTO]] = [:]
        
        // Group tasks
        for task in allTasks {
            let key = groupKey(for: task)
            groups[key, default: []].append(task)
        }
        
        // Sort tasks within columns by position
        for (key, items) in groups {
            groups[key] = items.sorted { $0.position < $1.position }
        }
        
        // Build columns list respecting columnOrder if provided
        var newColumns: [BoardColumn] = []
        
        let order = resolvedColumnOrder(fallbackGroups: groups)
        
        for key in order {
            let items = groups[key] ?? []
            let title = displayTitle(for: key)
            let limit = config.wipLimits?[key]
            
            newColumns.append(BoardColumn(id: key, title: title, items: items, wipLimit: limit))
        }

        // Append unknown group keys (e.g., unmapped status ids) to avoid "missing tasks" in UI.
        let known = Set(order)
        for key in groups.keys.sorted() where !known.contains(key) {
            let items = groups[key] ?? []
            guard !items.isEmpty else { continue }
            newColumns.append(BoardColumn(id: key, title: displayTitle(for: key), items: items, wipLimit: config.wipLimits?[key]))
        }
        
        self.columns = newColumns
    }
    
    // MARK: - Drag and Drop Handling
    
    /// Moves a task from one column to another, or reorders within the same column.
    public func moveTask(taskId: UUID, to targetColumnId: String, atIndex: Int) async {
        guard !isMoving else { return }
        
        // Find the current representation of the task
        guard let originalTask = allTasks.first(where: { $0.id == taskId }) else { return }
        let originalColumnId = groupKey(for: originalTask)

        // Only status grouping supports cross-column moves right now (BulkMoveTaskRequest targets status).
        // Other groupings can still reorder within the same column.
        if config.groupBy != .status, originalColumnId != targetColumnId {
            return
        }
        
        // Rebuild columns with optimistic update
        var updatedColumns = columns
        
        guard let sourceIndex = updatedColumns.firstIndex(where: { $0.id == originalColumnId }),
              let destIndex = updatedColumns.firstIndex(where: { $0.id == targetColumnId }) else { return }
        
        var sourceItems = updatedColumns[sourceIndex].items
        var destItems = updatedColumns[destIndex].items
        
        guard let itemIndex = sourceItems.firstIndex(where: { $0.id == taskId }) else { return }
        let movedItem = sourceItems.remove(at: itemIndex)
        
        let insertIndex = min(max(0, atIndex), destItems.count)
        
        if sourceIndex == destIndex {
            // Reordering within the same column
            sourceItems.insert(movedItem, at: insertIndex)
            updatedColumns[sourceIndex] = BoardColumn(
                id: updatedColumns[sourceIndex].id,
                title: updatedColumns[sourceIndex].title,
                items: sourceItems,
                wipLimit: updatedColumns[sourceIndex].wipLimit
            )
            destItems = sourceItems
        } else {
            // Moving across columns
            destItems.insert(movedItem, at: insertIndex)
            updatedColumns[sourceIndex] = BoardColumn(
                id: updatedColumns[sourceIndex].id,
                title: updatedColumns[sourceIndex].title,
                items: sourceItems,
                wipLimit: updatedColumns[sourceIndex].wipLimit
            )
            updatedColumns[destIndex] = BoardColumn(
                id: updatedColumns[destIndex].id,
                title: updatedColumns[destIndex].title,
                items: destItems,
                wipLimit: updatedColumns[destIndex].wipLimit
            )
        }
        
        // Calculate new LexoRank position
        let newPosition: Double
        if destItems.count == 1 {
            newPosition = 65536.0 // First item in empty column
        } else if insertIndex == 0 {
            newPosition = destItems[1].position / 2.0 // Placed at top
        } else if insertIndex == destItems.count - 1 {
            newPosition = destItems[destItems.count - 2].position + 65536.0 // Placed at bottom
        } else {
            // Placed between two items
            let prev = destItems[insertIndex - 1].position
            let next = destItems[insertIndex + 1].position
            newPosition = (prev + next) / 2.0
        }
        
        // Apply optimistic UI
        self.columns = updatedColumns
        
        // Extract what changed for the API
        var patchStatus: TaskStatus? = nil
        var patchStatusId: UUID? = nil
        // We only support patching status automatically in bulk move right now.
        // If grouped by assignee/priority, we would need to map those fields too,
        // but BulkMoveTaskRequest currently strongly types `targetStatus`.
        if config.groupBy == .status {
            if !workflowStatuses.isEmpty, let uuid = UUID(uuidString: targetColumnId) {
                patchStatusId = uuid
            } else {
                patchStatus = TaskStatus(rawValue: targetColumnId)
            }
        }
        
        let payload = BulkMoveTaskRequest(
            targetListId: nil, // Retain list
            targetStatusId: patchStatusId,
            targetStatus: patchStatus,
            moves: [TaskMoveAction(taskId: taskId, newPosition: newPosition)]
        )
        
        // Fire API
        isMoving = true
        self.error = nil
        
        do {
            let updatedDTOs = try await taskRepository.moveMultiple(payload: payload)
            
            // Merge updated DTOs back into allTasks
            for dto in updatedDTOs {
                if let idx = self.allTasks.firstIndex(where: { $0.id == dto.id }) {
                    self.allTasks[idx] = dto
                }
            }
            // Re-render
            rebuildColumns()
            
        } catch {
            self.error = error
            // Revert on failure
            rebuildColumns()
        }
        
        isMoving = false
    }
    
    // MARK: - Grouping Helpers
    
    private func groupKey(for task: TaskItemDTO) -> String {
        switch config.groupBy {
        case .status:
            if !workflowStatuses.isEmpty, let statusId = task.statusId {
                return statusId.uuidString
            }
            return task.status.rawValue
        case .priority:
            return task.priority.rawValue
        case .assignee:
            return task.assigneeId?.uuidString ?? "unassigned"
        }
    }
    
    private func defaultColumnOrder() -> [String] {
        switch config.groupBy {
        case .status:
            if !workflowStatuses.isEmpty {
                return workflowStatuses.map { $0.id.uuidString }
            }
            return TaskStatus.allCases.map { $0.rawValue }
        case .priority:
            return TaskPriority.allCases.sorted { $0.sortOrder > $1.sortOrder }.map { $0.rawValue }
        case .assignee:
            // Dynamic column generation for assignees is tricky.
            // Ideally, the server returns the unique assignees.
            // For now, extract unique UUIDs from tasks.
            var keys = Set<String>()
            for t in allTasks {
                keys.insert(t.assigneeId?.uuidString ?? "unassigned")
            }
            return Array(keys).sorted()
        }
    }
    
    private func displayTitle(for key: String) -> String {
        switch config.groupBy {
        case .status:
            if !workflowStatuses.isEmpty,
               let uuid = UUID(uuidString: key),
               let s = workflowStatuses.first(where: { $0.id == uuid }) {
                return s.name
            }
            return TaskStatus(rawValue: key)?.displayName ?? key.capitalized
        case .priority:
            return TaskPriority(rawValue: key)?.displayName ?? key.capitalized
        case .assignee:
            if key == "unassigned" { return "Unassigned" }
            return "User..." // We don't have member models mapped here directly yet
        }
    }

    private func resolvedColumnOrder(fallbackGroups: [String: [TaskItemDTO]]) -> [String] {
        guard let configured = config.columnOrder, !configured.isEmpty else {
            return defaultColumnOrder()
        }

        if config.groupBy != .status || workflowStatuses.isEmpty {
            return configured
        }

        let ids = Set(workflowStatuses.map { $0.id.uuidString })
        if configured.allSatisfy({ ids.contains($0) }) {
            return configured
        }

        // If configured uses legacy TaskStatus raw values, map to workflow ids where possible.
        let legacyToId: [String: String] = Dictionary(uniqueKeysWithValues: workflowStatuses.compactMap { s in
            guard let legacy = s.legacyStatus else { return nil }
            return (legacy, s.id.uuidString)
        })
        if configured.allSatisfy({ TaskStatus(rawValue: $0) != nil }) {
            let mapped = configured.compactMap { legacyToId[$0] }
            if !mapped.isEmpty { return mapped }
        }

        // Default to workflow order, then append any visible unknown keys.
        var base = defaultColumnOrder()
        let extras = fallbackGroups.keys.filter { !Set(base).contains($0) }.sorted()
        base.append(contentsOf: extras)
        return base
    }
}
