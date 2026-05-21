import Foundation
import Combine
import Domain
import AppNetwork
import SharedModels

@MainActor
public final class ScheduledMessageStore: ObservableObject {
    public static let shared = ScheduledMessageStore()

    @Published public private(set) var items: [ScheduledMessageDTO] = []
    @Published public var lastError: Error?
    @Published public var isLoading: Bool = false

    private var repository: ProductivityRepositoryProtocol?
    private var realtimeProvider: RealTimeProvider?
    private var listenerId: UUID?

    private init() {}

    public func configure(repository: ProductivityRepositoryProtocol, realtimeProvider: RealTimeProvider? = nil) {
        self.repository = repository
        self.realtimeProvider = realtimeProvider
        attachListenerIfNeeded()
    }

    public func load(status: String? = nil) async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await repository.listMyScheduled(status: status)
            items = response.data ?? []
        } catch {
            lastError = error
        }
    }

    @discardableResult
    public func schedule(conversationId: UUID, body: String, parentId: UUID? = nil, scheduledFor: Date) async -> ScheduledMessageDTO? {
        guard let repository else { return nil }
        do {
            let response = try await repository.createScheduled(
                conversationId: conversationId,
                request: CreateScheduledMessageRequest(body: body, parentId: parentId, scheduledFor: scheduledFor)
            )
            if let dto = response.data {
                items.insert(dto, at: 0)
                return dto
            }
        } catch { lastError = error }
        return nil
    }

    @discardableResult
    public func update(id: UUID, body: String?, scheduledFor: Date?) async -> ScheduledMessageDTO? {
        guard let repository else { return nil }
        let previous = items
        if let idx = items.firstIndex(where: { $0.id == id }) {
            let cur = items[idx]
            items[idx] = ScheduledMessageDTO(
                id: cur.id, userId: cur.userId, orgId: cur.orgId, conversationId: cur.conversationId,
                parentId: cur.parentId, body: body ?? cur.body, messageType: cur.messageType,
                scheduledFor: scheduledFor ?? cur.scheduledFor, status: cur.status,
                sentMessageId: cur.sentMessageId, error: cur.error,
                createdAt: cur.createdAt, updatedAt: cur.updatedAt
            )
        }
        do {
            let response = try await repository.updateScheduled(id: id, request: UpdateScheduledMessageRequest(body: body, scheduledFor: scheduledFor))
            if let dto = response.data {
                replace(dto)
                return dto
            }
        } catch {
            items = previous
            lastError = error
        }
        return nil
    }

    @discardableResult
    public func cancel(_ id: UUID) async -> ScheduledMessageDTO? {
        guard let repository else { return nil }
        let previous = items
        items.removeAll { $0.id == id }
        do {
            let response = try await repository.cancelScheduled(id: id)
            return response.data
        } catch {
            items = previous
            lastError = error
        }
        return nil
    }

    @discardableResult
    public func sendNow(_ id: UUID) async -> ScheduledMessageDTO? {
        guard let repository else { return nil }
        do {
            let response = try await repository.sendNowScheduled(id: id)
            if let dto = response.data { replace(dto) }
            return response.data
        } catch { lastError = error }
        return nil
    }

    private func replace(_ dto: ScheduledMessageDTO) {
        if let idx = items.firstIndex(where: { $0.id == dto.id }) {
            items[idx] = dto
        } else {
            items.insert(dto, at: 0)
        }
    }

    // MARK: - Realtime

    private func attachListenerIfNeeded() {
        guard let realtimeProvider, listenerId == nil else { return }
        listenerId = realtimeProvider.addEventListener { [weak self] event in
            guard event.type.hasPrefix("scheduled_message.") else { return }
            Task { @MainActor [weak self] in
                await self?.load()
            }
        }
    }
}
