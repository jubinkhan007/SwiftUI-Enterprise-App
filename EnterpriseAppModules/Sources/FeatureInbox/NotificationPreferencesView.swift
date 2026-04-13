import SwiftUI
import SharedModels
import DesignSystem
import Domain

public struct NotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss

    let conversation: ConversationDTO
    let currentMember: ConversationMemberDTO?
    let messagingRepository: MessagingRepositoryProtocol
    let onUpdated: (ConversationMemberDTO) -> Void

    @State private var selectedPreference: String
    @State private var isMuted: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    public init(
        conversation: ConversationDTO,
        currentMember: ConversationMemberDTO?,
        messagingRepository: MessagingRepositoryProtocol,
        onUpdated: @escaping (ConversationMemberDTO) -> Void
    ) {
        self.conversation = conversation
        self.currentMember = currentMember
        self.messagingRepository = messagingRepository
        self.onUpdated = onUpdated
        _selectedPreference = State(initialValue: currentMember?.notificationPreference ?? "all")
        _isMuted = State(initialValue: currentMember?.isMuted ?? false)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Conversation") {
                    Toggle("Mute this conversation", isOn: $isMuted)
                }

                Section("Notifications") {
                    Picker("Notify me", selection: $selectedPreference) {
                        Text("All messages").tag("all")
                        Text("Mentions only").tag("mentions")
                        Text("Nothing").tag("none")
                    }
                    .pickerStyle(.inline)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(isSaving)
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let response = try await messagingRepository.updatePreferences(
                conversationId: conversation.id,
                request: UpdateConversationMemberPreferencesRequest(
                    notificationPreference: selectedPreference,
                    isMuted: isMuted
                )
            )
            guard let updated = response.data else {
                errorMessage = response.error?.message ?? "Could not save notification preferences."
                return
            }

            selectedPreference = updated.notificationPreference ?? selectedPreference
            isMuted = updated.isMuted
            onUpdated(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
