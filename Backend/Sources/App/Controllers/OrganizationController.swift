import Fluent
import SharedModels
import Vapor

/// Handles organization CRUD, membership management, invite lifecycle, and the `/api/me` endpoint.
struct OrganizationController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // /api/me — no org context required, returns user + all their orgs
        routes.get("me", use: me)
        // /api/invites — no org context required, returns invites addressed to the current user
        routes.get("invites", use: myInvites)

        let orgs = routes.grouped("organizations")
        orgs.post(use: create)
        orgs.get(use: listMyOrgs)

        // Org-scoped routes (require X-Org-Id header)
        let orgScoped = orgs.grouped(OrgTenantMiddleware())
        orgScoped.group(":orgID") { org in
            org.get(use: show)
            org.get("members", use: listMembers)
            org.post("invites", use: createInvite)
            org.get("invites", use: listInvites)
            org.put("members", ":memberID", "role", use: updateMemberRole)
            org.delete("members", ":memberID", use: removeMember)
            org.post("invites", ":inviteID", "revoke", use: revokeInvite)
            org.get("audit-log", use: listAuditLog)
            org.post("join", use: requestToJoin)
            org.get("join-requests", use: listJoinRequests)
        }

        // Join request response (no specific org context in header — admin acts on a pending request)
        orgs.post("join-requests", ":requestID", "respond", use: respondToJoinRequest)

        // Workspace discovery search (no org membership required)
        orgs.get("search", use: searchOrganizations)

        // Public invite acceptance (no org context needed, uses invite token)
        orgs.post("invites", ":inviteID", "accept", use: acceptInvite)
    }

    // MARK: - GET /api/me

    /// Returns the current user's profile, organizations, and (optionally) permissions for a specific org.
    @Sendable
    func me(req: Request) async throws -> APIResponse<MeResponse> {
        let userId = try req.authContext.userId

        guard let user = try await UserModel.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        // Fetch all orgs the user belongs to
        let memberships = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()

        let orgIds = memberships.map { $0.$organization.id }
        let orgs = try await OrganizationModel.query(on: req.db)
            .filter(\.$id ~~ orgIds)
            .all()

        let orgDTOs = orgs.map { $0.toDTO() }

        // If org_id query param provided, resolve role + permissions for that specific org
        var activeRole: UserRole? = nil
        var activePermissions: PermissionSet? = nil
        var activeOrgId: UUID? = nil

        if let orgIdString = try? req.query.get(String.self, at: "org_id"),
           let orgId = UUID(uuidString: orgIdString) {
            if let membership = memberships.first(where: { $0.$organization.id == orgId }) {
                activeOrgId = orgId
                activeRole = membership.role
                activePermissions = PermissionSet.defaultPermissions(for: membership.role)
            }
        }

        let response = MeResponse(
            user: user.toDTO(),
            orgId: activeOrgId,
            role: activeRole,
            permissions: activePermissions,
            organizations: orgDTOs
        )

        return .success(response)
    }

    // MARK: - GET /api/invites

    /// Returns pending invites addressed to the current user's email.
    /// This endpoint does not require an org context (X-Org-Id) since the user
    /// is not yet a member of the invited org.
    @Sendable
    func myInvites(req: Request) async throws -> APIResponse<[PendingInviteDTO]> {
        let userId = try req.authContext.userId

        guard let user = try await UserModel.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let now = Date()
        let invites = try await OrganizationInviteModel.query(on: req.db)
            .filter(\.$email == user.email.lowercased())
            .filter(\.$status == .pending)
            .filter(\.$expiresAt > now)
            .sort(\.$createdAt, .descending)
            .all()

        if invites.isEmpty {
            return .success([])
        }

        let orgIds = Array(Set(invites.map { $0.$organization.id }))
        let orgs = try await OrganizationModel.query(on: req.db)
            .filter(\.$id ~~ orgIds)
            .all()

        var orgNameById: [UUID: String] = [:]
        orgNameById.reserveCapacity(orgs.count)
        for org in orgs {
            if let id = org.id {
                orgNameById[id] = org.name
            }
        }

        let dtos = invites.map { invite in
            PendingInviteDTO(
                id: invite.id ?? UUID(),
                orgId: invite.$organization.id,
                orgName: orgNameById[invite.$organization.id] ?? "Workspace",
                role: invite.role,
                invitedBy: invite.invitedBy,
                expiresAt: invite.expiresAt,
                createdAt: invite.createdAt
            )
        }

        return .success(dtos)
    }

    // MARK: - POST /api/organizations

    @Sendable
    func create(req: Request) async throws -> APIResponse<OrganizationDTO> {
        let userId = try req.authContext.userId

        let payload = try req.content.decode(CreateOrganizationRequest.self)

        guard !payload.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Organization name is required.")
        }

        // Generate slug from name
        let slug = payload.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        // Check for duplicate slug
        let existing = try await OrganizationModel.query(on: req.db)
            .filter(\.$slug == slug)
            .first()
        guard existing == nil else {
            throw Abort(.conflict, reason: "An organization with this name already exists.")
        }

        let org = OrganizationModel(
            name: payload.name.trimmingCharacters(in: .whitespaces),
            slug: slug,
            description: payload.description,
            ownerId: userId
        )

        // Create org, owner membership, and default hierarchy in a transaction
        try await req.db.transaction { db in
            try await org.save(on: db)
            let newOrgId = try org.requireID()

            let membership = OrganizationMemberModel(
                orgId: newOrgId,
                userId: userId,
                role: .owner
            )
            try await membership.save(on: db)
            
            // Auto-generate default Phase 7 hierarchy
            let defaultSpace = SpaceModel(orgId: newOrgId, name: "Default Space")
            try await defaultSpace.save(on: db)
            
            let defaultProject = ProjectModel(spaceId: try defaultSpace.requireID(), name: "General")
            try await defaultProject.save(on: db)
            
            let defaultList = TaskListModel(projectId: try defaultProject.requireID(), name: "To Do")
            try await defaultList.save(on: db)
        }

        return .success(org.toDTO(memberCount: 1))
    }

    // MARK: - GET /api/organizations

    @Sendable
    func listMyOrgs(req: Request) async throws -> APIResponse<[OrganizationDTO]> {
        let userId = try req.authContext.userId

        let memberships = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()

        let orgIds = memberships.map { $0.$organization.id }
        let orgs = try await OrganizationModel.query(on: req.db)
            .filter(\.$id ~~ orgIds)
            .all()

        let dtos = orgs.map { $0.toDTO() }
        return .success(dtos)
    }

    // MARK: - GET /api/organizations/:orgID

    @Sendable
    func show(req: Request) async throws -> APIResponse<OrganizationDTO> {
        guard let org = try await OrganizationModel.find(req.parameters.get("orgID"), on: req.db) else {
            throw Abort(.notFound, reason: "Organization not found.")
        }

        let memberCount = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$organization.$id == org.requireID())
            .count()

        return .success(org.toDTO(memberCount: memberCount))
    }

    // MARK: - GET /api/organizations/:orgID/members

    @Sendable
    func listMembers(req: Request) async throws -> APIResponse<[OrganizationMemberDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.membersView)

        let members = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .with(\.$user)
            .all()

        let dtos = members.map {
            $0.toDTO(displayName: $0.user.displayName, email: $0.user.email)
        }

        return .success(dtos)
    }

    // MARK: - POST /api/organizations/:orgID/invites

    @Sendable
    func createInvite(req: Request) async throws -> APIResponse<OrganizationInviteDTO> {
        let ctx = try req.orgContext
        try req.requirePermission(.membersInvite)

        let payload = try req.content.decode(CreateInviteRequest.self)

        guard payload.email.contains("@") else {
            throw Abort(.badRequest, reason: "Invalid email address.")
        }

        // Cannot invite as owner
        guard payload.role != .owner else {
            throw Abort(.badRequest, reason: "Cannot invite a user as Owner. Use ownership transfer instead.")
        }

        // Check if already a member
        let existingUser = try await UserModel.query(on: req.db)
            .filter(\.$email == payload.email.lowercased())
            .first()

        if let existingUser = existingUser {
            let existingMembership = try await OrganizationMemberModel.query(on: req.db)
                .filter(\.$organization.$id == ctx.orgId)
                .filter(\.$user.$id == existingUser.requireID())
                .first()
            if existingMembership != nil {
                throw Abort(.conflict, reason: "This user is already a member of this workspace.")
            }
        }

        // Check for existing pending invite
        let existingInvite = try await OrganizationInviteModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$email == payload.email.lowercased())
            .filter(\.$status == .pending)
            .first()

        guard existingInvite == nil else {
            throw Abort(.conflict, reason: "A pending invite already exists for this email.")
        }

        let invite = OrganizationInviteModel(
            orgId: ctx.orgId,
            email: payload.email.lowercased(),
            role: payload.role,
            invitedBy: ctx.userId,
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days
        )

        try await invite.save(on: req.db)

        // Audit log
        try await AuditLogModel.log(
            on: req.db, orgId: ctx.orgId, userId: ctx.userId,
            userEmail: "", action: "member.invited",
            resourceType: "invite", resourceId: invite.id,
            details: "Invited \(payload.email) as \(payload.role.rawValue)"
        )

        return .success(invite.toDTO())
    }

    // MARK: - GET /api/organizations/:orgID/invites

    @Sendable
    func listInvites(req: Request) async throws -> APIResponse<[OrganizationInviteDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.membersManage)

        let invites = try await OrganizationInviteModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .sort(\.$createdAt, .descending)
            .all()

        return .success(invites.map { $0.toDTO() })
    }

    // MARK: - POST /api/organizations/invites/:inviteID/accept

    @Sendable
    func acceptInvite(req: Request) async throws -> APIResponse<OrganizationMemberDTO> {
        let userId = try req.authContext.userId

        guard let invite = try await OrganizationInviteModel.find(req.parameters.get("inviteID"), on: req.db) else {
            throw Abort(.notFound, reason: "Invite not found.")
        }

        guard invite.status == .pending else {
            throw Abort(.badRequest, reason: "This invite is no longer valid (status: \(invite.status.rawValue)).")
        }

        guard invite.expiresAt > Date() else {
            invite.status = .expired
            try await invite.save(on: req.db)
            throw Abort(.gone, reason: "This invite has expired.")
        }

        // Verify the accepting user's email matches the invite
        guard let user = try await UserModel.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }
        guard user.email == invite.email else {
            throw Abort(.forbidden, reason: "This invite was sent to a different email address.")
        }

        // Create membership and mark invite accepted
        let membership = try await req.db.transaction { db -> OrganizationMemberModel in
            let membership = OrganizationMemberModel(
                orgId: invite.$organization.id,
                userId: userId,
                role: invite.role
            )
            try await membership.save(on: db)

            invite.status = .accepted
            try await invite.save(on: db)
            
            return membership
        }

        return .success(membership.toDTO(displayName: user.displayName, email: user.email))
    }

    // MARK: - PUT /api/organizations/:orgID/members/:memberID/role

    @Sendable
    func updateMemberRole(req: Request) async throws -> APIResponse<OrganizationMemberDTO> {
        let ctx = try req.orgContext
        try req.requirePermission(.membersManage)

        guard let member = try await OrganizationMemberModel.find(req.parameters.get("memberID"), on: req.db) else {
            throw Abort(.notFound, reason: "Member not found.")
        }

        // Cannot change the owner's role
        guard member.role != .owner else {
            throw Abort(.forbidden, reason: "Cannot change the Owner's role. Use ownership transfer instead.")
        }

        let payload = try req.content.decode(UpdateMemberRoleRequest.self)

        // Cannot promote to owner via role update
        guard payload.role != .owner else {
            throw Abort(.badRequest, reason: "Cannot assign Owner role. Use ownership transfer instead.")
        }

        let oldRole = member.role
        member.role = payload.role
        try await member.save(on: req.db)

        // Audit log
        try await AuditLogModel.log(
            on: req.db, orgId: ctx.orgId, userId: ctx.userId,
            userEmail: "", action: "member.role_changed",
            resourceType: "member", resourceId: member.id,
            details: "Changed role from \(oldRole.rawValue) to \(payload.role.rawValue)"
        )

        let user = try await UserModel.find(member.$user.id, on: req.db)
        return .success(member.toDTO(
            displayName: user?.displayName ?? "Unknown",
            email: user?.email ?? ""
        ))
    }

    // MARK: - DELETE /api/organizations/:orgID/members/:memberID

    @Sendable
    func removeMember(req: Request) async throws -> HTTPStatus {
        let ctx = try req.orgContext
        try req.requirePermission(.membersRemove)

        guard let member = try await OrganizationMemberModel.find(req.parameters.get("memberID"), on: req.db) else {
            throw Abort(.notFound, reason: "Member not found.")
        }

        // Cannot remove the last owner
        guard member.role != .owner else {
            throw Abort(.forbidden, reason: "Cannot remove the workspace Owner. Transfer ownership first.")
        }

        // Audit log
        try await AuditLogModel.log(
            on: req.db, orgId: ctx.orgId, userId: ctx.userId,
            userEmail: "", action: "member.removed",
            resourceType: "member", resourceId: member.id,
            details: "Removed member"
        )

        try await member.delete(on: req.db)
        return .noContent
    }

    // MARK: - POST /api/organizations/:orgID/invites/:inviteID/revoke

    @Sendable
    func revokeInvite(req: Request) async throws -> APIResponse<OrganizationInviteDTO> {
        try req.requirePermission(.membersManage)

        guard let invite = try await OrganizationInviteModel.find(req.parameters.get("inviteID"), on: req.db) else {
            throw Abort(.notFound, reason: "Invite not found.")
        }

        guard invite.status == .pending else {
            throw Abort(.badRequest, reason: "Only pending invites can be revoked.")
        }

        invite.status = .revoked
        try await invite.save(on: req.db)

        // Audit log
        let ctx = try req.orgContext
        try await AuditLogModel.log(
            on: req.db, orgId: ctx.orgId, userId: ctx.userId,
            userEmail: "", action: "invite.revoked",
            resourceType: "invite", resourceId: invite.id,
            details: "Revoked invite for \(invite.email)"
        )

        return .success(invite.toDTO())
    }

    // MARK: - GET /api/organizations/search

    @Sendable
    func searchOrganizations(req: Request) async throws -> APIResponse<[OrganizationDTO]> {
        let userId = try req.authContext.userId
        let query = (try? req.query.get(String.self, at: "q")) ?? ""
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .success([])
        }

        // Return orgs that match the query and the user is NOT already a member of
        let memberships = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()
        let joinedIds = Set(memberships.map { $0.$organization.id })

        let orgs = try await OrganizationModel.query(on: req.db)
            .filter(\.$name ~~ query)
            .all()

        let results = orgs.filter { org in
            guard let id = org.id else { return false }
            return !joinedIds.contains(id)
        }

        return .success(results.map { $0.toDTO() })
    }

    // MARK: - POST /api/organizations/:orgID/join

    @Sendable
    func requestToJoin(req: Request) async throws -> APIResponse<OrganizationJoinRequestDTO> {
        let userId = try req.authContext.userId
        guard let orgId = req.parameters.get("orgID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid organization ID.")
        }

        guard let org = try await OrganizationModel.find(orgId, on: req.db) else {
            throw Abort(.notFound, reason: "Organization not found.")
        }

        // Check not already a member
        let isMember = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .filter(\.$user.$id == userId)
            .count() > 0
        guard !isMember else {
            throw Abort(.conflict, reason: "You are already a member of this workspace.")
        }

        // Check no existing pending request
        let existing = try await OrganizationJoinRequestModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .filter(\.$user.$id == userId)
            .filter(\.$status == "pending")
            .first()
        guard existing == nil else {
            throw Abort(.conflict, reason: "You already have a pending join request for this workspace.")
        }

        guard let user = try await UserModel.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let joinRequest = OrganizationJoinRequestModel(orgId: orgId, userId: userId)
        try await joinRequest.save(on: req.db)

        return .success(joinRequest.toDTO(orgName: org.name, userName: user.displayName, userEmail: user.email))
    }

    // MARK: - GET /api/organizations/:orgID/join-requests

    @Sendable
    func listJoinRequests(req: Request) async throws -> APIResponse<[OrganizationJoinRequestDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.membersManage)

        guard let org = try await OrganizationModel.find(ctx.orgId, on: req.db) else {
            throw Abort(.notFound, reason: "Organization not found.")
        }

        let requests = try await OrganizationJoinRequestModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$status == "pending")
            .with(\.$user)
            .sort(\.$createdAt, .descending)
            .all()

        let dtos = requests.map { r in
            r.toDTO(orgName: org.name, userName: r.user.displayName, userEmail: r.user.email)
        }

        return .success(dtos)
    }

    // MARK: - POST /api/organizations/join-requests/:requestID/respond

    @Sendable
    func respondToJoinRequest(req: Request) async throws -> APIResponse<OrganizationJoinRequestDTO> {
        let userId = try req.authContext.userId

        guard let requestId = req.parameters.get("requestID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid request ID.")
        }

        guard let joinRequest = try await OrganizationJoinRequestModel.query(on: req.db)
            .filter(\.$id == requestId)
            .with(\.$organization)
            .with(\.$user)
            .first() else {
            throw Abort(.notFound, reason: "Join request not found.")
        }

        guard joinRequest.status == "pending" else {
            throw Abort(.badRequest, reason: "This join request has already been resolved.")
        }

        // Verify the responding user is an admin/owner of the org
        guard let membership = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$organization.$id == joinRequest.$organization.id)
            .filter(\.$user.$id == userId)
            .first(),
            membership.role == .admin || membership.role == .owner else {
            throw Abort(.forbidden, reason: "Only workspace admins can respond to join requests.")
        }

        let payload = try req.content.decode(RespondToJoinRequestRequest.self)
        guard payload.action == "accept" || payload.action == "reject" else {
            throw Abort(.badRequest, reason: "Action must be 'accept' or 'reject'.")
        }

        if payload.action == "accept" {
            joinRequest.status = "accepted"
            joinRequest.respondedBy = userId
            try await joinRequest.save(on: req.db)

            let orgId = joinRequest.$organization.id
            let targetUserId = joinRequest.$user.id

            let alreadyMember = try await OrganizationMemberModel.query(on: req.db)
                .filter(\.$organization.$id == orgId)
                .filter(\.$user.$id == targetUserId)
                .count() > 0

            if !alreadyMember {
                let newMembership = OrganizationMemberModel(orgId: orgId, userId: targetUserId, role: .member)
                try await newMembership.save(on: req.db)
            }
        } else {
            joinRequest.status = "rejected"
            joinRequest.respondedBy = userId
            try await joinRequest.save(on: req.db)
        }

        return .success(joinRequest.toDTO(
            orgName: joinRequest.organization.name,
            userName: joinRequest.user.displayName,
            userEmail: joinRequest.user.email
        ))
    }

    // MARK: - GET /api/organizations/:orgID/audit-log

    @Sendable
    func listAuditLog(req: Request) async throws -> APIResponse<[AuditLogDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.auditLogView)

        let logs = try await AuditLogModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .sort(\.$createdAt, .descending)
            .range(..<50)
            .all()

        return .success(logs.map { $0.toDTO() })
    }
}
