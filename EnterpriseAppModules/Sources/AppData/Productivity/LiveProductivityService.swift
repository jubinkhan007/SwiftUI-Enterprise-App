import Foundation
import Domain
import AppNetwork
import SharedModels

public final class LiveProductivityService: ProductivityRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration

    public init(apiClient: APIClientProtocol, configuration: APIConfiguration = .current) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    // MARK: Drafts

    public func getDraft(conversationId: UUID, parentId: UUID?) async throws -> APIResponse<MessageDraftDTO> {
        let ep = ProductivityEndpoint.getDraft(conversationId: conversationId, parentId: parentId, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MessageDraftDTO>.self)
    }

    public func upsertDraft(conversationId: UUID, request: UpsertDraftRequest) async throws -> APIResponse<MessageDraftDTO> {
        let ep = ProductivityEndpoint.upsertDraft(conversationId: conversationId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MessageDraftDTO>.self)
    }

    public func deleteDraft(conversationId: UUID, parentId: UUID?) async throws -> APIResponse<EmptyResponse> {
        let ep = ProductivityEndpoint.deleteDraft(conversationId: conversationId, parentId: parentId, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<EmptyResponse>.self)
    }

    public func listMyDrafts() async throws -> APIResponse<[MessageDraftDTO]> {
        let ep = ProductivityEndpoint.listMyDrafts(configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<[MessageDraftDTO]>.self)
    }

    // MARK: Scheduled

    public func createScheduled(conversationId: UUID, request: CreateScheduledMessageRequest) async throws -> APIResponse<ScheduledMessageDTO> {
        let ep = ProductivityEndpoint.createScheduled(conversationId: conversationId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<ScheduledMessageDTO>.self)
    }

    public func listMyScheduled(status: String?) async throws -> APIResponse<[ScheduledMessageDTO]> {
        let ep = ProductivityEndpoint.listMyScheduled(status: status, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<[ScheduledMessageDTO]>.self)
    }

    public func updateScheduled(id: UUID, request: UpdateScheduledMessageRequest) async throws -> APIResponse<ScheduledMessageDTO> {
        let ep = ProductivityEndpoint.updateScheduled(id: id, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<ScheduledMessageDTO>.self)
    }

    public func cancelScheduled(id: UUID) async throws -> APIResponse<ScheduledMessageDTO> {
        let ep = ProductivityEndpoint.cancelScheduled(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<ScheduledMessageDTO>.self)
    }

    public func sendNowScheduled(id: UUID) async throws -> APIResponse<ScheduledMessageDTO> {
        let ep = ProductivityEndpoint.sendNowScheduled(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<ScheduledMessageDTO>.self)
    }

    // MARK: Templates

    public func listTemplates(scope: String?) async throws -> APIResponse<[MessageTemplateDTO]> {
        let ep = ProductivityEndpoint.listTemplates(scope: scope, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<[MessageTemplateDTO]>.self)
    }

    public func createTemplate(_ request: CreateTemplateRequest) async throws -> APIResponse<MessageTemplateDTO> {
        let ep = ProductivityEndpoint.createTemplate(payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MessageTemplateDTO>.self)
    }

    public func updateTemplate(id: UUID, request: UpdateTemplateRequest) async throws -> APIResponse<MessageTemplateDTO> {
        let ep = ProductivityEndpoint.updateTemplate(id: id, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MessageTemplateDTO>.self)
    }

    public func deleteTemplate(id: UUID) async throws -> APIResponse<EmptyResponse> {
        let ep = ProductivityEndpoint.deleteTemplate(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<EmptyResponse>.self)
    }

    public func renderTemplate(id: UUID, request: RenderTemplateRequest) async throws -> APIResponse<RenderedTemplateDTO> {
        let ep = ProductivityEndpoint.renderTemplate(id: id, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<RenderedTemplateDTO>.self)
    }

    // MARK: Reminders

    public func listReminders(status: String?) async throws -> APIResponse<[ReminderDTO]> {
        let ep = ProductivityEndpoint.listReminders(status: status, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<[ReminderDTO]>.self)
    }

    public func createReminder(_ request: CreateReminderRequest) async throws -> APIResponse<ReminderDTO> {
        let ep = ProductivityEndpoint.createReminder(payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<ReminderDTO>.self)
    }

    public func createReminderForMessage(messageId: UUID, request: CreateMessageReminderRequest) async throws -> APIResponse<ReminderDTO> {
        let ep = ProductivityEndpoint.createReminderForMessage(messageId: messageId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<ReminderDTO>.self)
    }

    public func updateReminder(id: UUID, request: UpdateReminderRequest) async throws -> APIResponse<ReminderDTO> {
        let ep = ProductivityEndpoint.updateReminder(id: id, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<ReminderDTO>.self)
    }

    public func snoozeReminder(id: UUID, minutes: Int) async throws -> APIResponse<ReminderDTO> {
        let ep = ProductivityEndpoint.snoozeReminder(id: id, payload: SnoozeReminderRequest(minutes: minutes), configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<ReminderDTO>.self)
    }

    public func dismissReminder(id: UUID) async throws -> APIResponse<ReminderDTO> {
        let ep = ProductivityEndpoint.dismissReminder(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<ReminderDTO>.self)
    }

    public func deleteReminder(id: UUID) async throws -> APIResponse<EmptyResponse> {
        let ep = ProductivityEndpoint.deleteReminder(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<EmptyResponse>.self)
    }
}
