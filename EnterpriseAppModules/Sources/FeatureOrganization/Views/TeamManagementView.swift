import SwiftUI
import SharedModels
import DesignSystem
import AppNetwork

/// Full team management view with Members & Invites tabs.
/// Actions (invite, role edit, remove, revoke) are disabled based on the user's resolved `PermissionSet`.
public struct TeamManagementView: View {
    @StateObject private var viewModel: TeamManagementViewModel
    @State private var selectedTab = 0

    public init(orgId: UUID) {
        self._viewModel = StateObject(wrappedValue: TeamManagementViewModel(orgId: orgId))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Picker
                    Picker("", selection: $selectedTab) {
                        Text("Members (\(viewModel.members.count))").tag(0)
                        if viewModel.canViewInvites {
                            Text("Invites (\(viewModel.invites.count))").tag(1)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, AppSpacing.sm)

                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.statusWarning)
                            Text(error)
                                .appFont(AppTypography.caption1)
                                .foregroundColor(AppColors.statusError)
                            Spacer()
                            Button {
                                viewModel.errorMessage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.statusError.opacity(0.1))
                    }

                    // Content
                    if selectedTab == 0 {
                        membersListView
                    } else {
                        invitesListView
                    }
                }
            }
            .navigationTitle("Team")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if viewModel.canInvite {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.showInviteSheet = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(AppColors.brandPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showInviteSheet) {
                inviteSheet
            }
            .sheet(item: $viewModel.memberBeingEdited) { member in
                roleEditSheet(for: member)
            }
            .task {
                await viewModel.loadAll()
            }
            .refreshable {
                await viewModel.loadAll()
            }
        }
    }

    // MARK: - Members List

    private var membersListView: some View {
        Group {
            if viewModel.isLoadingMembers {
                ProgressView()
                    .tint(AppColors.brandPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.members.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "person.3")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textTertiary)
                    Text("No members yet")
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.members) { member in
                        memberRow(member)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func memberRow(_ member: OrganizationMemberDTO) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(AppColors.brandPrimary.opacity(0.15))
                    .frame(width: 42, height: 42)
                Text(String(member.displayName.prefix(1)).uppercased())
                    .appFont(AppTypography.headline)
                    .foregroundColor(AppColors.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .appFont(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                Text(member.email)
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            // Role badge
            Text(member.role.displayName)
                .appFont(AppTypography.caption1.weight(.semibold))
                .foregroundColor(roleBadgeColor(member.role))
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 4)
                .background(roleBadgeColor(member.role).opacity(0.12))
                .cornerRadius(AppRadius.small)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if viewModel.canRemoveMembers && member.role != .owner {
                Button(role: .destructive) {
                    Task { await viewModel.removeMember(member) }
                } label: {
                    Label("Remove", systemImage: "person.badge.minus")
                }
            }
            if viewModel.canManageRoles && member.role != .owner {
                Button {
                    viewModel.editedRole = member.role
                    viewModel.memberBeingEdited = member
                } label: {
                    Label("Role", systemImage: "pencil")
                }
                .tint(AppColors.brandPrimary)
            }
        }
    }

    // MARK: - Invites List

    private var invitesListView: some View {
        Group {
            if viewModel.isLoadingInvites {
                ProgressView()
                    .tint(AppColors.brandPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.invites.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textTertiary)
                    Text("No invitations")
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.invites) { invite in
                        inviteRow(invite)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func inviteRow(_ invite: OrganizationInviteDTO) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(inviteStatusColor(invite.status).opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: inviteStatusIcon(invite.status))
                    .foregroundColor(inviteStatusColor(invite.status))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(invite.email)
                    .appFont(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                HStack(spacing: AppSpacing.xs) {
                    Text(invite.role.displayName)
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                    Text("•")
                        .foregroundColor(AppColors.textTertiary)
                    Text(invite.status.rawValue.capitalized)
                        .appFont(AppTypography.caption1)
                        .foregroundColor(inviteStatusColor(invite.status))
                }
            }

            Spacer()

            if invite.status == .pending {
                Text(expiryText(invite.expiresAt))
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            if invite.status == .pending && viewModel.canManageRoles {
                Button(role: .destructive) {
                    Task { await viewModel.revokeInvite(invite) }
                } label: {
                    Label("Revoke", systemImage: "xmark.circle")
                }
            }
        }
    }

    // MARK: - Invite Sheet

    private var inviteSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary.ignoresSafeArea()

                VStack(spacing: AppSpacing.lg) {
                    AppTextField("Email Address", text: $viewModel.inviteEmail)

                    // Role Picker
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Role")
                            .appFont(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        Picker("Role", selection: $viewModel.inviteRole) {
                            Text("Guest").tag(UserRole.guest)
                            Text("Member").tag(UserRole.member)
                            Text("Manager").tag(UserRole.manager)
                            if viewModel.currentRole == .owner || viewModel.currentRole == .admin {
                                Text("Admin").tag(UserRole.admin)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(AppColors.surfaceElevated.opacity(0.5))
                    .cornerRadius(AppRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.statusError)
                    }

                    AppButton(
                        viewModel.isSendingInvite ? "Sending…" : "Send Invite",
                        variant: .primary,
                        leadingIcon: "envelope.fill",
                        isLoading: viewModel.isSendingInvite
                    ) {
                        Task { await viewModel.sendInvite() }
                    }
                    .disabled(viewModel.inviteEmail.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSendingInvite)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Invite Member")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showInviteSheet = false
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Role Edit Sheet

    private func roleEditSheet(for member: OrganizationMemberDTO) -> some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary.ignoresSafeArea()

                VStack(spacing: AppSpacing.lg) {
                    // Member info
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(AppColors.brandPrimary.opacity(0.15))
                                .frame(width: 50, height: 50)
                            Text(String(member.displayName.prefix(1)).uppercased())
                                .appFont(AppTypography.title3)
                                .foregroundColor(AppColors.brandPrimary)
                        }
                        VStack(alignment: .leading) {
                            Text(member.displayName)
                                .appFont(AppTypography.headline)
                                .foregroundColor(AppColors.textPrimary)
                            Text(member.email)
                                .appFont(AppTypography.caption1)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(AppColors.surfaceElevated)
                    .cornerRadius(AppRadius.medium)

                    // Role picker
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Change Role")
                            .appFont(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        ForEach([UserRole.guest, .member, .manager, .admin], id: \.self) { role in
                            Button {
                                viewModel.editedRole = role
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(role.displayName)
                                            .appFont(AppTypography.body)
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                    Spacer()
                                    if viewModel.editedRole == role {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.brandPrimary)
                                    }
                                }
                                .padding()
                                .background(
                                    viewModel.editedRole == role
                                        ? AppColors.brandPrimary.opacity(0.08)
                                        : AppColors.surfaceElevated
                                )
                                .cornerRadius(AppRadius.small)
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.statusError)
                    }

                    AppButton("Save Role", variant: .primary) {
                        Task { await viewModel.updateMemberRole(member, to: viewModel.editedRole) }
                    }
                    .disabled(viewModel.editedRole == member.role)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Edit Role")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.memberBeingEdited = nil
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func roleBadgeColor(_ role: UserRole) -> Color {
        switch role {
        case .owner: return AppColors.statusError
        case .admin: return AppColors.statusWarning
        case .manager: return AppColors.brandPrimary
        case .member: return AppColors.statusSuccess
        case .guest: return AppColors.textTertiary
        }
    }

    private func inviteStatusColor(_ status: InviteStatus) -> Color {
        switch status {
        case .pending: return AppColors.statusWarning
        case .accepted: return AppColors.statusSuccess
        case .expired: return AppColors.textTertiary
        case .revoked: return AppColors.statusError
        }
    }

    private func inviteStatusIcon(_ status: InviteStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .accepted: return "checkmark"
        case .expired: return "clock.badge.exclamationmark"
        case .revoked: return "xmark"
        }
    }

    private func expiryText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days <= 0 { return "Expired" }
        if days == 1 { return "1 day left" }
        return "\(days) days left"
    }
}
