import Foundation
import SwiftData
import SharedModels

public protocol TaskLocalStoreProtocol: Sendable {
    func getTasks(query: TaskQuery) async throws -> [LocalTaskItem]
    func getTask(id: UUID) async throws -> LocalTaskItem?
    func save(tasks: [LocalTaskItem]) async throws
    func save(task: LocalTaskItem) async throws
    func delete(id: UUID) async throws
    func getPendingSyncTasks() async throws -> [LocalTaskItem]
}

/// Manages offline persistence of tasks using SwiftData.
public final class TaskLocalStore: TaskLocalStoreProtocol {
    private let modelContainer: ModelContainer
    
    public init(container: ModelContainer) {
        self.modelContainer = container
    }
    
    @MainActor
    public func getTasks(query: TaskQuery) async throws -> [LocalTaskItem] {
        let context = modelContainer.mainContext
        var fetchDescriptor = FetchDescriptor<LocalTaskItem>(
            predicate: #Predicate { $0.isDeletedLocally == false },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        // Note: Complex filtering (status/priority/search) can be added to the predicate 
        // or filtered in-memory depending on dataset size.
        let allTasks = try context.fetch(fetchDescriptor)
        
        // In-memory filtering for simplicity in this version
        var filtered = allTasks
        if let status = query.status {
            filtered = filtered.filter { $0.statusRawValue == status.rawValue }
        }
        if let priority = query.priority {
            filtered = filtered.filter { $0.priorityRawValue == priority.rawValue }
        }
        if let search = query.search, !search.isEmpty {
            filtered = filtered.filter { $0.title.localizedCaseInsensitiveContains(search) }
        }
        
        let startIndex = (query.page - 1) * query.perPage
        if startIndex >= filtered.count { return [] }
        let endIndex = min(startIndex + query.perPage, filtered.count)
        
        return Array(filtered[startIndex..<endIndex])
    }
    
    @MainActor
    public func getTask(id: UUID) async throws -> LocalTaskItem? {
        let context = modelContainer.mainContext
        var fetchDescriptor = FetchDescriptor<LocalTaskItem>(predicate: #Predicate { $0.id == id })
        fetchDescriptor.fetchLimit = 1
        return try context.fetch(fetchDescriptor).first
    }
    
    @MainActor
    public func save(tasks: [LocalTaskItem]) async throws {
        let context = modelContainer.mainContext
        for task in tasks {
            context.insert(task)
        }
        try context.save()
    }
    
    @MainActor
    public func save(task: LocalTaskItem) async throws {
        let context = modelContainer.mainContext
        context.insert(task)
        try context.save()
    }
    
    @MainActor
    public func delete(id: UUID) async throws {
        let context = modelContainer.mainContext
        if let task = try await getTask(id: id) {
            context.delete(task)
            try context.save()
        }
    }
    
    @MainActor
    public func getPendingSyncTasks() async throws -> [LocalTaskItem] {
        let context = modelContainer.mainContext
        let fetchDescriptor = FetchDescriptor<LocalTaskItem>(
            predicate: #Predicate { $0.isPendingSync == true }
        )
        return try context.fetch(fetchDescriptor)
    }
}
