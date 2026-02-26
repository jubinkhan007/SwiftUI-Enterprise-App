import SwiftUI
import SharedModels
import Domain
import DesignSystem

public struct BoardView: View {
    @StateObject private var viewModel: BoardViewModel
    var tasks: [TaskItemDTO]
    
    public init(tasks: [TaskItemDTO], repository: TaskRepositoryProtocol) {
        self.tasks = tasks
        // Initialize with default status grouping
        self._viewModel = StateObject(wrappedValue: BoardViewModel(taskRepository: repository))
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
                        BoardColumnView(column: column, viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.updateTasks(tasks)
        }
        .onChange(of: tasks) { newTasks in
            viewModel.updateTasks(newTasks)
        }
    }
}
