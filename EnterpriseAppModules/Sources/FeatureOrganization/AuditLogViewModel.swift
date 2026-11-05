import Foundation
import SharedModels
import AppNetwork
import Combine

/// Categories for filtering workspace audit log entries on mobile.
public enum AuditCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case members = "Members & Roles"
    case security = "Security & Sessions"
    case channels = "Channels"
    case settings = "Settings & Compliance"
    case tasks = "Tasks & Projects"

    public var id: String { rawValue }
}

/// ViewModel for the Organization Audit Log screen.
/// Fetches `/api/organizations/:id/audit-log` and subscribes to live `audit.created` WebSocket events.
@MainActor
public final class AuditLogViewModel: ObservableObject {
    @Published public var logs: [AuditLogDTO] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var searchText: String = ""
    @Published public var selectedCategory: AuditCategory = .all
    @Published public var liveEventIds: Set<UUID> = []

    public let orgId: UUID
    private let apiClient: APIClientProtocol
    private let configuration: APIConfiguration
    private var cancellable: AnyCancellable?

    public init(
        orgId: UUID,
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .current
    ) {
        self.orgId = orgId
        self.apiClient = apiClient
        self.configuration = configuration

        self.cancellable = NotificationCenter.default
            .publisher(for: .realtimeAuditEventReceived)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self,
                      let event = note.object as? RealTimeProvider.ServerEvent,
                      event.orgId == self.orgId
                else { return }
                self.ingestLiveEvent(event)
            }
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let endpoint = OrganizationEndpoint.auditLog(orgId: orgId, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[AuditLogDTO]>.self)
            logs = response.data ?? []
        } catch {
            if case NetworkError.unauthorized = error {
                TokenStore.shared.clear()
                NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func ingestLiveEvent(_ event: RealTimeProvider.ServerEvent) {
        let p = event.payload ?? [:]
        let entryId = p["id"].flatMap(UUID.init(uuidString:)) ?? event.entityId
        guard !logs.contains(where: { $0.id == entryId }) else { return }

        let entry = AuditLogDTO(
            id: entryId,
            orgId: event.orgId,
            userId: p["userId"].flatMap(UUID.init(uuidString:)) ?? UUID(),
            userEmail: p["userEmail"]?.isEmpty == false ? p["userEmail"]! : "system",
            action: p["action"] ?? "audit.event",
            resourceType: p["resourceType"] ?? "org",
            resourceId: p["resourceId"].flatMap { $0.isEmpty ? nil : UUID(uuidString: $0) },
            details: p["details"].flatMap { $0.isEmpty ? nil : $0 },
            createdAt: event.updatedAt
        )
        liveEventIds.insert(entryId)
        logs.insert(entry, at: 0)
    }

    public var filteredLogs: [AuditLogDTO] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return logs.filter { log in
            if selectedCategory != .all && log.auditCategory != selectedCategory {
                return false
            }
            guard !q.isEmpty else { return true }
            return log.action.lowercased().contains(q)
                || log.userEmail.lowercased().contains(q)
                || log.resourceType.lowercased().contains(q)
                || (log.details?.lowercased().contains(q) ?? false)
        }
    }
}

public extension AuditLogDTO {
    var auditCategory: AuditCategory {
        let a = action.lowercased()
        let r = resourceType.lowercased()
        if a.contains("member") || a.contains("invite") || a.contains("join_request") || r == "member" || r == "invite" {
            return .members
        }
        if a.contains("session") || a.contains("sso") || a.contains("auth") || r == "session" {
            return .security
        }
        if a.contains("channel") || a.contains("message") || r == "channel" {
            return .channels
        }
        if a.contains("retention") || a.contains("compliance") || a.contains("branding") || a.contains("org.") || r == "org" {
            return .settings
        }
        return .tasks
    }

    var symbolName: String {
        switch auditCategory {
        case .members: return "person.2.badge.gearshape.fill"
        case .security: return "lock.shield.fill"
        case .channels: return "bubble.left.and.exclamationmark.bubble.right.fill"
        case .settings: return "slider.horizontal.3"
        case .tasks, .all: return "Checkmark.rectangle.stack.fill".lowercased() == "checkmark.rectangle.stack.fill" ? "checklist" : "doc.text"
        }
    }
}

