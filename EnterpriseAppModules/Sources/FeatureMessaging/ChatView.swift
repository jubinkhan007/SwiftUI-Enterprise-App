import SwiftUI
import SharedModels
import DesignSystem

public struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    let conversationName: String
    let currentUserId: UUID
    
    public init(viewModel: ChatViewModel, conversationName: String, currentUserId: UUID) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.conversationName = conversationName
        self.currentUserId = currentUserId
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
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

                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isCurrentUser: message.senderId == currentUserId,
                                onDelete: message.senderId == currentUserId && message.deletedAt == nil ? {
                                    Task { await viewModel.deleteMessage(id: message.id) }
                                } : nil,
                                onEdit: message.senderId == currentUserId && message.deletedAt == nil ? {
                                    viewModel.editingMessageId = message.id
                                    viewModel.inputText = message.body
                                } : nil
                            )
                            .id(message.id)
                        }
                    }
                    .padding()

                    if viewModel.isTypingIndicatorVisible {
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
                }
                .onChange(of: viewModel.messages.last?.id) { lastId in
                    if let lastId {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isTypingIndicatorVisible) { isTyping in
                    if isTyping {
                        withAnimation {
                            proxy.scrollTo("typing_indicator", anchor: .bottom)
                        }
                    }
                }
            }
            
            ChatInputBar(
                text: $viewModel.inputText,
                isEditing: viewModel.editingMessageId != nil,
                onCancelEdit: {
                    viewModel.editingMessageId = nil
                    viewModel.inputText = ""
                },
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            )
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(conversationName)
        .task {
            if viewModel.messages.isEmpty {
                await viewModel.fetchMessages()
            }
        }
    }
}
