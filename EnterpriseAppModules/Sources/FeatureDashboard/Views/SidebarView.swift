import SwiftUI
import DesignSystem
import SharedModels
import AppData
import Domain
import AppNetwork

public struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var syncManager: SyncEngineManager
    let session: Domain.AuthSession
    let authManager: AppData.AuthManager
    let selectedOrg: SharedModels.OrganizationDTO
    @Binding var showTeamManagement: Bool
    
    @State private var showingCreateSheet = false
    @State private var showingSyncCenter = false
    
    public init(
        viewModel: SidebarViewModel,
        syncManager: SyncEngineManager,
        session: Domain.AuthSession,
        authManager: AppData.AuthManager,
        selectedOrg: SharedModels.OrganizationDTO,
        showTeamManagement: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self.syncManager = syncManager
        self.session = session
        self.authManager = authManager
        self.selectedOrg = selectedOrg
        self._showTeamManagement = showTeamManagement
    }
    
    public var body: some View {
        List(selection: $viewModel.selectedArea) {
            navigationSection
            loadingSection
            hierarchySections
        }
        .listStyle(.sidebar)
        .navigationTitle("Workspace")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                personMenu
            }
            createToolbarItem
            syncToolbarItem
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateHierarchyItemSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingSyncCenter) {
            SyncCenterSheet(syncManager: syncManager)
                .presentationDetents([.medium, .large])
        }
        .refreshable {
            await viewModel.fetchHierarchy()
            await syncManager.refresh()
            syncManager.syncNow()
        }
        .onAppear {
            if viewModel.areas.isEmpty {
                Task {
                    await viewModel.fetchHierarchy()
                }
            }
            Task {
                await syncManager.refresh()
                syncManager.syncNow()
            }
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        Section("Navigation") {
            NavigationLink(value: SidebarViewModel.SidebarItem.allTasks) {
                Label("All Tasks", systemImage: "tray.2.fill")
            }
            NavigationLink(value: SidebarViewModel.SidebarItem.myTasks) {
                Label("My Tasks", systemImage: "person.fill")
            }
            NavigationLink(value: SidebarViewModel.SidebarItem.inbox) {
                Label("Inbox", systemImage: "envelope.fill")
            }
            NavigationLink(value: SidebarViewModel.SidebarItem.messages) {
                Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
            }
        }
    }

    // MARK: - Loading Section

    @ViewBuilder
    private var loadingSection: some View {
        if viewModel.isLoading && viewModel.areas.isEmpty {
            Section {
                ProgressView()
            }
        }
    }

    // MARK: - Hierarchy Sections

    @ViewBuilder
    private var hierarchySections: some View {
        ForEach(viewModel.areas, id: \.space.id) { spaceNode in
            SpaceDisclosureGroup(spaceNode: spaceNode)
        }
    }

    // MARK: - Toolbar Items

    private var createToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(AppColors.brandPrimary)
            }
            .accessibilityLabel("Create Team, Project, or List")
        }
    }

    private var syncToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingSyncCenter = true
            } label: {
                syncButtonLabel
            }
            .accessibilityLabel("Sync Center")
        }
    }

    @ViewBuilder
    private var syncButtonLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: syncIconName)
            if let last = syncManager.lastSyncedAt, syncManager.state != .offline {
                Text("Last: \(Self.relativeTime(from: last))")
                    .appFont(AppTypography.caption1)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var personMenu: some View {
        Menu {
            Section {
                Text("Signed in as \(session.user.displayName)")
                    .font(.caption)
                Text("Workspace: \(selectedOrg.name)")
                    .font(.caption)
            }
            
            Divider()
            
            Button {
                showTeamManagement = true
            } label: {
                Label("Team Management", systemImage: "person.3")
            }
            
            Divider()
            
            Button("Sign Out", role: .destructive) {
                OrganizationContext.shared.clear()
                authManager.signOut()
            }
        } label: {
            Image(systemName: "person.circle")
                .appFont(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)
        }
    }

    private var syncIconName: String {
        switch syncManager.state {
        case .online:
            return "icloud"
        case .offline:
            return "icloud.slash"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .attentionNeeded:
            return "exclamationmark.icloud"
        }
    }

    private static func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Extracted Hierarchy Sub-Views

private struct SpaceDisclosureGroup: View {
    let spaceNode: HierarchyTreeDTO.SpaceNode

    var body: some View {
        DisclosureGroup {
            ForEach(spaceNode.projects, id: \.project.id) { projectNode in
                ProjectDisclosureGroup(projectNode: projectNode)
            }
        } label: {
            NavigationLink(value: SidebarViewModel.SidebarItem.space(spaceNode.space.id)) {
                Label(spaceNode.space.name, systemImage: "building.2.fill")
            }
        }
    }
}

private struct ProjectDisclosureGroup: View {
    let projectNode: HierarchyTreeDTO.ProjectNode

    var body: some View {
        DisclosureGroup {
            ForEach(projectNode.lists, id: \.id) { list in
                listRow(list)
            }
        } label: {
            NavigationLink(value: SidebarViewModel.SidebarItem.project(projectNode.project.id)) {
                Label(projectNode.project.name, systemImage: "folder.fill")
            }
        }
    }

    private func listRow(_ list: TaskListDTO) -> some View {
        NavigationLink(value: SidebarViewModel.SidebarItem.list(list.id)) {
            Label(list.name, systemImage: "list.bullet")
                .swipeActions {
                    Button(role: .destructive) {
                        // Archive action
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
        }
    }
}
