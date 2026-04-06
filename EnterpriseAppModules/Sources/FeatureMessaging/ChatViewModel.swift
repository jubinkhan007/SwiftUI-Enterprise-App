import Foundation
import SwiftUI
import Combine
import Domain
import SharedModels
import AppNetwork

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public private(set) var messages: [MessageDTO] = []
    @Published public var inputText: String = ""
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isLoadingMore: Bool = false
    @Published public private(set) var hasMoreMessages: Bool = false
    @Published public var error: Error?
    @Published public var editingMessageId: UUID?
    @Published public var isTypingIndicatorVisible: Bool = false
    
    public let conversationId: UUID
    public let currentUserId: UUID
    private let messagingRepository: MessagingRepositoryProtocol
    private let realtimeProvider: RealTimeProvider
    private var lastMessageId: UUID?
    private var realtimeListenerID: UUID?
    private var typingTimer: Timer?
    
    public init(conversationId: UUID, currentUserId: UUID, messagingRepository: MessagingRepositoryProtocol, realtimeProvider: RealTimeProvider) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        self.messagingRepository = messagingRepository
        self.realtimeProvider = realtimeProvider
        
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
            self.hasMoreMessages = fetched.count == 50

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
                }
            } catch {
                self.error = error
                inputText = text // Revert
            }
        }
    }
    
    public func deleteMessage(id: UUID) async {
        do {
            _ = try await messagingRepository.deleteMessage(messageId: id)
            if let idx = messages.firstIndex(where: { $0.id == id }) {
                // optimistic
                var old = messages[idx]
                messages[idx] = MessageDTO(id: old.id, conversationId: old.conversationId, senderId: old.senderId, senderName: old.senderName, body: old.body, messageType: old.messageType, editedAt: old.editedAt, deletedAt: Date(), createdAt: old.createdAt)
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
            case "message.new", "message.updated", "message.deleted":
                await fetchMessages()
            case "conversation.typing_started":
                if let typingIdStr = payload["userId"], typingIdStr != currentUserId.uuidString {
                    showTypingIndicator()
                }
            default:
                break
            }
        }
    }
    
    private func showTypingIndicator() {
        self.isTypingIndicatorVisible = true
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isTypingIndicatorVisible = false
            }
        }
    }
}
