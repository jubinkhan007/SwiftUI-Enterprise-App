import Foundation
import Combine
import SwiftUI
import Domain
import SharedModels

@MainActor
public final class InboxViewModel: ObservableObject {
    @Published public private(set) var notifications: [NotificationDTO] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var unreadCount: Int = 0
    @Published public var error: Error?
    public enum NotificationFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case mentions = "Mentions"
        case assignments = "Assignments"
        case updates = "Updates"
        case messages = "Messages"
        case meetings = "Meetings"
        
        public var id: String { self.rawValue }
    }
    
    @Published public var filterType: NotificationFilter = .all
    @Published public var unreadOnly: Bool = false {
        didSet {
            Task {
                await fetchNotifications()
            }
        }
    }
    
    public var filteredNotifications: [NotificationDTO] {
        let base = notifications
        switch filterType {
        case .all:
            return base
        case .mentions:
            return base.filter { $0.type.lowercased().contains("mention") }
        case .assignments:
            return base.filter { $0.type.lowercased().contains("assign") }
        case .updates:
            return base.filter { $0.type.lowercased().contains("update") || $0.type.lowercased().contains("status") }
        case .messages:
            return base.filter { $0.type.lowercased().contains("message") || $0.type.lowercased().contains("chat") }
        case .meetings:
            return base.filter { $0.type.lowercased().contains("meeting") || $0.type.lowercased().contains("call") }
        }
    }
    
    private let notificationRepository: NotificationRepositoryProtocol
    
    public init(notificationRepository: NotificationRepositoryProtocol) {
        self.notificationRepository = notificationRepository
    }
    
    public func fetchNotifications() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let response = try await notificationRepository.getNotifications(unreadOnly: unreadOnly)
            self.notifications = response.data ?? []
            if let countDTO = try? await notificationRepository.getUnreadCount(), let count = countDTO.data?.count {
                self.unreadCount = count
            } else {
                self.unreadCount = self.notifications.filter { $0.readAt == nil }.count
            }
        } catch {
             self.error = error
        }
        
        isLoading = false
    }
    
    public func markAsRead(_ notification: NotificationDTO) async {
        do {
            let response = try await notificationRepository.markRead(id: notification.id)
            if let updated = response.data {
                if let index = notifications.firstIndex(where: { $0.id == updated.id }) {
                    if unreadOnly {
                        notifications.remove(at: index)
                    } else {
                        notifications[index] = updated
                    }
                    self.unreadCount = self.notifications.filter { $0.readAt == nil }.count
                }
            }
        } catch {
            self.error = error
        }
    }
    
    public func markAllAsRead() async {
        do {
            _ = try await notificationRepository.markAllRead()
            let now = Date()
            notifications = notifications.map { item in
                NotificationDTO(
                    id: item.id,
                    userId: item.userId,
                    orgId: item.orgId,
                    actorUserId: item.actorUserId,
                    entityType: item.entityType,
                    entityId: item.entityId,
                    type: item.type,
                    payloadJson: item.payloadJson,
                    readAt: now,
                    createdAt: item.createdAt
                )
            }
            if unreadOnly {
                notifications.removeAll()
            }
            self.unreadCount = 0
        } catch {
            self.error = error
        }
    }
}
