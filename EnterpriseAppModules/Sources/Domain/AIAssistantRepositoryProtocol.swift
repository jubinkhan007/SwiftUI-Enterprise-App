import Foundation
import SharedModels

public protocol AIAssistantRepositoryProtocol: Sendable {
    func executeAction(_ request: AIAssistantRequest) async throws -> AIAssistantResponse
    func breakdownTask(title: String, description: String?, contextId: String?) async throws -> AIAssistantResponse
    func generateStandup() async throws -> AIAssistantResponse
    func askKnowledgeBase(prompt: String, entityTypes: [SearchEntityType]?, maxSources: Int?) async throws -> AIAssistantResponse
    func streamAction(_ request: AIAssistantRequest) -> AsyncThrowingStream<AIAssistantStreamEvent, Error>
}

