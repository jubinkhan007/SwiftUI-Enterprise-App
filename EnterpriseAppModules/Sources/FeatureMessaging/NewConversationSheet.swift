import SwiftUI
import Domain
import SharedModels
import DesignSystem

public struct NewConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let messagingRepository: MessagingRepositoryProtocol
    let onCreated: (ConversationDTO) -> Void
    
    @State private var otherUserIdStr: String = ""
    @State private var isLoading = false
    @State private var errorText: String?
    
    public init(messagingRepository: MessagingRepositoryProtocol, onCreated: @escaping (ConversationDTO) -> Void) {
        self.messagingRepository = messagingRepository
        self.onCreated = onCreated
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Direct Message")) {
                    TextField("Other User UUID", text: $otherUserIdStr)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled(true)
                }
                
                if let err = errorText {
                    Section {
                        Text(err).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await create() }
                    }
                    .disabled(isLoading || otherUserIdStr.isEmpty)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private func create() async {
        guard let uuid = UUID(uuidString: otherUserIdStr.trimmingCharacters(in: .whitespaces)) else {
            errorText = "Invalid UUID formatting."
            return
        }
        isLoading = true
        errorText = nil
        do {
            let request = CreateConversationRequest(type: "direct", memberIds: [uuid], name: nil)
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
        isLoading = false
    }
}
