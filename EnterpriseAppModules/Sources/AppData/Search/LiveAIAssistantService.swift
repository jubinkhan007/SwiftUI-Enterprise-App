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

    public func askKnowledgeBase(prompt: String, entityTypes: [SearchEntityType]?, maxSources: Int?) async throws -> AIAssistantResponse {
        let request = AIAssistantRequest(
            action: .askKnowledgeBase,
            prompt: prompt,
            entityTypes: entityTypes,
            maxSources: maxSources
        )
        let ep = AIAssistantEndpoint.ask(payload: request, configuration: apiConfiguration)
        let response = try await apiClient.request(ep, responseType: APIResponse<AIAssistantResponse>.self)
        guard let data = response.data else {
            throw NetworkError.decodingFailed("Missing response data for knowledge base Q&A.")
        }
        return data
    }

    public func streamAction(_ request: AIAssistantRequest) -> AsyncThrowingStream<AIAssistantStreamEvent, Error> {
        let ep = AIAssistantEndpoint.stream(payload: request, configuration: apiConfiguration)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let urlRequest = ep.makeURLRequest() else {
                        continuation.finish(throwing: NetworkError.invalidURL)
                        return
                    }

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        continuation.finish(throwing: NetworkError.serverError(statusCode: http.statusCode, message: "Stream failed with status \(http.statusCode)"))
                        return
                    }

                    let decoder = JSONCoding.decoder
                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data:") else { continue }
                        let jsonStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !jsonStr.isEmpty, let data = jsonStr.data(using: .utf8) else { continue }
                        do {
                            let event = try decoder.decode(AIAssistantStreamEvent.self, from: data)
                            continuation.yield(event)
                            if event.event == .done {
                                continuation.finish()
                                return
                            }
                        } catch {
                            // ignore partial chunk decode error
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

