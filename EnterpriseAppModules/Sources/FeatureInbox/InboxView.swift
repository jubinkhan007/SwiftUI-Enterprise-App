import SwiftUI
import SharedModels
import DesignSystem

public struct InboxView: View {
    @StateObject private var viewModel: InboxViewModel

    public init(viewModel: InboxViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            filterChips
            contentArea
        }
        .background(AppColors.backgroundPrimary)
        .refreshable {
            await viewModel.fetchNotifications()
        }
        .task {
            if viewModel.notifications.isEmpty {
                await viewModel.fetchNotifications()
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: AppSpacing.md) {
            Text("Inbox")
                .appFont(AppTypography.title1)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button {
                Task { await viewModel.markAllAsRead() }
            } label: {
                Label("Mark All Read", systemImage: "checkmark.circle")
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.brandPrimary)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Toggle(isOn: $viewModel.unreadOnly) {
                Text("Unread")
                    .appFont(AppTypography.subheadline)
            }
            .toggleStyle(.button)
            .tint(AppColors.brandPrimary)
        }
        .padding(.horizontal)
        .padding(.bottom, AppSpacing.sm)
        .background(AppColors.backgroundPrimary)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(InboxViewModel.NotificationFilter.allCases) { filter in
                    FilterChip(
                        label: filter.rawValue,
                        isSelected: viewModel.filterType == filter
                    ) {
                        viewModel.filterType = filter
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.backgroundPrimary)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading && viewModel.notifications.isEmpty {
            Spacer()
            ProgressView()
                .tint(AppColors.brandPrimary)
            Spacer()
        } else if viewModel.filteredNotifications.isEmpty {
            emptyState
        } else {
            List {
                ForEach(viewModel.filteredNotifications) { notification in
                    InboxRowView(notification: notification) {
                        Task { await viewModel.markAsRead(notification) }
                    }
                    .listRowBackground(AppColors.backgroundPrimary)
                    .listRowSeparatorTint(AppColors.borderDefault)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundPrimary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColors.surfaceElevated)
                    .frame(width: 80, height: 80)
                Image(systemName: "bell.badge")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(AppColors.brandGradient)
            }
            VStack(spacing: AppSpacing.xs) {
                Text("All caught up!")
                    .appFont(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                Text(viewModel.unreadOnly ? "No unread notifications right now." : "You have no notifications yet.")
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(AppColors.backgroundPrimary)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .appFont(AppTypography.subheadline)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? AppColors.brandPrimary : AppColors.surfaceElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
