import Foundation
import SharedModels

public enum ProductivityEndpoint {
    // Drafts
    case getDraft(conversationId: UUID, parentId: UUID?, configuration: APIConfiguration)
    case upsertDraft(conversationId: UUID, payload: UpsertDraftRequest, configuration: APIConfiguration)
    case deleteDraft(conversationId: UUID, parentId: UUID?, configuration: APIConfiguration)
    case listMyDrafts(configuration: APIConfiguration)

    // Scheduled messages
    case createScheduled(conversationId: UUID, payload: CreateScheduledMessageRequest, configuration: APIConfiguration)
    case listMyScheduled(status: String?, configuration: APIConfiguration)
    case updateScheduled(id: UUID, payload: UpdateScheduledMessageRequest, configuration: APIConfiguration)
    case cancelScheduled(id: UUID, configuration: APIConfiguration)
    case sendNowScheduled(id: UUID, configuration: APIConfiguration)

    // Templates
    case listTemplates(scope: String?, configuration: APIConfiguration)
    case createTemplate(payload: CreateTemplateRequest, configuration: APIConfiguration)
    case updateTemplate(id: UUID, payload: UpdateTemplateRequest, configuration: APIConfiguration)
    case deleteTemplate(id: UUID, configuration: APIConfiguration)
    case renderTemplate(id: UUID, payload: RenderTemplateRequest, configuration: APIConfiguration)

    // Reminders
    case listReminders(status: String?, configuration: APIConfiguration)
    case createReminder(payload: CreateReminderRequest, configuration: APIConfiguration)
    case createReminderForMessage(messageId: UUID, payload: CreateMessageReminderRequest, configuration: APIConfiguration)
    case updateReminder(id: UUID, payload: UpdateReminderRequest, configuration: APIConfiguration)
    case snoozeReminder(id: UUID, payload: SnoozeReminderRequest, configuration: APIConfiguration)
    case dismissReminder(id: UUID, configuration: APIConfiguration)
    case deleteReminder(id: UUID, configuration: APIConfiguration)
}

extension ProductivityEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .getDraft(_, _, let c), .upsertDraft(_, _, let c), .deleteDraft(_, _, let c),
             .listMyDrafts(let c),
             .createScheduled(_, _, let c), .listMyScheduled(_, let c),
             .updateScheduled(_, _, let c), .cancelScheduled(_, let c), .sendNowScheduled(_, let c),
             .listTemplates(_, let c), .createTemplate(_, let c),
             .updateTemplate(_, _, let c), .deleteTemplate(_, let c), .renderTemplate(_, _, let c),
             .listReminders(_, let c), .createReminder(_, let c),
             .createReminderForMessage(_, _, let c),
             .updateReminder(_, _, let c), .snoozeReminder(_, _, let c),
             .dismissReminder(_, let c), .deleteReminder(_, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .getDraft(let id, _, _), .upsertDraft(let id, _, _), .deleteDraft(let id, _, _):
            return "/api/conversations/\(id.uuidString)/draft"
        case .listMyDrafts:
            return "/api/me/drafts"
        case .createScheduled(let id, _, _):
            return "/api/conversations/\(id.uuidString)/scheduled-messages"
        case .listMyScheduled:
            return "/api/me/scheduled-messages"
        case .updateScheduled(let id, _, _), .cancelScheduled(let id, _):
            return "/api/scheduled-messages/\(id.uuidString)"
        case .sendNowScheduled(let id, _):
            return "/api/scheduled-messages/\(id.uuidString)/send-now"
        case .listTemplates, .createTemplate:
            return "/api/templates"
        case .updateTemplate(let id, _, _), .deleteTemplate(let id, _):
            return "/api/templates/\(id.uuidString)"
        case .renderTemplate(let id, _, _):
            return "/api/templates/\(id.uuidString)/render"
        case .listReminders, .createReminder:
            return "/api/me/reminders"
        case .createReminderForMessage(let id, _, _):
            return "/api/messages/\(id.uuidString)/remind"
        case .updateReminder(let id, _, _), .deleteReminder(let id, _):
            return "/api/reminders/\(id.uuidString)"
        case .snoozeReminder(let id, _, _):
            return "/api/reminders/\(id.uuidString)/snooze"
        case .dismissReminder(let id, _):
            return "/api/reminders/\(id.uuidString)/dismiss"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .getDraft, .listMyDrafts, .listMyScheduled, .listTemplates, .listReminders:
            return .get
        case .upsertDraft, .updateScheduled, .updateReminder, .updateTemplate:
            return .put
        case .deleteDraft, .cancelScheduled, .deleteTemplate, .deleteReminder:
            return .delete
        case .createScheduled, .sendNowScheduled,
             .createTemplate, .renderTemplate,
             .createReminder, .createReminderForMessage,
             .snoozeReminder, .dismissReminder:
            return .post
        }
    }

    public var queryParameters: [String: String]? {
        switch self {
        case .getDraft(_, let pid, _), .deleteDraft(_, let pid, _):
            if let pid { return ["parentId": pid.uuidString] }
            return nil
        case .listMyScheduled(let status, _), .listReminders(let status, _):
            if let s = status, !s.isEmpty { return ["status": s] }
            return nil
        case .listTemplates(let scope, _):
            if let s = scope, !s.isEmpty { return ["scope": s] }
            return nil
        default:
            return nil
        }
    }

    public var headers: [String: String]? {
        var h = ["Content-Type": "application/json"]
        if let token = TokenStore.shared.token {
            h["Authorization"] = "Bearer \(token)"
        }
        if let orgId = OrganizationContext.shared.orgId {
            h["X-Org-Id"] = orgId.uuidString
        }
        return h
    }

    public var body: Data? {
        switch self {
        case .upsertDraft(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .createScheduled(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .updateScheduled(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .createTemplate(let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .updateTemplate(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .renderTemplate(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .createReminder(let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .createReminderForMessage(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .updateReminder(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .snoozeReminder(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        default: return nil
        }
    }
}
