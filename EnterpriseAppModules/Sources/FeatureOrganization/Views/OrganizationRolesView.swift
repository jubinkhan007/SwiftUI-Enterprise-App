import SwiftUI
import SharedModels
import DesignSystem

/// Read-only "Organization Roles" screen: explains each role and shows the
/// role → permission matrix, highlighting the signed-in user's current role.
/// Source of truth is `PermissionSet.defaultPermissions(for:)` in SharedModels,
/// the same mapping the backend enforces.
public struct OrganizationRolesView: View {
    private let currentRole: UserRole?
    @State private var selectedRole: UserRole
    @State private var compareRole: UserRole? = nil
    @State private var selectedCategory: PermissionCategory?
    @State private var searchQuery: String = ""
    @State private var showFullMatrix: Bool = false
    @Environment(\.dismiss) private var dismiss

    /// Highest privilege first, matching the web admin console.
    private static let roleOrder: [UserRole] = [.owner, .admin, .manager, .member, .viewer, .guest]

    public init(currentRole: UserRole?) {
        self.currentRole = currentRole
        self._selectedRole = State(initialValue: currentRole ?? .member)
    }

    public var body: some View {
        NavigationStack {
            List {
                if let currentRole {
                    Section {
                        HStack(spacing: AppSpacing.md) {
                            RoleBadge(role: currentRole)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your role in this workspace")
                                    .appFont(AppTypography.caption1)
                                    .foregroundColor(AppColors.textSecondary)
                                Text("\(PermissionSet.defaultPermissions(for: currentRole).permissions.count) of \(Permission.allCases.count) permissions")
                                    .appFont(AppTypography.headline)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }
                }

                Section {
                    Picker("View Mode", selection: $showFullMatrix) {
                        Text("Role Inspector").tag(false)
                        Text("Side-by-Side Matrix").tag(true)
                    }
                    .pickerStyle(.segmented)

                    TextField("Search permissions (e.g. audit, sprints, delete)...", text: $searchQuery)
                        .appFont(AppTypography.subheadline)

                    Picker("Category", selection: $selectedCategory) {
                        Text("All categories").tag(PermissionCategory?.none)
                        ForEach(PermissionCategory.allCases) { category in
                            Text(category.title).tag(PermissionCategory?.some(category))
                        }
                    }
                }

                if showFullMatrix {
                    fullMatrixSections
                } else {
                    roleInspectorSections
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("Roles & Permissions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var roleInspectorSections: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Self.roleOrder, id: \.self) { role in
                        Button {
                            selectedRole = role
                        } label: {
                            Text(role.displayName + (role == currentRole ? " (You)" : ""))
                                .appFont(AppTypography.subheadline)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.xs + 2)
                                .background(selectedRole == role ? role.tint : AppColors.surfaceElevated)
                                .foregroundColor(selectedRole == role ? .white : AppColors.textPrimary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, AppSpacing.xs)
            }
            Text(selectedRole.summary)
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)

            Picker("Compare With Role", selection: $compareRole) {
                Text("None").tag(UserRole?.none)
                ForEach(Self.roleOrder.filter { $0 != selectedRole }, id: \.self) { role in
                    Text(role.displayName).tag(UserRole?.some(role))
                }
            }
        } header: {
            Text("Roles")
        }

        let granted = PermissionSet.defaultPermissions(for: selectedRole)
        let comparedGranted = compareRole.map { PermissionSet.defaultPermissions(for: $0) }
        ForEach(visibleCategories) { category in
            let perms = filteredPermissions(in: category)
            if !perms.isEmpty {
                Section(category.title) {
                    ForEach(perms, id: \.self) { permission in
                        let hasSelected = granted.has(permission)
                        let hasCompared = comparedGranted?.has(permission)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(permission.label)
                                    .appFont(AppTypography.body)
                                    .foregroundColor(AppColors.textPrimary)
                                Text(permission.rawValue)
                                    .appFont(AppTypography.caption2)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            Spacer()
                            if let hasCompared, hasSelected != hasCompared {
                                Text(hasSelected ? "+ Only \(selectedRole.displayName)" : "- Missing vs \(compareRole?.displayName ?? "")")
                                    .appFont(AppTypography.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((hasSelected ? AppColors.statusSuccess : AppColors.statusWarning).opacity(0.16))
                                    .foregroundColor(hasSelected ? AppColors.statusSuccess : AppColors.statusWarning)
                                    .cornerRadius(4)
                            }
                            Image(systemName: hasSelected ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(hasSelected ? AppColors.statusSuccess : AppColors.textTertiary)
                                .accessibilityLabel(hasSelected ? "Allowed" : "Not allowed")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var fullMatrixSections: some View {
        ForEach(visibleCategories) { category in
            let perms = filteredPermissions(in: category)
            if !perms.isEmpty {
                Section(category.title) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Permission")
                                    .appFont(AppTypography.caption2)
                                    .fontWeight(.bold)
                                    .frame(width: 140, alignment: .leading)
                                ForEach(Self.roleOrder, id: \.self) { role in
                                    Text(String(role.displayName.prefix(3)).uppercased())
                                        .appFont(AppTypography.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(role.tint)
                                        .frame(width: 36)
                                }
                            }
                            Divider()
                            ForEach(perms, id: \.self) { permission in
                                HStack(spacing: 8) {
                                    Text(permission.label)
                                        .appFont(AppTypography.caption1)
                                        .frame(width: 140, alignment: .leading)
                                        .lineLimit(1)
                                    ForEach(Self.roleOrder, id: \.self) { role in
                                        let ok = PermissionSet.defaultPermissions(for: role).has(permission)
                                        Image(systemName: ok ? "checkmark.circle.fill" : "minus")
                                            .font(.system(size: 12))
                                            .foregroundColor(ok ? AppColors.statusSuccess : AppColors.textTertiary.opacity(0.5))
                                            .frame(width: 36)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func filteredPermissions(in category: PermissionCategory) -> [Permission] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return category.permissions }
        return category.permissions.filter {
            $0.label.lowercased().contains(q) || $0.rawValue.lowercased().contains(q)
        }
    }

    private var visibleCategories: [PermissionCategory] {
        if let selectedCategory { return [selectedCategory] }
        return PermissionCategory.allCases
    }
}

// MARK: - Role badge

public struct RoleBadge: View {
    let role: UserRole
    public init(role: UserRole) { self.role = role }

    public var body: some View {
        Text(role.displayName)
            .appFont(AppTypography.caption1)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(role.tint.opacity(0.15))
            .foregroundColor(role.tint)
            .clipShape(Capsule())
    }
}

extension UserRole {
    /// Same palette as the web console / Android TeamScreen.
    var tint: Color {
        switch self {
        case .owner: return Color(red: 0.43, green: 0.34, blue: 0.81)   // purple
        case .admin: return Color(red: 0.0, green: 0.48, blue: 1.0)     // blue
        case .manager: return Color(red: 1.0, green: 0.58, blue: 0.0)   // amber
        case .member: return Color(red: 0.20, green: 0.78, blue: 0.35)  // green
        case .viewer, .guest: return Color(red: 0.56, green: 0.56, blue: 0.58) // gray
        }
    }

    var summary: String {
        switch self {
        case .owner: return "Full ownership: billing, workspace deletion, and every admin capability."
        case .admin: return "Team management, member roles, workspace settings, and audit log access."
        case .manager: return "Sprint and release planning, inviting teammates, and analytics export."
        case .member: return "Standard contributor: create and edit tasks, comment, and upload files."
        case .viewer: return "Read-only visibility into tasks, projects, and analytics."
        case .guest: return "Restricted access to assigned tasks and notifications only."
        }
    }
}

// MARK: - Permission grouping

enum PermissionCategory: String, CaseIterable, Identifiable {
    case tasks, views, team, projects, agile, analytics, collaboration, admin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks: return "Tasks"
        case .views: return "Saved Views"
        case .team: return "Team & Members"
        case .projects: return "Projects"
        case .agile: return "Agile & Releases"
        case .analytics: return "Analytics & Reports"
        case .collaboration: return "Collaboration"
        case .admin: return "Workspace Settings"
        }
    }

    var permissions: [Permission] {
        Permission.allCases.filter { $0.category == self }
    }
}

extension Permission {
    var category: PermissionCategory {
        switch self {
        case .tasksRead, .tasksCreate, .tasksEdit, .tasksDelete, .tasksAssign,
             .tasksCreateSubtask, .tasksChangeType, .tasksRelate, .tasksManageChecklist:
            return .tasks
        case .viewsCreate, .viewsUpdate, .viewsDelete, .viewsShare, .viewsSetDefault:
            return .views
        case .membersView, .membersInvite, .membersManage, .membersRemove:
            return .team
        case .projectsRead, .projectsCreate, .projectsEdit, .projectsDelete, .projectsArchive:
            return .projects
        case .sprintsManage, .releasesManage, .issuesEditBugFields:
            return .agile
        case .analyticsView, .analyticsExport, .reportsExport:
            return .analytics
        case .commentsCreate, .attachmentsUpload, .attachmentsDownload, .notificationsRead:
            return .collaboration
        case .orgSettings, .orgDelete, .auditLogView:
            return .admin
        }
    }

    /// "tasks.create_subtask" -> "Create subtask"
    var label: String {
        let action = rawValue.split(separator: ".").last.map(String.init) ?? rawValue
        let words = action.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

