import SwiftUI
import DesignSystem
import SharedModels

public struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateTaskViewModel
    
    // Callback to refresh the dashboard when a task is successfully created
    let onTaskCreated: () -> Void
    
    public init(viewModel: CreateTaskViewModel, onTaskCreated: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onTaskCreated = onTaskCreated
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        
                        // Title Input
                        AppTextField(
                            "Task Title (Required)",
                            text: $viewModel.title,
                            validationState: viewModel.title.isEmpty ? .normal : .success
                        )
                        
                        // Description Input
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Description (Optional)")
                                .appFont(AppTypography.caption1)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.sm)
                            
                            TextEdit(text: $viewModel.descriptionText)
                                .frame(minHeight: 100)
                                .padding()
                                .background(AppColors.surfacePrimary)
                                .cornerRadius(AppRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(AppColors.borderDefault, lineWidth: 1)
                                )
                        }
                        
                        // Pickers
                        HStack(spacing: AppSpacing.md) {
                            VStack(alignment: .leading) {
                                Text("Status")
                                    .appFont(AppTypography.caption1)
                                    .foregroundColor(AppColors.textSecondary)
                                Picker("Status", selection: $viewModel.status) {
                                    ForEach(TaskStatus.allCases, id: \.self) { status in
                                        Text(status.displayName).tag(status)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(AppSpacing.sm)
                                .background(AppColors.surfacePrimary)
                                .cornerRadius(AppRadius.small)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Priority")
                                    .appFont(AppTypography.caption1)
                                    .foregroundColor(AppColors.textSecondary)
                                Picker("Priority", selection: $viewModel.priority) {
                                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                                        Text(priority.displayName).tag(priority)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(AppSpacing.sm)
                                .background(AppColors.surfacePrimary)
                                .cornerRadius(AppRadius.small)
                            }
                        }
                        
                        if let error = viewModel.error {
                            Text(error.localizedDescription)
                                .appFont(AppTypography.caption1)
                                .foregroundColor(AppColors.statusError)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.brandPrimary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel.saveTask() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Create")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(viewModel.isValid && !viewModel.isSaving ? AppColors.brandPrimary : AppColors.textTertiary)
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
        }
        .onChange(of: viewModel.isSuccess) {
            if viewModel.isSuccess {
                onTaskCreated()
                dismiss()
            }
        }
    }
}
