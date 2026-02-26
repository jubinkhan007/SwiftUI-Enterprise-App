import SwiftUI
import Domain
import DesignSystem

public struct DashboardTab: View {
    private let taskRepository: TaskRepositoryProtocol
    private let activityRepository: TaskActivityRepositoryProtocol
    
    @State private var viewType: DashboardViewType = .list
    
    public init(taskRepository: TaskRepositoryProtocol, activityRepository: TaskActivityRepositoryProtocol) {
        self.taskRepository = taskRepository
        self.activityRepository = activityRepository
    }
    
    public var body: some View {
        // Instantiate the ViewModel holding the repository dependency
        let viewModel = DashboardViewModel(taskRepository: taskRepository, activityRepository: activityRepository)
        
        DashboardView(viewModel: viewModel, viewType: $viewType)
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
    }
}
