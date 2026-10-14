import Foundation
import XCTest
import Domain
import AppNetwork
import SharedModels

final class SearchAndAITests: XCTestCase {
    func testSearchEndpointGet() {
        let config = APIConfiguration(baseURL: URL(string: "http://localhost:8080")!)
        let ep = SearchEndpoint.search(query: "release", types: [.task, .message], limit: 15, configuration: config)

        XCTAssertEqual(ep.path, "/api/search")
        XCTAssertEqual(ep.method, .get)
        XCTAssertEqual(ep.queryParameters?["q"], "release")
        XCTAssertEqual(ep.queryParameters?["types"], "task,message")
        XCTAssertEqual(ep.queryParameters?["limit"], "15")
    }

    func testAIAssistantEndpointPost() throws {
        let config = APIConfiguration(baseURL: URL(string: "http://localhost:8080")!)
        let req = AIAssistantRequest(action: .breakdownTask, prompt: "Build onboarding")
        let ep = AIAssistantEndpoint.breakdown(payload: req, configuration: config)

        XCTAssertEqual(ep.path, "/api/ai/breakdown")
        XCTAssertEqual(ep.method, .post)
        XCTAssertNotNil(ep.body)

        let decoded = try JSONCoding.decoder.decode(AIAssistantRequest.self, from: ep.body!)
        XCTAssertEqual(decoded.action, .breakdownTask)
        XCTAssertEqual(decoded.prompt, "Build onboarding")
    }

    func testAIAssistantEndpointStandup() {
        let config = APIConfiguration(baseURL: URL(string: "http://localhost:8080")!)
        let ep = AIAssistantEndpoint.standup(configuration: config)

        XCTAssertEqual(ep.path, "/api/ai/standup")
        XCTAssertEqual(ep.method, .get)
        XCTAssertNil(ep.body)
    }

    func testSearchResponseSerialization() throws {
        let item = SearchResultItemDTO(
            id: UUID().uuidString,
            entityType: .task,
            title: "Setup CI/CD pipeline",
            subtitle: "DevOps",
            deepLink: "taskflow://tasks/123",
            icon: "checkmark.square.fill",
            badge: "Critical",
            metadata: ["key": "TASK-1"],
            updatedAt: Date()
        )
        let response = OmnibarSearchResponse(results: [item], totalCount: 1, query: "pipeline")

        let data = try JSONCoding.encoder.encode(response)
        let decoded = try JSONCoding.decoder.decode(OmnibarSearchResponse.self, from: data)

        XCTAssertEqual(decoded.totalCount, 1)
        XCTAssertEqual(decoded.results.first?.title, "Setup CI/CD pipeline")
        XCTAssertEqual(decoded.results.first?.deepLink, "taskflow://tasks/123")
    }

    func testSearchEndpointHybridAndSemantic() {
        let config = APIConfiguration(baseURL: URL(string: "http://localhost:8080")!)
        let ep = SearchEndpoint.search(
            query: "that bug with login",
            types: [.task],
            limit: 20,
            mode: .semantic,
            threshold: 0.35,
            configuration: config
        )

        XCTAssertEqual(ep.path, "/api/search")
        XCTAssertEqual(ep.method, .get)
        XCTAssertEqual(ep.queryParameters?["q"], "that bug with login")
        XCTAssertEqual(ep.queryParameters?["mode"], "semantic")
        XCTAssertEqual(ep.queryParameters?["threshold"], "0.35")
    }

    func testSearchResultSemanticFieldsSerialization() throws {
        let item = SearchResultItemDTO(
            id: UUID().uuidString,
            entityType: .task,
            title: "Fix OAuth authentication crash on sign in",
            subtitle: "Critical bug",
            deepLink: "taskflow://tasks/456",
            icon: "checkmark.square.fill",
            badge: "✨ 85% Match",
            metadata: ["taskKey": "PROJ-102"],
            similarityScore: 0.854,
            matchType: "semantic",
            highlightSnippet: "Users encounter freeze on auth modal",
            updatedAt: Date()
        )
        let response = OmnibarSearchResponse(
            results: [item],
            totalCount: 1,
            query: "that bug with login",
            mode: .hybrid
        )

        let data = try JSONCoding.encoder.encode(response)
        let decoded = try JSONCoding.decoder.decode(OmnibarSearchResponse.self, from: data)

        XCTAssertEqual(decoded.mode, .hybrid)
        XCTAssertEqual(decoded.results.first?.similarityScore, 0.854)
        XCTAssertEqual(decoded.results.first?.matchType, "semantic")
        XCTAssertEqual(decoded.results.first?.highlightSnippet, "Users encounter freeze on auth modal")
        XCTAssertEqual(decoded.results.first?.badge, "✨ 85% Match")
    }

