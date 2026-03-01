import Fluent
import JWT
import SharedModels
import Vapor

enum RealtimeController {
    struct ClientMessage: Decodable, Sendable {
        let action: String
        let channels: [String]?
    }

    static func register(on app: Application) {
        app.webSocket("ws") { req, ws in
            do {
                let token = try extractToken(from: req)
                let payload = try req.jwt.verify(token, as: JWTAuthPayload.self)
                guard let userId = payload.userId else {
                    try await ws.close(code: .policyViolation)
                    return
                }

                guard let orgIdStr = try? req.query.get(String.self, at: "org_id"),
                      let orgId = UUID(uuidString: orgIdStr)
                else {
                    try await ws.close(code: .policyViolation)
                    return
                }

                // Verify membership before subscribing.
                let isMember = try await OrganizationMemberModel.query(on: req.db)
                    .filter(\.$organization.$id == orgId)
                    .filter(\.$user.$id == userId)
                    .count() > 0
                guard isMember else {
                    try await ws.close(code: .policyViolation)
                    return
                }

                let connId = app.realtimeHub.addConnection(
                    userId: userId,
                    orgId: orgId,
                    socket: ws,
                    initialChannels: ["org:\(orgId.uuidString)"]
                )

                ws.onClose.whenComplete { _ in
                    app.realtimeHub.removeConnection(id: connId)
                }

                ws.onText { ws, text in
                    Task {
                        await handleClientText(app: app, req: req, ws: ws, connId: connId, orgId: orgId, text: text)
                    }
                }
            } catch {
                ws.close(promise: nil)
            }
        }
    }

    private static func handleClientText(
        app: Application,
        req: Request,
        ws: WebSocket,
        connId: UUID,
        orgId: UUID,
        text: String
    ) async {
        guard let data = text.data(using: .utf8) else { return }
        guard let msg = try? JSONDecoder().decode(ClientMessage.self, from: data) else { return }

        switch msg.action {
        case "ping":
            try? await ws.send(#"{"type":"pong"}"#)
        case "subscribe":
            let channels = (msg.channels ?? []).filter { isValidChannel($0) }
            let allowed = await filterAllowedChannels(channels, orgId: orgId, db: req.db)
            app.realtimeHub.subscribe(id: connId, channels: allowed)
        case "unsubscribe":
            let channels = (msg.channels ?? []).filter { isValidChannel($0) }
            app.realtimeHub.unsubscribe(id: connId, channels: channels)
        default:
            return
        }
    }

    private static func extractToken(from req: Request) throws -> String {
        if let token = req.headers.bearerAuthorization?.token {
            return token
        }
        if let token: String = try? req.query.get(String.self, at: "token") {
            return token
        }
        throw Abort(.unauthorized, reason: "Missing authorization token.")
    }

    private static func isValidChannel(_ channel: String) -> Bool {
        channel.hasPrefix("org:") || channel.hasPrefix("project:") || channel.hasPrefix("list:")
    }

    private static func filterAllowedChannels(_ channels: [String], orgId: UUID, db: Database) async -> [String] {
        var allowed: [String] = []
        allowed.reserveCapacity(channels.count)

        for ch in channels {
            if ch.hasPrefix("org:") {
                // Only allow the bound org.
                if ch == "org:\(orgId.uuidString)" { allowed.append(ch) }
                continue
            }

            if ch.hasPrefix("project:") {
                let idStr = String(ch.dropFirst("project:".count))
                guard let projectId = UUID(uuidString: idStr) else { continue }
                let ok: Bool
                do {
                    if let project = try await ProjectModel.query(on: db)
                        .filter(\.$id == projectId)
                        .with(\.$space)
                        .first()
                    {
                        ok = project.space.$organization.id == orgId
                    } else {
                        ok = false
                    }
                } catch {
                    ok = false
                }
                if ok { allowed.append(ch) }
                continue
            }

            if ch.hasPrefix("list:") {
                let idStr = String(ch.dropFirst("list:".count))
                guard let listId = UUID(uuidString: idStr) else { continue }
                var ok = false
                do {
                    let query = TaskListModel.query(on: db)
                        .filter(\.$id == listId)
                        .with(\.$project, { project in
                            project.with(\.$space)
                        })
                    if let list = try await query.first() {
                        ok = list.project.space.$organization.id == orgId
                    }
                } catch {
                    ok = false
                }
                if ok { allowed.append(ch) }
                continue
            }
        }

        return allowed
    }
}
