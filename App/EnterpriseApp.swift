import SwiftUI
import SwiftData
import FeatureAuth
import FeatureOrganization
import FeatureDashboard
import FeatureInbox
import FeatureMessaging
import FeatureMeetings
import DesignSystem
import AppNetwork
import AppData
import Domain
import SharedModels

@main
struct EnterpriseApp: App {
    let modelContainer: ModelContainer
    @StateObject private var authManager: AppData.AuthManager
    
    init() {
        do {
            modelContainer = try ModelContainer(
                for: LocalTaskItem.self,
                LocalSyncOperation.self,
                LocalOrganization.self,
                LocalSpace.self,
                LocalProject.self,
                LocalTaskList.self,
                HierarchySyncCursor.self
            )
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }

        let service = AppData.LiveAuthService.mappedErrors(configuration: AppNetwork.APIConfiguration.current)
        self._authManager = StateObject(wrappedValue: AppData.AuthManager(authService: service))
    }
    
    var body: some Scene {
        WindowGroup {
            AuthGateView(authManager: authManager) { session, manager in
                // After auth, gate on organization selection
                OrganizationGateView(
                    session: session,
                    authManager: manager,
                    viewModel: OrganizationGateViewModel()
                ) { selectedOrg in
                    AuthenticatedRootView(
                        session: session,
                        authManager: manager,
                        selectedOrg: selectedOrg,
                        modelContainer: modelContainer
                    )
                }
            }
        }
    }
}

