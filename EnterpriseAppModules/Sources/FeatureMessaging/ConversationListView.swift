import SwiftUI
import SharedModels
import DesignSystem
import AppNetwork
import Domain

public struct ConversationListView: View {
    @StateObject private var viewModel: ConversationListViewModel
    let messagingRepository: MessagingRepositoryProtocol
    let apiClient: APIClientProtocol
    let realtimeProvider: RealTimeProvider
    let currentUserId: UUID

    @State private var showingNewSheet = false
    @State private var navigationPath = NavigationPath()

    public init(viewModel: ConversationListViewModel, messagingRepository: MessagingRepositoryProtocol, apiClient: APIClientProtocol, realtimeProvider: RealTimeProvider, currentUserId: UUID) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.messagingRepository = messagingRepository
        self.apiClient = apiClient
        self.realtimeProvider = realtimeProvider
        self.currentUserId = currentUserId
    }
    
    public var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                searchBar
                
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.conversations.isEmpty {
                    Spacer()
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.textSecondary)
                        Text("No Conversations")
                            .appFont(AppTypography.title3)
                    }
                    Spacer()
                } else {
                    List(viewModel.filteredConversations) { conv in
                        NavigationLink(value: conv) {
                            conversationRow(conv)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .navigationDestination(for: ConversationListItemDTO.self) { conv in
                let chatVM = ChatViewModel(conversationId: conv.id, currentUserId: currentUserId, messagingRepository: messagingRepository, realtimeProvider: realtimeProvider)
                ChatView(viewModel: chatVM, conversationName: conv.name ?? "Unknown", currentUserId: currentUserId)
            }
            .navigationDestination(for: ConversationDTO.self) { conv in
                let chatVM = ChatViewModel(conversationId: conv.id, currentUserId: currentUserId, messagingRepository: messagingRepository, realtimeProvider: realtimeProvider)
                ChatView(viewModel: chatVM, conversationName: conv.name ?? "Unknown", currentUserId: currentUserId)
            }
            .sheet(isPresented: $showingNewSheet) {
                NewConversationSheet(
                    messagingRepository: messagingRepository,
                    apiClient: apiClient,
                    currentUserId: currentUserId
                ) { newConv in
                    navigationPath.append(newConv)
                    Task { await viewModel.fetchConversations() }
                }
                .presentationDetents([.medium, .large])
            }
            .task {
                if viewModel.conversations.isEmpty {
                    if let orgId = OrganizationContext.shared.orgId {
                        viewModel.setOrgId(orgId)
                    }
                    await viewModel.fetchConversations()
                }
            }
            .refreshable {
                await viewModel.fetchConversations()
            }
        }
    }
    
    private var searchBar: some View {
        AppTextField("Search...", text: $viewModel.searchQuery)
            .padding()
            .background(AppColors.surfacePrimary)
    }
    
    private func conversationRow(_ conv: ConversationListItemDTO) -> some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(AppColors.surfaceElevated)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((conv.name ?? "U").prefix(1)).uppercased())
                        .appFont(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(conv.name ?? "Unknown")
                    .appFont(AppTypography.body)
                    .fontWeight(conv.unreadCount > 0 ? .bold : .regular)
                
                if let msg = conv.lastMessage {
                    Text("\(msg.senderName): \(msg.body)")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(conv.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                if let dates = conv.lastMessageAt {
                    Text(dates, style: .time)
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                if conv.unreadCount > 0 {
                    ZStack {
                        Capsule()
                            .fill(AppColors.brandPrimary)
                            .frame(minWidth: 20, minHeight: 20)
                        
                        Text("\(conv.unreadCount)")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
