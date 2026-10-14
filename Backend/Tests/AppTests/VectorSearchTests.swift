import XCTest
import SharedModels
@testable import App

final class VectorSearchTests: XCTestCase {
    func testVectorDimensionsAndNormalization() {
        let service = EmbeddingService.shared
        let query = "that bug with the login screen"
        let vector = service.embed(query)
        
        XCTAssertEqual(vector.count, EmbeddingService.vectorDimension)
        
        // Magnitude should be approximately 1.0 (L2 unit normalized)
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        XCTAssertEqual(magnitude, 1.0, accuracy: 0.001)
    }

    func testIdenticalTextCosineSimilarity() {
        let service = EmbeddingService.shared
        let text = "Fix OAuth authentication crash on sign in"
        let v1 = service.embed(text)
        let v2 = service.embed(text)
        
        let similarity = service.cosineSimilarity(v1, v2)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.0001)
    }

    func testSemanticMatchingWithoutKeywordOverlap() {
        let service = EmbeddingService.shared
        
        // Query has no exact keywords in common with target task:
        // "that bug with the login screen" vs "Fix OAuth authentication crash on sign in"
        let query = "that bug with the login screen"
        let authCrashTask = "Fix OAuth authentication crash on sign in"
        let billingTask = "Upgrade Stripe billing subscription plan"
        let meetingTask = "Weekly team sync video call agenda"
        
        let qVec = service.embed(query)
        let authVec = service.embed(authCrashTask)
        let billingVec = service.embed(billingTask)
        let meetingVec = service.embed(meetingTask)
        
        let authSim = service.cosineSimilarity(qVec, authVec)
        let billingSim = service.cosineSimilarity(qVec, billingVec)
        let meetingSim = service.cosineSimilarity(qVec, meetingVec)
        
        // Auth crash should match strongly because "bug" clusters with "crash" and "login" with "authentication" / "oauth"
        XCTAssertGreaterThan(authSim, 0.65, "Auth crash task similarity should exceed 0.65")
        
        // Billing & Meeting tasks should have significantly lower similarity
        XCTAssertLessThan(billingSim, 0.35, "Billing task similarity should be low")
        XCTAssertLessThan(meetingSim, 0.35, "Meeting task similarity should be low")
        XCTAssertGreaterThan(authSim - billingSim, 0.40, "Auth should clearly outrank billing")
    }

    func testTokenizationAndStopWords() {
        let service = EmbeddingService.shared
        let text = "The bug in that login screen is very broken!"
        let tokens = service.tokenize(text)
        
        // "the", "in", "that", "is", "very" are stop words
        XCTAssertTrue(tokens.contains("bug"))
        XCTAssertTrue(tokens.contains("login"))
        XCTAssertTrue(tokens.contains("screen"))
        XCTAssertTrue(tokens.contains("broken"))
        XCTAssertFalse(tokens.contains("the"))
        XCTAssertFalse(tokens.contains("that"))
    }

    func testRAGCitationDTOModelAndSerialization() throws {
        let citation = RAGCitationDTO(
            id: UUID().uuidString,
            entityType: .task,
            title: "Fix OAuth 2.0 PKCE login crash",
            snippet: "Users on iOS 18 encounter unhandled token refresh failure.",
            deepLink: "taskflow://tasks/123e4567-e89b-12d3-a456-426614174000",
            similarityScore: 0.88,
            citationNumber: 1
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(citation)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(RAGCitationDTO.self, from: data)

        XCTAssertEqual(decoded.title, citation.title)
        XCTAssertEqual(decoded.entityType, SearchEntityType.task)
        XCTAssertEqual(decoded.citationNumber, 1)
        XCTAssertEqual(decoded.similarityScore, 0.88)
        XCTAssertEqual(decoded.deepLink, citation.deepLink)
    }

    func testRAGKnowledgeBaseRequestAndResponse() throws {
        let request = AIAssistantRequest(
            action: .askKnowledgeBase,
            prompt: "What is that bug with the login screen?",
            entityTypes: [.task, .message],
            maxSources: 3
        )

        XCTAssertEqual(request.action, AIAssistantAction.askKnowledgeBase)
        XCTAssertEqual(request.prompt, "What is that bug with the login screen?")
        XCTAssertEqual(request.entityTypes?.count, 2)
        XCTAssertEqual(request.maxSources, 3)

        let citation = RAGCitationDTO(
            id: "task-001",
            entityType: .task,
            title: "Fix OAuth sign in crash",
            snippet: "Resolves crash when exchanging authorization code.",
            deepLink: "taskflow://tasks/task-001",
            similarityScore: 0.91,
            citationNumber: 1
        )

        let response = AIAssistantResponse(
            action: .askKnowledgeBase,
            summary: "Based on task [1], the login screen issue is caused by an unhandled OAuth exchange error.",
            actionItems: ["Review [1] Fix OAuth sign in crash"],
            citations: [citation],
            suggestedFollowUps: ["Open Fix OAuth sign in crash in detail", "Check sprint blockers"]
        )

        XCTAssertEqual(response.action, AIAssistantAction.askKnowledgeBase)
        XCTAssertEqual(response.citations?.count, 1)
        XCTAssertEqual(response.citations?.first?.citationNumber, 1)
        XCTAssertEqual(response.suggestedFollowUps?.count, 2)
        XCTAssertTrue(response.summary.contains("[1]"))
    }

    func testAIAssistantStreamEventSerialization() throws {
        let citation = RAGCitationDTO(
            id: "task-002",
            entityType: .task,
            title: "Optimize Search indexing",
            snippet: "Adds background vector indexing",
            deepLink: "taskflow://tasks/task-002",
            similarityScore: 0.95,
            citationNumber: 1
        )

        let tokenEvent = AIAssistantStreamEvent(
            event: .token,
            token: "Hello "
        )

        let citationsEvent = AIAssistantStreamEvent(
            event: .citations,
            citations: [citation]
        )

        let doneEvent = AIAssistantStreamEvent(
            event: .done,
            response: AIAssistantResponse(
                action: .askKnowledgeBase,
                summary: "Hello world",
                citations: [citation]
            )
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let tokenData = try encoder.encode(tokenEvent)
        let citationsData = try encoder.encode(citationsEvent)
        let doneData = try encoder.encode(doneEvent)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let decodedToken = try decoder.decode(AIAssistantStreamEvent.self, from: tokenData)
        let decodedCitations = try decoder.decode(AIAssistantStreamEvent.self, from: citationsData)
        let decodedDone = try decoder.decode(AIAssistantStreamEvent.self, from: doneData)

        XCTAssertEqual(decodedToken.event, .token)
        XCTAssertEqual(decodedToken.token, "Hello ")

        XCTAssertEqual(decodedCitations.event, .citations)
        XCTAssertEqual(decodedCitations.citations?.count, 1)
        XCTAssertEqual(decodedCitations.citations?.first?.title, "Optimize Search indexing")

        XCTAssertEqual(decodedDone.event, .done)
        XCTAssertEqual(decodedDone.response?.action, .askKnowledgeBase)
        XCTAssertEqual(decodedDone.response?.summary, "Hello world")
    }

    func testTokenizeIntoChunksPreservesText() {
        let original = """
        Based on your workspace knowledge base:

        [1] **Task Item**: Critical bug details.

        Next steps:
        - Check tests
        - Review release notes
        """

        let chunks = AIAssistantController.tokenizeIntoChunks(original)
        let reconstructed = chunks.joined()

        XCTAssertEqual(reconstructed, original)
        XCTAssertGreaterThan(chunks.count, 10)
    }
}

