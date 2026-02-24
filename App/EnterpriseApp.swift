import SwiftUI
import SwiftData
import FeatureAuth
import FeatureDashboard
import AppNetwork
import AppData
import Domain

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
                AuthenticatedRootView(
                    session: session,
                    authManager: manager,
                    modelContainer: modelContainer
                )
            }
        }
    }
}

struct AuthenticatedRootView: View {
    let session: Domain.AuthSession
    let authManager: AppData.AuthManager
    let viewModel: DashboardViewModel
    
    init(session: Domain.AuthSession, authManager: AppData.AuthManager, modelContainer: ModelContainer) {
        self.session = session
        self.authManager = authManager
        
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
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Text("Signed in as \(session.user.displayName)")
                        Button("Sign Out", role: .destructive) {
                            authManager.signOut()
                        }
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                }
            }
    }
}
