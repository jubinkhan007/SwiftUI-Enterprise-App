import Foundation
import SwiftUI

@MainActor
final class MessageInteractionStore: ObservableObject {
    static let shared = MessageInteractionStore()

    @Published private(set) var pinnedMessages: Set<UUID> = []
    @Published private(set) var bookmarkedMessages: Set<UUID> = []
    @Published private(set) var reactions: [UUID: [String: Set<UUID>]] = [:]

    private init() {}

    func togglePinned(_ messageId: UUID) {
        if pinnedMessages.contains(messageId) {
            pinnedMessages.remove(messageId)
        } else {
            pinnedMessages.insert(messageId)
        }
    }

    func toggleBookmarked(_ messageId: UUID) {
        if bookmarkedMessages.contains(messageId) {
            bookmarkedMessages.remove(messageId)
        } else {
            bookmarkedMessages.insert(messageId)
        }
    }

    func toggleReaction(_ emoji: String, for messageId: UUID, userId: UUID) {
        var messageReactions = reactions[messageId] ?? [:]
        var users = messageReactions[emoji] ?? []
        if users.contains(userId) {
            users.remove(userId)
        } else {
            users.insert(userId)
        }
        if users.isEmpty {
            messageReactions.removeValue(forKey: emoji)
        } else {
            messageReactions[emoji] = users
        }
        reactions[messageId] = messageReactions
    }

    func reactionSummary(for messageId: UUID) -> [(emoji: String, count: Int)] {
        (reactions[messageId] ?? [:])
            .map { ($0.key, $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.emoji < rhs.emoji }
                return lhs.count > rhs.count
            }
    }
}
