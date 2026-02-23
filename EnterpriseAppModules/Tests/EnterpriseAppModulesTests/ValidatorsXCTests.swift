import Domain
import XCTest

final class ValidatorsXCTests: XCTestCase {
    func testEmailValidation() {
        XCTAssertTrue(Validators.isValidEmail("name@company.com"))
        XCTAssertFalse(Validators.isValidEmail("not-an-email"))
    }

    func testPasswordValidation() {
        XCTAssertTrue(Validators.isValidPassword("12345678"))
        XCTAssertFalse(Validators.isValidPassword("1234567"))
    }
}

