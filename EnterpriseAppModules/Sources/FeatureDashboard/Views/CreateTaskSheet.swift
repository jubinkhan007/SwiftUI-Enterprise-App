import SwiftUI
import DesignSystem
import SharedModels

public struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateTaskViewModel
    
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
                        
                        // Status & Priority Pickers
                        HStack(spacing: AppSpacing.md) {
                            pickerCard(title: "Status") {
                                Picker("Status", selection: $viewModel.status) {
                                    ForEach(TaskStatus.allCases, id: \.self) { status in
                                        Text(status.displayName).tag(status)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            pickerCard(title: "Priority") {
                                Picker("Priority", selection: $viewModel.priority) {
                                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                                        Text(priority.displayName).tag(priority)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        // Start Date
                        dateField(
                            title: "Start Date",
                            date: $viewModel.startDate,
                            isExpanded: $viewModel.showStartDatePicker,
                            icon: "calendar.badge.clock"
                        )
                        
                        // Due Date
                        dateField(
                            title: "Due Date",
                            date: $viewModel.dueDate,
                            isExpanded: $viewModel.showDueDatePicker,
                            icon: "calendar.badge.exclamationmark"
                        )
                        
                        // Assignee
                        AppTextField(
                            "Assignee ID (Optional UUID)",
                            text: $viewModel.assigneeIdText,
                            validationState: assigneeValidation
                        )
                        
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
    
    // MARK: - Helpers
    
    private var assigneeValidation: TextFieldValidationState {
        let text = viewModel.assigneeIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .normal }
        return UUID(uuidString: text) != nil ? .success : .error("Must be a valid UUID")
    }
    
    private func pickerCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.sm)
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.small)
        }
    }
    
    private func dateField(title: String, date: Binding<Date?>, isExpanded: Binding<Bool>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppColors.brandPrimary)
                Text(title)
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                
                if date.wrappedValue != nil {
                    Button {
                        withAnimation { date.wrappedValue = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                Button {
                    withAnimation {
                        isExpanded.wrappedValue.toggle()
                        if isExpanded.wrappedValue && date.wrappedValue == nil {
                            date.wrappedValue = Date()
                        }
                    }
                } label: {
                    Text(date.wrappedValue.map { formatDate($0) } ?? "Not Set")
                        .appFont(AppTypography.body)
                        .foregroundColor(date.wrappedValue != nil ? AppColors.textPrimary : AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.surfacePrimary)
                        .cornerRadius(AppRadius.small)
                }
            }
            
            if isExpanded.wrappedValue, let _ = date.wrappedValue {
                DatePicker(
                    title,
                    selection: Binding(
                        get: { date.wrappedValue ?? Date() },
                        set: { date.wrappedValue = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.medium)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(AppColors.surfaceElevated.opacity(0.5))
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
