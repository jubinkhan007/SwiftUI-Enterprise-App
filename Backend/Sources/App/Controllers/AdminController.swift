import Fluent
import SharedModels
import Vapor

// MARK: - Boot date (process uptime source)

struct BootDateKey: StorageKey {
    typealias Value = Date
}

extension Application {
    var bootDate: Date {
        storage[BootDateKey.self] ?? Date()
    }
}

// MARK: - Platform admin DTOs (backend-local)

struct AdminOrgDTO: Content {
    let id: UUID
    let name: String
    let slug: String
    let status: String
    let ownerId: UUID
    let ownerEmail: String?
    let memberCount: Int
    let messageCount: Int
    let retentionDays: Int?
    let createdAt: Date?
}

struct AdminUserDTO: Content {
    let id: UUID
    let email: String
    let displayName: String
    let role: UserRole
    let isSuperAdmin: Bool
    let orgCount: Int
    let createdAt: Date?
}

struct ServerHealthDTO: Content {
    let status: String
    let uptimeSeconds: Int
    let memoryUsedMB: Double
    let totalConnections: Int
    let uniqueUsers: Int
    let activeChannels: Int
    let dbLatencyMs: Double
    let userCount: Int
    let orgCount: Int
    let messageCount: Int
    let timestamp: Date
}

struct CreateOrgAdminRequest: Content {
    let name: String
    let slug: String
    let description: String?
    /// Email of an existing user to own the org. Defaults to the acting super-admin.
    let ownerEmail: String?
}

struct ResetPasswordRequest: Content {
    let newPassword: String
}

struct ChangeRoleRequest: Content {
    let role: UserRole
}

struct ToggleSuperAdminRequest: Content {
    let isSuperAdmin: Bool
}

// MARK: - AdminController

