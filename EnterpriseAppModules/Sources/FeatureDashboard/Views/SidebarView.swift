import SwiftUI
import DesignSystem
import SharedModels

public struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel
    @State private var showingCreateSheet = false
    
    public init(viewModel: SidebarViewModel) {
        self.viewModel = viewModel
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
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateHierarchyItemSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .refreshable {
            await viewModel.fetchHierarchy()
        }
        .onAppear {
            if viewModel.areas.isEmpty {
                Task {
                    await viewModel.fetchHierarchy()
                }
            }
        }
    }
}
