import SwiftUI
import SharedModels
import DesignSystem
import AppNetwork
import Domain
import FeatureInbox

@MainActor
final class ChannelSettingsViewModel: ObservableObject {
    @Published private(set) var conversation: ConversationDTO
    @Published var name: String
    @Published var topic: String
    @Published var descriptionText: String
    @Published var availableMembers: [OrganizationMemberDTO] = []
    @Published var selectedMemberIds = Set<UUID>()
    @Published var errorText: String?
    @Published var isSaving = false

    let currentUserId: UUID
    private let messagingRepository: MessagingRepositoryProtocol
    private let apiClient: APIClientProtocol

    init(conversation: ConversationDTO, currentUserId: UUID, messagingRepository: MessagingRepositoryProtocol, apiClient: APIClientProtocol) {
        self.conversation = conversation
        self.currentUserId = currentUserId
        self.messagingRepository = messagingRepository
        self.apiClient = apiClient
        self.name = conversation.name ?? ""
        self.topic = conversation.topic ?? ""
        self.descriptionText = conversation.description ?? ""
    }

    var currentMember: ConversationMemberDTO? {
        conversation.members?.first(where: { $0.userId == currentUserId })
    }

    var canManage: Bool {
        guard let currentMember else { return false }
        return currentMember.role.lowercased() == "admin" || conversation.ownerId == currentUserId
    }

    func refresh() async {
        do {
            let response = try await messagingRepository.getConversation(id: conversation.id)
            if let updated = response.data {
                conversation = updated
                name = updated.name ?? name
                topic = updated.topic ?? topic
                descriptionText = updated.description ?? descriptionText
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    func loadAvailableMembers() async {
        guard let orgId = OrganizationContext.shared.orgId else { return }
        do {
            let endpoint = OrganizationEndpoint.listMembers(orgId: orgId, configuration: .current)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[OrganizationMemberDTO]>.self)
            let currentIds = Set(conversation.members?.map(\.userId) ?? [])
            availableMembers = (response.data ?? []).filter { !currentIds.contains($0.userId) }
        } catch {
            errorText = error.localizedDescription
        }
    }

    func saveMetadata() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let response = try await messagingRepository.updateConversation(
                id: conversation.id,
                request: UpdateConversationRequest(
                    name: name.isEmpty ? nil : name,
                    description: descriptionText.isEmpty ? nil : descriptionText,
                    topic: topic.isEmpty ? nil : topic
                )
            )
            if let updated = response.data {
                conversation = updated
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    func addSelectedMembers() async {
        guard !selectedMemberIds.isEmpty else { return }
        do {
            let response = try await messagingRepository.addMembers(
                conversationId: conversation.id,
                request: AddConversationMembersRequest(memberIds: Array(selectedMemberIds))
            )
            if let updated = response.data {
                conversation = updated
                selectedMemberIds.removeAll()
                await loadAvailableMembers()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    func removeMember(_ memberId: UUID) async {
        do {
            let response = try await messagingRepository.removeMember(conversationId: conversation.id, memberId: memberId)
            if let updated = response.data {
                conversation = updated
                await loadAvailableMembers()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    func archive() async -> Bool {
        do {
            let response = try await messagingRepository.archiveConversation(id: conversation.id)
            if let updated = response.data {
                conversation = updated
            }
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func leave() async -> Bool {
        do {
            _ = try await messagingRepository.leaveConversation(id: conversation.id)
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func applyPreferenceUpdate(_ updated: ConversationMemberDTO) {
        guard var members = conversation.members,
              let index = members.firstIndex(where: { $0.id == updated.id }) else { return }
        members[index] = updated
        conversation = ConversationDTO(
            id: conversation.id,
            type: conversation.type,
            name: conversation.name,
            description: conversation.description,
            topic: conversation.topic,
            isArchived: conversation.isArchived,
            ownerId: conversation.ownerId,
            lastMessageAt: conversation.lastMessageAt,
            createdAt: conversation.createdAt,
            members: members
        )
    }
}

public struct ChannelSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChannelSettingsViewModel
    let messagingRepository: MessagingRepositoryProtocol

    @State private var showNotificationPreferences = false

    public init(
        conversation: ConversationDTO,
        currentUserId: UUID,
        messagingRepository: MessagingRepositoryProtocol,
        apiClient: APIClientProtocol
    ) {
        _viewModel = StateObject(wrappedValue: ChannelSettingsViewModel(
            conversation: conversation,
            currentUserId: currentUserId,
            messagingRepository: messagingRepository,
            apiClient: apiClient
        ))
        self.messagingRepository = messagingRepository
    }

    public var body: some View {
        Form {
            Section("Metadata") {
                TextField("Name", text: $viewModel.name)
                TextField("Topic", text: $viewModel.topic)
                TextField("Description", text: $viewModel.descriptionText, axis: .vertical)
                    .lineLimit(3...6)

                if viewModel.canManage {
                    Button(viewModel.isSaving ? "Saving..." : "Save Changes") {
                        Task { await viewModel.saveMetadata() }
                    }
                    .disabled(viewModel.isSaving)
                }
            }

            Section("Preferences") {
                Button("Notification Preferences") {
                    showNotificationPreferences = true
                }
            }

            Section("Members") {
                ForEach(viewModel.conversation.members ?? []) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName)
                            Text(member.role.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if viewModel.canManage && viewModel.conversation.ownerId != member.userId {
                            Button("Remove", role: .destructive) {
                                Task { await viewModel.removeMember(member.userId) }
                            }
                        }
                    }
                }

                if viewModel.canManage && !viewModel.availableMembers.isEmpty {
                    ForEach(viewModel.availableMembers) { member in
                        Toggle(
                            "\(member.displayName) (\(member.email))",
                            isOn: Binding(
                                get: { viewModel.selectedMemberIds.contains(member.userId) },
                                set: { isOn in
                                    if isOn {
                                        viewModel.selectedMemberIds.insert(member.userId)
                                    } else {
                                        viewModel.selectedMemberIds.remove(member.userId)
                                    }
                                }
                            )
                        )
                    }
                    Button("Add Selected Members") {
                        Task { await viewModel.addSelectedMembers() }
                    }
                    .disabled(viewModel.selectedMemberIds.isEmpty)
                }
            }

            Section("Lifecycle") {
                Button("Leave Channel", role: .destructive) {
                    Task {
                        if await viewModel.leave() {
                            dismiss()
                        }
                    }
                }

                if viewModel.canManage {
                    Button("Archive Channel", role: .destructive) {
                        Task {
                            if await viewModel.archive() {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Channel Settings")
        .task {
            await viewModel.refresh()
            await viewModel.loadAvailableMembers()
        }
        .sheet(isPresented: $showNotificationPreferences) {
            NotificationPreferencesView(
                conversation: viewModel.conversation,
                currentMember: viewModel.currentMember,
                messagingRepository: messagingRepository
            ) { updated in
                viewModel.applyPreferenceUpdate(updated)
            }
        }
    }
}
