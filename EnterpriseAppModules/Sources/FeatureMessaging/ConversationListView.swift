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
    let taskRepository: TaskRepositoryProtocol
    let hierarchy: [HierarchyTreeDTO.SpaceNode]

    @State private var showingNewSheet = false
    @State private var showingGlobalSearch = false
    @State private var navigationPath = NavigationPath()

    public init(
        viewModel: ConversationListViewModel,
        messagingRepository: MessagingRepositoryProtocol,
        apiClient: APIClientProtocol,
        realtimeProvider: RealTimeProvider,
        currentUserId: UUID,
        taskRepository: TaskRepositoryProtocol,
        hierarchy: [HierarchyTreeDTO.SpaceNode]
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.messagingRepository = messagingRepository
        self.apiClient = apiClient
        self.realtimeProvider = realtimeProvider
        self.currentUserId = currentUserId
        self.taskRepository = taskRepository
        self.hierarchy = hierarchy
    }
    
    public var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                searchBar
                contentArea
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Messages")
            .applyNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: AppSpacing.sm) {
                        Button {
                            showingGlobalSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppColors.brandPrimary)
                        }

                        Button {
                            showingNewSheet = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(AppColors.brandPrimary)
                        }
                    }
                }
            }
            .navigationDestination(for: ConversationListItemDTO.self) { conv in
                let chatVM = ChatViewModel(
                    conversationId: conv.id,
                    currentUserId: currentUserId,
                    messagingRepository: messagingRepository,
                    realtimeProvider: realtimeProvider
                )
                ChatView(
                    viewModel: chatVM,
                    conversationName: conv.name ?? "Unknown",
                    currentUserId: currentUserId,
                    messagingRepository: messagingRepository,
                    taskRepository: taskRepository,
                    hierarchy: hierarchy,
                    apiClient: apiClient
                )
            }
            .navigationDestination(for: ConversationDTO.self) { conv in
                let chatVM = ChatViewModel(
                    conversationId: conv.id,
                    currentUserId: currentUserId,
                    messagingRepository: messagingRepository,
                    realtimeProvider: realtimeProvider
                )
                ChatView(
                    viewModel: chatVM,
                    conversationName: conv.name ?? "Unknown",
                    currentUserId: currentUserId,
                    messagingRepository: messagingRepository,
                    taskRepository: taskRepository,
                    hierarchy: hierarchy,
                    apiClient: apiClient
                )
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
            .sheet(isPresented: $showingGlobalSearch) {
                GlobalSearchView(messagingRepository: messagingRepository)
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

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textSecondary)
                .font(.system(size: 15))

            TextField("Search conversations…", text: $viewModel.searchQuery)
                .appFont(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
                .autocorrectionDisabled()

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .background(AppColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundPrimary)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading && viewModel.conversations.isEmpty {
            Spacer()
            ProgressView()
                .tint(AppColors.brandPrimary)
            Spacer()
        } else if viewModel.filteredConversations.isEmpty {
            emptyState
        } else {
            List(viewModel.filteredConversations) { conv in
                NavigationLink(value: conv) {
                    conversationRow(conv)
                }
                .listRowBackground(AppColors.backgroundPrimary)
                .listRowSeparatorTint(AppColors.borderDefault)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundPrimary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColors.surfaceElevated)
                    .frame(width: 80, height: 80)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(AppColors.brandGradient)
            }
            VStack(spacing: AppSpacing.xs) {
                Text("No Conversations Yet")
                    .appFont(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                Text("Start a new message with a teammate.")
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showingNewSheet = true
            } label: {
                Label("New Message", systemImage: "square.and.pencil")
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.brandPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(AppColors.backgroundPrimary)
    }

    // MARK: - Row

    private func conversationRow(_ conv: ConversationListItemDTO) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppColors.brandPrimary.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String((conv.name ?? "U").prefix(1)).uppercased())
                    .appFont(AppTypography.headline)
                    .foregroundStyle(AppColors.brandGradient)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(conv.name ?? "Unknown")
                    .appFont(AppTypography.body)
                    .fontWeight(conv.unreadCount > 0 ? .semibold : .regular)
                    .foregroundColor(AppColors.textPrimary)

                if let msg = conv.lastMessage {
                    Text("\(msg.senderName): \(msg.body)")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(conv.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let date = conv.lastMessageAt {
                    Text(date, style: .time)
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }

                if conv.unreadCount > 0 {
                    Text("\(conv.unreadCount)")
                        .appFont(AppTypography.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppColors.brandPrimary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private extension View {
    @ViewBuilder
    func applyNavigationChrome() -> some View {
#if os(iOS)
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
#else
        self
#endif
    }
}