struct AuthenticatedRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let session: Domain.AuthSession
    let authManager: AppData.AuthManager
    let selectedOrg: OrganizationDTO
    let viewModel: DashboardViewModel
    let apiClient: APIClientProtocol
    let integrationRepository: IntegrationRepositoryProtocol
    let messagingRepository: MessagingRepositoryProtocol
    let meetingRepository: MeetingRepositoryProtocol
    let realtimeProvider: RealTimeProvider
    @StateObject private var sidebarViewModel: SidebarViewModel
    @StateObject private var orgGateViewModel: OrganizationGateViewModel
    @StateObject private var syncManager: SyncEngineManager
    @StateObject private var inboxViewModel: InboxViewModel
    @StateObject private var conversationListViewModel: ConversationListViewModel
    @State private var showTeamManagement = false
    @State private var showingCreateTask = false
    @State private var viewType: DashboardViewType = .list
    @State private var projectSettingsSheet: ProjectSettingsSheetItem? = nil
    @State private var selectedNotificationTask: TaskItemDTO? = nil
    @State private var isLoadingTask: Bool = false
    @State private var meetingMembers: [MeetingPickableMember] = []

    private struct ProjectSettingsSheetItem: Identifiable {
        let id: UUID
    }
    
    init(session: Domain.AuthSession, authManager: AppData.AuthManager, selectedOrg: OrganizationDTO, modelContainer: ModelContainer) {
        self.session = session
        self.authManager = authManager
        self.selectedOrg = selectedOrg
        
        let apiClient = APIClient()
        let localStore = TaskLocalStore(container: modelContainer)
        let operationStore = LocalSyncOperationStore(container: modelContainer)
        let syncEngine = GlobalSyncEngine(apiClient: apiClient, taskLocalStore: localStore, operationStore: operationStore)
        let taskRepository = TaskRepository(
            apiClient: apiClient,
            localStore: localStore,
            operationStore: operationStore
        )
        let activityRepository = TaskActivityRepository(apiClient: apiClient)
        let hierarchyLocalStore = HierarchyLocalStore(container: modelContainer)
        let hierarchyRepo = HierarchyRepository(apiClient: apiClient, localStore: hierarchyLocalStore)
        let workflowRepo = WorkflowRepository(apiClient: apiClient)
        let attachmentRepo = AttachmentRepository(apiClient: apiClient)
        let analyticsRepo = AnalyticsRepository(apiClient: apiClient)
        let integrationRepo = IntegrationRepository(apiClient: apiClient)
        let messagingRepo = LiveMessagingService(apiClient: apiClient)
        let meetingRepo = LiveMeetingService(apiClient: apiClient)
        let productivityRepo = LiveProductivityService(apiClient: apiClient)
        let presenceRepo = LivePresenceService(apiClient: apiClient)
        let notificationRepo = LiveNotificationService(apiClient: apiClient)
        let rtProvider = RealTimeProvider()

        // Configure shared stores once at app startup so any view can use them.
        Task { @MainActor in
            PresenceStore.shared.configure(presenceRepository: presenceRepo, currentUserId: session.user.id)
            MeetingsStore.shared.configure(repository: meetingRepo, currentUserId: session.user.id)
            DraftStore.shared.configure(repository: productivityRepo, currentUserId: session.user.id, realtimeProvider: rtProvider)
            ScheduledMessageStore.shared.configure(repository: productivityRepo, realtimeProvider: rtProvider)
            ReminderStore.shared.configure(repository: productivityRepo, realtimeProvider: rtProvider)
            TemplateStore.shared.configure(
                repository: productivityRepo,
                currentUserName: session.user.displayName,
                currentUserEmail: session.user.email,
                currentOrgName: selectedOrg.name
            )
        }
        
        self.viewModel = DashboardViewModel(
            taskRepository: taskRepository,
            activityRepository: activityRepository,
            hierarchyRepository: hierarchyRepo,
            workflowRepository: workflowRepo,
            attachmentRepository: attachmentRepo,
            analyticsRepository: analyticsRepo
        )
        self.apiClient = apiClient
        self.integrationRepository = integrationRepo
        self.messagingRepository = messagingRepo
        self.meetingRepository = meetingRepo
        self.realtimeProvider = rtProvider
        
        self._sidebarViewModel = StateObject(wrappedValue: SidebarViewModel(hierarchyRepository: hierarchyRepo))
        self._syncManager = StateObject(wrappedValue: SyncEngineManager(engine: syncEngine, operationStore: operationStore, taskLocalStore: localStore))
        
        let gateVM = OrganizationGateViewModel()
        gateVM.selectedOrg = selectedOrg
        gateVM.organizations = [selectedOrg]
        self._orgGateViewModel = StateObject(wrappedValue: gateVM)
        self._inboxViewModel = StateObject(wrappedValue: InboxViewModel(notificationRepository: notificationRepo))
        self._conversationListViewModel = StateObject(wrappedValue: ConversationListViewModel(messagingRepository: messagingRepo, realtimeProvider: rtProvider))
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: sidebarViewModel,
                syncManager: syncManager,
                session: session,
                authManager: authManager,
                selectedOrg: selectedOrg,
                showTeamManagement: $showTeamManagement
            )
        } detail: {
            NavigationStack {
                VStack(spacing: 0) {
                    if sidebarViewModel.selectedArea == .inbox {
                        InboxView(viewModel: inboxViewModel, onNotificationTap: handleNotificationTap)
                    } else if sidebarViewModel.selectedArea == .messages {
                        ConversationListView(
                            viewModel: conversationListViewModel,
                            messagingRepository: messagingRepository,
                            apiClient: apiClient,
                            realtimeProvider: realtimeProvider,
                            currentUserId: session.user.id,
                            taskRepository: viewModel.taskRepository,
                            hierarchy: sidebarViewModel.areas
                        )
                    } else if sidebarViewModel.selectedArea == .meetings {
                        MeetingsHomeView(
                            currentUserId: session.user.id,
                            repository: meetingRepository,
                            realtimeProvider: realtimeProvider,
                            availableMembers: meetingMembers
                        )
                    } else if sidebarViewModel.selectedArea == .productivity {
                        ProductivityHubView(canManageOrgTemplates: isOrgAdmin)
                    } else {
                        if horizontalSizeClass == .compact {
                            compactHeaderControls
                        }
                        DashboardView(viewModel: viewModel, viewType: $viewType)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        personMenu
                    }

                    if horizontalSizeClass != .compact {
                        ToolbarItem(placement: .principal) {
                            HStack(spacing: AppSpacing.sm) {
                                WorkspaceSwitcherView(viewModel: orgGateViewModel)

                                Picker("View", selection: $viewType) {
                                    ForEach(DashboardViewType.allCases) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 150)
                            }
                        }
                    }

                    if sidebarViewModel.selectedArea != .inbox && sidebarViewModel.selectedArea != .messages && sidebarViewModel.selectedArea != .meetings && sidebarViewModel.selectedArea != .productivity {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingCreateTask = true
                            } label: {
                                Image(systemName: "plus")
                                    .appFont(AppTypography.headline)
                                    .foregroundColor(AppColors.brandPrimary)
                            }
                        }
                    }

                    if case .project(let projectId) = sidebarViewModel.selectedArea {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                projectSettingsSheet = ProjectSettingsSheetItem(id: projectId)
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.subheadline)
                            }
                        }
                    }

                    if horizontalSizeClass != .compact {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showTeamManagement = true
                            } label: {
                                Image(systemName: "person.3")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showTeamManagement) {
                    TeamManagementView(orgId: selectedOrg.id)
                }
                .sheet(isPresented: $showingCreateTask) {
                    CreateTaskSheet(
                        viewModel: CreateTaskViewModel(taskRepository: viewModel.taskRepository, listId: viewModel.query.listId),
                        hierarchy: sidebarViewModel.areas
                    ) {
                        Task { await viewModel.refresh() }
                    }
                    .presentationDetents([.medium, .large])
                }
                .sheet(item: $projectSettingsSheet) { item in
                    ProjectSettingsView(projectId: item.id, workflowRepository: viewModel.workflowRepository, integrationRepository: integrationRepository)
                }
                .sheet(item: $selectedNotificationTask) { task in
                    NavigationStack {
                        TaskDetailView(
                            viewModel: TaskDetailViewModel(
                                task: task,
                                taskRepository: viewModel.taskRepository,
                                activityRepository: viewModel.activityRepository,
                                hierarchyRepository: viewModel.hierarchyRepository,
                                workflowRepository: viewModel.workflowRepository,
                                attachmentRepository: viewModel.attachmentRepository
                            )
                        )
                    }
                }
            }
        }
        .overlay {
            if isLoadingTask {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .padding()
                        .background(AppColors.surfacePrimary)
                        .cornerRadius(8)
                }
            }
        }
        .onChange(of: sidebarViewModel.selectedArea) { oldValue, newValue in
            viewModel.handleSidebarSelection(newValue, viewType: viewType)
        }
        .task {
            await orgGateViewModel.fetchOrganizations()
            if sidebarViewModel.areas.isEmpty {
                await sidebarViewModel.fetchHierarchy()
            }
            if meetingMembers.isEmpty {
                await loadMeetingMembers()
            }
            await syncManager.refresh()
            syncManager.syncNow()
        }
    }
    
    private var personMenu: some View {
        Menu {
            Text("Signed in as \(session.user.displayName)")
            Text("Workspace: \(selectedOrg.name)")
            Divider()
            Button {
                showTeamManagement = true
            } label: {
                Label("Team Management", systemImage: "person.3")
            }
            Divider()
            Button("Sign Out", role: .destructive) {
                OrganizationContext.shared.clear()
                authManager.signOut()
            }
        } label: {
            Image(systemName: "person.circle")
                .font(.title3)
        }
    }

    private func handleNotificationTap(_ notification: NotificationDTO) {
        if notification.type == "mention" || notification.type.starts(with: "task.") {
            var taskIdString: String? = nil
            if notification.entityType == "task" {
                taskIdString = notification.entityId.uuidString
            } else if let payloadStr = notification.payloadJson,
                      let data = payloadStr.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                taskIdString = dict["taskId"]
            }
            
            if let idString = taskIdString, let taskId = UUID(uuidString: idString) {
                Task {
                    isLoadingTask = true
                    do {
                        let taskItem = try await viewModel.taskRepository.getTask(id: taskId)
                        selectedNotificationTask = taskItem
                    } catch {
                        print("Failed to fetch task from notification: \(error)")
                    }
                    isLoadingTask = false
                }
            }
        } else if notification.type == "message.mention" || notification.entityType == "conversation" {
            sidebarViewModel.selectedArea = .messages
            conversationListViewModel.pendingChannelId = notification.entityId
        } else if notification.type.starts(with: "meeting.") || notification.entityType == "meeting" {
            sidebarViewModel.selectedArea = .meetings
            // MeetingsHomeView observes MeetingsStore; tap-to-open requires the user
            // to pick the meeting from the list. Direct nav lands in 4-A polish.
        } else if notification.type.starts(with: "reminder.") || notification.entityType == "reminder"
                  || notification.type.starts(with: "scheduled_message.") {
            sidebarViewModel.selectedArea = .productivity
        }
    }

    /// Whether the current user can create/edit org-wide templates.
    /// Currently derived from org ownership; broader admin-role detection lands
    /// when we surface OrganizationMemberDTO.role on the session.
    private var isOrgAdmin: Bool {
        selectedOrg.ownerId == session.user.id
    }

    private func loadMeetingMembers() async {
        let endpoint = OrganizationEndpoint.listMembers(orgId: selectedOrg.id, configuration: .current)
        do {
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[OrganizationMemberDTO]>.self)
            let mapped: [MeetingPickableMember] = (response.data ?? [])
                .filter { $0.userId != session.user.id }
                .map { MeetingPickableMember(id: $0.userId, displayName: $0.displayName, email: $0.email) }
            meetingMembers = mapped
        } catch {
            // Non-fatal — sheet just shows "No org members available."
        }
    }

    private var compactHeaderControls: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                WorkspaceSwitcherView(viewModel: orgGateViewModel)
                Spacer(minLength: 0)
            }

            Picker("View", selection: $viewType) {
                ForEach(DashboardViewType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.sm)
        .background(AppColors.backgroundPrimary)
    }
}
