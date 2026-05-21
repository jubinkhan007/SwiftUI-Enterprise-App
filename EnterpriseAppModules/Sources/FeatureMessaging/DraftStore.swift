import Foundation
import Combine
import Domain
import AppNetwork
import SharedModels

/// Singleton store for cross-device-synced message drafts.
/// Debounces upsert by 400ms to keep the wire quiet during typing.
@MainActor
public final class DraftStore: ObservableObject {
    public static let shared = DraftStore()

    public struct Key: Hashable, Sendable {
        public let conversationId: UUID
        public let parentId: UUID?
    }

    @Published public private(set) var byKey: [Key: String] = [:]
    @Published public var lastError: Error?

    private var repository: ProductivityRepositoryProtocol?
    private var currentUserId: UUID?
    private var realtimeProvider: RealTimeProvider?
    private var listenerId: UUID?

    private var pendingTask: [Key: Task<Void, Never>] = [:]
    private static let debounce: TimeInterval = 0.4

    private init() {}

    public func configure(repository: ProductivityRepositoryProtocol, currentUserId: UUID, realtimeProvider: RealTimeProvider? = nil) {
        self.repository = repository
        self.currentUserId = currentUserId
        self.realtimeProvider = realtimeProvider
        attachRealtimeListenerIfNeeded()
    }

    // MARK: - Hydration

    /// Fetch + cache draft for a conversation/thread; returns body (empty string if none).
    @discardableResult
    public func loadDraft(conversationId: UUID, parentId: UUID? = nil) async -> String {
        guard let repository else { return "" }
        let key = Key(conversationId: conversationId, parentId: parentId)
        do {
            let response = try await repository.getDraft(conversationId: conversationId, parentId: parentId)
            let body = response.data?.body ?? ""
            byKey[key] = body
            return body
        } catch {
            lastError = error
            return byKey[key] ?? ""
        }
    }

    public func draft(conversationId: UUID, parentId: UUID? = nil) -> String {
        byKey[Key(conversationId: conversationId, parentId: parentId)] ?? ""
    }

    // MARK: - Debounced upsert

    public func setDraft(conversationId: UUID, parentId: UUID? = nil, body: String) {
        let key = Key(conversationId: conversationId, parentId: parentId)
        byKey[key] = body
        scheduleUpsert(key: key, body: body)
    }

    public func clearLocal(conversationId: UUID, parentId: UUID? = nil) {
        let key = Key(conversationId: conversationId, parentId: parentId)
        byKey[key] = ""
        pendingTask[key]?.cancel()
        pendingTask[key] = nil
    }

    public func discardOnBackend(conversationId: UUID, parentId: UUID? = nil) async {
        let key = Key(conversationId: conversationId, parentId: parentId)
        byKey[key] = ""
        pendingTask[key]?.cancel()
        pendingTask[key] = nil
        guard let repository else { return }
        do { _ = try await repository.deleteDraft(conversationId: conversationId, parentId: parentId) }
        catch { lastError = error }
    }

    private func scheduleUpsert(key: Key, body: String) {
        pendingTask[key]?.cancel()
        let trimmed = body
        pendingTask[key] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.debounce * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.performUpsert(key: key, body: trimmed)
        }
    }

    private func performUpsert(key: Key, body: String) async {
        guard let repository else { return }
        let request = UpsertDraftRequest(parentId: key.parentId, body: body)
        do { _ = try await repository.upsertDraft(conversationId: key.conversationId, request: request) }
        catch { lastError = error }
    }

    // MARK: - Realtime cross-device sync

    private func attachRealtimeListenerIfNeeded() {
        guard let realtimeProvider, listenerId == nil else { return }
        listenerId = realtimeProvider.addEventListener { [weak self] event in
            guard event.type == "draft.updated" else { return }
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.handleRemoteDraftUpdated(event: event)
            }
        }
    }

    private func handleRemoteDraftUpdated(event: RealTimeProvider.ServerEvent) async {
        guard let repository,
              let convIdStr = event.payload?["conversationId"],
              let convId = UUID(uuidString: convIdStr) else { return }
        let parentId: UUID? = {
            guard let s = event.payload?["parentId"], !s.isEmpty else { return nil }
            return UUID(uuidString: s)
        }()
        do {
            let response = try await repository.getDraft(conversationId: convId, parentId: parentId)
            let key = Key(conversationId: convId, parentId: parentId)
            byKey[key] = response.data?.body ?? ""
        } catch {
            // Non-fatal — local copy still works.
        }
    }
}
