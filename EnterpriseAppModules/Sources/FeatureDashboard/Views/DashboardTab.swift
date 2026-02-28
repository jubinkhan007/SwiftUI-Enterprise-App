import SwiftUI
import Domain
import DesignSystem

public struct DashboardTab: View {
    private let taskRepository: TaskRepositoryProtocol
    private let activityRepository: TaskActivityRepositoryProtocol
    private let hierarchyRepository: HierarchyRepositoryProtocol
    private let workflowRepository: WorkflowRepositoryProtocol
    
    @State private var viewType: DashboardViewType = .list
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        activityRepository: TaskActivityRepositoryProtocol,
        hierarchyRepository: HierarchyRepositoryProtocol,
        workflowRepository: WorkflowRepositoryProtocol
    ) {
        self.taskRepository = taskRepository
        self.activityRepository = activityRepository
        self.hierarchyRepository = hierarchyRepository
        self.workflowRepository = workflowRepository
    }
    
    public var body: some View {
        // Instantiate the ViewModel holding the repository dependency
        let viewModel = DashboardViewModel(
            taskRepository: taskRepository,
            activityRepository: activityRepository,
            hierarchyRepository: hierarchyRepository,
            workflowRepository: workflowRepository
        )
        
        DashboardView(viewModel: viewModel, viewType: $viewType)
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
    }
}
