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
            HStack {
                Text("Inbox")
                    .appFont(AppTypography.title1)
                Spacer()
                Toggle("Unread Only", isOn: $viewModel.unreadOnly)
                    .toggleStyle(.button)
                    .tint(AppColors.brandPrimary)
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
                    ForEach(viewModel.notifications) { notification in
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
