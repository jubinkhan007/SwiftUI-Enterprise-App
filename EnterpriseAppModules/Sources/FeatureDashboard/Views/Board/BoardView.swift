import SwiftUI
import SharedModels
import Domain
import DesignSystem

public struct BoardView: View {
    @StateObject private var viewModel: BoardViewModel
    var tasks: [TaskItemDTO]
    var workflowStatuses: [WorkflowStatusDTO]
    private let taskRepository: TaskRepositoryProtocol
    private let activityRepository: TaskActivityRepositoryProtocol
    private let hierarchyRepository: HierarchyRepositoryProtocol
    private let workflowRepository: WorkflowRepositoryProtocol
    private let attachmentRepository: AttachmentRepositoryProtocol
    
    public init(
        tasks: [TaskItemDTO],
        workflowStatuses: [WorkflowStatusDTO] = [],
        taskRepository: TaskRepositoryProtocol,
        activityRepository: TaskActivityRepositoryProtocol,
        hierarchyRepository: HierarchyRepositoryProtocol,
        workflowRepository: WorkflowRepositoryProtocol,
        attachmentRepository: AttachmentRepositoryProtocol
    ) {
        self.tasks = tasks
        self.workflowStatuses = workflowStatuses
        self.taskRepository = taskRepository
        self.activityRepository = activityRepository
        self.hierarchyRepository = hierarchyRepository
        self.workflowRepository = workflowRepository
        self.attachmentRepository = attachmentRepository
        // Initialize with default status grouping
        self._viewModel = StateObject(wrappedValue: BoardViewModel(taskRepository: taskRepository))
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Grouping Toolbar
            HStack {
                Text("Group By:")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                
                Picker("Group By", selection: $viewModel.config.groupBy) {
                    Text("Status").tag(BoardGroupBy.status)
                    Text("Priority").tag(BoardGroupBy.priority)
                    Text("Assignee").tag(BoardGroupBy.assignee)
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.config.groupBy) { _ in
                    viewModel.updateTasks(tasks)
                }
                
                Spacer()
                
                if viewModel.isMoving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }
            }
            .padding()
            .background(AppColors.surfaceElevated)
            
            // Horizontal Board
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(viewModel.columns) { column in
                        BoardColumnView(
                            column: column,
                            viewModel: viewModel,
                            taskRepository: taskRepository,
                            activityRepository: activityRepository,
                            hierarchyRepository: hierarchyRepository,
                            workflowRepository: workflowRepository,
                            attachmentRepository: attachmentRepository
                        )
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.updateWorkflowStatuses(workflowStatuses)
            viewModel.updateTasks(tasks)
        }
        .onChange(of: tasks) { newTasks in
            viewModel.updateTasks(newTasks)
        }
        .onChange(of: workflowStatuses) { newValue in
            viewModel.updateWorkflowStatuses(newValue)
        }
    }
}
