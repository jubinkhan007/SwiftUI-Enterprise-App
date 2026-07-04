import SwiftUI
import SharedModels
import DesignSystem
import Domain
import AppNetwork

@MainActor
final class ThreadDetailViewModel: ObservableObject {
    @Published private(set) var rootMessage: MessageDTO?
    @Published private(set) var replies: [MessageDTO] = []
    @Published var inputText: String = ""
    @Published var isLoading = false
    @Published var error: Error?

    let rootMessageId: UUID
    let currentUserId: UUID
    private let messagingRepository: MessagingRepositoryProtocol
    private let realtimeProvider: RealTimeProvider
    private var realtimeListenerID: UUID?

    init(rootMessageId: UUID, currentUserId: UUID, messagingRepository: MessagingRepositoryProtocol, realtimeProvider: RealTimeProvider) {
        self.rootMessageId = rootMessageId
        self.currentUserId = currentUserId
        self.messagingRepository = messagingRepository
        self.realtimeProvider = realtimeProvider

        self.realtimeListenerID = realtimeProvider.addEventListener { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleRealtimeEvent(event)
            }
        }
    }

    deinit {
        if let id = realtimeListenerID {
            let provider = realtimeProvider
            Task { @MainActor in
                provider.removeEventListener(id)
            }
        }
    }

    private func handleRealtimeEvent(_ event: RealTimeProvider.ServerEvent) {
        guard let payload = event.payload,
              let convIdStr = payload["conversationId"],
              let root = rootMessage,
              convIdStr == root.conversationId.uuidString else {
            return
        }

        switch event.type {
        case "message.new", "message.updated", "message.deleted":
            Task {
                await load()
            }
        default:
            break
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await messagingRepository.getThread(messageId: rootMessageId)
            rootMessage = response.data?.rootMessage
            replies = response.data?.replies ?? []
        } catch {
            self.error = error
        }
    }

    func sendReply() async {
        guard let rootMessage, !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        do {
            let response = try await messagingRepository.sendMessage(
                conversationId: rootMessage.conversationId,
                request: SendMessageRequest(body: text, parentId: rootMessage.id)
            )
            if let reply = response.data {
                replies.append(reply)
            }
        } catch {
            self.error = error
            inputText = text
        }
    }
}

public struct ThreadDetailView: View {
    @StateObject private var viewModel: ThreadDetailViewModel
    let currentUserId: UUID

    public init(rootMessageId: UUID, currentUserId: UUID, messagingRepository: MessagingRepositoryProtocol, realtimeProvider: RealTimeProvider) {
        _viewModel = StateObject(wrappedValue: ThreadDetailViewModel(rootMessageId: rootMessageId, currentUserId: currentUserId, messagingRepository: messagingRepository, realtimeProvider: realtimeProvider))
        self.currentUserId = currentUserId
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let root = viewModel.rootMessage {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Original Message")
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.textSecondary)

                        MessageBubbleView(message: root, isCurrentUser: root.senderId == currentUserId)

                        Divider()

                        Text("Replies")
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.textSecondary)

                        ForEach(viewModel.replies) { reply in
                            MessageBubbleView(message: reply, isCurrentUser: reply.senderId == currentUserId)
                        }
                    }
                    .padding()
                }

                ChatInputBar(text: $viewModel.inputText, onSend: {
                    Task { await viewModel.sendReply() }
                })
            } else if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                Spacer()
                Text("Thread unavailable")
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
        }
        .navigationTitle("Thread")
        .task {
            await viewModel.load()
        }
    }
}
