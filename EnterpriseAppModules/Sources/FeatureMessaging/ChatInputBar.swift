import SwiftUI
import DesignSystem
import SharedModels

/// Chat input bar with built-in productivity affordances:
/// - Leading "templates" button (when `onPickTemplate` is provided)
/// - Slash-command palette overlay when the text starts with `/`
/// - Long-press the send button to schedule the message (when `onScheduleSend` is provided)
/// - Debounced draft autosave via `DraftStore` (when `conversationId` is provided)
public struct ChatInputBar: View {
    @Binding var text: String
    let isEditing: Bool
    let onCancelEdit: (() -> Void)?
    let onSend: () -> Void

    // Productivity (all optional — existing callers keep working without these)
    let conversationId: UUID?
    let parentId: UUID?
    let onPickTemplate: (() -> Void)?
    let onScheduleSend: (() -> Void)?
    let onCommandPicked: ((SlashCommandSpec) -> Void)?

    @State private var draftLoaded = false

    public init(
        text: Binding<String>,
        isEditing: Bool = false,
        onCancelEdit: (() -> Void)? = nil,
        onSend: @escaping () -> Void,
        conversationId: UUID? = nil,
        parentId: UUID? = nil,
        onPickTemplate: (() -> Void)? = nil,
        onScheduleSend: (() -> Void)? = nil,
        onCommandPicked: ((SlashCommandSpec) -> Void)? = nil
    ) {
        self._text = text
        self.isEditing = isEditing
        self.onCancelEdit = onCancelEdit
        self.onSend = onSend
        self.conversationId = conversationId
        self.parentId = parentId
        self.onPickTemplate = onPickTemplate
        self.onScheduleSend = onScheduleSend
        self.onCommandPicked = onCommandPicked
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showSlashPalette {
                SlashCommandPalette(filter: text) { spec in
                    if let handler = onCommandPicked {
                        handler(spec)
                    } else {
                        // Default behavior: just fill in the command name.
                        text = "/\(spec.name) "
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: AppSpacing.sm) {
                if isEditing {
                    Button(action: { onCancelEdit?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(AppColors.statusError)
                    }
                }

                if let onPickTemplate, !isEditing {
                    Button(action: onPickTemplate) {
                        Image(systemName: "text.badge.star")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .accessibilityLabel("Insert template")
                }

                TextField("Type a message…", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.surfaceElevated)
                    .clipShape(Capsule())

                sendButton
            }
            .padding()
            .background(AppColors.backgroundPrimary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(AppColors.borderDefault)
                    .padding(.top, 0),
                alignment: .top
            )
            .task {
                await hydrateDraftIfNeeded()
            }
            .onChange(of: text) { _, newValue in
                guard draftLoaded, let conversationId else { return }
                DraftStore.shared.setDraft(conversationId: conversationId, parentId: parentId, body: newValue)
            }
        }
    }

    @ViewBuilder
    private var sendButton: some View {
        let disabled = text.trimmingCharacters(in: .whitespaces).isEmpty
        let icon = isEditing ? "checkmark.circle.fill" : "arrow.up.circle.fill"
        let view = Image(systemName: icon)
            .resizable()
            .frame(width: 32, height: 32)
            .foregroundColor(disabled ? AppColors.textSecondary : AppColors.brandPrimary)

        if let onScheduleSend, !isEditing {
            Button(action: onSend) { view }
                .disabled(disabled)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        guard !disabled else { return }
                        onScheduleSend()
                    }
                )
        } else {
            Button(action: onSend) { view }
                .disabled(disabled)
        }
    }

    private var showSlashPalette: Bool {
        !isEditing && text.hasPrefix("/") && !text.contains("\n")
    }

    private func hydrateDraftIfNeeded() async {
        guard !draftLoaded, let conversationId, text.isEmpty else {
            draftLoaded = true
            return
        }
        let body = await DraftStore.shared.loadDraft(conversationId: conversationId, parentId: parentId)
        if !body.isEmpty, text.isEmpty {
            text = body
        }
        draftLoaded = true
    }
}
