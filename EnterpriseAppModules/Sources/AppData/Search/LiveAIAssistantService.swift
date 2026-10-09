import Foundation
import Domain
import AppNetwork
import SharedModels

public final class LiveAIAssistantService: AIAssistantRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration

    public init(apiClient: APIClientProtocol, configuration: APIConfiguration = .current) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    public func executeAction(_ request: AIAssistantRequest) async throws -> AIAssistantResponse {
        let ep = AIAssistantEndpoint.copilot(payload: request, configuration: apiConfiguration)
        let response = try await apiClient.request(ep, responseType: APIResponse<AIAssistantResponse>.self)
        guard let data = response.data else {
            throw NetworkError.decodingFailed("Missing response data for AI copilot.")
        }
        return data
    }

    public func breakdownTask(title: String, description: String?, contextId: String?) async throws -> AIAssistantResponse {
        var payload = [String: String]()
        payload["title"] = title
        if let description { payload["description"] = description }
        let request = AIAssistantRequest(
            action: .breakdownTask,
            contextId: contextId,
            prompt: title,
            entityPayload: payload
        )
        let ep = AIAssistantEndpoint.breakdown(payload: request, configuration: apiConfiguration)
        let response = try await apiClient.request(ep, responseType: APIResponse<AIAssistantResponse>.self)
        guard let data = response.data else {
            throw NetworkError.decodingFailed("Missing response data for task breakdown.")
        }
        return data
    }

    public func generateStandup() async throws -> AIAssistantResponse {
        let ep = AIAssistantEndpoint.standup(configuration: apiConfiguration)
        let response = try await apiClient.request(ep, responseType: APIResponse<AIAssistantResponse>.self)
        guard let data = response.data else {
            throw NetworkError.decodingFailed("Missing response data for standup generator.")
        }
        return data
    }
}
