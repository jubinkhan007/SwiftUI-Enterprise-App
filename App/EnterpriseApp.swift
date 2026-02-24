import SwiftUI
import SwiftData
import FeatureAuth
import FeatureOrganization
import FeatureDashboard
import AppNetwork
import AppData
import Domain
import SharedModels

@main
struct EnterpriseApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: LocalTaskItem.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AuthGateView(configuration: AppNetwork.APIConfiguration.localVapor) { session, manager in
                // After auth, gate on organization selection
                OrganizationGateView(
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
    let session: Domain.AuthSession
    let authManager: AppData.AuthManager
    let selectedOrg: OrganizationDTO
    let viewModel: DashboardViewModel
    @StateObject private var orgGateViewModel = OrganizationGateViewModel()
    @State private var showTeamManagement = false
    
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
        self.viewModel = DashboardViewModel(taskRepository: taskRepository)
    }
    
    var body: some View {
        DashboardView(viewModel: viewModel)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    WorkspaceSwitcherView(viewModel: orgGateViewModel)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showTeamManagement = true
                    } label: {
                        Image(systemName: "person.3")
                            .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
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
            }
            .sheet(isPresented: $showTeamManagement) {
                TeamManagementView(orgId: selectedOrg.id)
            }
            .task {
                await orgGateViewModel.fetchOrganizations()
            }
    }
}
