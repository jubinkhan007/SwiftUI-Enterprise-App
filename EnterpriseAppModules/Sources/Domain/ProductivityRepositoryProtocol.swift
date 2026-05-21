import Foundation
import SharedModels

public protocol ProductivityRepositoryProtocol: Sendable {
    // Drafts
    func getDraft(conversationId: UUID, parentId: UUID?) async throws -> APIResponse<MessageDraftDTO>
    func upsertDraft(conversationId: UUID, request: UpsertDraftRequest) async throws -> APIResponse<MessageDraftDTO>
    func deleteDraft(conversationId: UUID, parentId: UUID?) async throws -> APIResponse<EmptyResponse>
    func listMyDrafts() async throws -> APIResponse<[MessageDraftDTO]>

    // Scheduled messages
    func createScheduled(conversationId: UUID, request: CreateScheduledMessageRequest) async throws -> APIResponse<ScheduledMessageDTO>
    func listMyScheduled(status: String?) async throws -> APIResponse<[ScheduledMessageDTO]>
    func updateScheduled(id: UUID, request: UpdateScheduledMessageRequest) async throws -> APIResponse<ScheduledMessageDTO>
    func cancelScheduled(id: UUID) async throws -> APIResponse<ScheduledMessageDTO>
    func sendNowScheduled(id: UUID) async throws -> APIResponse<ScheduledMessageDTO>

    // Templates
    func listTemplates(scope: String?) async throws -> APIResponse<[MessageTemplateDTO]>
    func createTemplate(_ request: CreateTemplateRequest) async throws -> APIResponse<MessageTemplateDTO>
    func updateTemplate(id: UUID, request: UpdateTemplateRequest) async throws -> APIResponse<MessageTemplateDTO>
    func deleteTemplate(id: UUID) async throws -> APIResponse<EmptyResponse>
    func renderTemplate(id: UUID, request: RenderTemplateRequest) async throws -> APIResponse<RenderedTemplateDTO>

    // Reminders
    func listReminders(status: String?) async throws -> APIResponse<[ReminderDTO]>
    func createReminder(_ request: CreateReminderRequest) async throws -> APIResponse<ReminderDTO>
    func createReminderForMessage(messageId: UUID, request: CreateMessageReminderRequest) async throws -> APIResponse<ReminderDTO>
    func updateReminder(id: UUID, request: UpdateReminderRequest) async throws -> APIResponse<ReminderDTO>
    func snoozeReminder(id: UUID, minutes: Int) async throws -> APIResponse<ReminderDTO>
    func dismissReminder(id: UUID) async throws -> APIResponse<ReminderDTO>
    func deleteReminder(id: UUID) async throws -> APIResponse<EmptyResponse>
}
