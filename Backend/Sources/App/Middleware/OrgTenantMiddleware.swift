import Fluent
import SharedModels
import Vapor

/// Middleware that validates the `X-Org-Id` header and ensures the authenticated user
/// is a member of the specified organization. Stores the resolved org membership
/// in `Request.storage` for downstream handlers.
struct OrgTenantMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Extract X-Org-Id header
        guard let orgIdString = request.headers.first(name: "X-Org-Id"),
              let orgId = UUID(uuidString: orgIdString) else {
            throw Abort(.badRequest, reason: "Missing or invalid X-Org-Id header.")
        }

        // Get the authenticated user
        let authPayload = try request.authPayload
        guard let userId = authPayload.userId else {
            throw Abort(.unauthorized, reason: "Invalid user token.")
        }

        // Verify user is a member of this organization
        guard let membership = try await OrganizationMemberModel.query(on: request.db)
            .filter(\.$organization.$id == orgId)
            .filter(\.$user.$id == userId)
            .first()
        else {
            throw Abort(.forbidden, reason: "You do not have access to this workspace.")
        }

        // Store the resolved context for downstream use
        request.storage[OrgContextKey.self] = OrgContext(
            orgId: orgId,
            userId: userId,
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
