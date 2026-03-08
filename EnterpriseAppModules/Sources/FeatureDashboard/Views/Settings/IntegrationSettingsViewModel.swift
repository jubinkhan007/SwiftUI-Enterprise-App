import SwiftUI
import SharedModels
import AppData
import DesignSystem
import Domain

@MainActor
public final class IntegrationSettingsViewModel: ObservableObject {
    private let repository: IntegrationRepositoryProtocol
    
    @Published public var apiKeys: [APIKeyDTO] = []
    @Published public var webhooks: [WebhookSubscriptionDTO] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    // API Key Creation state
    @Published public var showAPIKeySecret: String?
    
    public init(repository: IntegrationRepositoryProtocol) {
        self.repository = repository
    }
    
    public func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let fetchedKeys = repository.getAPIKeys()
            async let fetchedWebhooks = repository.getWebhooks()
            
            let (keys, hooks) = try await (fetchedKeys, fetchedWebhooks)
            self.apiKeys = keys
            self.webhooks = hooks
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    public func createAPIKey(name: String) async {
        guard !name.isEmpty else { return }
        do {
            let request = CreateAPIKeyRequest(name: name, scopes: ["all"], expiresAt: nil)
            let response = try await repository.createAPIKey(request)
            apiKeys.insert(response.apiKey, at: 0)
            showAPIKeySecret = response.rawKey
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func revokeAPIKey(id: UUID) async {
        do {
            try await repository.revokeAPIKey(id: id)
            apiKeys.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func createWebhook(targetUrl: String, events: [String]) async {
        guard let _ = URL(string: targetUrl) else {
            errorMessage = "Invalid URL"
            return
        }
        do {
            let secret = String([UInt8].random(count: 32).hex.prefix(32))
            let request = CreateWebhookRequest(targetUrl: targetUrl, secret: secret, events: events)
            let subscription = try await repository.createWebhook(request)
            webhooks.insert(subscription, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func testWebhook(id: UUID) async {
        do {
            try await repository.testWebhook(id: id)
            // Show a temporary success toast ideally, but print for now
            print("Webhook test ping sent.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func deleteWebhook(id: UUID) async {
        do {
            try await repository.deleteWebhook(id: id)
            webhooks.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
