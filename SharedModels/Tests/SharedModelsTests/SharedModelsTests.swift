import XCTest
@testable import SharedModels

final class SharedModelsTests: XCTestCase {
    func testTaskStatusRawValues() {
        XCTAssertEqual(TaskStatus.inProgress.rawValue, "in_progress")
        XCTAssertEqual(TaskStatus.inReview.rawValue, "in_review")
    }

    func testPaginationMeta() {
        let meta = PaginationMeta(page: 1, perPage: 20, total: 55)
        XCTAssertEqual(meta.totalPages, 3)
    }
}
