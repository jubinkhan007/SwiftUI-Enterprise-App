import SwiftUI
import DesignSystem

struct ReactionDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let emoji: String
    let messageId: UUID
    let currentUserId: UUID
    let interactionStore: MessageInteractionStore
    let participantNames: [UUID: String]

    private var reactors: [(id: UUID, name: String)] {
        Array(interactionStore.reactions[messageId]?[emoji] ?? [])
            .map { userId in
                (id: userId, name: displayName(for: userId))
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var didCurrentUserReact: Bool {
        interactionStore.reactions[messageId]?[emoji]?.contains(currentUserId) == true
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(reactors, id: \.id) { reactor in
                        HStack(spacing: AppSpacing.md) {
                            Circle()
                                .fill(AppColors.surfaceElevated)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(emoji)
                                        .font(.system(size: 16))
                                )
                            Text(reactor.name)
                                .appFont(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                } header: {
                    HStack(spacing: AppSpacing.xs) {
                        Text(emoji)
                        Text("·")
                        Text("\(reactors.count)")
                    }
                    .appFont(AppTypography.subheadline)
                }

                if didCurrentUserReact {
                    Section {
                        Button("Remove my \(emoji) reaction", role: .destructive) {
                            interactionStore.toggleReaction(emoji, for: messageId, userId: currentUserId)
                            dismiss()
                        }
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle("Reactions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func displayName(for userId: UUID) -> String {
        if userId == currentUserId {
            return "You"
        }

        let trimmed = participantNames[userId]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }

        return "Unknown member"
    }
}
