import Vapor
import Fluent
import Crypto
import SharedModels

/// An internal service that looks up active webhook subscriptions for a given organization and event,
/// signs the payload with HMAC-SHA256, and fires an asynchronous HTTP request using Circuit Breaker logic.
struct WebhookDispatcher {
    
    /// Called directly by the test ping endpoint bypasses rules and sends a dummy payload.
    static func dispatchPing(to subscription: WebhookSubscriptionModel, on req: Request) async throws {
        let payload = WebhookPayload(
            eventId: UUID(),
            eventType: "ping",
            timestamp: Date(),
            orgId: subscription.$organization.id,
            data: ["message": "Webhook ping successful!"]
        )
        try await send(payload: payload, to: subscription, on: req)
    }

    /// Dispatches an event payload functionally to all active subscribers for that org/event type.
    static func dispatchEvent<T: Encodable>(
        orgId: UUID,
        eventType: String,
        data: T,
        on req: Request
    ) {
        // Run in background to not block the main API response
        Task {
            do {
                let subscriptions = try await WebhookSubscriptionModel.query(on: req.db)
                    .filter(\.$organization.$id == orgId)
                    .filter(\.$isActive == true)
                    .all()

                let matching = subscriptions.filter { $0.events.contains(eventType) }
                guard !matching.isEmpty else { return }

                let eventId = UUID()
                let payload = WebhookPayload(
                    eventId: eventId,
                    eventType: eventType,
                    timestamp: Date(),
                    orgId: orgId,
                    data: data
                )

                for sub in matching {
                    // Intentionally fire and forget each one individually so one failure doesnt block others
                    Task {
                        try? await send(payload: payload, to: sub, on: req)
                    }
                }
            } catch {
                req.logger.error("Failed to query webhook subscriptions for event \(eventType): \(error)")
            }
        }
    }

    private static func send<T: Encodable>(payload: WebhookPayload<T>, to sub: WebhookSubscriptionModel, on req: Request) async throws {
        // Enforce Circuit Breaker
        if sub.failureCount >= 10 {
            sub.isActive = false
            req.logger.warning("Webhook \(sub.id?.uuidString ?? "") circuit breaker tripped. Deactivating.")
            try await sub.save(on: req.db)
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let payloadData = try encoder.encode(payload)
        
        // Generate HMAC-SHA256 signature
        let secretKey = SymmetricKey(data: Data(sub.secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: secretKey)
        let signatureString = Data(signature).hex

        do {
            let response = try await req.client.post(URI(string: sub.targetUrl)) { request in
                request.headers.contentType = .json
                request.headers.add(name: "X-Webhook-Signature", value: "sha256=\(signatureString)")
                request.headers.add(name: "X-Webhook-EventID", value: payload.eventId.uuidString)
                request.body = .init(data: payloadData)
            }

            if response.status.code >= 200 && response.status.code < 300 {
                // Success: reset failure count
                if sub.failureCount > 0 {
                    sub.failureCount = 0
                    try await sub.save(on: req.db)
                }
            } else {
                req.logger.error("Webhook \(sub.targetUrl) returned \(response.status.code)")
                sub.failureCount += 1
                try await sub.save(on: req.db)
            }
        } catch {
            req.logger.error("Webhook \(sub.targetUrl) delivery failed: \(error)")
            sub.failureCount += 1
            try await sub.save(on: req.db)
        }
    }
}

// Wrapper format for all outgoing webhooks
struct WebhookPayload<T: Encodable>: Encodable {
    let eventId: UUID
    let eventType: String
    let timestamp: Date
    let orgId: UUID
    let data: T
}
