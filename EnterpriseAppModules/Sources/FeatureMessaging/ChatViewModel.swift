import Foundation
import SwiftUI
import Combine
import Domain
import SharedModels
import AppNetwork

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public private(set) var messages: [MessageDTO] = []
    @Published public private(set) var memberDirectory: [UUID: String] = [:]
    @Published public private(set) var memberReadTimes: [UUID: Date] = [:]
    @Published public var inputText: String = ""
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isLoadingMore: Bool = false
    @Published public private(set) var hasMoreMessages: Bool = false
    @Published public var error: Error?
    @Published public var editingMessageId: UUID?
    @Published public var isTypingIndicatorVisible: Bool = false
    @Published public private(set) var typingUsers: [UUID: Date] = [:]
    
    public var typingText: String {
        let active = typingUsers.filter { $0.value.timeIntervalSinceNow > -3.0 }
        let names = active.compactMap { memberDirectory[$0.key] ?? "Someone" }
        if names.isEmpty { return "" }
        if names.count == 1 { return "\(names[0]) is typing..." }
        if names.count == 2 { return "\(names[0]) and \(names[1]) are typing..." }
        return "\(names.count) people are typing..."
    }
    
    public let conversationId: UUID
    public let currentUserId: UUID
    private let messagingRepository: MessagingRepositoryProtocol
    private let realtimeProvider: RealTimeProvider
    private var lastMessageId: UUID?
    private var realtimeListenerID: UUID?
    private var typingTimer: Timer?
    private var typingCleanupTimers: [UUID: Timer] = [:]
    
    public init(conversationId: UUID, currentUserId: UUID, messagingRepository: MessagingRepositoryProtocol, realtimeProvider: RealTimeProvider) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        self.messagingRepository = messagingRepository
        self.realtimeProvider = realtimeProvider

        MessageInteractionStore.shared.configure(
            messagingRepository: messagingRepository,
            currentUserId: currentUserId
        )

        realtimeListenerID = realtimeProvider.addEventListener { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleRealtimeEvent(event)
            }
        }
        
        $inputText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] text in
                if !text.isEmpty {
                    Task { @MainActor [weak self] in
                        self?.sendTypingIndicator()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    deinit {
        if let realtimeListenerID {
            Task { @MainActor [realtimeProvider] in
                realtimeProvider.removeEventListener(realtimeListenerID)
            }
        }
    }
    
    public func fetchMessages() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let response = try await messagingRepository.getMessages(conversationId: conversationId, cursor: nil, limit: 50)
            let fetched = response.data ?? []
            self.messages = Array(fetched.reversed())
            mergeMemberDirectory(from: self.messages)
            MessageInteractionStore.shared.ingest(self.messages)
            self.hasMoreMessages = fetched.count == 50
            await refreshMemberDirectory()

            if let last = self.messages.last {
                self.lastMessageId = last.id
                await markRead()
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    public func loadMoreMessages() async {
        guard !isLoadingMore, hasMoreMessages, let oldest = messages.first else { return }
        isLoadingMore = true

        do {
            let response = try await messagingRepository.getMessages(conversationId: conversationId, cursor: oldest.id, limit: 50)
            let fetched = response.data ?? []
            self.messages = Array(fetched.reversed()) + self.messages
            mergeMemberDirectory(from: self.messages)
            MessageInteractionStore.shared.ingest(self.messages)
            self.hasMoreMessages = fetched.count == 50
        } catch {
            self.error = error
        }

        isLoadingMore = false
    }
    
    public func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let request = SendMessageRequest(body: text)
        inputText = "" // Optimistic
        
        if let editId = editingMessageId {
            editingMessageId = nil
            do {
                let response = try await messagingRepository.editMessage(messageId: editId, request: EditMessageRequest(body: text))
                if let newMsg = response.data, let idx = messages.firstIndex(where: { $0.id == editId }) {
                    messages[idx] = newMsg
                    memberDirectory[newMsg.senderId] = newMsg.senderName
                    MessageInteractionStore.shared.ingest(newMsg)
                }
            } catch {
                self.error = error
                inputText = text // Revert
                editingMessageId = editId
            }
        } else {
            do {
                let response = try await messagingRepository.sendMessage(conversationId: conversationId, request: request)
                if let newMsg = response.data {
                    if !messages.contains(where: { $0.id == newMsg.id }) {
                        messages.append(newMsg)
                    }
                    memberDirectory[newMsg.senderId] = newMsg.senderName
                    MessageInteractionStore.shared.ingest(newMsg)
                }
            } catch {
                self.error = error
                inputText = text // Revert
            }
        }
    }

    public func applyConvertedToTask(_ updated: MessageDTO) {
        if let idx = messages.firstIndex(where: { $0.id == updated.id }) {
            messages[idx] = updated
        }
        MessageInteractionStore.shared.ingest(updated)
    }
    
    public func deleteMessage(id: UUID) async {
        do {
            _ = try await messagingRepository.deleteMessage(messageId: id)
            if let idx = messages.firstIndex(where: { $0.id == id }) {
                // optimistic — keep all Phase 3 metadata on the tombstone
                let old = messages[idx]
                messages[idx] = MessageDTO(
                    id: old.id,
                    conversationId: old.conversationId,
                    senderId: old.senderId,
                    senderName: old.senderName,
                    body: old.body,
                    messageType: old.messageType,
                    parentId: old.parentId,
                    replyCount: old.replyCount,
                    threadPreviewText: old.threadPreviewText,
                    linkedTask: old.linkedTask,
                    reactions: old.reactions,
                    isPinned: old.isPinned,
                    pinnedBy: old.pinnedBy,
                    pinnedAt: old.pinnedAt,
                    isBookmarkedByMe: old.isBookmarkedByMe,
                    editedAt: old.editedAt,
                    deletedAt: Date(),
                    createdAt: old.createdAt
                )
            }
        } catch {
            self.error = error
        }
    }
    
    private func sendTypingIndicator() {
        Task {
            try? await messagingRepository.sendTypingIndicator(conversationId: conversationId, request: TypingIndicatorRequest(userId: currentUserId))
        }
    }
    
    private func markRead() async {
        guard let id = lastMessageId else { return }
        do {
            _ = try await messagingRepository.markRead(conversationId: conversationId, request: MarkReadRequest(lastReadMessageId: id))
        } catch {}
    }
    
    private func handleRealtimeEvent(_ event: RealTimeProvider.ServerEvent) {
        guard let payload = event.payload,
              let convIdStr = payload["conversationId"],
              convIdStr == conversationId.uuidString else {
            return
        }
        
        Task { @MainActor in
            switch event.type {
            case "message.new",
                 "message.updated",
                 "message.deleted",
                 "message.reaction_added",
                 "message.reaction_removed",
                 "message.pinned",
                 "message.unpinned",
                 "message.task_linked":
                await fetchMessages()
            case "conversation.typing_started":
                if let typingIdStr = payload["userId"],
                   let typingId = UUID(uuidString: typingIdStr),
                   typingId != currentUserId {
                    self.typingUsers[typingId] = Date()
                    self.isTypingIndicatorVisible = true
                    self.scheduleTypingCleanup(for: typingId)
                }
            case "conversation.read":
                if let userIdStr = payload["userId"],
                   let userId = UUID(uuidString: userIdStr) {
                    memberReadTimes[userId] = Date()
                }
            default:
                break
            }
        }
    }
    
    private func scheduleTypingCleanup(for userId: UUID) {
        typingCleanupTimers[userId]?.invalidate()
        typingCleanupTimers[userId] = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.typingUsers.removeValue(forKey: userId)
                if self?.typingUsers.isEmpty == true {
                    self?.isTypingIndicatorVisible = false
                }
            }
        }
    }

    private func mergeMemberDirectory(from messages: [MessageDTO]) {
        for message in messages {
            memberDirectory[message.senderId] = message.senderName
        }
    }

    private func refreshMemberDirectory() async {
        do {
            let response = try await messagingRepository.getConversation(id: conversationId)
            guard let members = response.data?.members else { return }

            var updated = memberDirectory
            var readTimes = memberReadTimes
            for member in members {
                updated[member.userId] = member.displayName
                if let lastRead = member.lastReadAt {
                    readTimes[member.userId] = lastRead
                }
            }
            memberDirectory = updated
            memberReadTimes = readTimes
        } catch {
            // Message rendering can proceed with sender names if member lookup fails.
        }
    }

    public func lastReadMessageId(for userId: UUID) -> UUID? {
        guard let readDate = memberReadTimes[userId] else { return nil }
        for msg in messages.reversed() {
            if let msgDate = msg.createdAt, msgDate <= readDate {
                return msg.id
            }
        }
        return nil
    }

    public func lastReaders(for messageId: UUID) -> [UUID] {
        var readers: [UUID] = []
        for (userId, _) in memberReadTimes {
            if userId != currentUserId {
                if lastReadMessageId(for: userId) == messageId {
                    readers.append(userId)
                }
            }
        }
        return readers
    }

    public func readersOfMessage(_ message: MessageDTO) -> [UUID] {
        guard let messageDate = message.createdAt else { return [] }
        return memberReadTimes.compactMap { userId, readDate in
            if userId != currentUserId && readDate >= messageDate {
                return userId
            }
            return nil
        }
    }
}
