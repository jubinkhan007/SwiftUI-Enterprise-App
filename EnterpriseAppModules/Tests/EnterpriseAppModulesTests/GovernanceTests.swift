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
        XCTAssertTrue(viewer.isStrictSubset(of: member))
        XCTAssertTrue(member.isStrictSubset(of: manager))
        XCTAssertTrue(manager.isStrictSubset(of: admin))
        XCTAssertTrue(admin.isStrictSubset(of: owner))
        XCTAssertEqual(owner.count, Permission.allCases.count)
    }

    @MainActor
    func testAuditLogCategoryAndLiveEventIngestion() {
        let orgId = UUID()
        let vm = AuditLogViewModel(orgId: orgId)
        let eventId = UUID()
        let event = RealTimeProvider.ServerEvent(
            eventId: UUID().uuidString,
            orgId: orgId,
            type: "audit.created",
            entityId: eventId,
            updatedAt: Date(),
            payload: [
                "id": eventId.uuidString,
                "orgId": orgId.uuidString,
                "userEmail": "alice@acme.com",
                "action": "session.revoked",
                "resourceType": "session",
                "details": "Revoked session (mobile, 10.0.0.1)"
            ]
        )

        vm.ingestLiveEvent(event)
        XCTAssertEqual(vm.logs.count, 1)
        XCTAssertTrue(vm.liveEventIds.contains(eventId))
        XCTAssertEqual(vm.logs.first?.auditCategory, .security)

        vm.selectedCategory = .members
        XCTAssertTrue(vm.filteredLogs.isEmpty)

        vm.selectedCategory = .security
        vm.searchText = "10.0.0.1"
        XCTAssertEqual(vm.filteredLogs.count, 1)
    }

    func testWorkspaceGovernanceEndpointProperties() {
        let orgId = UUID()

        let brandingEndpoint = OrganizationEndpoint.updateBranding(
            orgId: orgId,
            payload: UpdateBrandingRequest(
                logoUrl: "https://cdn.acme.com/logo.png",
                brandColorHex: "#2563EB"
            ),
            configuration: .current
        )
        XCTAssertEqual(brandingEndpoint.path, "/api/organizations/\(orgId.uuidString)/branding")
        XCTAssertEqual(brandingEndpoint.method, HTTPMethod.put)
        XCTAssertNotNil(brandingEndpoint.body)

        let domainEndpoint = OrganizationEndpoint.updateDomainSettings(
            orgId: orgId,
            payload: UpdateDomainSettingsRequest(customDomain: "tasks.acme.com", allowedEmailDomains: "acme.com, eng.acme.com"),
            configuration: .current
        )
        XCTAssertEqual(domainEndpoint.path, "/api/organizations/\(orgId.uuidString)/domain-settings")
        XCTAssertEqual(domainEndpoint.method, HTTPMethod.put)
        XCTAssertNotNil(domainEndpoint.body)

        let ssoEndpoint = OrganizationEndpoint.updateSSOSettings(
            orgId: orgId,
            payload: UpdateSSOSettingsRequest(
                ssoEnabled: true,
                ssoIdpUrl: "https://acme.okta.com/sso/saml",
                ssoEntityId: "http://www.okta.com/exk123",
                ssoCertificate: "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
            ),
            configuration: .current
        )
        XCTAssertEqual(ssoEndpoint.path, "/api/organizations/\(orgId.uuidString)/sso-settings")
        XCTAssertEqual(ssoEndpoint.method, HTTPMethod.put)
        XCTAssertNotNil(ssoEndpoint.body)

        let getRetention = OrganizationEndpoint.getRetentionPolicy(orgId: orgId, configuration: .current)
        XCTAssertEqual(getRetention.path, "/api/admin/org/retention")
        XCTAssertEqual(getRetention.method, HTTPMethod.get)
        XCTAssertEqual(getRetention.headers?["X-Org-Id"], orgId.uuidString)

        let putRetention = OrganizationEndpoint.updateRetentionPolicy(
            orgId: orgId,
            payload: RetentionPolicyPayloadDTO(retentionDays: 90),
            configuration: .current
        )
        XCTAssertEqual(putRetention.path, "/api/admin/org/retention")
        XCTAssertEqual(putRetention.method, HTTPMethod.put)
        XCTAssertNotNil(putRetention.body)

        let purgeNow = OrganizationEndpoint.purgeExpiredMessages(orgId: orgId, configuration: .current)
        XCTAssertEqual(purgeNow.path, "/api/admin/org/retention/purge-now")
        XCTAssertEqual(purgeNow.method, HTTPMethod.post)

        let exportCsv = OrganizationEndpoint.createComplianceExport(orgId: orgId, format: "csv", configuration: .current)
        XCTAssertEqual(exportCsv.path, "/api/admin/org/export?format=csv")
        XCTAssertEqual(exportCsv.method, HTTPMethod.post)
    }
}