    func testAIAssistantEndpointAskKnowledgeBase() throws {
        let config = APIConfiguration(baseURL: URL(string: "http://localhost:8080")!)
        let req = AIAssistantRequest(
            action: .askKnowledgeBase,
            prompt: "What was decided about SAML SSO?",
            entityTypes: [.task, .message],
            maxSources: 4
        )
        let ep = AIAssistantEndpoint.ask(payload: req, configuration: config)

        XCTAssertEqual(ep.path, "/api/ai/ask")
        XCTAssertEqual(ep.method, .post)
        XCTAssertNotNil(ep.body)

        let decoded = try JSONCoding.decoder.decode(AIAssistantRequest.self, from: ep.body!)
        XCTAssertEqual(decoded.action, .askKnowledgeBase)
        XCTAssertEqual(decoded.prompt, "What was decided about SAML SSO?")
        XCTAssertEqual(decoded.maxSources, 4)
    }

    func testRAGResponseAndCitationsSerialization() throws {
        let citation = RAGCitationDTO(
            id: UUID().uuidString,
            entityType: .message,
            title: "Architecture Discussion",
            snippet: "Agreed to adopt SAML 2.0 with Okta and Azure AD.",
            deepLink: "taskflow://channels/thread-10",
            similarityScore: 0.92,
            citationNumber: 1
        )
        let response = AIAssistantResponse(
            action: .askKnowledgeBase,
            summary: "Based on discussion [1], SAML 2.0 was approved for Okta and Azure AD.",
            actionItems: ["Review [1] Architecture Discussion"],
            citations: [citation],
            suggestedFollowUps: ["Show Azure AD setup tasks", "Who participated in the discussion?"]
        )

        let data = try JSONCoding.encoder.encode(response)
        let decoded = try JSONCoding.decoder.decode(AIAssistantResponse.self, from: data)

        XCTAssertEqual(decoded.action, .askKnowledgeBase)
        XCTAssertEqual(decoded.citations?.count, 1)
        XCTAssertEqual(decoded.citations?.first?.citationNumber, 1)
        XCTAssertEqual(decoded.citations?.first?.title, "Architecture Discussion")
        XCTAssertEqual(decoded.citations?.first?.similarityScore, 0.92)
        XCTAssertEqual(decoded.suggestedFollowUps?.count, 2)
    }

    func testAIAssistantEndpointStream() throws {
        let config = APIConfiguration(baseURL: URL(string: "http://localhost:8080")!)
        let req = AIAssistantRequest(
            action: .askKnowledgeBase,
            prompt: "Explain stream feature",
            entityTypes: [.task]
        )
        let ep = AIAssistantEndpoint.stream(payload: req, configuration: config)

        XCTAssertEqual(ep.path, "/api/ai/stream")
        XCTAssertEqual(ep.method, .post)
        XCTAssertEqual(ep.headers?["Accept"], "text/event-stream")
        XCTAssertNotNil(ep.body)

        let decoded = try JSONCoding.decoder.decode(AIAssistantRequest.self, from: ep.body!)
        XCTAssertEqual(decoded.action, .askKnowledgeBase)
        XCTAssertEqual(decoded.prompt, "Explain stream feature")

        let urlReq = ep.makeURLRequest()
        XCTAssertNotNil(urlReq)
        XCTAssertEqual(urlReq?.url?.absoluteString, "http://localhost:8080/api/ai/stream")
        XCTAssertEqual(urlReq?.httpMethod, "POST")
        XCTAssertEqual(urlReq?.value(forHTTPHeaderField: "Accept"), "text/event-stream")
    }

    func testAIAssistantStreamEventSerialization() throws {
        let citation = RAGCitationDTO(
            id: "cit-1",
            entityType: .task,
            title: "Task Streaming",
            snippet: "Streaming token chunks via SSE",
            deepLink: "taskflow://tasks/stream",
            similarityScore: 0.95,
            citationNumber: 1
        )
        let tokenEvent = AIAssistantStreamEvent(
            event: .token,
            token: "Hello world"
        )
        let citationsEvent = AIAssistantStreamEvent(
            event: .citations,
            citations: [citation]
        )
        let followUpsEvent = AIAssistantStreamEvent(
            event: .followUps,
            suggestedFollowUps: ["What about error handling?", "Show code example"]
        )

        let tokenData = try JSONCoding.encoder.encode(tokenEvent)
        let decodedToken = try JSONCoding.decoder.decode(AIAssistantStreamEvent.self, from: tokenData)
        XCTAssertEqual(decodedToken.event, .token)
        XCTAssertEqual(decodedToken.token, "Hello world")

        let citData = try JSONCoding.encoder.encode(citationsEvent)
        let decodedCit = try JSONCoding.decoder.decode(AIAssistantStreamEvent.self, from: citData)
        XCTAssertEqual(decodedCit.event, .citations)
        XCTAssertEqual(decodedCit.citations?.first?.title, "Task Streaming")

        let followUpsData = try JSONCoding.encoder.encode(followUpsEvent)
        let decodedFollowUps = try JSONCoding.decoder.decode(AIAssistantStreamEvent.self, from: followUpsData)
        XCTAssertEqual(decodedFollowUps.event, .followUps)
        XCTAssertEqual(decodedFollowUps.suggestedFollowUps?.count, 2)
    }
}

