import Foundation
import Combine
import Domain
import AppNetwork
import SharedModels

@MainActor
public final class ReminderStore: ObservableObject {
    public static let shared = ReminderStore()

    @Published public private(set) var items: [ReminderDTO] = []
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
            let response = try await repository.listReminders(status: status)
            items = response.data ?? []
        } catch { lastError = error }
    }

    @discardableResult
    public func create(body: String, remindAt: Date, sourceType: ReminderSourceType? = nil, sourceId: UUID? = nil) async -> ReminderDTO? {
        guard let repository else { return nil }
        do {
            let response = try await repository.createReminder(
                CreateReminderRequest(body: body, remindAt: remindAt, sourceType: sourceType, sourceId: sourceId)
            )
            if let dto = response.data {
                items.insert(dto, at: 0)
                return dto
            }
        } catch { lastError = error }
        return nil
    }

    @discardableResult
    public func createForMessage(messageId: UUID, remindAt: Date, body: String? = nil) async -> ReminderDTO? {
        guard let repository else { return nil }
        do {
            let response = try await repository.createReminderForMessage(
                messageId: messageId,
                request: CreateMessageReminderRequest(remindAt: remindAt, body: body)
            )
            if let dto = response.data {
                items.insert(dto, at: 0)
                return dto
            }
        } catch { lastError = error }
        return nil
    }

    @discardableResult
    public func snooze(_ id: UUID, minutes: Int) async -> ReminderDTO? {
        guard let repository else { return nil }
        do {
            let response = try await repository.snoozeReminder(id: id, minutes: minutes)
            if let dto = response.data { replace(dto) }
            return response.data
        } catch { lastError = error }
        return nil
    }

    @discardableResult
    public func dismiss(_ id: UUID) async -> ReminderDTO? {
        guard let repository else { return nil }
        let prev = items
        if let idx = items.firstIndex(where: { $0.id == id }) {
            let cur = items[idx]
            items[idx] = ReminderDTO(
                id: cur.id, userId: cur.userId, orgId: cur.orgId, body: cur.body,
                remindAt: cur.remindAt, status: .dismissed, sourceType: cur.sourceType,
                sourceId: cur.sourceId, firedAt: cur.firedAt,
                createdAt: cur.createdAt, updatedAt: cur.updatedAt
            )
        }
        do {
            let response = try await repository.dismissReminder(id: id)
            if let dto = response.data { replace(dto) }
            return response.data
        } catch {
            items = prev
            lastError = error
        }
        return nil
    }

    public func delete(_ id: UUID) async {
        guard let repository else { return }
        let prev = items
        items.removeAll { $0.id == id }
        do { _ = try await repository.deleteReminder(id: id) }
        catch {
            items = prev
            lastError = error
        }
    }

    private func replace(_ dto: ReminderDTO) {
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
            guard event.type.hasPrefix("reminder.") else { return }
            Task { @MainActor [weak self] in
                await self?.load()
            }
        }
    }
}
