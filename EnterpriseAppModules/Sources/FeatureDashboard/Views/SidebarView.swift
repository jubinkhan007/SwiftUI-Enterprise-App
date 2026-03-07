import SwiftUI
import DesignSystem
import SharedModels
import AppData

public struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var syncManager: SyncEngineManager
    @State private var showingCreateSheet = false
    @State private var showingSyncCenter = false
    
    public init(viewModel: SidebarViewModel, syncManager: SyncEngineManager) {
        self.viewModel = viewModel
        self.syncManager = syncManager
    }
    
    public var body: some View {
        List(selection: $viewModel.selectedArea) {
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
            }
            
            if viewModel.isLoading && viewModel.areas.isEmpty {
                Section {
                    ProgressView()
                }
            }
            
            ForEach(viewModel.areas, id: \.space.id) { spaceNode in
                DisclosureGroup {
                    ForEach(spaceNode.projects, id: \.project.id) { projectNode in
                        DisclosureGroup {
                            ForEach(projectNode.lists, id: \.id) { list in
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
                        } label: {
                            NavigationLink(value: SidebarViewModel.SidebarItem.project(projectNode.project.id)) {
                                Label(projectNode.project.name, systemImage: "folder.fill")
                            }
                        }
                    }
                } label: {
                    NavigationLink(value: SidebarViewModel.SidebarItem.space(spaceNode.space.id)) {
                        Label(spaceNode.space.name, systemImage: "building.2.fill")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Workspace")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(AppColors.brandPrimary)
                }
                .accessibilityLabel("Create Team, Project, or List")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSyncCenter = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: syncIconName)
                        if let last = syncManager.lastSyncedAt, syncManager.state != .offline {
                            Text("Last: \(Self.relativeTime(from: last))")
                                .appFont(AppTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityLabel("Sync Center")
            }
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
