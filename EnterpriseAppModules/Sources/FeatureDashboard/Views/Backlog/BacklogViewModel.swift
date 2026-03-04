import Foundation
import Domain
import SharedModels

@MainActor
public final class BacklogViewModel: ObservableObject {
    @Published public private(set) var backlog: [TaskItemDTO] = []
    @Published public private(set) var sprints: [SprintDTO] = []
    @Published public private(set) var sprintIssues: [UUID: [TaskItemDTO]] = [:]
    @Published public private(set) var isLoading: Bool = false
    @Published public var error: Error?

    private let projectId: UUID
    private let taskRepository: TaskRepositoryProtocol
    private let analyticsRepository: AnalyticsRepositoryProtocol

    public init(
        projectId: UUID,
        taskRepository: TaskRepositoryProtocol,
        analyticsRepository: AnalyticsRepositoryProtocol
    ) {
        self.projectId = projectId
        self.taskRepository = taskRepository
        self.analyticsRepository = analyticsRepository
    }

    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            async let sprintsTask = analyticsRepository.listSprints(projectId: projectId)
            async let backlogTask = taskRepository.getBacklog(projectId: projectId)
            let (sprints, backlog) = try await (sprintsTask, backlogTask)

            self.sprints = sprints.sorted(by: Self.sortSprints)
            self.backlog = backlog.sorted(by: Self.sortBacklogTasks)

