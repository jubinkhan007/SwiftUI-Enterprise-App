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
    
    @Published public var isSaving = false
    @Published public var error: Error?
    @Published public var isSuccess = false
    
    // Derived state for validation
    public var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private let taskRepository: TaskRepositoryProtocol
    
    public init(taskRepository: TaskRepositoryProtocol) {
        self.taskRepository = taskRepository
    }
    
    public func saveTask() async {
        guard isValid, !isSaving else { return }
        
        isSaving = true
        error = nil
        
        let payload = CreateTaskRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.isEmpty ? nil : descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            priority: priority,
            dueDate: nil,
            assigneeId: nil
        )
        
        do {
            _ = try await taskRepository.createTask(payload: payload)
            // Success handles either online remote creation or offline optimistic queueing
            isSuccess = true
        } catch {
            self.error = error
        }
        
        isSaving = false
    }
}
