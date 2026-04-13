import SwiftUI
import SharedModels
import DesignSystem
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct MessageActionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let message: MessageDTO
    let currentUserId: UUID
    let interactionStore: MessageInteractionStore
    let onReplyInThread: () -> Void
    let onCreateTask: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var showingEmojiPicker = false

    private let quickReactions = ["👍", "❤️", "👀", "✅", "🔥"]

    init(
        message: MessageDTO,
        currentUserId: UUID,
        interactionStore: MessageInteractionStore,
        onReplyInThread: @escaping () -> Void,
        onCreateTask: @escaping () -> Void,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.message = message
        self.currentUserId = currentUserId
        self.interactionStore = interactionStore
        self.onReplyInThread = onReplyInThread
        self.onCreateTask = onCreateTask
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Reactions") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(quickReactions, id: \.self) { emoji in
                                Button(emoji) {
                                    interactionStore.toggleReaction(emoji, for: message.id, userId: currentUserId)
                                }
                                .buttonStyle(.bordered)
                            }
                            Button {
                                showingEmojiPicker = true
                            } label: {
                                Image(systemName: "face.smiling")
                                    .foregroundColor(AppColors.brandPrimary)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }

                    ForEach(interactionStore.reactionSummary(for: message.id), id: \.emoji) { reaction in
                        HStack {
                            Text(reaction.emoji)
                            Spacer()
                            Text("\(reaction.count)")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Section("Actions") {
                    actionRow("Reply in Thread", systemImage: "arrowshape.turn.up.left") {
                        dismiss()
                        onReplyInThread()
                    }
                    actionRow(
                        interactionStore.pinnedMessages.contains(message.id) ? "Unpin Message" : "Pin Message",
                        systemImage: "pin"
                    ) {
                        interactionStore.togglePinned(message.id)
                    }
                    actionRow(
                        interactionStore.bookmarkedMessages.contains(message.id) ? "Remove Bookmark" : "Save / Bookmark",
                        systemImage: "bookmark"
                    ) {
                        interactionStore.toggleBookmarked(message.id)
                    }

                    ShareLink(
                        item: message.body,
                        subject: Text("Message from \(message.senderName)"),
                        message: Text(message.body)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    actionRow("Copy Link", systemImage: "link") {
                        copyToPasteboard("enterpriseapp://messages/\(message.conversationId.uuidString)/\(message.id.uuidString)")
                    }
                    actionRow("Create Task from Message", systemImage: "checklist") {
                        dismiss()
                        onCreateTask()
                    }
                    if let onEdit {
                        actionRow("Edit", systemImage: "pencil") {
                            dismiss()
                            onEdit()
                        }
                    }
                    if let onDelete {
                        Button(role: .destructive) {
                            dismiss()
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Message Actions")
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerSheet { emoji in
                    interactionStore.toggleReaction(emoji, for: message.id, userId: currentUserId)
                }
            }
        }
    }

    private func actionRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
    }

    private func copyToPasteboard(_ text: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = text
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }
}

// MARK: - Full Emoji Picker

private struct EmojiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void

    private let categories: [(name: String, emojis: [String])] = [
        ("Smileys", ["😀","😂","🥰","😍","🤩","😎","🤔","😢","😡","🤯","😅","🤣","☺️","😊","🙂","😇","🥳","🤗","😏","😒"]),
        ("Gestures", ["👍","👎","👏","🙌","🤝","✌️","🤞","💪","🙏","👋","🤙","☝️","👆","👇","👉","👈","🤜","🤛"]),
        ("Hearts", ["❤️","🧡","💛","💚","💙","💜","🖤","🤍","🤎","💔","❣️","💕","💞","💓","💗","💖","💝","💘"]),
        ("Symbols", ["✅","❌","⭐","🔥","💯","🎉","🚀","💡","👀","💬","🔔","📌","🏆","⚡","🎯","💎","🔑","🛡️"]),
        ("Nature", ["🌟","🌈","🌙","☀️","⛅","🌊","🌸","🌺","🍀","🦋","🐶","🐱","🦊","🐸","🦁","🐯","🦄","🐧"]),
        ("Food", ["☕","🍕","🎂","🍔","🍟","🌮","🍣","🍜","🍩","🍪","🍫","🧁","🥑","🍎","🍊","🍋","🍇","🍓"]),
    ]

    private let columns = Array(repeating: GridItem(.flexible()), count: 8)

    var body: some View {
        NavigationStack {
            ScrollView {
                ForEach(categories, id: \.name) { category in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(category.name)
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                            ForEach(category.emojis, id: \.self) { emoji in
                                Button(emoji) {
                                    onSelect(emoji)
                                    dismiss()
                                }
                                .font(.title2)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, AppSpacing.md)
                }
            }
            .navigationTitle("Add Reaction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
