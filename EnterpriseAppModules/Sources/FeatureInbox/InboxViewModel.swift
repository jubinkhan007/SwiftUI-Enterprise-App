import Foundation
import Combine
import SwiftUI
import Domain
import SharedModels

@MainActor
public final class InboxViewModel: ObservableObject {
    @Published public private(set) var notifications: [NotificationDTO] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public var error: Error?
    public enum NotificationFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case mentions = "Mentions"
        case assignments = "Assignments"
        case updates = "Updates"
        
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
                }
            }
        } catch {
            self.error = error
        }
    }
    
    public func markAllAsRead() async {
        let unread = notifications.filter { $0.readAt == nil }
        for notification in unread {
            await markAsRead(notification)
        }
    }
}
