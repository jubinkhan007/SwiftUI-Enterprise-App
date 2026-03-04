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
    @Published public private(set) var attachmentsLoadError: Error?
    
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
    @Published public private(set) var downloadingAttachmentId: UUID? = nil
    @Published public private(set) var orgMembers: [OrganizationMemberDTO] = []
    @Published public private(set) var isLoadingOrgMembers = false
    @Published public private(set) var orgMembersLoadError: Error?

    /// Mention IDs accumulated as the user inserts @-suggestions. Sent with the comment
    /// so the body can contain plain `@Full Name` without embedded UUIDs.
    private var pendingMentionIds: [UUID] = []
    
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

    /// Refreshes the task from the server (useful to avoid version conflicts when saving).
    public func fetchTask() async {
        guard !isLoadingTask else { return }
        isLoadingTask = true
        defer { isLoadingTask = false }

        let previousTask = task
        do {
            let endpoint = TaskEndpoint.getTask(id: task.id, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
            guard let updated = response.data else { return }

            self.task = updated

            // Only overwrite form state if the user hasn't diverged from the original values yet.
            if editTitle == previousTask.title { editTitle = updated.title }
            if editDescription == (previousTask.description ?? "") { editDescription = updated.description ?? "" }
            if editPriority == previousTask.priority { editPriority = updated.priority }
            if workflowStatuses.isEmpty {
                if editStatus == previousTask.status { editStatus = updated.status }
            } else {
                if editStatusId == previousTask.statusId { editStatusId = updated.statusId }
            }
        } catch {
            self.error = error
        }
    }

    public func fetchAttachments() async {
        if isLoadingAttachments {
            pendingAttachmentsRefresh = true
            return
        }
        isLoadingAttachments = true
        pendingAttachmentsRefresh = false
        attachmentsLoadError = nil
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
            attachmentsLoadError = error
            self.error = error
        }
    }

    public func addPendingMention(userId: UUID) {
        if !pendingMentionIds.contains(userId) {
            pendingMentionIds.append(userId)
        }
    }

    public func uploadJPEG(_ data: Data, filename: String = "image.jpg") async {
        await uploadRaw(data: data, filename: filename, mimeType: "image/jpeg")
    }

    /// Upload any supported file type selected via the document picker.
    public func uploadFile(url: URL) async {
        guard !isUploadingAttachment else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let maxBytes = 24 * 1024 * 1024
            guard data.count <= maxBytes else {
                self.error = NSError(
                    domain: "TaskDetailViewModel",
                    code: 413,
                    userInfo: [NSLocalizedDescriptionKey: "File is too large to upload (max 25 MB)."]
                )
                return
            }
            let filename = url.lastPathComponent
            let mimeType = Self.mimeType(for: url)
            await uploadRaw(data: data, filename: filename, mimeType: mimeType)
        } catch {
            self.error = error
        }
    }

    private func uploadRaw(data: Data, filename: String, mimeType: String) async {
        guard !isUploadingAttachment else { return }
        isUploadingAttachment = true
        defer { isUploadingAttachment = false }
        do {
            _ = try await attachmentRepository.upload(taskId: task.id, filename: filename, data: data, mimeType: mimeType)
            await fetchAttachments()
        } catch {
            self.error = error
        }
    }

    /// Download an attachment to a temp file and return its local URL for preview.
    public func downloadAttachment(_ attachment: AttachmentDTO) async -> URL? {
        guard downloadingAttachmentId == nil else { return nil }
        downloadingAttachmentId = attachment.id
        defer { downloadingAttachmentId = nil }
        do {
            let data = try await attachmentRepository.download(attachmentId: attachment.id)
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(attachment.filename)
            try data.write(to: tmp, options: [.atomic])
            return tmp
        } catch {
            self.error = error
            return nil
        }
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png":        return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "pdf":        return "application/pdf"
        case "txt":        return "text/plain"
        case "csv":        return "text/csv"
        case "json":       return "application/json"
        case "zip":        return "application/zip"
        default:           return "application/octet-stream"
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

    public func presentErrorDeferred(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.error = error
        }
    }

    public func presentErrorDeferred(message: String) {
        presentErrorDeferred(
            NSError(
                domain: "TaskDetailViewModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        )
    }
    
    @discardableResult
    public func saveChanges() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
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

            NotificationCenter.default.post(name: .taskDidUpdate, object: updatedTask)
            
            await fetchActivities() // Refresh activity log

            return true
        } catch NetworkError.serverError(let statusCode, _) where statusCode == 409 {
            self.hasConflict = true
            self.error = NetworkError.underlying("This task was modified by someone else. Please refresh and try again.")
            return false
        } catch {
            self.error = error
            return false
        }
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
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubmittingComment else { return }

        isSubmittingComment = true
        let payload = CreateCommentRequest(
            content: trimmed,
            mentionedUserIds: pendingMentionIds.isEmpty ? nil : pendingMentionIds
        )

        do {
            let newActivity = try await activityRepository.createComment(taskId: task.id, payload: payload)
            self.activities.insert(newActivity, at: 0)
            self.newCommentText = ""
            self.pendingMentionIds = []
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
