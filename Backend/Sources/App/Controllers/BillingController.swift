import Fluent
import SharedModels
import Vapor

struct BillingController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api", "org", "billing")
        let tenant = api.grouped(OrgTenantMiddleware())

        tenant.post("checkout", use: createCheckoutSession)
        tenant.post("portal", use: createPortalSession)
        
        // Public webhook endpoint (Stripe hits this without auth)
        api.post("webhook", use: handleStripeWebhook)
    }

    // MARK: - POST /api/org/billing/checkout
    @Sendable
    func createCheckoutSession(req: Request) async throws -> Response {
        let ctx = try req.orgContext
        guard let _ = try await OrganizationModel.find(ctx.orgId, on: req.db) else {
            throw Abort(.notFound, reason: "Organization not found.")
        }

        let stripeKey = Environment.get("STRIPE_SECRET_KEY") ?? ""
        if stripeKey.isEmpty {
            if let org = try await OrganizationModel.find(ctx.orgId, on: req.db) {
                org.subscriptionTier = "pro"
                org.subscriptionStatus = "active"
                org.stripeCustomerId = "cus_mock_\(UUID().uuidString.prefix(8).lowercased())"
                org.stripeSubscriptionId = "sub_mock_\(UUID().uuidString.prefix(8).lowercased())"
                try await org.save(on: req.db)
                req.logger.info("Mock sandbox checkout: upgraded org \(ctx.orgId) to Pro.")
            }
            // Local fallback mock link
            let mockRedirect = "http://localhost:5173/org/billing?mock_checkout=success&org_id=\(ctx.orgId.uuidString)"
            struct CheckoutResponse: Content {
                let url: String
            }
            return try await CheckoutResponse(url: mockRedirect).encodeResponse(for: req)
        }

        // Call live Stripe Sandbox
        let headers = HTTPHeaders([
            ("Authorization", "Bearer \(stripeKey)"),
            ("Content-Type", "application/x-www-form-urlencoded")
        ])

        let successUrl = "http://localhost:5173/org/billing?stripe_session_id={CHECKOUT_SESSION_ID}"
        let cancelUrl = "http://localhost:5173/org/billing"
        
        var body = ""
        body += "payment_method_types[0]=card&"
        body += "mode=subscription&"
        body += "line_items[0][price_data][currency]=usd&"
        body += "line_items[0][price_data][product_data][name]=Pro+Plan+(SaaS+Subscription)&"
        body += "line_items[0][price_data][unit_amount]=1900&" // $19.00
        body += "line_items[0][price_data][recurring][interval]=month&"
        body += "line_items[0][quantity]=1&"
        body += "client_reference_id=\(ctx.orgId.uuidString)&"
        body += "success_url=\(successUrl)&"
        body += "cancel_url=\(cancelUrl)"

        let stripeResponse = try await req.client.post(URI(string: "https://api.stripe.com/v1/checkout/sessions"), headers: headers) { postReq in
            postReq.body = ByteBuffer(string: body)
        }

        guard stripeResponse.status == .ok else {
            let errorMsg = stripeResponse.body?.getString(at: 0, length: stripeResponse.body?.readableBytes ?? 0) ?? ""
            req.logger.error("Stripe Checkout Error: \(errorMsg)")
            throw Abort(.internalServerError, reason: "Failed to communicate with Stripe sandbox gateway.")
        }

        struct StripeSession: Decodable {
            let url: String
        }

        let session = try stripeResponse.content.decode(StripeSession.self)
        struct CheckoutResponse: Content {
            let url: String
        }
        return try await CheckoutResponse(url: session.url).encodeResponse(for: req)
    }

    // MARK: - POST /api/org/billing/portal
    @Sendable
    func createPortalSession(req: Request) async throws -> Response {
        let ctx = try req.orgContext
        guard let org = try await OrganizationModel.find(ctx.orgId, on: req.db) else {
            throw Abort(.notFound, reason: "Organization not found.")
        }

        let stripeKey = Environment.get("STRIPE_SECRET_KEY") ?? ""
        if stripeKey.isEmpty {
            // Local fallback mock link - downgrade to free tier for prototyping
            org.subscriptionTier = "free"
            org.subscriptionStatus = nil
            org.stripeCustomerId = nil
            org.stripeSubscriptionId = nil
            try await org.save(on: req.db)
            req.logger.info("Mock sandbox portal: downgraded org \(ctx.orgId) to Free.")

            let mockRedirect = "http://localhost:5173/org/billing?mock_portal=downgrade"
            struct PortalResponse: Content {
                let url: String
            }
            return try await PortalResponse(url: mockRedirect).encodeResponse(for: req)
        }

        guard let customerId = org.stripeCustomerId, !customerId.isEmpty else {
            throw Abort(.badRequest, reason: "No active Stripe customer profile found for this organization.")
        }

        let headers = HTTPHeaders([
            ("Authorization", "Bearer \(stripeKey)"),
            ("Content-Type", "application/x-www-form-urlencoded")
        ])

        let returnUrl = "http://localhost:5173/org/billing"
        let body = "customer=\(customerId)&return_url=\(returnUrl)"

        let stripeResponse = try await req.client.post(URI(string: "https://api.stripe.com/v1/billing_portal/sessions"), headers: headers) { postReq in
            postReq.body = ByteBuffer(string: body)
        }

        guard stripeResponse.status == .ok else {
            throw Abort(.internalServerError, reason: "Failed to communicate with Stripe sandbox gateway.")
        }

        struct StripePortal: Decodable {
            let url: String
        }

        let portal = try stripeResponse.content.decode(StripePortal.self)
        struct PortalResponse: Content {
            let url: String
        }
        return try await PortalResponse(url: portal.url).encodeResponse(for: req)
    }

    // MARK: - POST /api/org/billing/webhook
    @Sendable
    func handleStripeWebhook(req: Request) async throws -> HTTPStatus {
        struct StripeWebhookEvent: Decodable {
            struct DataObj: Decodable {
                struct ObjectObj: Decodable {
                    let id: String?
                    let customer: String?
                    let subscription: String?
                    let client_reference_id: String?
                    let status: String?
                }
                let object: ObjectObj
            }
            let type: String
            let data: DataObj
        }

        let event: StripeWebhookEvent
        do {
            event = try req.content.decode(StripeWebhookEvent.self)
        } catch {
            req.logger.error("Failed to decode Stripe webhook payload: \(error)")
            return .badRequest
        }

        req.logger.info("Stripe Webhook Received: \(event.type)")

        switch event.type {
        case "checkout.session.completed":
            let obj = event.data.object
            guard let orgIdStr = obj.client_reference_id,
                  let orgId = UUID(uuidString: orgIdStr),
                  let customer = obj.customer,
                  let subscription = obj.subscription else {
                return .badRequest
            }

            if let org = try await OrganizationModel.find(orgId, on: req.db) {
                org.subscriptionTier = "pro"
                org.stripeCustomerId = customer
                org.stripeSubscriptionId = subscription
                org.subscriptionStatus = "active"
                try await org.save(on: req.db)
                req.logger.info("Organization \(orgId) successfully upgraded to Pro via Stripe.")
            }

        case "invoice.payment_failed", "customer.subscription.deleted":
            let obj = event.data.object
            guard let customer = obj.customer else {
                return .badRequest
            }

            // Find organization by stripeCustomerId
            if let org = try await OrganizationModel.query(on: req.db)
                .filter(\.$stripeCustomerId == customer)
                .first() {
                org.subscriptionStatus = "unpaid"
                org.subscriptionTier = "free" // Fallback to free tier
                try await org.save(on: req.db)
                req.logger.info("Organization \(org.id ?? UUID()) reverted to free tier due to payment failure / cancellation.")
            }

        default:
            break
        }

        return .ok
    }
}
