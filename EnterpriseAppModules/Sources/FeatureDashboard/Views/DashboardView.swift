import SwiftUI
import SharedModels
import DesignSystem

public enum DashboardViewType: String, CaseIterable, Identifiable {
    case list = "List"
    case board = "Board"
    case calendar = "Calendar"
    case timeline = "Timeline"
    public var id: String { self.rawValue }
}

public struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @State private var showingCreateTask = false
    @Binding var viewType: DashboardViewType
    
    public init(viewModel: DashboardViewModel, viewType: Binding<DashboardViewType>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _viewType = viewType
    }
    
    public var body: some View {
        ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchAndFilterArea
                    
                    if viewModel.isLoading && viewModel.tasks.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.error != nil && viewModel.tasks.isEmpty {
                        ErrorStateView(error: viewModel.error) {
                            Task {
                                await viewModel.fetchTasks()
                            }
                        }
                    } else if viewModel.tasks.isEmpty {
                        EmptyStateView(title: "No Tasks Found", message: "Try adjusting your search or filters.")
                    } else {
                        if viewType == .list {
                            TaskTableView(viewModel: viewModel)
                        } else if viewType == .board {
                            BoardView(
                                tasks: viewModel.tasks,
                                taskRepository: viewModel.taskRepository,
                                activityRepository: viewModel.activityRepository
                            )
                        } else if viewType == .calendar {
                            CalendarView(viewModel: viewModel)
                        } else if viewType == .timeline {
                            TimelineView(viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            // The toolbar items have been lifted to the parent AuthenticatedRootView in EnterpriseApp.swift
            .task {
                if viewModel.tasks.isEmpty {
                    await viewModel.fetchTasks(for: viewType)
                }
            }
            .refreshable {
                await viewModel.refresh(viewType: viewType)
            }
            .onChange(of: viewType) { oldValue, newValue in
                Task {
                    await viewModel.fetchTasks(for: newValue)
                }
            }
            .sheet(isPresented: $showingCreateTask) {
                CreateTaskSheet(viewModel: CreateTaskViewModel(taskRepository: viewModel.taskRepository, listId: viewModel.query.listId)) {
                    Task { await viewModel.refresh() }
                }
                .presentationDetents([.medium, .large])
        }
    }
    
    private var searchAndFilterArea: some View {
        VStack(spacing: AppSpacing.sm) {
            AppTextField(
                "Search tasks...",
                text: $viewModel.searchQuery
            )
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    FilterChip(
                        title: "All",
                        isSelected: viewModel.filterStatus == nil
                    ) {
                        viewModel.filterStatus = nil
                    }

                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        FilterChip(
                            title: status.displayName,
                            isSelected: viewModel.filterStatus == status
                        ) {
                            viewModel.filterStatus = status
                        }
                    }

                    Divider().frame(height: 20)

                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        FilterChip(
                            title: priority.displayName,
                            isSelected: viewModel.filterPriority == priority
                        ) {
                            if viewModel.filterPriority == priority {
                                viewModel.filterPriority = nil
                            } else {
                                viewModel.filterPriority = priority
                            }
                        }
                    }

                    Divider().frame(height: 20)

                    ForEach(TaskType.allCases, id: \.self) { type in
                        FilterChipWithIcon(
                            title: type.displayName,
                            iconName: type.iconName,
                            isSelected: viewModel.filterTaskType == type
                        ) {
                            if viewModel.filterTaskType == type {
                                viewModel.filterTaskType = nil
                            } else {
                                viewModel.filterTaskType = type
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, AppSpacing.sm)
            }
        }
        .padding(.top, AppSpacing.sm)
        .background(AppColors.surfacePrimary)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
        .zIndex(1)
    }
    
    // Omitted taskList property as it is replaced by TaskTableView
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appFont(AppTypography.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(isSelected ? AppColors.brandPrimary : AppColors.surfaceElevated)
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppColors.borderDefault, lineWidth: 1)
                )
        }
    }
}

struct FilterChipWithIcon: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.caption)
                Text(title)
                    .appFont(AppTypography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(isSelected ? AppColors.brandPrimary : AppColors.surfaceElevated)
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppColors.borderDefault, lineWidth: 1)
            )
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary)
            Text(title)
                .appFont(AppTypography.title3)
            Text(message)
                .appFont(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let error: Error?
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Oops! Something went wrong.")
                .appFont(AppTypography.title3)
            Text(error?.localizedDescription ?? "Unknown error occurred.")
                .appFont(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            AppButton("Retry", action: retryAction)
                .frame(width: 150)
                .padding(.top, AppSpacing.sm)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
