import Foundation
import SwiftUI
import Domain
import SharedModels

/// Backend-backed cache for per-message interactions (reactions, pins, bookmarks).
///
/// Maintained as a singleton because at most one chat is active at a time on
/// the visible navigation stack. `configure(...)` is called by ChatViewModel
/// when a chat opens so the store knows which repository and viewer to use.
/// `ingest(...)` mirrors backend state from MessageDTO into the store so views
/// reading `reactions[messageId]`, `pinnedMessages`, `bookmarkedMessages`
/// reflect the server.
@MainActor
public final class MessageInteractionStore: ObservableObject {
    public static let shared = MessageInteractionStore()

    @Published public private(set) var pinnedMessages: Set<UUID> = []
    @Published public private(set) var bookmarkedMessages: Set<UUID> = []
    /// messageId -> emoji -> set of user IDs that reacted with that emoji.
    @Published public private(set) var reactions: [UUID: [String: Set<UUID>]] = [:]
    /// Messages currently waiting on a backend action so the UI can disable repeat taps.
    @Published public private(set) var inFlight: Set<MessageInteractionKey> = []
    /// Last error from a backend interaction; presented at view layer if needed.
    @Published public var lastError: Error?

    private var messagingRepository: MessagingRepositoryProtocol?
    private var currentUserId: UUID?

    private init() {}

    // MARK: - Configuration

    public func configure(messagingRepository: MessagingRepositoryProtocol, currentUserId: UUID) {
        self.messagingRepository = messagingRepository
        self.currentUserId = currentUserId
    }

    /// Optional reset between chats. Keeps things tidy when switching conversations.
    public func reset() {
        pinnedMessages.removeAll()
        bookmarkedMessages.removeAll()
        reactions.removeAll()
        inFlight.removeAll()
        lastError = nil
    }

    // MARK: - Ingest

    public func ingest(_ messages: [MessageDTO]) {
        for message in messages { ingest(message) }
    }

    public func ingest(_ message: MessageDTO) {
        if message.isPinned {
            pinnedMessages.insert(message.id)
        } else {
            pinnedMessages.remove(message.id)
        }

        if message.isBookmarkedByMe {
            bookmarkedMessages.insert(message.id)
        } else {
            bookmarkedMessages.remove(message.id)
        }

        var emojiMap: [String: Set<UUID>] = [:]
        for group in message.reactions {
            emojiMap[group.emoji] = Set(group.userIds)
        }
        if emojiMap.isEmpty {
            reactions.removeValue(forKey: message.id)
        } else {
            reactions[message.id] = emojiMap
        }
    }

    // MARK: - Reads

    public func reactionSummary(for messageId: UUID) -> [(emoji: String, count: Int)] {
        (reactions[messageId] ?? [:])
            .map { ($0.key, $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.emoji < rhs.emoji }
                return lhs.count > rhs.count
            }
    }

    public func didReact(_ emoji: String, for messageId: UUID) -> Bool {
        guard let currentUserId else { return false }
        return reactions[messageId]?[emoji]?.contains(currentUserId) == true
    }

    // MARK: - Writes (backend-backed)

    @discardableResult
    public func toggleReaction(_ emoji: String, for messageId: UUID) async -> MessageDTO? {
        guard let messagingRepository, let currentUserId else { return nil }
        let key = MessageInteractionKey(messageId: messageId, kind: .reaction(emoji))
        guard !inFlight.contains(key) else { return nil }
        inFlight.insert(key)
        defer { inFlight.remove(key) }

        let alreadyReacted = reactions[messageId]?[emoji]?.contains(currentUserId) == true

        // Optimistic update
        applyOptimisticReaction(emoji: emoji, messageId: messageId, didReact: !alreadyReacted, userId: currentUserId)

        do {
            let response: APIResponse<MessageDTO>
            if alreadyReacted {
                response = try await messagingRepository.removeReaction(messageId: messageId, emoji: emoji)
            } else {
                response = try await messagingRepository.addReaction(messageId: messageId, emoji: emoji)
            }
            if let dto = response.data { ingest(dto) }
            return response.data
        } catch {
            // Roll back optimistic update
            applyOptimisticReaction(emoji: emoji, messageId: messageId, didReact: alreadyReacted, userId: currentUserId)
            lastError = error
            return nil
        }
    }

    @discardableResult
    public func togglePinned(_ messageId: UUID) async -> MessageDTO? {
        guard let messagingRepository else { return nil }
        let key = MessageInteractionKey(messageId: messageId, kind: .pin)
        guard !inFlight.contains(key) else { return nil }
        inFlight.insert(key)
        defer { inFlight.remove(key) }

        let wasPinned = pinnedMessages.contains(messageId)

        // Optimistic
        if wasPinned { pinnedMessages.remove(messageId) } else { pinnedMessages.insert(messageId) }

        do {
            let response = wasPinned
                ? try await messagingRepository.unpinMessage(messageId: messageId)
                : try await messagingRepository.pinMessage(messageId: messageId)
            if let dto = response.data { ingest(dto) }
            return response.data
        } catch {
            // Roll back
            if wasPinned { pinnedMessages.insert(messageId) } else { pinnedMessages.remove(messageId) }
            lastError = error
            return nil
        }
    }

    @discardableResult
    public func toggleBookmarked(_ messageId: UUID) async -> MessageDTO? {
        guard let messagingRepository else { return nil }
        let key = MessageInteractionKey(messageId: messageId, kind: .bookmark)
        guard !inFlight.contains(key) else { return nil }
        inFlight.insert(key)
        defer { inFlight.remove(key) }

        let wasBookmarked = bookmarkedMessages.contains(messageId)

        // Optimistic
        if wasBookmarked { bookmarkedMessages.remove(messageId) } else { bookmarkedMessages.insert(messageId) }

        do {
            let response = wasBookmarked
                ? try await messagingRepository.unbookmarkMessage(messageId: messageId)
                : try await messagingRepository.bookmarkMessage(messageId: messageId)
            if let dto = response.data { ingest(dto) }
            return response.data
        } catch {
            // Roll back
            if wasBookmarked { bookmarkedMessages.insert(messageId) } else { bookmarkedMessages.remove(messageId) }
            lastError = error
            return nil
        }
    }

    // MARK: - Helpers

    private func applyOptimisticReaction(emoji: String, messageId: UUID, didReact: Bool, userId: UUID) {
        var emojiMap = reactions[messageId] ?? [:]
        var users = emojiMap[emoji] ?? []
        if didReact {
            users.insert(userId)
        } else {
            users.remove(userId)
        }
        if users.isEmpty {
            emojiMap.removeValue(forKey: emoji)
        } else {
            emojiMap[emoji] = users
        }
        if emojiMap.isEmpty {
            reactions.removeValue(forKey: messageId)
        } else {
            reactions[messageId] = emojiMap
        }
    }
}

public struct MessageInteractionKey: Hashable, Sendable {
    public let messageId: UUID
    public let kind: Kind

    public enum Kind: Hashable, Sendable {
        case pin
        case bookmark
        case reaction(String)
    }
}
