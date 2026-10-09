import XCTest
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
}