            var issuesBySprint: [UUID: [TaskItemDTO]] = [:]
            try await withThrowingTaskGroup(of: (UUID, [TaskItemDTO]).self) { group in
                for sprint in sprints {
                    group.addTask { [taskRepository] in
                        let issues = try await taskRepository.getSprintIssues(sprintId: sprint.id)
                        return (sprint.id, issues.sorted(by: Self.sortSprintTasks))
                    }
                }
                for try await (id, issues) in group {
                    issuesBySprint[id] = issues
                }
            }
            self.sprintIssues = issuesBySprint
        } catch {
            self.error = error
        }

        isLoading = false
    }

    public func moveBacklog(fromOffsets: IndexSet, toOffset: Int) {
        var updated = backlog
        updated.move(fromOffsets: fromOffsets, toOffset: toOffset)
        guard let movedIndex = Self.movedIndex(fromOffsets: fromOffsets, toOffset: toOffset, count: updated.count) else {
            backlog = updated
            return
        }

        let moved = updated[movedIndex]
        let newPos = Self.computeNewPosition(
            before: movedIndex > 0 ? Self.backlogPosition(for: updated[movedIndex - 1]) : nil,
            after: movedIndex + 1 < updated.count ? Self.backlogPosition(for: updated[movedIndex + 1]) : nil
        )

        backlog = updated
        Task {
            do {
                let updatedTask = try await taskRepository.partialUpdateTask(
                    id: moved.id,
                    payload: UpdateTaskRequest(backlogPosition: newPos)
                )
                await replaceTask(updatedTask)
            } catch {
                self.error = error
            }
        }
    }

    public func moveSprintIssues(sprintId: UUID, fromOffsets: IndexSet, toOffset: Int) {
        var arr = sprintIssues[sprintId] ?? []
        arr.move(fromOffsets: fromOffsets, toOffset: toOffset)
        guard let movedIndex = Self.movedIndex(fromOffsets: fromOffsets, toOffset: toOffset, count: arr.count) else {
            sprintIssues[sprintId] = arr
            return
        }

        let moved = arr[movedIndex]
        let newPos = Self.computeNewPosition(
            before: movedIndex > 0 ? Self.sprintPosition(for: arr[movedIndex - 1]) : nil,
            after: movedIndex + 1 < arr.count ? Self.sprintPosition(for: arr[movedIndex + 1]) : nil
        )

        sprintIssues[sprintId] = arr
        Task {
            do {
                let updatedTask = try await taskRepository.partialUpdateTask(
                    id: moved.id,
                    payload: UpdateTaskRequest(sprintPosition: newPos)
                )
                await replaceTask(updatedTask)
            } catch {
                self.error = error
            }
        }
    }

    public func handleDrop(itemIds: [String], toSprintId: UUID?) async -> Bool {
        var didMove = false
        for idStr in itemIds {
            guard let taskId = UUID(uuidString: idStr) else { continue }
            do {
                if let toSprintId {
                    let pos = Self.computeAppendPosition(for: sprintIssues[toSprintId], key: \.sprintPosition, fallback: \.position)
                    let updated = try await taskRepository.partialUpdateTask(
                        id: taskId,
                        payload: UpdateTaskRequest(sprintId: toSprintId, sprintPosition: pos)
                    )
                    await applyCrossSectionMove(updated, toSprintId: toSprintId)
                } else {
                    let pos = Self.computeAppendPosition(for: backlog, key: \.backlogPosition, fallback: \.position)
                    let updated = try await taskRepository.partialUpdateTask(
                        id: taskId,
                        payload: UpdateTaskRequest(backlogPosition: pos)
                    )
                    await applyCrossSectionMove(updated, toSprintId: nil)
                }
                didMove = true
            } catch {
                self.error = error
            }
        }
        return didMove
    }

    public func pointsForSprint(_ sprintId: UUID) -> (assigned: Double, capacity: Double?) {
        let issues = sprintIssues[sprintId] ?? []
        let assigned = issues.reduce(0.0) { $0 + Double($1.storyPoints ?? 0) }
        let cap = sprints.first(where: { $0.id == sprintId })?.capacity
        return (assigned, cap)
    }

    // MARK: - Local state updates

    private func replaceTask(_ updated: TaskItemDTO) async {
        if let idx = backlog.firstIndex(where: { $0.id == updated.id }) {
            backlog[idx] = updated
        }
        for (sid, issues) in sprintIssues {
            if let idx = issues.firstIndex(where: { $0.id == updated.id }) {
                var copy = issues
                copy[idx] = updated
                sprintIssues[sid] = copy
                break
            }
        }
    }

    private func applyCrossSectionMove(_ updated: TaskItemDTO, toSprintId: UUID?) async {
        // Remove from backlog
        backlog.removeAll { $0.id == updated.id }

        // Remove from any sprint
        for (sid, issues) in sprintIssues {
            if issues.contains(where: { $0.id == updated.id }) {
                sprintIssues[sid] = issues.filter { $0.id != updated.id }
            }
        }

        if let toSprintId {
            var arr = sprintIssues[toSprintId] ?? []
            arr.append(updated)
            arr.sort(by: Self.sortSprintTasks)
            sprintIssues[toSprintId] = arr
        } else {
            backlog.append(updated)
            backlog.sort(by: Self.sortBacklogTasks)
        }
    }

    // MARK: - Sorting / Positioning

    nonisolated private static func sortSprints(_ a: SprintDTO, _ b: SprintDTO) -> Bool {
        func rank(_ s: SprintStatus) -> Int {
            switch s {
            case .active: return 0
            case .planned: return 1
            case .closed, .completed: return 2
            }
        }
        if rank(a.status) != rank(b.status) {
            return rank(a.status) < rank(b.status)
        }
        if a.startDate != b.startDate { return a.startDate < b.startDate }
        return a.name < b.name
    }

    nonisolated private static func sortBacklogTasks(_ a: TaskItemDTO, _ b: TaskItemDTO) -> Bool {
        backlogPosition(for: a) < backlogPosition(for: b)
    }

    nonisolated private static func sortSprintTasks(_ a: TaskItemDTO, _ b: TaskItemDTO) -> Bool {
        sprintPosition(for: a) < sprintPosition(for: b)
    }

    nonisolated private static func backlogPosition(for task: TaskItemDTO) -> Double {
        task.backlogPosition ?? task.position
    }

    nonisolated private static func sprintPosition(for task: TaskItemDTO) -> Double {
        task.sprintPosition ?? task.position
    }

    nonisolated private static func computeAppendPosition<T>(
        for items: [T]?,
        key: KeyPath<T, Double?>,
        fallback: KeyPath<T, Double>
    ) -> Double {
        let maxPos = (items ?? []).map { $0[keyPath: key] ?? $0[keyPath: fallback] }.max() ?? 0
        return maxPos + 1000
    }

    nonisolated private static func computeNewPosition(before: Double?, after: Double?) -> Double {
        switch (before, after) {
        case (nil, nil):
            return 1000
        case (nil, let a?):
            return a / 2
        case (let b?, nil):
            return b + 1000
        case (let b?, let a?):
            let mid = (a + b) / 2
            if mid == a || mid == b {
                return b + 0.0001
            }
            return mid
        }
    }

    nonisolated private static func movedIndex(fromOffsets: IndexSet, toOffset: Int, count: Int) -> Int? {
        guard let from = fromOffsets.first else { return nil }
        let dest = toOffset > from ? toOffset - 1 : toOffset
        guard dest >= 0, dest < count else { return nil }
        return dest
    }
}
