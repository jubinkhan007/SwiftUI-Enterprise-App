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
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isCurrentUser: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            ChatInputBar(text: $viewModel.inputText) {
                Task {
                    await viewModel.sendMessage()
                }
            }
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
