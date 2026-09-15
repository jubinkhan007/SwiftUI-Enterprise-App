import SwiftUI
import AppData
import DesignSystem

public struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager: AuthManager
    private let initialName: String
    private let initialEmail: String

    @State private var displayName: String
    @State private var email: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    public init(authManager: AuthManager) {
        self._authManager = ObservedObject(wrappedValue: authManager)
        let user = authManager.session?.user
        self.initialName = user?.displayName ?? ""
        self.initialEmail = user?.email ?? ""
        self._displayName = State(initialValue: user?.displayName ?? "")
        self._email = State(initialValue: user?.email ?? "")
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        AppAvatar(name: displayName.isEmpty ? initialName : displayName, size: .large)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName.isEmpty ? "Your profile" : displayName)
                                .appFont(AppTypography.headline)
                            Text(authManager.session?.user.role.rawValue.capitalized ?? "Member")
                                .appFont(AppTypography.caption1)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Personal information") {
                    TextField("Full name", text: $displayName)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(AppColors.statusError)
                    }
                }
            }
            .navigationTitle("Profile")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, address.contains("@") else {
            errorMessage = "Enter a valid name and email address."
            return
        }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await authManager.updateProfile(displayName: name, email: address)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
