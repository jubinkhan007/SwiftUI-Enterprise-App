import SwiftUI
import Domain
import DesignSystem

public struct DashboardTab: View {
    private let taskRepository: TaskRepositoryProtocol
    
    public init(taskRepository: TaskRepositoryProtocol) {
        self.taskRepository = taskRepository
    }
    
    public var body: some View {
        // Instantiate the ViewModel holding the repository dependency
        let viewModel = DashboardViewModel(taskRepository: taskRepository)
        
        DashboardView(viewModel: viewModel)
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
    }
}
