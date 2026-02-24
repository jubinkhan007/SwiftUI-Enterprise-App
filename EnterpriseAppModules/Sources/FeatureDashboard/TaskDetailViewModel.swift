import Foundation
import SwiftUI
import Domain
import SharedModels
import AppNetwork

@MainActor
public final class TaskDetailViewModel: ObservableObject {
    @Published public private(set) var task: TaskItemDTO
    @Published public private(set) var activities: [TaskActivityDTO] = []
    
    @Published public var isLoadingTask = false
    @Published public var isLoadingActivities = false
    @Published public var isSaving = false
    @Published public var error: Error?
    
    // Form State (for editing)
    @Published public var editTitle: String
    @Published public var editDescription: String
    @Published public var editStatus: TaskStatus
    @Published public var editPriority: TaskPriority
    
    // Conflict State
    @Published public var hasConflict = false
    
    // Comment State
    @Published public var newCommentText = ""
    @Published public var isSubmittingComment = false
    
    private let taskRepository: TaskRepositoryProtocol
    private let activityRepository: TaskActivityRepositoryProtocol
    
    public init(
        task: TaskItemDTO,
        taskRepository: TaskRepositoryProtocol,
        activityRepository: TaskActivityRepositoryProtocol
    ) {
        self.task = task
        self.taskRepository = taskRepository
        self.activityRepository = activityRepository
        
        self.editTitle = task.title
        self.editDescription = task.description ?? ""
        self.editStatus = task.status
        self.editPriority = task.priority
    }
    
    public func fetchActivities() async {
        guard !isLoadingActivities else { return }
        isLoadingActivities = true
        
        do {
            let response = try await activityRepository.getActivities(taskId: task.id)
            if let data = response.data {
                self.activities = data
            }
        } catch {
            self.error = error
        }
        
        isLoadingActivities = false
    }
    
    public func saveChanges() async {
        guard !isSaving else { return }
        isSaving = true
        error = nil
        hasConflict = false
        
        let payload = UpdateTaskRequest(
            title: editTitle != task.title ? editTitle : nil,
            description: editDescription != (task.description ?? "") ? editDescription : nil,
            status: editStatus != task.status ? editStatus : nil,
            priority: editPriority != task.priority ? editPriority : nil,
            dueDate: nil,
            assigneeId: nil,
            expectedVersion: task.version
        )
        
        do {
            let updatedTask = try await taskRepository.updateTask(id: task.id, payload: payload)
            self.task = updatedTask
            // Update local fields to match server
            self.editTitle = updatedTask.title
            self.editDescription = updatedTask.description ?? ""
            self.editStatus = updatedTask.status
            self.editPriority = updatedTask.priority
            
            await fetchActivities() // Refresh activity log
            
        } catch NetworkError.serverError(let statusCode, _) where statusCode == 409 {
            self.hasConflict = true
            self.error = NetworkError.underlying("This task was modified by someone else. Please refresh and try again.")
        } catch {
            self.error = error
        }
        
        isSaving = false
    }
    
    public func submitComment() async {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSubmittingComment else { return }
        
        isSubmittingComment = true
        let payload = CreateCommentRequest(content: newCommentText)
        
        do {
            let newActivity = try await activityRepository.createComment(taskId: task.id, payload: payload)
            self.activities.insert(newActivity, at: 0) // Prepend new comment optimistically
            self.newCommentText = ""
        } catch {
            self.error = error
        }
        
        isSubmittingComment = false
    }
    
    public func refreshTask() async {
        // Needs a fetch single task method, but if we don't have it, we could rely on Dashboard Refresh.
        // Or we could implement it on TaskRepository.
    }
}
