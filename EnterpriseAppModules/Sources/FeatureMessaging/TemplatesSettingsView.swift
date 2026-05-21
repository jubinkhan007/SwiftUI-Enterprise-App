import SwiftUI
import DesignSystem
import SharedModels

public struct TemplatesSettingsView: View {
    @StateObject private var store: TemplateStore = .shared
    @State private var editing: MessageTemplateDTO?
    @State private var showCreate = false

    public let canManageOrgTemplates: Bool

    public init(canManageOrgTemplates: Bool) {
        self.canManageOrgTemplates = canManageOrgTemplates
    }

    public var body: some View {
        List {
            section(title: "My templates", templates: myTemplates, canEdit: { _ in true })
            section(title: "Org-wide templates", templates: orgTemplates, canEdit: { _ in canManageOrgTemplates })
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Templates")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill").appFont(AppTypography.title3)
                }
            }
        }
        .task { await store.load() }
        .refreshable { await store.load() }
        .sheet(item: $editing) { tpl in
            TemplateEditorSheet(canManageOrgTemplates: canManageOrgTemplates, editing: tpl)
        }
        .sheet(isPresented: $showCreate) {
            TemplateEditorSheet(canManageOrgTemplates: canManageOrgTemplates, editing: nil)
        }
    }

    @ViewBuilder
    private func section(title: String, templates: [MessageTemplateDTO], canEdit: @escaping (MessageTemplateDTO) -> Bool) -> some View {
        Section(title) {
            if templates.isEmpty {
                Text("None.")
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(templates) { tpl in
                    Button {
                        if canEdit(tpl) { editing = tpl }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(tpl.name)
                                    .appFont(AppTypography.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                if let s = tpl.shortcut {
                                    Text("/template \(s)")
                                        .appFont(AppTypography.caption2)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            Text(tpl.body)
                                .appFont(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }
                    .disabled(!canEdit(tpl))
                }
                .onDelete { offsets in
                    let ids = offsets.map { templates[$0].id }
                    Task {
                        for id in ids {
                            if let target = templates.first(where: { $0.id == id }), canEdit(target) {
                                await store.delete(id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var myTemplates: [MessageTemplateDTO] { store.templates.filter { $0.scope == .user } }
    private var orgTemplates: [MessageTemplateDTO] { store.templates.filter { $0.scope == .org } }
}

private struct TemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let canManageOrgTemplates: Bool
    let editing: MessageTemplateDTO?

    @State private var name: String = ""
    @State private var shortcut: String = ""
    @State private var bodyText: String = ""
    @State private var scope: TemplateScope = .user
    @State private var isSubmitting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Name", text: $name)
                    TextField("Shortcut (optional)", text: $shortcut)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Body", text: $bodyText, axis: .vertical).lineLimit(4...10)
                }
                Section("Scope") {
                    Picker("Scope", selection: $scope) {
                        Text("Just me").tag(TemplateScope.user)
                        Text("Org-wide").tag(TemplateScope.org)
                            .disabled(!canManageOrgTemplates && editing?.scope != .org)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Text("Variables: {{user.name}}, {{user.email}}, {{org.name}}, {{conversation.name}}, {{date}}, {{time}}")
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                if let error {
                    Section { Text(error).foregroundColor(.red).appFont(AppTypography.caption1) }
                }
            }
            .navigationTitle(editing == nil ? "New template" : "Edit template")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting { ProgressView() }
                    else {
                        Button("Save") {
                            Task { await submit() }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  bodyText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .onAppear {
                if let t = editing {
                    name = t.name
                    shortcut = t.shortcut ?? ""
                    bodyText = t.body
                    scope = t.scope
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmedShortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if let editing {
            if let _ = await TemplateStore.shared.update(id: editing.id, name: name, shortcut: trimmedShortcut, body: bodyText) {
                dismiss()
            } else { error = "Failed to save." }
        } else {
            if let _ = await TemplateStore.shared.create(scope: scope, name: name, shortcut: trimmedShortcut, body: bodyText) {
                dismiss()
            } else { error = "Failed to create." }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
