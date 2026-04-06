import SwiftUI
import Domain
import SharedModels
import DesignSystem
import AppNetwork

public struct NewConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let messagingRepository: MessagingRepositoryProtocol
    let apiClient: APIClientProtocol
    let currentUserId: UUID
    let onCreated: (ConversationDTO) -> Void

    @State private var members: [OrganizationMemberDTO] = []
    @State private var searchText: String = ""
    @State private var isLoadingMembers = false
    @State private var isCreating = false
    @State private var errorText: String?

    public init(
        messagingRepository: MessagingRepositoryProtocol,
        apiClient: APIClientProtocol,
        currentUserId: UUID,
        onCreated: @escaping (ConversationDTO) -> Void
    ) {
        self.messagingRepository = messagingRepository
        self.apiClient = apiClient
        self.currentUserId = currentUserId
        self.onCreated = onCreated
    }

    private var filteredMembers: [OrganizationMemberDTO] {
        if searchText.isEmpty { return members }
        let lower = searchText.lowercased()
        return members.filter {
            $0.displayName.lowercased().contains(lower) || $0.email.lowercased().contains(lower)
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if isLoadingMembers {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredMembers) { member in
                        Button {
                            Task { await startConversation(with: member.userId) }
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Circle()
                                    .fill(AppColors.surfaceElevated)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(String(member.displayName.prefix(1)).uppercased())
                                            .appFont(AppTypography.caption1)
                                            .foregroundColor(AppColors.textPrimary)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.displayName)
                                        .appFont(AppTypography.body)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(member.email)
                                        .appFont(AppTypography.caption1)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                if isCreating {
                                    ProgressView()
                                        .scaleEffect(0.75)
                                }
                            }
                        }
                        .disabled(isCreating)
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search members")
                }
            }
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("OK") { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
        .task {
            await fetchMembers()
        }
    }

    private func fetchMembers() async {
        guard let orgId = OrganizationContext.shared.orgId else { return }
        isLoadingMembers = true
        do {
            let endpoint = OrganizationEndpoint.listMembers(orgId: orgId, configuration: .current)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[OrganizationMemberDTO]>.self)
            members = (response.data ?? []).filter { $0.userId != currentUserId }
        } catch {
            errorText = error.localizedDescription
        }
        isLoadingMembers = false
    }

    private func startConversation(with userId: UUID) async {
        isCreating = true
        errorText = nil
        do {
            let request = CreateConversationRequest(type: "direct", memberIds: [userId], name: nil)
            let response = try await messagingRepository.createConversation(request)
            if let conv = response.data {
                dismiss()
                onCreated(conv)
            } else {
                errorText = "No conversation returned."
            }
        } catch {
            errorText = error.localizedDescription
        }
        isCreating = false
    }
}
