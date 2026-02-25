import SwiftUI
import SharedModels
import DesignSystem
import AppNetwork

/// A compact workspace switcher view designed to be shown in a toolbar or sidebar.
/// Displays the current org name and allows switching via a menu or sheet.
public struct WorkspaceSwitcherView: View {
    @ObservedObject var viewModel: OrganizationGateViewModel

    public init(viewModel: OrganizationGateViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Menu {
            ForEach(viewModel.organizations) { org in
                Button {
                    viewModel.switchOrganization(to: org)
                } label: {
                    Label {
                        Text(org.name)
                    } icon: {
                        if org.id == viewModel.selectedOrg?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button {
                viewModel.showJoinSheet = true
            } label: {
                Label("Join Workspace", systemImage: "person.badge.plus")
            }

            Button {
                viewModel.showCreateSheet = true
            } label: {
                Label("New Workspace", systemImage: "plus.circle")
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "building.2")
                    .font(.subheadline)
                    .foregroundColor(AppColors.brandPrimary)

                Text(viewModel.selectedOrg?.name ?? "Workspace")
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.surfaceElevated.opacity(0.8))
            .cornerRadius(AppRadius.small)
        }
    }
}
