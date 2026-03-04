import SwiftUI
import SharedModels
import DesignSystem

public struct MemberPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let members: [OrganizationMemberDTO]
    @Binding var selectedUserId: UUID?
    let allowUnassign: Bool

    @State private var searchText: String = ""

    public init(
        title: String = "Select member",
        members: [OrganizationMemberDTO],
        selectedUserId: Binding<UUID?>,
        allowUnassign: Bool = true
    ) {
        self.title = title
        self.members = members
        self._selectedUserId = selectedUserId
        self.allowUnassign = allowUnassign
    }

    public var body: some View {
        NavigationStack {
            List {
                if allowUnassign {
                    Button {
                        selectedUserId = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("Unassigned")
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            if selectedUserId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.brandPrimary)
                            }
                        }
                    }
                }

                ForEach(filteredMembers) { member in
                    Button {
                        selectedUserId = member.userId
                        dismiss()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName)
                                    .appFont(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textPrimary)
                                Text(member.email)
                                    .appFont(AppTypography.caption1)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            if selectedUserId == member.userId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.brandPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.brandPrimary)
                }
            }
        }
    }

    private var filteredMembers: [OrganizationMemberDTO] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = members.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        guard !trimmed.isEmpty else { return base }
        let needle = trimmed.lowercased()
        return base.filter { m in
            m.displayName.lowercased().contains(needle) || m.email.lowercased().contains(needle)
        }
    }
}

