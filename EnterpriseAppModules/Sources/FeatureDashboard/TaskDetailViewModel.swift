import Foundation
import SwiftUI
import Domain
import SharedModels
import AppNetwork

@MainActor
public final class TaskDetailViewModel: ObservableObject {
    @Published public private(set) var task: TaskItemDTO
    @Published public private(set) var activities: [TaskActivityDTO] = []
    @Published public private(set) var workflowStatuses: [WorkflowStatusDTO] = []
    @Published public private(set) var workflowProjectId: UUID? = nil
    @Published public private(set) var attachments: [AttachmentDTO] = []
    
    @Published public var isLoadingTask = false
    @Published public var isLoadingActivities = false
    @Published public var isLoadingWorkflow = false
    @Published public var isLoadingAttachments = false
    @Published public var isSaving = false
    @Published public var error: Error?
    
    // Form State (for editing)
    @Published public var editTitle: String
    @Published public var editDescription: String
    @Published public var editStatus: TaskStatus
    @Published public var editStatusId: UUID?
    @Published public var editPriority: TaskPriority
    
    // Conflict State
    @Published public var hasConflict = false
    
    // Comment State
    @Published public var newCommentText = ""
    @Published public var isSubmittingComment = false
    @Published public var isUploadingAttachment = false
    @Published public private(set) var orgMembers: [OrganizationMemberDTO] = []
    @Published public private(set) var isLoadingOrgMembers = false
    @Published public private(set) var orgMembersLoadError: Error?
    
    private let taskRepository: TaskRepositoryProtocol
    private let activityRepository: TaskActivityRepositoryProtocol
    private let hierarchyRepository: HierarchyRepositoryProtocol
    private let workflowRepository: WorkflowRepositoryProtocol
    private let attachmentRepository: AttachmentRepositoryProtocol
    private var realtimeProvider: RealTimeProvider? = nil
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration
    private var pendingAttachmentsRefresh = false
    
    public init(
        task: TaskItemDTO,
        taskRepository: TaskRepositoryProtocol,
        activityRepository: TaskActivityRepositoryProtocol,
        hierarchyRepository: HierarchyRepositoryProtocol,
        workflowRepository: WorkflowRepositoryProtocol,
        attachmentRepository: AttachmentRepositoryProtocol,
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .localVapor
    ) {
        self.task = task
        self.taskRepository = taskRepository
        self.activityRepository = activityRepository
        self.hierarchyRepository = hierarchyRepository
        self.workflowRepository = workflowRepository
        self.attachmentRepository = attachmentRepository
        self.apiClient = apiClient
        self.apiConfiguration = configuration
        
        self.editTitle = task.title
        self.editDescription = task.description ?? ""
        self.editStatus = task.status
        self.editStatusId = task.statusId
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

    public func fetchAttachments() async {
        if isLoadingAttachments {
            pendingAttachmentsRefresh = true
            return
        }
        isLoadingAttachments = true
        pendingAttachmentsRefresh = false
        defer {
            isLoadingAttachments = false
            if pendingAttachmentsRefresh {
                pendingAttachmentsRefresh = false
                Task { await self.fetchAttachments() }
            }
        }

        do {
            self.attachments = try await attachmentRepository.list(taskId: task.id)
        } catch {
            self.error = error
        }
    }

    public func uploadJPEG(_ data: Data, filename: String = "image.jpg") async {
        guard !isUploadingAttachment else { return }
        isUploadingAttachment = true
        defer { isUploadingAttachment = false }

        do {
            _ = try await attachmentRepository.upload(taskId: task.id, filename: filename, data: data, mimeType: "image/jpeg")
            await fetchAttachments()
        } catch {
            self.error = error
        }
    }

    public func loadOrgMembersIfNeeded() async {
        guard orgMembers.isEmpty else { return }
        guard !isLoadingOrgMembers else { return }
        guard let orgId = OrganizationContext.shared.orgId else { return }
        isLoadingOrgMembers = true
        orgMembersLoadError = nil
        defer { isLoadingOrgMembers = false }
        do {
            let endpoint = OrganizationEndpoint.listMembers(orgId: orgId, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[OrganizationMemberDTO]>.self)
            self.orgMembers = response.data ?? []
        } catch {
            orgMembersLoadError = error
        }
    }

    public func reloadOrgMembers() async {
        orgMembers = []
        await loadOrgMembersIfNeeded()
    }
    
    public func saveChanges() async {
        guard !isSaving else { return }
        isSaving = true
        error = nil
        hasConflict = false

        let statusIdDelta: UUID? = {
            guard !workflowStatuses.isEmpty, let selected = editStatusId else { return nil }
            return selected != task.statusId ? selected : nil
        }()

        let payload = UpdateTaskRequest(
            title: editTitle != task.title ? editTitle : nil,
            description: editDescription != (task.description ?? "") ? editDescription : nil,
            statusId: statusIdDelta,
            status: (statusIdDelta == nil && editStatus != task.status) ? editStatus : nil,
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
            self.editStatusId = updatedTask.statusId
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

    public func loadWorkflowIfNeeded() async {
        guard !isLoadingWorkflow else { return }
        guard workflowStatuses.isEmpty else { return }
        guard let listId = task.listId else { return }

        isLoadingWorkflow = true
        defer { isLoadingWorkflow = false }

        do {
            let tree = try await hierarchyRepository.getHierarchy()
            guard let projectId = Self.projectId(for: listId, in: tree) else { return }
            self.workflowProjectId = projectId

            let bundle = try await workflowRepository.getWorkflow(projectId: projectId)
            self.workflowStatuses = bundle.statuses.sorted { $0.position < $1.position }

            // Prefer the task's canonical statusId; fall back to legacy mapping; otherwise default.
            if let current = task.statusId, workflowStatuses.contains(where: { $0.id == current }) {
                self.editStatusId = current
            } else if let mapped = workflowStatuses.first(where: { $0.legacyStatus == task.status.rawValue }) {
                self.editStatusId = mapped.id
            } else if let def = workflowStatuses.first(where: { $0.isDefault }) {
                self.editStatusId = def.id
            }
        } catch {
            self.error = error
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

    public func startRealtime() async {
        guard realtimeProvider == nil else { return }
        guard let orgId = OrganizationContext.shared.orgId else { return }

        let provider = RealTimeProvider()
        provider.onEvent = { [weak self] event in
            guard let self else { return }
            // Only react to events for this task.
            if event.payload?["taskId"] == self.task.id.uuidString {
                Task {
                    if event.type == "comment.created" {
                        await self.fetchActivities()
                    } else if event.type == "attachment.created" {
                        await self.fetchAttachments()
                    }
                }
            }
        }
        realtimeProvider = provider

        await provider.connect(orgId: orgId)
        if let listId = task.listId {
            await provider.subscribe(channels: ["list:\(listId.uuidString)"])
        }
        if let projectId = workflowProjectId {
            await provider.subscribe(channels: ["project:\(projectId.uuidString)"])
        }
    }

    public func stopRealtime() {
        realtimeProvider?.disconnect()
        realtimeProvider = nil
    }
}
