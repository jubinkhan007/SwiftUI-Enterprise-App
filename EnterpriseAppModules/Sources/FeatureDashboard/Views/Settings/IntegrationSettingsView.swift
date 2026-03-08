import SwiftUI
import Domain
import SharedModels
import DesignSystem
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class IntegrationSettingsViewModel: ObservableObject {
    @Published var apiKeys: [APIKeyDTO] = []
    @Published var webhooks: [WebhookSubscriptionDTO] = []
    @Published var isLoading = false
    @Published var error: Error?

    @Published var createdAPIKey: CreateAPIKeyResponse?

    private let integrationRepository: IntegrationRepositoryProtocol

    init(integrationRepository: IntegrationRepositoryProtocol) {
        self.integrationRepository = integrationRepository
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            async let keys = integrationRepository.listAPIKeys()
            async let hooks = integrationRepository.listWebhooks()
            apiKeys = try await keys
            webhooks = try await hooks
        } catch {
            self.error = error
        }
    }

    func createAPIKey(name: String, scopes: [APIKeyScope]) async {
        do {
            let response = try await integrationRepository.createAPIKey(
                payload: CreateAPIKeyRequest(name: name, scopes: scopes)
            )
            createdAPIKey = response
            await refresh()
        } catch {
            self.error = error
        }
    }

    func revokeAPIKey(id: UUID) async {
        do {
            try await integrationRepository.revokeAPIKey(id: id)
            await refresh()
        } catch {
            self.error = error
        }
    }

    func createWebhook(url: String, events: [String], secret: String?) async {
        do {
            _ = try await integrationRepository.createWebhook(
                payload: CreateWebhookSubscriptionRequest(targetUrl: url, events: events, secret: secret)
            )
            await refresh()
        } catch {
            self.error = error
        }
    }

    func deleteWebhook(id: UUID) async {
        do {
            try await integrationRepository.deleteWebhook(id: id)
            await refresh()
        } catch {
            self.error = error
        }
    }

    func testWebhook(id: UUID) async -> WebhookTestResponse? {
        do {
            return try await integrationRepository.testWebhook(id: id)
        } catch {
            self.error = error
            return nil
        }
    }
}

public struct IntegrationSettingsView: View {
    @StateObject private var viewModel: IntegrationSettingsViewModel

    @State private var showingCreateKey = false
    @State private var showingCreateWebhook = false
    @State private var showErrorAlert = false

    public init(integrationRepository: IntegrationRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: IntegrationSettingsViewModel(integrationRepository: integrationRepository))
    }

    public var body: some View {
        List {
            apiKeysSection
            webhooksSection
        }
        .navigationTitle("Integrations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New API Key") { showingCreateKey = true }
                    Button("New Webhook") { showingCreateWebhook = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
        .onChange(of: viewModel.error != nil) { _, hasError in
            showErrorAlert = hasError
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "Something went wrong.")
        }
        .sheet(isPresented: $showingCreateKey) {
            CreateAPIKeySheet { name, scopes in
                Task { await viewModel.createAPIKey(name: name, scopes: scopes) }
                showingCreateKey = false
            }
        }
        .sheet(isPresented: $showingCreateWebhook) {
            CreateWebhookSheet { url, events, secret in
                Task { await viewModel.createWebhook(url: url, events: events, secret: secret) }
                showingCreateWebhook = false
            }
        }
        .sheet(item: $viewModel.createdAPIKey) { created in
            CreatedAPIKeySheet(created: created) {
                viewModel.createdAPIKey = nil
            }
        }
    }

    private var apiKeysSection: some View {
        Section {
            if viewModel.apiKeys.isEmpty {
                Text("No API keys yet.")
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(viewModel.apiKeys) { key in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(key.name)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Prefix: \(key.keyPrefix) • Scopes: \(key.scopes.map(\.rawValue).joined(separator: ", "))")
                            .foregroundColor(AppColors.textSecondary)
                            .font(.caption)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await viewModel.revokeAPIKey(id: key.id) }
                        } label: {
                            Label("Revoke", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("API Keys")
        } footer: {
            Text("Keys are shown once on creation. Store them securely.")
        }
    }

    private var webhooksSection: some View {
        Section {
            let hooks = viewModel.webhooks
            if hooks.isEmpty {
                Text("No webhooks yet.")
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(Array(hooks.enumerated()), id: \.element.id) { _, hook in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(hook.targetUrl)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)
                        Text("Events: \(hook.events.joined(separator: ", "))")
                            .foregroundColor(AppColors.textSecondary)
                            .font(.caption)

                        HStack(spacing: 12) {
                            Text(hook.isActive ? "Active" : "Paused")
                                .font(.caption2)
                                .foregroundColor(hook.isActive ? AppColors.statusSuccess : AppColors.statusWarning)

                            Text("Failures: \(hook.failureCount)")
                                .font(.caption2)
                                .foregroundColor(AppColors.textTertiary)

                            Spacer()

                            Button("Test") {
                                Task {
                                    _ = await viewModel.testWebhook(id: hook.id)
                                }
                            }
                            .font(.caption)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteWebhook(id: hook.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Webhooks")
        } footer: {
            Text("Requests include HMAC signature in `X-Webhook-Signature`.")
        }
    }
}

private struct CreateAPIKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var scopes: Set<APIKeyScope> = [.tasksRead, .tasksWrite]

    let onCreate: (_ name: String, _ scopes: [APIKeyScope]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                }
                Section("Scopes") {
                    scopeToggle(.tasksRead, label: "Tasks: Read")
                    scopeToggle(.tasksWrite, label: "Tasks: Write")
                    scopeToggle(.webhooksManage, label: "Webhooks: Manage")
                    scopeToggle(.apiKeysManage, label: "API Keys: Manage")
                }
            }
            .navigationTitle("New API Key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), Array(scopes))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || scopes.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func scopeToggle(_ scope: APIKeyScope, label: String) -> some View {
        Toggle(isOn: Binding(
            get: { scopes.contains(scope) },
            set: { isOn in
                if isOn { scopes.insert(scope) } else { scopes.remove(scope) }
            }
        )) {
            Text(label)
        }
    }
}

private struct CreateWebhookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url: String = ""
    @State private var eventsText: String = "task.created, task.updated, task.deleted"
    @State private var secret: String = ""

    let onCreate: (_ url: String, _ events: [String], _ secret: String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Endpoint") {
                    TextField("Target URL", text: $url)
                        .platformTextEntry()
                }
                Section("Events") {
                    TextField("Comma-separated events", text: $eventsText)
                        .platformTextEntry()
                }
                Section("Secret (Optional)") {
                    TextField("Signing secret", text: $secret)
                        .platformTextEntry()
                }
            }
            .navigationTitle("New Webhook")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let events = eventsText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        let sec = secret.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreate(
                            url.trimmingCharacters(in: .whitespacesAndNewlines),
                            events,
                            sec.isEmpty ? nil : sec
                        )
                    }
                    .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct CreatedAPIKeySheet: View {
    let created: CreateAPIKeyResponse
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("API Key Created")
                    .font(.headline)

                Text("Copy this key now. You won’t be able to see it again.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(created.rawKey)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Copy") {
                    Clipboard.copy(created.rawKey)
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationTitle("API Key")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func platformTextEntry() -> some View {
#if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
#else
        self
#endif
    }
}

private enum Clipboard {
    static func copy(_ text: String) {
#if os(iOS)
        UIPasteboard.general.string = text
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }
}
