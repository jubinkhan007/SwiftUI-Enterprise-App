import Foundation
import SharedModels

public protocol NotificationRepositoryProtocol: Sendable {
    func getNotifications(unreadOnly: Bool) async throws -> APIResponse<[NotificationDTO]>
    func getNotifications(category: String?, unreadOnly: Bool) async throws -> APIResponse<[NotificationDTO]>
    func markRead(id: UUID) async throws -> APIResponse<NotificationDTO>
    func markAllRead() async throws -> APIResponse<NotificationBatchReadResponse>
    func getUnreadCount() async throws -> APIResponse<NotificationUnreadCountDTO>
}

