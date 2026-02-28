import SwiftUI
import Domain
import SharedModels
import DesignSystem

public struct TaskDetailView: View {
    @StateObject private var viewModel: TaskDetailViewModel
    
    public init(viewModel: TaskDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.hasConflict {
                    conflictBanner
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        taskHeader
                        Divider()
                        taskDescription
                        Divider()
                        activitySection
                    }
                    .padding()
                }
                
                commentInputArea
            }
            
            if viewModel.isSaving {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .padding()
                        .background(AppColors.surfacePrimary)
                        .cornerRadius(8)
                }
            }
        }
        .navigationTitle("Task Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task { await viewModel.saveChanges() }
                }) {
                    Text("Save")
                        .appFont(AppTypography.headline)
                        .foregroundColor(viewModel.isSaving ? AppColors.textTertiary : AppColors.brandPrimary)
                }
                .disabled(viewModel.isSaving)
            }
        }
        .task {
            await viewModel.fetchActivities()
            await viewModel.loadWorkflowIfNeeded()
        }
    }
    
    // MARK: - Components
    
    private var conflictBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Conflict detected! Another user modified this task. Please refresh.")
                .appFont(AppTypography.subheadline)
            Spacer()
        }
        .padding()
        .background(AppColors.statusError.opacity(0.2))
        .foregroundColor(AppColors.statusError)
    }
    
    private var taskHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            AppTextField("Title", text: $viewModel.editTitle)
            
            HStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading) {
                    Text("Status")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                    if !viewModel.workflowStatuses.isEmpty {
                        Picker("Status", selection: $viewModel.editStatusId) {
                            ForEach(viewModel.workflowStatuses) { status in
                                Text(status.name).tag(Optional(status.id))
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Picker("Status", selection: $viewModel.editStatus) {
                            ForEach(TaskStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Priority")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                    Picker("Priority", selection: $viewModel.editPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
    
    private var taskDescription: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Description")
                .appFont(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)
            
            TextEdit(text: $viewModel.editDescription)
                .frame(minHeight: 100)
                .padding()
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.borderDefault, lineWidth: 1)
                )
        }
    }
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Activity")
                .appFont(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            if viewModel.isLoadingActivities {
                ProgressView()
            } else if viewModel.activities.isEmpty {
                Text("No activity yet.")
                    .appFont(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(viewModel.activities) { activity in
                    ActivityRow(activity: activity)
                }
            }
        }
    }
    
    private var commentInputArea: some View {
        HStack {
            AppTextField("Add a comment...", text: $viewModel.newCommentText)
            
            Button(action: {
                Task { await viewModel.submitComment() }
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(viewModel.newCommentText.isEmpty ? AppColors.textTertiary : AppColors.brandPrimary)
                    .padding()
            }
            .disabled(viewModel.newCommentText.isEmpty || viewModel.isSubmittingComment)
        }
        .padding()
        .background(AppColors.surfacePrimary)
        .shadow(color: Color.black.opacity(0.1), radius: 3, y: -2)
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let activity: TaskActivityDTO
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: activity.type == .comment ? "bubble.left.fill" : "arrow.triangle.2.circlepath")
                .foregroundColor(AppColors.brandPrimary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("User \(activity.userId.uuidString.prefix(4))") // Mocking user string
                    .appFont(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                if let content = activity.content, activity.type == .comment {
                    Text(content)
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    Text(activity.type.rawValue.capitalized)
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .italic()
                }
                
                Text(activity.createdAt, style: .time)
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, AppSpacing.sm)
    }
}

// TextEdit wrapper for multiline TextField
struct TextEdit: View {
    @Binding var text: String
    
    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            TextField("Task description...", text: $text, axis: .vertical)
                .lineLimit(5...)
        } else {
            TextEditor(text: $text)
        }
    }
}
