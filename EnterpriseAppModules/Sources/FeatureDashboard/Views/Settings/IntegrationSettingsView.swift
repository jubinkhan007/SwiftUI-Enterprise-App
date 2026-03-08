import SwiftUI
import DesignSystem
import SharedModels
import AppData
import Domain

public struct IntegrationSettingsView: View {
    @StateObject private var viewModel: IntegrationSettingsViewModel
    
    @State private var showingCreateKeyPopover = false
    @State private var newKeyName = ""
    
    @State private var showingCreateWebhook = false
    @State private var newWebhookUrl = ""
    @State private var newWebhookEvents: Set<String> = ["task.created", "task.updated"]
    
    let availableEvents = [
        "task.created", "task.updated", "task.deleted",
        "comment.created", "sprint.closed"
    ]
    
    public init(integrationRepository repository: IntegrationRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: IntegrationSettingsViewModel(repository: repository))
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                if let error = viewModel.errorMessage {
                    AppBanner(message: error, style: .error)
                }
                
                apiKeysSection
                
                Divider()
                
                webhooksSection
            }
            .padding(24)
        }
        .navigationTitle("Integrations")
        .task {
            await viewModel.loadData()
        }
        .sheet(item: Binding(
            get: { viewModel.showAPIKeySecret.map { IdentifiableString(value: $0) } },
            set: { _ in viewModel.showAPIKeySecret = nil }
        )) { wrapper in
            NavigationStack {
                VStack(spacing: 24) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.primary)
                    
                    Text("Your New API Key")
                        .font(AppTypography.h2)
                    
                    Text("Copy this key now. You won't be able to see it again.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    HStack {
                        Text(wrapper.value)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button {
                            UIPasteboard.general.string = wrapper.value
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    .padding()
                    .background(AppColors.surfaceBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.border, lineWidth: 1)
                        )
                    
                    Button("Done") {
                        viewModel.showAPIKeySecret = nil
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(32)
                .presentationDetents([.height(350)])
            }
        }
    }
    
    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal API Keys")
                        .font(AppTypography.h3)
                    Text("Generate keys for scripted access to your workspace.")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Button("Generate Key") {
                    showingCreateKeyPopover = true
                }
                .buttonStyle(SecondaryButtonStyle())
                .popover(isPresented: $showingCreateKeyPopover) {
                    VStack(spacing: 16) {
                        Text("New API Key")
                            .font(AppTypography.h4)
                        TextField("e.g. Zapier Integration", text: $newKeyName)
                            .textFieldStyle(.roundedBorder)
                        Button("Create") {
                            Task {
                                await viewModel.createAPIKey(name: newKeyName)
                                newKeyName = ""
                                showingCreateKeyPopover = false
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(newKeyName.isEmpty)
                    }
                    .padding()
                    .frame(width: 300)
                    .presentationCompactAdaptation(.popover)
                }
            }
            
            if viewModel.apiKeys.isEmpty && !viewModel.isLoading {
                Text("No active API keys.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.apiKeys) { key in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key.name)
                                .font(AppTypography.body.weight(.semibold))
                            Text("\(key.keyPrefix)••••••••")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Button("Revoke", role: .destructive) {
                            Task { await viewModel.revokeAPIKey(id: key.id) }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding()
                    .background(AppColors.surfaceBackground)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))
                }
            }
        }
    }
    
    private var webhooksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Outbound Webhooks")
                        .font(AppTypography.h3)
                    Text("Push events to your servers in real-time.")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Button("Add Endpoint") {
                    showingCreateWebhook = true
                }
                .buttonStyle(SecondaryButtonStyle())
                .popover(isPresented: $showingCreateWebhook) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("New Webhook")
                            .font(AppTypography.h4)
                        
                        TextField("https://your-server.com/webhook", text: $newWebhookUrl)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                        
                        Text("Events")
                            .font(AppTypography.caption1.weight(.semibold))
                        
                        ForEach(availableEvents, id: \.self) { event in
                            Toggle(event, isOn: Binding(
                                get: { newWebhookEvents.contains(event) },
                                set: { isOn in
                                    if isOn { newWebhookEvents.insert(event) }
                                    else { newWebhookEvents.remove(event) }
                                }
                            ))
                        }
                        
                        Button("Create Endpoint") {
                            Task {
                                await viewModel.createWebhook(targetUrl: newWebhookUrl, events: Array(newWebhookEvents))
                                newWebhookUrl = ""
                                showingCreateWebhook = false
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(newWebhookUrl.isEmpty || newWebhookEvents.isEmpty)
                    }
                    .padding()
                    .frame(width: 320)
                    .presentationCompactAdaptation(.popover)
                }
            }
            
            if viewModel.webhooks.isEmpty && !viewModel.isLoading {
                Text("No webhooks configured.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.webhooks) { hook in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Circle()
                                .fill(hook.isActive ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(hook.targetUrl)
                                .font(AppTypography.body.weight(.semibold))
                            
                            Spacer()
                            
                            Menu {
                                Button("Test Ping") {
                                    Task { await viewModel.testWebhook(id: hook.id) }
                                }
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.deleteWebhook(id: hook.id) }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .padding(8)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        
                        if hook.failureCount > 0 {
                            Text("\(hook.failureCount) recent delivery failures")
                                .font(AppTypography.caption1)
                                .foregroundColor(.red)
                        }
                        
                        HStack {
                            ForEach(hook.events, id: \.self) { event in
                                Text(event)
                                    .font(AppTypography.caption1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.brandSecondary)
                                    .foregroundColor(AppColors.brandPrimary)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.surfaceBackground)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))
                }
            }
        }
    }
}

private struct IdentifiableString: Identifiable {
    var id: String { value }
    let value: String
}
