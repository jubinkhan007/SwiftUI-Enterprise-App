import SwiftUI
import SharedModels
import DesignSystem
import Domain
import AppNetwork

public struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var selectedThreadMessage: MessageDTO?
    @State private var actionSheetMessage: MessageDTO?
    @State private var createTaskMessage: MessageDTO?
    @State private var showChannelSettings = false
    @State private var showTemplatePicker = false
    @State private var showScheduleSend = false
    @State private var commandError: String?

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
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerSheet(conversationId: viewModel.conversationId) { rendered in
                    viewModel.inputText = rendered
                }
            }
            .sheet(isPresented: $showScheduleSend) {
                ScheduleSendSheet(
                    messageBody: viewModel.inputText,
                    conversationId: viewModel.conversationId
                ) { _ in
                    viewModel.inputText = ""
                }
            }
            .alert("Command", isPresented: Binding(get: { commandError != nil }, set: { if !$0 { commandError = nil } })) {
                Button("OK") { commandError = nil }
            } message: {
                Text(commandError ?? "")
            }
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
                if handleSlashCommandIfPresent() { return }
                Task { await viewModel.sendMessage() }
            },
            conversationId: viewModel.conversationId,
            parentId: nil,
            onPickTemplate: { showTemplatePicker = true },
            onScheduleSend: { showScheduleSend = true },
            onCommandPicked: { spec in
                viewModel.inputText = "/\(spec.name) "
            }
        )
    }

    /// Returns true if input was a slash command and was handled (so the regular
    /// send should be skipped). Built-in commands not handled here just fall through.
    private func handleSlashCommandIfPresent() -> Bool {
        guard let (spec, rest) = SlashCommandRegistry.shared.parse(viewModel.inputText) else {
            return false
        }
        switch spec.name {
        case "me":
            let trimmed = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                viewModel.inputText = "_\(trimmed)_"
                Task { await viewModel.sendMessage() }
            }
            return true
        case "schedule":
            let trimmed = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                viewModel.inputText = trimmed
            }
            showScheduleSend = true
            return true
        case "template":
            let shortcut = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            if shortcut.isEmpty {
                showTemplatePicker = true
            } else if let tpl = TemplateStore.shared.findByShortcut(shortcut) {
                Task {
                    let rendered = await TemplateStore.shared.render(tpl, conversationId: viewModel.conversationId)
                    viewModel.inputText = rendered
                }
            } else {
                showTemplatePicker = true
            }
            return true
        case "remind":
            if let (when, body) = SlashCommandRegistry.parseRemind(rest) {
                Task {
                    _ = await ReminderStore.shared.create(body: body, remindAt: when)
                    viewModel.inputText = ""
                }
            } else {
                commandError = "Usage: /remind me in 2h <text>"
            }
            return true
        case "status":
            // Form: /status [emoji] text
            let trimmed = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { commandError = "Usage: /status [emoji] <text>"; return true }
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            let emoji: String?
            let text: String
            if parts.count == 2, parts[0].count <= 4 {
                emoji = parts[0]; text = parts[1]
            } else {
                emoji = nil; text = trimmed
            }
            Task {
                _ = await PresenceStore.shared.setCustomStatus(emoji: emoji, text: text, expiresAt: nil)
                viewModel.inputText = ""
            }
            return true
        case "task":
            // Pre-fill: title comes from rest of input; open the convert sheet against
            // a placeholder message wrapping the text so the existing flow can be reused.
            let title = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty { commandError = "Usage: /task <title>"; return true }
            let synthetic = MessageDTO(
                id: UUID(), conversationId: viewModel.conversationId, senderId: currentUserId,
                senderName: "you", body: title, messageType: "text",
                editedAt: nil, deletedAt: nil, createdAt: Date()
            )
            createTaskMessage = synthetic
            viewModel.inputText = ""
            return true
        case "help":
            commandError = SlashCommandRegistry.shared.catalog
                .map { "/\($0.name) — \($0.summary)" }
                .joined(separator: "\n")
            viewModel.inputText = ""
            return true
        default:
            return false
        }
    }

    private func messageRow(for message: MessageDTO) -> some View {
        MessageBubbleView(
            message: message,
            isCurrentUser: message.senderId == currentUserId,
            currentUserId: currentUserId,
            participantNames: viewModel.memberDirectory,
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
        ConvertMessageToTaskSheet(
            message: message,
            hierarchy: hierarchy,
            messagingRepository: messagingRepository
        ) { response in
            viewModel.applyConvertedToTask(response.message)
        }
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
