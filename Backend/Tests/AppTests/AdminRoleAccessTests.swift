@testable import App
import Fluent
import XCTVapor
import SharedModels

final class AdminRoleAccessTests: XCTestCase {
    private func signCookieToken(app: Application, userId: UUID, role: UserRole) throws -> String {
        let payload = AdminTokenPayload(
            subject: .init(value: userId.uuidString),
            expiration: .init(value: Date().addingTimeInterval(3600)),
            role: role.rawValue,
            kind: "access",
            sessionId: nil
        )
        return try app.jwt.signers.sign(payload)
    }

    private struct OrgSeed {
        let orgId: UUID
        let ownerUser: UserModel
        let memberUser: UserModel
        let managerUser: UserModel
    }

    private func seedTestOrg(app: Application) async throws -> OrgSeed {
        let owner = UserModel(email: "owner+\(UUID().uuidString)@example.com", displayName: "Owner", passwordHash: "x", role: .member)
        try await owner.save(on: app.db)
        let ownerId = try owner.requireID()

        let manager = UserModel(email: "mgr+\(UUID().uuidString)@example.com", displayName: "Manager", passwordHash: "x", role: .member)
        try await manager.save(on: app.db)
        let managerId = try manager.requireID()

        let member = UserModel(email: "mbr+\(UUID().uuidString)@example.com", displayName: "Member", passwordHash: "x", role: .member)
        try await member.save(on: app.db)
        let memberId = try member.requireID()

        let org = OrganizationModel(name: "Test Org \(UUID().uuidString.prefix(6))", slug: "test-\(UUID().uuidString.prefix(6))", ownerId: ownerId)
        try await org.save(on: app.db)
        let orgId = try org.requireID()

        try await OrganizationMemberModel(orgId: orgId, userId: ownerId, role: .owner).save(on: app.db)
        try await OrganizationMemberModel(orgId: orgId, userId: managerId, role: .manager).save(on: app.db)
        try await OrganizationMemberModel(orgId: orgId, userId: memberId, role: .member).save(on: app.db)

        return OrgSeed(orgId: orgId, ownerUser: owner, memberUser: member, managerUser: manager)
    }

    func testAdminAuthMeReturnsMembershipsForAllRoles() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedTestOrg(app: app)
        let memberId = try seed.memberUser.requireID()
        let token = try signCookieToken(app: app, userId: memberId, role: .member)

        try await app.test(.GET, "api/admin/auth/me", beforeRequest: { req in
            req.headers.add(name: .cookie, value: "\(AdminSession.accessCookieName)=\(token)")
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try res.content.decode(APIResponse<AdminMeResponse>.self)
            let data = try XCTUnwrap(decoded.data)
            XCTAssertEqual(data.user.id, memberId)
            // Regular member has empty admin_orgs, but non-empty memberships!
            XCTAssertTrue(data.adminOrgs.isEmpty)
            XCTAssertEqual(data.memberships.count, 1)
            XCTAssertEqual(data.memberships.first?.role, .member)
            XCTAssertEqual(data.memberships.first?.id, seed.orgId)
        })
    }

    func testCookieAuthAllowsMembersToViewOrgMembersList() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedTestOrg(app: app)
        let memberId = try seed.memberUser.requireID()
        let token = try signCookieToken(app: app, userId: memberId, role: .member)

        // Standard member can view members list via cookie authentication
        try await app.test(.GET, "api/organizations/\(seed.orgId.uuidString)/members", beforeRequest: { req in
            req.headers.add(name: .cookie, value: "\(AdminSession.accessCookieName)=\(token)")
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try res.content.decode(APIResponse<[OrganizationMemberDTO]>.self)
            let list = try XCTUnwrap(decoded.data)
            XCTAssertEqual(list.count, 3)
        })
    }

    func testNonAdminBlockedFromAdminRestrictedRoutes() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try configure(app)

        let seed = try await seedTestOrg(app: app)
        let memberId = try seed.memberUser.requireID()
        let token = try signCookieToken(app: app, userId: memberId, role: .member)

        // Standard member is rejected from admin-only retention endpoint
        try await app.test(.GET, "api/admin/org/retention", beforeRequest: { req in
            req.headers.add(name: .cookie, value: "\(AdminSession.accessCookieName)=\(token)")
            req.headers.add(name: "X-Org-Id", value: seed.orgId.uuidString)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .forbidden)
        })
    }
}
