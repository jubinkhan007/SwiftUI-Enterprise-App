import SwiftUI
import SharedModels
import Domain
import DesignSystem

public struct BoardColumnView: View {
    let column: BoardColumn
    @ObservedObject var viewModel: BoardViewModel
    private let taskRepository: TaskRepositoryProtocol
    private let activityRepository: TaskActivityRepositoryProtocol
    private let hierarchyRepository: HierarchyRepositoryProtocol
    private let workflowRepository: WorkflowRepositoryProtocol
    private let attachmentRepository: AttachmentRepositoryProtocol
    @State private var isColumnDropTargeted = false
    
    public init(
        column: BoardColumn,
        viewModel: BoardViewModel,
        taskRepository: TaskRepositoryProtocol,
        activityRepository: TaskActivityRepositoryProtocol,
        hierarchyRepository: HierarchyRepositoryProtocol,
        workflowRepository: WorkflowRepositoryProtocol,
        attachmentRepository: AttachmentRepositoryProtocol
    ) {
        self.column = column
        self.viewModel = viewModel
        self.taskRepository = taskRepository
        self.activityRepository = activityRepository
        self.hierarchyRepository = hierarchyRepository
        self.workflowRepository = workflowRepository
        self.attachmentRepository = attachmentRepository
    }
    
    public var body: some View {
        let isOverWip = column.wipLimit.map { column.items.count > $0 } ?? false

        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(column.title)
                    .font(.headline)
                    .foregroundColor(isOverWip ? AppColors.statusError : AppColors.textPrimary)

                if let limit = column.wipLimit {
                    Text("WIP: \(limit)")
                        .font(.caption2)
                        .foregroundColor(isOverWip ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isOverWip ? AppColors.statusError : AppColors.surfaceElevated)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text("\(column.items.count)")
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isOverWip ? AppColors.statusError : AppColors.surfaceElevated)
                    .clipShape(Capsule())
                    .foregroundColor(isOverWip ? .white : AppColors.textSecondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Cards
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(Array(column.items.enumerated()), id: \.element.id) { index, task in
                        NavigationLink(
                            destination: TaskDetailView(
                                viewModel: TaskDetailViewModel(
                                    task: task,
                                    taskRepository: taskRepository,
                                    activityRepository: activityRepository,
                                    hierarchyRepository: hierarchyRepository,
                                    workflowRepository: workflowRepository,
                                    attachmentRepository: attachmentRepository
                                )
                            )
                        ) {
                            BoardCardView(task: task)
                        }
                        .buttonStyle(.plain)
                        .onDrag {
                            NSItemProvider(object: task.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            guard let provider = providers.first else { return false }
                            _ = provider.loadObject(ofClass: String.self) { uuidString, _ in
                                guard let uuidString,
                                      let taskId = UUID(uuidString: uuidString) else { return }
                                Task {
                                    await viewModel.moveTask(taskId: taskId, to: column.id, atIndex: index)
                                }
                            }
                            return true
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(AppColors.backgroundPrimary)
            // Basic Drop operation
            .onDrop(of: [.text], isTargeted: $isColumnDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                
                _ = provider.loadObject(ofClass: String.self) { uuidString, error in
                    guard let uuidString = uuidString, let taskId = UUID(uuidString: uuidString) else { return }
                    
                    Task {
                        // Drop at the bottom of the column by default
                        await viewModel.moveTask(taskId: taskId, to: column.id, atIndex: column.items.count)
                    }
                }
                return true
            }
        }
        .frame(width: 300)
        .background(AppColors.surfacePrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isOverWip ? AppColors.statusError.opacity(0.8) :
                    (isColumnDropTargeted ? AppColors.brandPrimary.opacity(0.6) : Color.clear),
                    lineWidth: 2
                )
        )
    }
}

// Minimal Card View
struct BoardCardView: View {
    let task: TaskItemDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                
                Spacer()
                
                TaskTypeBadge(taskType: task.taskType)
            }
            
            if let dueDate = task.dueDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption)
                .foregroundColor(dueDate < Date() ? AppColors.statusError : AppColors.textSecondary)
            }
        }
        .padding(12)
        .background(AppColors.surfaceElevated)
        .cornerRadius(8)
    }
}
