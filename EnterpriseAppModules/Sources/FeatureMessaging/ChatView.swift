import SwiftUI
import SharedModels
import DesignSystem
import Domain
import AppNetwork
import FeatureDashboard

public struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var selectedThreadMessage: MessageDTO?
    @State private var actionSheetMessage: MessageDTO?
    @State private var createTaskMessage: MessageDTO?
    @State private var showChannelSettings = false

    let conversationName: String
    let currentUserId: UUID
    let messagingRepository: MessagingRepositoryProtocol
    let taskRepository: TaskRepositoryProtocol
    let hierarchy: [HierarchyTreeDTO.SpaceNode]
    let apiClient: APIClientProtocol

    public init(
        viewModel: ChatViewModel,
        conversationName: String,
        currentUserId: UUID,
        messagingRepository: MessagingRepositoryProtocol,
        taskRepository: TaskRepositoryProtocol,
        hierarchy: [HierarchyTreeDTO.SpaceNode],
        apiClient: APIClientProtocol
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.conversationName = conversationName
        self.currentUserId = currentUserId
        self.messagingRepository = messagingRepository
        self.taskRepository = taskRepository
        self.hierarchy = hierarchy
        self.apiClient = apiClient
    }

    public var body: some View {
        chatLayout
            .background(AppColors.backgroundPrimary)
            .navigationTitle(conversationName)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showChannelSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .task {
                if viewModel.messages.isEmpty {
                    await viewModel.fetchMessages()
                }
            }
            .sheet(item: $selectedThreadMessage, content: threadSheet)
            .sheet(item: $actionSheetMessage, content: actionsSheet)
            .sheet(item: $createTaskMessage, content: createTaskSheet)
            .sheet(isPresented: $showChannelSettings, content: channelSettingsSheet)
    }

    private var chatLayout: some View {
        VStack(spacing: 0) {
            messageScroller
            mentionHint
            composer
        }
    }

    private var messageScroller: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    loadMoreButton

                    ForEach(viewModel.messages) { message in
                        messageRow(for: message)
                    }
                }
                .padding()

                if viewModel.isTypingIndicatorVisible {
                    typingIndicator
                }
            }
            .onChange(of: viewModel.messages.last?.id) { _, lastId in
                guard let lastId else { return }
                withAnimation {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isTypingIndicatorVisible) { _, isTyping in
                guard isTyping else { return }
                withAnimation {
                    proxy.scrollTo("typing_indicator", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private var loadMoreButton: some View {
        if viewModel.hasMoreMessages {
            Button {
                Task { await viewModel.loadMoreMessages() }
            } label: {
                if viewModel.isLoadingMore {
                    ProgressView()
                } else {
                    Text("Load earlier messages")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.brandPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
        }
    }

    private var typingIndicator: some View {
        HStack {
            Text("Someone is typing...")
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
                .italic()
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, AppSpacing.md)
        .id("typing_indicator")
    }

    private var composer: some View {
        ChatInputBar(
            text: $viewModel.inputText,
            isEditing: viewModel.editingMessageId != nil,
            onCancelEdit: {
                viewModel.editingMessageId = nil
                viewModel.inputText = ""
            },
            onSend: {
                Task { await viewModel.sendMessage() }
            }
        )
    }

    private func messageRow(for message: MessageDTO) -> some View {
        MessageBubbleView(
            message: message,
            isCurrentUser: message.senderId == currentUserId,
            onDelete: deleteAction(for: message),
            onEdit: editAction(for: message),
            onOpenThread: {
                selectedThreadMessage = message
            },
            onOpenActions: {
                actionSheetMessage = message
            }
        )
        .id(message.id)
    }

    private func editAction(for message: MessageDTO) -> (() -> Void)? {
        guard message.senderId == currentUserId, message.deletedAt == nil else { return nil }
        return {
            viewModel.editingMessageId = message.id
            viewModel.inputText = message.body
        }
    }

    private func deleteAction(for message: MessageDTO) -> (() -> Void)? {
        guard message.senderId == currentUserId, message.deletedAt == nil else { return nil }
        return {
            Task { await viewModel.deleteMessage(id: message.id) }
        }
    }

    private func threadSheet(message: MessageDTO) -> some View {
        NavigationStack {
            ThreadDetailView(
                rootMessageId: message.id,
                currentUserId: currentUserId,
                messagingRepository: messagingRepository
            )
        }
    }

    private func actionsSheet(message: MessageDTO) -> some View {
        MessageActionSheet(
            message: message,
            currentUserId: currentUserId,
            interactionStore: MessageInteractionStore.shared,
            onReplyInThread: {
                selectedThreadMessage = message
            },
            onCreateTask: {
                createTaskMessage = message
            },
            onEdit: editAction(for: message),
            onDelete: deleteAction(for: message)
        )
    }

    private func createTaskSheet(message: MessageDTO) -> some View {
        CreateTaskSheet(
            viewModel: CreateTaskViewModel(
                taskRepository: taskRepository,
                listId: hierarchy.first?.projects.first?.lists.first?.id,
                initialTitle: message.body.split(separator: "\n").first.map(String.init) ?? "Follow up on message",
                initialDescription: message.body
            ),
            hierarchy: hierarchy
        ) {}
        .presentationDetents([.medium, .large])
    }

    private func channelSettingsSheet() -> some View {
        NavigationStack {
            ChannelSettingsLoaderView(
                conversationId: viewModel.conversationId,
                currentUserId: currentUserId,
                messagingRepository: messagingRepository,
                apiClient: apiClient
            )
        }
    }

    @ViewBuilder
    private var mentionHint: some View {
        if viewModel.inputText.contains("@channel") || viewModel.inputText.contains("@here") {
            HStack {
                Image(systemName: "bell.badge")
                Text(viewModel.inputText.contains("@channel") ? "@channel will notify everyone in this conversation." : "@here will notify currently active members.")
                    .appFont(AppTypography.caption1)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(AppColors.surfaceElevated)
        }
    }
}

private struct ChannelSettingsLoaderView: View {
    @Environment(\.dismiss) private var dismiss

    let conversationId: UUID
    let currentUserId: UUID
    let messagingRepository: MessagingRepositoryProtocol
    let apiClient: APIClientProtocol

    @State private var conversation: ConversationDTO?

    var body: some View {
        Group {
            if let conversation {
                ChannelSettingsView(
                    conversation: conversation,
                    currentUserId: currentUserId,
                    messagingRepository: messagingRepository,
                    apiClient: apiClient
                )
            } else {
                ProgressView()
                    .task {
                        let response = try? await messagingRepository.getConversation(id: conversationId)
                        conversation = response?.data
                        if conversation == nil {
                            dismiss()
                        }
                    }
            }
        }
    }
}
