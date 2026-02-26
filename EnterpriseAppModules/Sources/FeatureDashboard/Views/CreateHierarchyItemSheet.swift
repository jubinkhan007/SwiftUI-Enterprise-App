import SwiftUI
import DesignSystem
import SharedModels

public struct CreateHierarchyItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: SidebarViewModel

    private enum Mode: String, CaseIterable, Identifiable {
        case space = "Team"
        case project = "Project"
        case list = "List"

        var id: String { rawValue }
    }

    @State private var mode: Mode = .list
    @State private var selectedSpaceId: UUID?
    @State private var selectedProjectId: UUID?
    @State private var name: String = ""
    @State private var descriptionText: String = ""
    @State private var colorText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    public init(viewModel: SidebarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary.ignoresSafeArea()
                ScrollView {
                    content
                        .padding()
                }
            }
            .navigationTitle("Create")
            .toolbar { toolbarContent }
        }
        .task {
            if selectedSpaceId == nil {
                selectedSpaceId = viewModel.areas.first?.space.id
            }
            syncProjectSelection()
        }
        .onChange(of: selectedSpaceId) { _, _ in
            syncProjectSelection()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .foregroundColor(AppColors.brandPrimary)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Create").fontWeight(.bold)
                }
            }
            .foregroundColor(canSave ? AppColors.brandPrimary : AppColors.textTertiary)
            .disabled(!canSave || isSaving)
        }
    }

    private var content: some View {
        VStack(spacing: AppSpacing.lg) {
            pickerCard(title: "Type") {
                Picker("Type", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if mode != .space {
                pickerCard(title: "Team") {
                    Picker("Team", selection: spaceBinding) {
                        if viewModel.areas.isEmpty {
                            Text("No teams yet").tag(Optional<UUID>.none)
                        } else {
                            ForEach(viewModel.areas, id: \.space.id) { node in
                                Text(node.space.name).tag(Optional(node.space.id))
                            }
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if mode == .list || mode == .project {
                pickerCard(title: "Project") {
                    Picker("Project", selection: projectBinding) {
                        if projectOptions.isEmpty {
                            Text("No projects yet").tag(Optional<UUID>.none)
                        } else {
                            ForEach(projectOptions, id: \.id) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            AppTextField(
                namePlaceholder,
                text: $name,
                validationState: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .normal : .success
            )

            if mode != .list {
                AppTextField("Description (Optional)", text: $descriptionText, validationState: .normal)
            }

            if mode == .list {
                AppTextField("Color (Optional, e.g. #6E56CF)", text: $colorText, validationState: .normal)
            }

            if let errorMessage {
                Text(errorMessage)
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.statusError)
                    .multilineTextAlignment(.center)
            }

            if mode == .list && projectOptions.isEmpty {
                Text("Create a Team and Project first, then add a List.")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        switch mode {
        case .space:
            return true
        case .project:
            return selectedSpaceId != nil
        case .list:
            return selectedProjectId != nil
        }
    }

    private var namePlaceholder: String {
        switch mode {
        case .space: return "Team Name (Required)"
        case .project: return "Project Name (Required)"
        case .list: return "List Name (Required)"
        }
    }

    private var spaceBinding: Binding<UUID?> {
        Binding(
            get: { selectedSpaceId },
            set: { selectedSpaceId = $0 }
        )
    }

    private var projectBinding: Binding<UUID?> {
        Binding(
            get: { selectedProjectId },
            set: { selectedProjectId = $0 }
        )
    }

    private struct ProjectOption: Identifiable, Hashable {
        let id: UUID
        let name: String
    }

    private var projectOptions: [ProjectOption] {
        guard let selectedSpaceId,
              let space = viewModel.areas.first(where: { $0.space.id == selectedSpaceId }) else {
            return []
        }

        return space.projects.map { ProjectOption(id: $0.project.id, name: $0.project.name) }
    }

    private func syncProjectSelection() {
        if selectedProjectId == nil || !projectOptions.contains(where: { $0.id == selectedProjectId }) {
            selectedProjectId = projectOptions.first?.id
        }
    }

    private func save() async {
        guard canSave, !isSaving else { return }
        isSaving = true
        errorMessage = nil

        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = trimmedDescription.isEmpty ? nil : trimmedDescription
            let trimmedColor = colorText.trimmingCharacters(in: .whitespacesAndNewlines)
            let color = trimmedColor.isEmpty ? nil : trimmedColor

            switch mode {
            case .space:
                _ = try await viewModel.createSpace(name: trimmedName, description: description)
            case .project:
                guard let selectedSpaceId else { break }
                _ = try await viewModel.createProject(spaceId: selectedSpaceId, name: trimmedName, description: description)
            case .list:
                guard let selectedProjectId else { break }
                _ = try await viewModel.createList(projectId: selectedProjectId, name: trimmedName, color: color)
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func pickerCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.sm)
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.small)
        }
    }
}
