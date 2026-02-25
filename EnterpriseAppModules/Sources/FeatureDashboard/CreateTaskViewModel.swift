import Foundation
import SwiftUI
import Domain
import SharedModels

@MainActor
public final class CreateTaskViewModel: ObservableObject {
    @Published public var title: String = ""
    @Published public var descriptionText: String = ""
    @Published public var status: TaskStatus = .todo
    @Published public var priority: TaskPriority = .medium
    
    @Published public var startDate: Date? = nil
    @Published public var dueDate: Date? = nil
    @Published public var assigneeIdText: String = ""
    @Published public var listId: UUID? = nil
    
    @Published public var showStartDatePicker = false
    @Published public var showDueDatePicker = false
    
    @Published public var isSaving = false
    @Published public var error: Error?
    @Published public var isSuccess = false
    
    // Derived state for validation
    public var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private let taskRepository: TaskRepositoryProtocol
    
    public init(taskRepository: TaskRepositoryProtocol, listId: UUID? = nil) {
        self.taskRepository = taskRepository
        self.listId = listId
    }
    
    public func saveTask() async {
        guard isValid, !isSaving else { return }
        
        isSaving = true
        error = nil
        
        let assigneeId = UUID(uuidString: assigneeIdText.trimmingCharacters(in: .whitespacesAndNewlines))
        
        let payload = CreateTaskRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.isEmpty ? nil : descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            priority: priority,
            startDate: startDate,
            dueDate: dueDate,
            assigneeId: assigneeId,
            listId: listId
        )
        
        do {
            _ = try await taskRepository.createTask(payload: payload)
            isSuccess = true
        } catch {
            self.error = error
        }
        
        isSaving = false
    }
}
