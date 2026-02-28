import Foundation
import SwiftUI
import Combine
import Domain
import SharedModels
import AppNetwork

@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public private(set) var tasks: [TaskItemDTO] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public var error: Error?
    
    // Filtering & Pagination State
    @Published public var query: TaskQuery = TaskQuery()
    @Published public var filterStatus: TaskStatus? = nil {
        didSet {
            query.status = filterStatus
            resetPagination()
            Task { await fetchTasks() }
        }
    }
    @Published public var filterPriority: TaskPriority? = nil {
        didSet {
            query.priority = filterPriority
            resetPagination()
            Task { await fetchTasks() }
        }
    }
    @Published public var filterTaskType: TaskType? = nil {
        didSet {
            query.taskType = filterTaskType
            resetPagination()
            Task { await fetchTasks() }
        }
    }
    @Published public var searchQuery: String = ""
    
    // Selection state for potential bulk actions
    @Published public var selectedTaskIds: Set<UUID> = []

    // Phase 10: workflow context for current project/list scope (used by Board + TaskDetail fallbacks)
    @Published public private(set) var workflowBundle: WorkflowBundleDTO? = nil
    
    public let taskRepository: TaskRepositoryProtocol
    public let activityRepository: TaskActivityRepositoryProtocol
    public let hierarchyRepository: HierarchyRepositoryProtocol
    public let workflowRepository: WorkflowRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private var hasMorePages = true
    private var nextCursor: String? = nil
    private var isMyTasksMode = false
    
    // Range state for Calendar/Timeline
    @Published public var startDate: Date = Date().startOfMonth()
    @Published public var endDate: Date = Date().endOfMonth()
    @Published public var timelineResponse: TimelineResponseDTO? = nil
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        activityRepository: TaskActivityRepositoryProtocol,
        hierarchyRepository: HierarchyRepositoryProtocol,
        workflowRepository: WorkflowRepositoryProtocol
    ) {
        self.taskRepository = taskRepository
        self.activityRepository = activityRepository
        self.hierarchyRepository = hierarchyRepository
        self.workflowRepository = workflowRepository
        setupSearchDebounce()
    }
    
    private func setupSearchDebounce() {
        $searchQuery
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                guard let self = self else { return }
                self.query.search = searchText.isEmpty ? nil : searchText
                self.resetPagination()
                Task { await self.fetchTasks() }
            }
            .store(in: &cancellables)
    }
    
    public func fetchTasks(for viewType: DashboardViewType = .list) async {
        switch viewType {
        case .list, .board:
            await fetchStandardTasks()
        case .calendar:
            await fetchCalendarTasks()
        case .timeline:
            await fetchTimeline()
        }
    }
    
    private func fetchStandardTasks() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let response: APIResponse<[TaskItemDTO]>
            if isMyTasksMode {
                response = try await taskRepository.getAssignedTasks(query: query)
            } else {
                response = try await taskRepository.getTasks(query: query)
            }
            guard let data = response.data else {
                throw NetworkError.underlying("No task data returned")
            }

            // Cursor mode = append; fresh load (no cursor sent) = replace
            if query.cursor == nil {
                self.tasks = data
            } else {
                self.tasks.append(contentsOf: data)
            }

            // Store next cursor for subsequent "load more" calls
            self.nextCursor = response.pagination?.cursor
            self.hasMorePages = self.nextCursor != nil || (response.pagination.map { $0.page < $0.totalPages } ?? false)
            
        } catch {
            self.error = error
            if case NetworkError.unauthorized = error {
                TokenStore.shared.clear()
                NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
            }
        }

        isLoading = false
    }
    
    public func loadMoreIfNeeded(currentItem: TaskItemDTO) {
        guard hasMorePages, !isLoading, let lastItem = tasks.last, currentItem.id == lastItem.id else {
            return
        }

        if let cursor = nextCursor {
            // Keyset mode: pass cursor, keep page as-is (backend ignores page when cursor present)
            query.cursor = cursor
        } else {
            // Offset fallback
            query.page += 1
        }
        Task { await fetchTasks() }
    }
    
    public func fetchCalendarTasks() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        query.from = startDate
        query.to = endDate
        
        do {
            let response = try await taskRepository.getCalendarTasks(query: query)
            self.tasks = response.data ?? []
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func fetchTimeline() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        query.from = startDate
        query.to = endDate
        
        do {
            let response = try await taskRepository.getTimeline(query: query)
            self.timelineResponse = response.data
            self.tasks = response.data?.tasks ?? []
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func toggleSelection(for taskId: UUID) {
        if selectedTaskIds.contains(taskId) {
            selectedTaskIds.remove(taskId)
        } else {
            selectedTaskIds.insert(taskId)
        }
    }
    
    public func refresh(viewType: DashboardViewType = .list) async {
        resetPagination()
        await fetchTasks(for: viewType)
    }

    /// Update a single task in the in-memory list without a full refresh.
    /// Called after a successful inline partial-update.
    public func updateTaskLocally(_ updated: TaskItemDTO) {
        if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
            tasks[idx] = updated
        }
    }

    // MARK: - Private helpers

    /// Resets page/cursor state before a fresh fetch triggered by a filter or search change.
    /// Callers are responsible for triggering the fetch afterwards.
    private func resetPagination() {
        query.page = 1
        query.cursor = nil
        nextCursor = nil
    }
    
    public func handleSidebarSelection(_ selection: SidebarViewModel.SidebarItem?, viewType: DashboardViewType = .list) {
        // Reset query state
        resetPagination()
        query.spaceId = nil
        query.projectId = nil
        query.listId = nil
        workflowBundle = nil
        
        guard let selection = selection else {
            Task {
                await fetchTasks(for: viewType)
                await loadWorkflowForScope(selection: nil)
            }
            return
        }
        
        switch selection {
        case .allTasks, .inbox:
            isMyTasksMode = false
        case .myTasks:
            isMyTasksMode = true
        case .space(let id):
            isMyTasksMode = false
            query.spaceId = id
        case .project(let id):
            isMyTasksMode = false
            query.projectId = id
        case .list(let id):
            isMyTasksMode = false
            query.listId = id
        }
        
        Task {
            await fetchTasks(for: viewType)
            await loadWorkflowForScope(selection: selection)
        }
    }

    // MARK: - Workflow loading

    private func loadWorkflowForScope(selection: SidebarViewModel.SidebarItem?) async {
        // Only meaningful when scoped to a single project (project selection) or a single list.
        let projectId: UUID?
        switch selection {
        case .project(let id):
            projectId = id
        case .list(let listId):
            do {
                let tree = try await hierarchyRepository.getHierarchy()
                projectId = Self.projectId(for: listId, in: tree)
            } catch {
                self.error = error
                self.workflowBundle = nil
                return
            }
        default:
            projectId = nil
        }

        guard let projectId else {
            self.workflowBundle = nil
            return
        }

        do {
            self.workflowBundle = try await workflowRepository.getWorkflow(projectId: projectId)
        } catch {
            self.error = error
            self.workflowBundle = nil
        }
    }

    private static func projectId(for listId: UUID, in tree: HierarchyTreeDTO) -> UUID? {
        for space in tree.spaces {
            for project in space.projects {
                if project.lists.contains(where: { $0.id == listId }) {
                    return project.project.id
                }
            }
        }
        return nil
    }
}
