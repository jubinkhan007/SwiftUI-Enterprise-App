import SwiftUI
import DesignSystem
import SharedModels

/// Searchable list of templates the user can insert into the chat composer.
public struct TemplatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: TemplateStore = .shared

    let conversationId: UUID?
    let onInsert: (String) -> Void

    @State private var search: String = ""

    public init(conversationId: UUID? = nil, onInsert: @escaping (String) -> Void) {
        self.conversationId = conversationId
        self.onInsert = onInsert
    }

    public var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    Text(store.templates.isEmpty ? "No templates yet." : "No matches.")
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    ForEach(filtered) { tpl in
                        Button {
                            Task {
                                let rendered = await store.render(tpl, conversationId: conversationId)
                                onInsert(rendered)
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(tpl.name)
                                        .appFont(AppTypography.headline)
                                        .foregroundColor(AppColors.textPrimary)
                                    if let shortcut = tpl.shortcut {
                                        Text("/template \(shortcut)")
                                            .appFont(AppTypography.caption2)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    Spacer()
                                    Text(tpl.scope == .org ? "ORG" : "MINE")
                                        .appFont(AppTypography.overline)
                                        .foregroundColor(tpl.scope == .org ? .purple : AppColors.textSecondary)
                                }
                                Text(tpl.body)
                                    .appFont(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, AppSpacing.xs)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search templates")
            .navigationTitle("Templates")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .task { await store.load() }
        }
    }

    private var filtered: [MessageTemplateDTO] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.templates }
        return store.templates.filter {
            $0.name.lowercased().contains(q)
            || ($0.shortcut?.lowercased().contains(q) ?? false)
            || $0.body.lowercased().contains(q)
        }
    }
}
