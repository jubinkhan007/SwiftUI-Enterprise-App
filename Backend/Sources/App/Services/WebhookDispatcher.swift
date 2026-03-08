import Fluent
import Vapor

struct WebhookDispatcher: Sendable {
    struct Envelope<T: Content>: Content {
        let event: String
        let timestamp: Date
        let data: T
    }

    let app: Application

    func dispatch<T: Content>(event: String, orgId: UUID, data: T) {
        let app = self.app
        let logger = app.logger

        Task.detached(priority: .utility) {
            let db = app.db
            let client = app.client

            let subscriptions = try await WebhookSubscriptionModel.query(on: db)
                .filter(\.$organization.$id == orgId)
                .filter(\.$isActive == true)
                .all()

            let matches = subscriptions.filter { $0.events.contains(event) }
            if matches.isEmpty { return }

            let now = Date()
            let timestampHeader = WebhookSigning.timestampString(for: now)
            let envelope = Envelope(event: event, timestamp: now, data: data)

            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            let body = try encoder.encode(envelope)

            await withTaskGroup(of: Void.self) { group in
                for sub in matches {
                    let subscriptionId = sub.id
                    let targetUrl = sub.targetUrl
                    let secret = sub.secret

                    group.addTask {
                        guard let subscriptionId else { return }
                        do {
                            let signature = WebhookSigning.signature(secret: secret, timestamp: timestampHeader, body: body)
                            let response = try await client.post(URI(string: targetUrl)) { req in
                                req.headers.contentType = .json
                                req.headers.replaceOrAdd(name: "X-Webhook-Timestamp", value: timestampHeader)
                                req.headers.replaceOrAdd(name: "X-Webhook-Signature", value: "sha256=\(signature)")
                                req.body = .init(data: body)
                            }

                            try await updateDeliveryState(
                                db: db,
                                subscriptionId: subscriptionId,
                                success: response.status.code >= 200 && response.status.code < 300
                            )
                        } catch {
                            logger.warning("Webhook delivery failed (\(event) -> \(targetUrl)): \(String(describing: error))")
                            try? await updateDeliveryState(db: db, subscriptionId: subscriptionId, success: false)
                        }
                    }
                }
            }
        }
    }

    private func updateDeliveryState(db: Database, subscriptionId: UUID, success: Bool) async throws {
        guard let sub = try await WebhookSubscriptionModel.find(subscriptionId, on: db) else { return }

        if success {
            if sub.failureCount != 0 {
                sub.failureCount = 0
            }
        } else {
            sub.failureCount += 1
            if sub.failureCount >= 10 {
                sub.isActive = false
            }
        }

        try await sub.save(on: db)
    }
}

