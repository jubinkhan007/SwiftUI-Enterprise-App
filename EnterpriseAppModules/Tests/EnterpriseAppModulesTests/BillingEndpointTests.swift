import Foundation
import XCTest
import AppNetwork
import SharedModels

final class BillingEndpointTests: XCTestCase {
    func testBillingCheckoutEndpointProperties() {
        let orgId = UUID()
        let endpoint = OrganizationEndpoint.billingCheckout(orgId: orgId, configuration: .current)

        XCTAssertEqual(endpoint.path, "/api/org/billing/checkout")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(endpoint.headers?["X-Org-Id"], orgId.uuidString)
    }

    func testBillingPortalEndpointProperties() {
        let orgId = UUID()
        let endpoint = OrganizationEndpoint.billingPortal(orgId: orgId, configuration: .current)

        XCTAssertEqual(endpoint.path, "/api/org/billing/portal")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(endpoint.headers?["X-Org-Id"], orgId.uuidString)
    }

    func testBillingRedirectDTODecoding() throws {
        let json = """
        {
            "url": "https://checkout.stripe.com/c/pay/cs_test_mock_123"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(BillingRedirectDTO.self, from: json)
        XCTAssertEqual(dto.url, "https://checkout.stripe.com/c/pay/cs_test_mock_123")
    }

    func testAPIResponseWithBillingRedirectDTO() throws {
        let json = """
        {
            "success": true,
            "data": {
                "url": "https://billing.stripe.com/p/session/test_portal"
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(APIResponse<BillingRedirectDTO>.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.data?.url, "https://billing.stripe.com/p/session/test_portal")
    }
}
