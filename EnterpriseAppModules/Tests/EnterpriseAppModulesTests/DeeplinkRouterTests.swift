import Foundation
import XCTest
import Domain
import AppNetwork
import SharedModels

@MainActor
final class DeeplinkRouterTests: XCTestCase {
    func testTaskDeeplinkParsing() {
        let taskId = UUID()
        let url = URL(string: "taskflow://tasks/\(taskId.uuidString)")!
        let dest = DeeplinkParser.parse(url: url)
        XCTAssertEqual(dest, .task(id: taskId))
    }

    func testChannelDeeplinkParsing() {
        let channelId = UUID()
        let url = URL(string: "taskflow://channels/\(channelId.uuidString)")!
        let dest = DeeplinkParser.parse(url: url)
        XCTAssertEqual(dest, .channel(id: channelId))
    }

    func testMeetingDeeplinkParsing() {
        let meetingId = UUID()
        let url = URL(string: "taskflow://meetings/\(meetingId.uuidString)")!
        let dest = DeeplinkParser.parse(url: url)
        XCTAssertEqual(dest, .meeting(id: meetingId))
    }

    func testCallDeeplinkParsing() {
        let callId = UUID()
        let url = URL(string: "taskflow://calls/\(callId.uuidString)")!
        let dest = DeeplinkParser.parse(url: url)
        XCTAssertEqual(dest, .call(id: callId))
    }

    func testBillingDeeplinkParsing() {
        let url = URL(string: "taskflow://billing")!
        let dest = DeeplinkParser.parse(url: url)
        XCTAssertEqual(dest, .billing)
    }

    func testInboxDeeplinkParsing() {
        let url = URL(string: "taskflow://inbox")!
        let dest = DeeplinkParser.parse(url: url)
        XCTAssertEqual(dest, .inbox)
    }

    func testProductivityDeeplinkParsing() {
        let url = URL(string: "taskflow://productivity")!
        let dest = DeeplinkParser.parse(url: url)
        XCTAssertEqual(dest, .productivity)
    }

    func testHttpsUniversalLinkParsing() {
        let taskId = UUID()
        let url = URL(string: "https://taskflow.app/tasks/\(taskId.uuidString)")!
        let dest = DeeplinkParser.parse(url: url)
        XCTAssertEqual(dest, .task(id: taskId))
    }

    func testDeeplinkRouterHandling() {
        let taskId = UUID()
        let url = URL(string: "taskflow://tasks/\(taskId.uuidString)")!
        let handled = DeeplinkRouter.handle(url)
        XCTAssertTrue(handled)
        XCTAssertEqual(DeeplinkRouter.shared.currentDestination, .task(id: taskId))
        DeeplinkRouter.shared.clear()
        XCTAssertNil(DeeplinkRouter.shared.currentDestination)
    }

    func testDeviceTokenEndpointProperties() {
        let endpoint = DeviceTokenEndpoint.register(token: "apns_test_token_123", platform: "ios", environment: "development", configuration: .current)
        XCTAssertEqual(endpoint.path, "/api/me/device-tokens")
        XCTAssertEqual(endpoint.method, .post)

        let unregisterEndpoint = DeviceTokenEndpoint.unregister(token: "apns_test_token_123", configuration: .current)
        XCTAssertEqual(unregisterEndpoint.path, "/api/me/device-tokens/apns_test_token_123")
        XCTAssertEqual(unregisterEndpoint.method, .delete)
    }
}
