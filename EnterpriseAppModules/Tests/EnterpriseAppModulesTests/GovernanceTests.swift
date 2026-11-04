import Foundation
import XCTest
import AppNetwork
import FeatureOrganization
import SharedModels

final class GovernanceTests: XCTestCase {
    func testSessionEndpointListMineProperties() {
        let endpoint = SessionEndpoint.listMine(configuration: .current)
        XCTAssertEqual(endpoint.path, "/api/me/sessions")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertNil(endpoint.body)
    }

    func testSessionEndpointRevokeMineProperties() {
        let sessionId = UUID()
        let endpoint = SessionEndpoint.revokeMine(sessionId: sessionId, configuration: .current)
        XCTAssertEqual(endpoint.path, "/api/me/sessions/\(sessionId.uuidString)")
        XCTAssertEqual(endpoint.method, .delete)
        XCTAssertNil(endpoint.body)
    }

    func testUserSessionDTOClientLabelAndSymbol() {
        let iosSession = UserSessionDTO(
            id: UUID(),
            userId: UUID(),
            deviceType: "mobile",
            ipAddress: "192.168.1.10",
            userAgent: "EnterpriseApp/1.0 CFNetwork/1494.0.7 Darwin/23.4.0",
            isRevoked: false,
            expiresAt: Date().addingTimeInterval(3600),
            createdAt: Date()
        )
        XCTAssertEqual(iosSession.clientLabel, "iOS App")
        XCTAssertEqual(iosSession.deviceSymbol, "iphone")

        let androidSession = UserSessionDTO(
            id: UUID(),
            userId: UUID(),
            deviceType: "mobile",
            ipAddress: "10.0.2.2",
            userAgent: "okhttp/4.12.0",
            isRevoked: false,
            expiresAt: Date().addingTimeInterval(3600),
            createdAt: Date()
        )
        XCTAssertEqual(androidSession.clientLabel, "Android App")
        XCTAssertEqual(androidSession.deviceSymbol, "iphone")

        let webSession = UserSessionDTO(
            id: UUID(),
            userId: UUID(),
            deviceType: "web",
            ipAddress: "127.0.0.1",
            userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X) Chrome/124.0.0.0 Safari/537.36",
            isRevoked: false,
            expiresAt: Date().addingTimeInterval(3600),
            createdAt: Date()
        )
        XCTAssertEqual(webSession.clientLabel, "Chrome")
        XCTAssertEqual(webSession.deviceSymbol, "laptopcomputer")
    }

    func testDefaultRolePermissionsMonotonicity() {
        let guest = PermissionSet.defaultPermissions(for: .guest).permissions
        let viewer = PermissionSet.defaultPermissions(for: .viewer).permissions
        let member = PermissionSet.defaultPermissions(for: .member).permissions
        let manager = PermissionSet.defaultPermissions(for: .manager).permissions
        let admin = PermissionSet.defaultPermissions(for: .admin).permissions
        let owner = PermissionSet.defaultPermissions(for: .owner).permissions

        XCTAssertTrue(guest.isStrictSubset(of: viewer))
        XCTAssertTrue(member.isStrictSubset(of: manager))
        XCTAssertTrue(manager.isStrictSubset(of: admin))
        XCTAssertTrue(admin.isStrictSubset(of: owner))
        XCTAssertEqual(owner.count, Permission.allCases.count)
    }
}

