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
            query.page = 1
            Task { await fetchTasks() }
        }
    }
    @Published public var filterPriority: TaskPriority? = nil {
        didSet {
            query.priority = filterPriority
            query.page = 1
            Task { await fetchTasks() }
        }
    }
    @Published public var searchQuery: String = ""
    
    // Selection state for potential bulk actions
    @Published public var selectedTaskIds: Set<UUID> = []
    
    public let taskRepository: TaskRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private var hasMorePages = true
    
    public init(taskRepository: TaskRepositoryProtocol) {
        self.taskRepository = taskRepository
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
                self.query.page = 1
                Task { await self.fetchTasks() }
            }
            .store(in: &cancellables)
    }
    
    public func fetchTasks() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let response = try await taskRepository.getTasks(query: query)
            guard let data = response.data else {
                throw NetworkError.underlying("No task data returned")
            }
            
            if query.page == 1 {
                self.tasks = data
            } else {
                self.tasks.append(contentsOf: data)
            }
            
            if let meta = response.pagination {
                self.hasMorePages = meta.page < meta.totalPages
            } else {
                self.hasMorePages = false
            }
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    public func loadMoreIfNeeded(currentItem: TaskItemDTO) {
        guard hasMorePages, !isLoading, let lastItem = tasks.last, currentItem.id == lastItem.id else {
            return
        }
        
        query.page += 1
        Task {
            await fetchTasks()
        }
    }
    
    public func toggleSelection(for taskId: UUID) {
        if selectedTaskIds.contains(taskId) {
            selectedTaskIds.remove(taskId)
        } else {
            selectedTaskIds.insert(taskId)
        }
    }
    
    public func refresh() async {
        query.page = 1
        await fetchTasks()
    }
}
