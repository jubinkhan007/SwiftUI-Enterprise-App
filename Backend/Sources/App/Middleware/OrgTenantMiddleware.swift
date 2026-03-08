import Fluent
import SharedModels
import Vapor

/// Middleware that validates the `X-Org-Id` header and ensures the authenticated user
/// is a member of the specified organization. Stores the resolved org membership
/// in `Request.storage` for downstream handlers.
struct OrgTenantMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let auth = try request.authContext

        let headerOrgId: UUID? = {
            guard let raw = request.headers.first(name: "X-Org-Id") else { return nil }
            return UUID(uuidString: raw)
        }()

        let resolvedOrgId: UUID
        if let headerOrgId, let authOrgId = auth.orgId, headerOrgId != authOrgId {
            throw Abort(.badRequest, reason: "X-Org-Id does not match API key organization.")
        } else if let headerOrgId {
            resolvedOrgId = headerOrgId
        } else if let authOrgId = auth.orgId {
            resolvedOrgId = authOrgId
        } else {
            throw Abort(.badRequest, reason: "Missing X-Org-Id header.")
        }

        // Verify user is a member of this organization
        guard let membership = try await OrganizationMemberModel.query(on: request.db)
            .filter(\.$organization.$id == resolvedOrgId)
            .filter(\.$user.$id == auth.userId)
            .first()
        else {
            throw Abort(.forbidden, reason: "You do not have access to this workspace.")
        }

        // Store the resolved context for downstream use
        request.storage[OrgContextKey.self] = OrgContext(
            orgId: resolvedOrgId,
            userId: auth.userId,
            role: membership.role,
            permissions: PermissionSet.defaultPermissions(for: membership.role)
        )

        return try await next.respond(to: request)
    }
}

// MARK: - Storage

/// The resolved organization context for the current request.
struct OrgContext {
    let orgId: UUID
    let userId: UUID
    let role: UserRole
    let permissions: PermissionSet
}

struct OrgContextKey: StorageKey {
    typealias Value = OrgContext
}

extension Request {
    /// Access the validated organization context.
    var orgContext: OrgContext {
        get throws {
            guard let ctx = storage[OrgContextKey.self] else {
                throw Abort(.internalServerError, reason: "Org context not set. Ensure OrgTenantMiddleware is applied.")
            }
            return ctx
        }
    }

    /// Require a specific permission within the current org context.
    func requirePermission(_ permission: Permission) throws {
        let ctx = try orgContext
        guard ctx.permissions.has(permission) else {
            throw Abort(.forbidden, reason: "You do not have permission to perform this action (\(permission.rawValue)).")
        }
    }
}
