import SwiftUI
import SwiftData
import FeatureAuth
import FeatureOrganization
import FeatureDashboard
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
            modelContainer = try ModelContainer(for: LocalTaskItem.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }

        let service = AppData.LiveAuthService.mappedErrors(configuration: AppNetwork.APIConfiguration.localVapor)
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
    @StateObject private var sidebarViewModel: SidebarViewModel
    @StateObject private var orgGateViewModel: OrganizationGateViewModel
    @State private var showTeamManagement = false
    @State private var showingCreateTask = false
    @State private var viewType: DashboardViewType = .list
    @State private var projectSettingsSheet: ProjectSettingsSheetItem? = nil

    private struct ProjectSettingsSheetItem: Identifiable {
        let id: UUID
    }
    
    init(session: Domain.AuthSession, authManager: AppData.AuthManager, selectedOrg: OrganizationDTO, modelContainer: ModelContainer) {
        self.session = session
        self.authManager = authManager
        self.selectedOrg = selectedOrg
        
        let apiClient = APIClient()
        let localStore = TaskLocalStore(container: modelContainer)
        let syncQueue = TaskSyncQueue(localStore: localStore, apiClient: apiClient)
        let taskRepository = TaskRepository(
            apiClient: apiClient,
            localStore: localStore,
            syncQueue: syncQueue
        )
        let activityRepository = TaskActivityRepository(apiClient: apiClient)
        let hierarchyRepo = HierarchyRepository(apiClient: apiClient)
        let workflowRepo = WorkflowRepository(apiClient: apiClient)
        let attachmentRepo = AttachmentRepository(apiClient: apiClient)
        self.viewModel = DashboardViewModel(
            taskRepository: taskRepository,
            activityRepository: activityRepository,
            hierarchyRepository: hierarchyRepo,
            workflowRepository: workflowRepo,
            attachmentRepository: attachmentRepo
        )
        
        self._sidebarViewModel = StateObject(wrappedValue: SidebarViewModel(hierarchyRepository: hierarchyRepo))
        
        let gateVM = OrganizationGateViewModel()
        gateVM.selectedOrg = selectedOrg
        gateVM.organizations = [selectedOrg]
        self._orgGateViewModel = StateObject(wrappedValue: gateVM)
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: sidebarViewModel)
        } detail: {
            NavigationStack {
                VStack(spacing: 0) {
                    if horizontalSizeClass == .compact {
                        compactHeaderControls
                    }

                    DashboardView(viewModel: viewModel, viewType: $viewType)
                }
                .navigationTitle("Tasks")
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

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCreateTask = true
                        } label: {
                            Image(systemName: "plus")
                                .appFont(AppTypography.headline)
                                .foregroundColor(AppColors.brandPrimary)
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
                    ProjectSettingsView(projectId: item.id, workflowRepository: viewModel.workflowRepository)
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