/// Super-admin platform routes under `/api/admin`. Assumes the route group is
/// already protected by `CookieAuthMiddleware` + `SuperAdminMiddleware`.
struct AdminController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let orgs = routes.grouped("orgs")
        orgs.get(use: listOrgs)
        orgs.post(use: createOrg)
        orgs.post(":orgID", "suspend", use: suspendOrg)
        orgs.post(":orgID", "activate", use: activateOrg)
        orgs.delete(":orgID", use: deleteOrg)

        let users = routes.grouped("users")
        users.get(use: listUsers)
        users.post(":userID", "reset-password", use: resetPassword)
        users.put(":userID", "role", use: changeRole)
        users.put(":userID", "super-admin", use: toggleSuperAdmin)

        routes.get("health", use: health)
        routes.get("audit", use: globalAudit)
    }

    // MARK: - Organizations

    @Sendable
    func listOrgs(req: Request) async throws -> APIResponse<[AdminOrgDTO]> {
        let q = (try? req.query.get(String.self, at: "q"))?.lowercased()
        var query = OrganizationModel.query(on: req.db).with(\.$owner)
        if let q, !q.isEmpty {
            query = query.group(.or) { group in
                group.filter(\.$name ~~ q).filter(\.$slug ~~ q)
            }
        }
        let orgs = try await query.sort(\.$createdAt, .descending).all()

        var result: [AdminOrgDTO] = []
        for org in orgs {
            guard let orgId = org.id else { continue }
            let memberCount = try await OrganizationMemberModel.query(on: req.db)
                .filter(\.$organization.$id == orgId).count()
            let messageCount = try await MessageModel.query(on: req.db)
                .join(ConversationModel.self, on: \MessageModel.$conversation.$id == \ConversationModel.$id)
                .filter(ConversationModel.self, \.$organization.$id == orgId)
                .count()
            result.append(AdminOrgDTO(
                id: orgId, name: org.name, slug: org.slug, status: org.status,
                ownerId: org.$owner.id, ownerEmail: org.owner.email,
                memberCount: memberCount, messageCount: messageCount,
                retentionDays: org.retentionDays, createdAt: org.createdAt
            ))
        }
        return .success(result)
    }

    @Sendable
    func createOrg(req: Request) async throws -> APIResponse<AdminOrgDTO> {
        let payload = try req.content.decode(CreateOrgAdminRequest.self)
        let auth = try req.authContext

        let name = payload.name.trimmingCharacters(in: .whitespaces)
        let slug = payload.slug.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty, !slug.isEmpty else {
            throw Abort(.badRequest, reason: "Name and slug are required.")
        }
        if try await OrganizationModel.query(on: req.db).filter(\.$slug == slug).first() != nil {
            throw Abort(.conflict, reason: "An organization with this slug already exists.")
        }

        // Resolve owner.
        let owner: UserModel
        if let email = payload.ownerEmail?.lowercased(), !email.isEmpty {
            guard let u = try await UserModel.query(on: req.db).filter(\.$email == email).first() else {
                throw Abort(.badRequest, reason: "No user found with email \(email).")
            }
            owner = u
        } else {
            guard let u = try await UserModel.find(auth.userId, on: req.db) else {
                throw Abort(.unauthorized, reason: "Acting user not found.")
            }
            owner = u
        }
        guard let ownerId = owner.id else {
            throw Abort(.internalServerError, reason: "Owner missing id.")
        }

        let org = OrganizationModel(name: name, slug: slug, description: payload.description, ownerId: ownerId)
        try await org.save(on: req.db)
        guard let orgId = org.id else { throw Abort(.internalServerError) }

        let membership = OrganizationMemberModel(orgId: orgId, userId: ownerId, role: .owner)
        try await membership.save(on: req.db)

        return .success(AdminOrgDTO(
            id: orgId, name: org.name, slug: org.slug, status: org.status,
            ownerId: ownerId, ownerEmail: owner.email,
            memberCount: 1, messageCount: 0,
            retentionDays: org.retentionDays, createdAt: org.createdAt
        ))
    }

    @Sendable
    func suspendOrg(req: Request) async throws -> APIResponse<AdminOrgDTO> {
        try await setOrgStatus(req: req, status: "suspended")
    }

    @Sendable
    func activateOrg(req: Request) async throws -> APIResponse<AdminOrgDTO> {
        try await setOrgStatus(req: req, status: "active")
    }

    private func setOrgStatus(req: Request, status: String) async throws -> APIResponse<AdminOrgDTO> {
        guard let org = try await OrganizationModel.find(req.parameters.get("orgID"), on: req.db) else {
            throw Abort(.notFound, reason: "Organization not found.")
        }
        org.status = status
        try await org.save(on: req.db)
        try await org.$owner.load(on: req.db)
        guard let orgId = org.id else { throw Abort(.internalServerError) }
        let memberCount = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$organization.$id == orgId).count()
        return .success(AdminOrgDTO(
            id: orgId, name: org.name, slug: org.slug, status: org.status,
            ownerId: org.$owner.id, ownerEmail: org.owner.email,
            memberCount: memberCount, messageCount: 0,
            retentionDays: org.retentionDays, createdAt: org.createdAt
        ))
    }

    @Sendable
    func deleteOrg(req: Request) async throws -> APIResponse<EmptyResponse> {
        guard let org = try await OrganizationModel.find(req.parameters.get("orgID"), on: req.db),
              let orgId = org.id else {
            throw Abort(.notFound, reason: "Organization not found.")
        }
        // Remove dependent rows that lack DB-level cascade, then the org.
        try await OrganizationMemberModel.query(on: req.db).filter(\.$organization.$id == orgId).delete()
        try await OrganizationInviteModel.query(on: req.db).filter(\.$organization.$id == orgId).delete()
        try await AuditLogModel.query(on: req.db).filter(\.$organization.$id == orgId).delete()
        try await org.delete(on: req.db)
        return .empty()
    }

    // MARK: - Users

    @Sendable
    func listUsers(req: Request) async throws -> APIResponse<[AdminUserDTO]> {
        let q = (try? req.query.get(String.self, at: "q"))?.lowercased()
        var query = UserModel.query(on: req.db)
        if let q, !q.isEmpty {
            query = query.group(.or) { group in
                group.filter(\.$email ~~ q).filter(\.$displayName ~~ q)
            }
        }
        let users = try await query.sort(\.$createdAt, .descending).all()
        var result: [AdminUserDTO] = []
        for user in users {
            guard let userId = user.id else { continue }
            let orgCount = try await OrganizationMemberModel.query(on: req.db)
                .filter(\.$user.$id == userId).count()
            result.append(AdminUserDTO(
                id: userId, email: user.email, displayName: user.displayName,
                role: user.role, isSuperAdmin: user.isSuperAdmin,
                orgCount: orgCount, createdAt: user.createdAt
            ))
        }
        return .success(result)
    }

    @Sendable
    func resetPassword(req: Request) async throws -> APIResponse<EmptyResponse> {
        let payload = try req.content.decode(ResetPasswordRequest.self)
        guard payload.newPassword.count >= 8 else {
            throw Abort(.badRequest, reason: "Password must be at least 8 characters.")
        }
        guard let user = try await UserModel.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }
        user.passwordHash = try Bcrypt.hash(payload.newPassword, cost: 4)
        try await user.save(on: req.db)
        return .empty()
    }

    @Sendable
    func changeRole(req: Request) async throws -> APIResponse<AdminUserDTO> {
        let payload = try req.content.decode(ChangeRoleRequest.self)
        guard let user = try await UserModel.find(req.parameters.get("userID"), on: req.db),
              let userId = user.id else {
            throw Abort(.notFound, reason: "User not found.")
        }
        user.role = payload.role
        try await user.save(on: req.db)
        let orgCount = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$user.$id == userId).count()
        return .success(AdminUserDTO(
            id: userId, email: user.email, displayName: user.displayName,
            role: user.role, isSuperAdmin: user.isSuperAdmin,
            orgCount: orgCount, createdAt: user.createdAt
        ))
    }

    @Sendable
    func toggleSuperAdmin(req: Request) async throws -> APIResponse<AdminUserDTO> {
        let payload = try req.content.decode(ToggleSuperAdminRequest.self)
        let auth = try req.authContext
        guard let user = try await UserModel.find(req.parameters.get("userID"), on: req.db),
              let userId = user.id else {
            throw Abort(.notFound, reason: "User not found.")
        }
        // Guard against self-demotion locking everyone out is the caller's concern;
        // we only prevent removing your own super-admin in the same request.
        if userId == auth.userId && !payload.isSuperAdmin {
            throw Abort(.badRequest, reason: "You cannot revoke your own super-admin access.")
        }
        user.isSuperAdmin = payload.isSuperAdmin
        try await user.save(on: req.db)
        let orgCount = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$user.$id == userId).count()
        return .success(AdminUserDTO(
            id: userId, email: user.email, displayName: user.displayName,
            role: user.role, isSuperAdmin: user.isSuperAdmin,
            orgCount: orgCount, createdAt: user.createdAt
        ))
    }

    // MARK: - Server health

    @Sendable
    func health(req: Request) async throws -> APIResponse<ServerHealthDTO> {
        let hub = req.application.realtimeHub.stats()

        // DB latency probe.
        let probeStart = Date()
        let userCount = try await UserModel.query(on: req.db).count()
        let dbLatencyMs = Date().timeIntervalSince(probeStart) * 1000

        let orgCount = try await OrganizationModel.query(on: req.db).count()
        let messageCount = try await MessageModel.query(on: req.db).count()

        let uptime = Int(Date().timeIntervalSince(req.application.bootDate))
        let dto = ServerHealthDTO(
            status: "ok",
            uptimeSeconds: uptime,
            memoryUsedMB: Self.residentMemoryMB(),
            totalConnections: hub.totalConnections,
            uniqueUsers: hub.uniqueUsers,
            activeChannels: hub.activeChannels,
            dbLatencyMs: (dbLatencyMs * 100).rounded() / 100,
            userCount: userCount,
            orgCount: orgCount,
            messageCount: messageCount,
            timestamp: Date()
        )
        return .success(dto)
    }

    // MARK: - Global audit trail

    @Sendable
    func globalAudit(req: Request) async throws -> APIResponse<[AuditLogDTO]> {
        let limit = min((try? req.query.get(Int.self, at: "limit")) ?? 100, 500)
        var query = AuditLogModel.query(on: req.db)
        if let orgIdStr = try? req.query.get(String.self, at: "orgId"), let orgId = UUID(uuidString: orgIdStr) {
            query = query.filter(\.$organization.$id == orgId)
        }
        let logs = try await query.sort(\.$createdAt, .descending).range(..<limit).all()
        return .success(logs.map { $0.toDTO() })
    }

    // MARK: - Helpers

    /// Resident set size in MB (best-effort, cross-platform).
    static func residentMemoryMB() -> Double {
        #if os(macOS)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1_048_576.0
        #else
        // Linux: parse /proc/self/statm (pages * page size).
        guard let statm = try? String(contentsOfFile: "/proc/self/statm", encoding: .utf8),
              let residentPages = statm.split(separator: " ").dropFirst().first.flatMap({ Double($0) }) else {
            return 0
        }
        let pageSize = Double(sysconf(Int32(_SC_PAGESIZE)))
        return residentPages * pageSize / 1_048_576.0
        #endif
    }
}
