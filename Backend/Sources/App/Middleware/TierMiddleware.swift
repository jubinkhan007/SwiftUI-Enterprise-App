import Vapor
import Fluent

struct TierMiddleware: AsyncMiddleware {
    let requiredTier: String // "pro" or "enterprise"

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let ctx = try request.orgContext
        guard let org = try await OrganizationModel.find(ctx.orgId, on: request.db) else {
            throw Abort(.notFound, reason: "Organization not found.")
        }

        let tier = org.subscriptionTier?.lowercased() ?? "free"
        
        switch requiredTier {
        case "enterprise":
            guard tier == "enterprise" else {
                throw Abort(.forbidden, reason: "This feature is restricted to Enterprise tier workspaces. Please contact support or upgrade.")
            }
        case "pro":
            guard tier == "pro" || tier == "enterprise" else {
                throw Abort(.forbidden, reason: "This feature is restricted to Pro and Enterprise tier workspaces. Please upgrade your plan.")
            }
        default:
            break
        }

        return try await next.respond(to: request)
    }
}
