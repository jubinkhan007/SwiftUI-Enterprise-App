import Foundation
import SwiftUI
import Combine
import Domain
import SharedModels

/// Singleton store that holds presence snapshots and runs a periodic heartbeat
/// while the app is active so the backend can track online users.
@MainActor
public final class PresenceStore: ObservableObject {
    public static let shared = PresenceStore()

    /// Heartbeat frequency. Must be smaller than the backend's onlineWindow (60s).
    public static let heartbeatInterval: TimeInterval = 30

    @Published public private(set) var myPresence: UserPresenceDTO?
    @Published public private(set) var byUserId: [UUID: UserPresenceDTO] = [:]
    @Published public var lastError: Error?

    private var presenceRepository: PresenceRepositoryProtocol?
    private var currentUserId: UUID?
    private var heartbeatTask: Task<Void, Never>?

    private init() {}

    public func configure(presenceRepository: PresenceRepositoryProtocol, currentUserId: UUID) {
        self.presenceRepository = presenceRepository
        self.currentUserId = currentUserId
    }

    // MARK: - Heartbeat lifecycle

    public func startHeartbeat() {
        guard heartbeatTask == nil, presenceRepository != nil else { return }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sendHeartbeat()
                try? await Task.sleep(nanoseconds: UInt64(Self.heartbeatInterval * 1_000_000_000))
            }
        }
    }

    public func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    // MARK: - Backend operations

    public func sendHeartbeat(state: PresenceState? = nil) async {
        guard let presenceRepository else { return }
        do {
            let response = try await presenceRepository.heartbeat(state: state)
            if let dto = response.data {
                myPresence = dto
                byUserId[dto.userId] = dto
            }
        } catch {
            lastError = error
        }
    }

    @discardableResult
    public func setCustomStatus(emoji: String?, text: String?, expiresAt: Date?) async -> UserPresenceDTO? {
        guard let presenceRepository else { return nil }
        do {
            let response = try await presenceRepository.setCustomStatus(
                SetCustomStatusRequest(emoji: emoji, text: text, expiresAt: expiresAt)
            )
            if let dto = response.data {
                myPresence = dto
                byUserId[dto.userId] = dto
            }
            return response.data
        } catch {
            lastError = error
            return nil
        }
    }

    @discardableResult
    public func clearCustomStatus() async -> UserPresenceDTO? {
        guard let presenceRepository else { return nil }
        do {
            let response = try await presenceRepository.clearCustomStatus()
            if let dto = response.data {
                myPresence = dto
                byUserId[dto.userId] = dto
            }
            return response.data
        } catch {
            lastError = error
            return nil
        }
    }

    public func refreshMyPresence() async {
        guard let presenceRepository else { return }
        do {
            let response = try await presenceRepository.getMyPresence()
            if let dto = response.data {
                myPresence = dto
                byUserId[dto.userId] = dto
            }
        } catch {
            lastError = error
        }
    }

    public func loadPresences(for userIds: [UUID]) async {
        guard let presenceRepository, !userIds.isEmpty else { return }
        do {
            let response = try await presenceRepository.getBulkPresence(userIds: userIds)
            if let bundle = response.data {
                for entry in bundle.presences {
                    byUserId[entry.userId] = entry
                }
            }
        } catch {
            lastError = error
        }
    }

    public func presence(for userId: UUID) -> UserPresenceDTO {
        byUserId[userId] ?? UserPresenceDTO(userId: userId, state: .offline)
    }
}
