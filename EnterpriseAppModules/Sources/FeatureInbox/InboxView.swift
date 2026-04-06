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
            HStack(spacing: AppSpacing.md) {
                Text("Inbox")
                    .appFont(AppTypography.title1)
                Spacer()
                
                Picker("Filter", selection: $viewModel.filterType) {
                    ForEach(InboxViewModel.NotificationFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                
                Toggle("Unread", isOn: $viewModel.unreadOnly)
                    .toggleStyle(.button)
                    .tint(AppColors.brandPrimary)
                
                Button(action: {
                    Task { await viewModel.markAllAsRead() }
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.brandPrimary)
                }
            }
            .padding()
            
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.notifications.isEmpty {
                Spacer()
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary)
                    Text("No Notifications")
                        .appFont(AppTypography.title3)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.filteredNotifications) { notification in
                        InboxRowView(notification: notification) {
                            Task {
                                await viewModel.markAsRead(notification)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
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
}
