import SwiftUI
import SharedModels
import DesignSystem
import Domain

public struct ConvertMessageToTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    let message: MessageDTO
    let hierarchy: [HierarchyTreeDTO.SpaceNode]
    let messagingRepository: MessagingRepositoryProtocol
    let onConverted: (ConvertMessageToTaskResponse) -> Void

    @State private var title: String
    @State private var description: String
    @State private var selectedListId: UUID?
    @State private var isSubmitting = false
    @State private var error: String?

    public init(
        message: MessageDTO,
        hierarchy: [HierarchyTreeDTO.SpaceNode],
        messagingRepository: MessagingRepositoryProtocol,
        onConverted: @escaping (ConvertMessageToTaskResponse) -> Void
    ) {
        self.message = message
        self.hierarchy = hierarchy
        self.messagingRepository = messagingRepository
        self.onConverted = onConverted

        let defaultTitle = message.body
            .split(separator: "\n").first.map(String.init) ?? "Follow up on message"
        self._title = State(initialValue: String(defaultTitle.prefix(140)))
        self._description = State(initialValue: message.body)
        self._selectedListId = State(initialValue: hierarchy.first?.projects.first?.lists.first?.id)
    }

    public var body: some View {
        NavigationStack {
            Form {
                taskSection
                destinationSection
                errorSection
            }
            .navigationTitle("Convert to Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
        }
    }

    @ViewBuilder
    private var taskSection: some View {
        Section("Task") {
            TextField("Title", text: $title)
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    @ViewBuilder
    private var destinationSection: some View {
        Section("Destination") {
            if hierarchy.isEmpty {
                Text("No projects available")
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(destinationOptions, id: \.list.id) { option in
                    destinationRow(option)
                }
            }
        }
    }

    @ViewBuilder
    private func destinationRow(_ option: DestinationOption) -> some View {
        Button {
            selectedListId = option.list.id
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(option.list.name)
                        .foregroundColor(AppColors.textPrimary)
                    Text(option.subtitle)
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if selectedListId == option.list.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppColors.brandPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error {
            Section {
                Text(error)
                    .foregroundColor(.red)
                    .appFont(AppTypography.caption1)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            if isSubmitting {
                ProgressView()
            } else {
                Button("Create") {
                    Task { await submit() }
                }
                .disabled(selectedListId == nil || title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var destinationOptions: [DestinationOption] {
        var out: [DestinationOption] = []
        for space in hierarchy {
            for project in space.projects {
                for list in project.lists {
                    out.append(DestinationOption(
                        list: list,
                        subtitle: "\(space.space.name) · \(project.project.name)"
                    ))
                }
            }
        }
        return out
    }

    private struct DestinationOption {
        let list: TaskListDTO
        let subtitle: String
    }

    private func submit() async {
        guard let listId = selectedListId else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let request = ConvertMessageToTaskRequest(
            listId: listId,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description
        )
        do {
            let response = try await messagingRepository.convertMessageToTask(messageId: message.id, request: request)
            if let data = response.data {
                onConverted(data)
                dismiss()
            } else {
                error = "Could not create task."
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
