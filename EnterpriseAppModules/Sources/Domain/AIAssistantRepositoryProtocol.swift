import Foundation
import SharedModels

public protocol AIAssistantRepositoryProtocol: Sendable {
    func executeAction(_ request: AIAssistantRequest) async throws -> AIAssistantResponse
    func breakdownTask(title: String, description: String?, contextId: String?) async throws -> AIAssistantResponse
    func generateStandup() async throws -> AIAssistantResponse
}
