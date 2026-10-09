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
}
