import Foundation
import SharedModels

public protocol AIAssistantRepositoryProtocol: Sendable {
    func executeAction(_ request: AIAssistantRequest) async throws -> AIAssistantResponse
    func breakdownTask(title: String, description: String?, contextId: String?) async throws -> AIAssistantResponse
    func generateStandup() async throws -> AIAssistantResponse
    func askKnowledgeBase(prompt: String, entityTypes: [SearchEntityType]?, maxSources: Int?) async throws -> AIAssistantResponse
    func streamAction(_ request: AIAssistantRequest) -> AsyncThrowingStream<AIAssistantStreamEvent, Error>
    func transcribeAudio(_ request: AudioTranscriptionRequest) async throws -> AudioTranscriptionResponse
}

public extension AIAssistantRepositoryProtocol {
    func transcribeAudio(_ request: AudioTranscriptionRequest) async throws -> AudioTranscriptionResponse {
        let text = request.simulatedText ?? "How do we configure SAML SSO and manage team roles?"
        return AudioTranscriptionResponse(text: text, confidence: 0.98)
    }
}

