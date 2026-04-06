import Foundation
import SwiftUI
import Domain
import SharedModels
import AppNetwork

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public private(set) var messages: [MessageDTO] = []
    @Published public var inputText: String = ""
    @Published public private(set) var isLoading: Bool = false
    @Published public var error: Error?
    
    public let conversationId: UUID
    private let messagingRepository: MessagingRepositoryProtocol
    private let realtimeProvider: RealTimeProvider
    private var lastMessageId: UUID?
    private var realtimeListenerID: UUID?
    
    public init(conversationId: UUID, messagingRepository: MessagingRepositoryProtocol, realtimeProvider: RealTimeProvider) {
        self.conversationId = conversationId
        self.messagingRepository = messagingRepository
        self.realtimeProvider = realtimeProvider
        
        realtimeListenerID = realtimeProvider.addEventListener { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleRealtimeEvent(event)
            }
        }
    }

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
            self.messages = response.data?.reversed() ?? []
            
            if let last = self.messages.last {
                self.lastMessageId = last.id
                await markRead()
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    public func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let request = SendMessageRequest(body: text)
        inputText = "" // Optimistic
        
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
    
    private func markRead() async {
        guard let id = lastMessageId else { return }
        do {
            _ = try await messagingRepository.markRead(conversationId: conversationId, request: MarkReadRequest(lastReadMessageId: id))
        } catch {}
    }
    
    private func handleRealtimeEvent(_ event: RealTimeProvider.ServerEvent) {
        guard event.type == "message.new",
              let payload = event.payload,
              let convIdStr = payload["conversationId"],
              convIdStr == conversationId.uuidString else {
            return
        }
        
        Task {
            await fetchMessages()
        }
    }
}
