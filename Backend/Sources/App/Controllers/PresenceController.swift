import Fluent
import SharedModels
import Vapor

/// Phase 3: per-user presence + custom status.
///
/// Presence is computed from `last_heartbeat_at`:
/// - within 60s            -> online (or away if explicitly set)
/// - within 5 minutes      -> away
/// - older / no row        -> offline
struct PresenceController: RouteCollection {
    /// How long a heartbeat keeps a user "online".
    static let onlineWindow: TimeInterval = 60
    /// How long a heartbeat keeps a user "away" after dropping out of the online window.
    static let awayWindow: TimeInterval = 5 * 60

    func boot(routes: any RoutesBuilder) throws {
        let me = routes.grouped("me")
        me.post("presence", "heartbeat", use: heartbeat)
        me.put("status", use: setStatus)
        me.delete("status", use: clearStatus)
        me.get("presence", use: getMyPresence)

        let presence = routes.grouped("presence")
        presence.get(use: getBulkPresence)

        let users = routes.grouped("users")
        users.get(":userID", "presence", use: getUserPresence)
    }

    // MARK: - Heartbeat

    @Sendable
    func heartbeat(req: Request) async throws -> APIResponse<UserPresenceDTO> {
        let ctx = try req.orgContext
        let payload = (try? req.content.decode(PresenceHeartbeatRequest.self)) ?? PresenceHeartbeatRequest()

        let row = try await upsertPresence(userId: ctx.userId, on: req.db) { presence in
            presence.lastHeartbeatAt = Date()
            if let state = payload.state {
                presence.state = state.rawValue
            } else if presence.state == PresenceState.offline.rawValue {
                presence.state = PresenceState.online.rawValue
            }
        }
        return .success(toDTO(row, now: Date()))
    }

    // MARK: - Custom Status

    @Sendable
    func setStatus(req: Request) async throws -> APIResponse<UserPresenceDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(SetCustomStatusRequest.self)

        let emoji = payload.emoji?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = payload.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let emoji, emoji.count > 16 {
            throw Abort(.badRequest, reason: "Emoji too long.")
        }
        if let text, text.count > 200 {
            throw Abort(.badRequest, reason: "Status text must be 200 characters or fewer.")
        }
        if (emoji?.isEmpty ?? true) && (text?.isEmpty ?? true) {
            throw Abort(.badRequest, reason: "Status must include emoji or text.")
        }

        let row = try await upsertPresence(userId: ctx.userId, on: req.db) { presence in
            presence.customStatusEmoji = emoji?.nilIfEmpty
            presence.customStatusText = text?.nilIfEmpty
            presence.customStatusExpiresAt = payload.expiresAt
        }
        return .success(toDTO(row, now: Date()))
    }

    @Sendable
    func clearStatus(req: Request) async throws -> APIResponse<UserPresenceDTO> {
        let ctx = try req.orgContext

        let row = try await upsertPresence(userId: ctx.userId, on: req.db) { presence in
            presence.customStatusEmoji = nil
            presence.customStatusText = nil
            presence.customStatusExpiresAt = nil
        }
        return .success(toDTO(row, now: Date()))
    }

    // MARK: - Read

    @Sendable
    func getMyPresence(req: Request) async throws -> APIResponse<UserPresenceDTO> {
        let ctx = try req.orgContext
        let row = try await fetchOrPlaceholder(userId: ctx.userId, on: req.db)
        return .success(toDTO(row, now: Date()))
    }

    @Sendable
    func getUserPresence(req: Request) async throws -> APIResponse<UserPresenceDTO> {
        _ = try req.orgContext
        let userID = try req.parameters.require("userID", as: UUID.self)
        let row = try await fetchOrPlaceholder(userId: userID, on: req.db)
        return .success(toDTO(row, now: Date()))
    }

    @Sendable
    func getBulkPresence(req: Request) async throws -> APIResponse<BulkPresenceResponse> {
        _ = try req.orgContext

        let raw = (try? req.query.get(String.self, at: "userIds")) ?? ""
        let userIds = raw
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0).trimmingCharacters(in: .whitespaces)) }

        guard !userIds.isEmpty else {
            return .success(BulkPresenceResponse(presences: []))
        }

        let rows = try await UserPresenceModel.query(on: req.db)
            .filter(\.$user.$id ~~ userIds)
            .all()
        let byUser = Dictionary(uniqueKeysWithValues: rows.map { ($0.$user.id, $0) })

        let now = Date()
        let dtos = userIds.map { uid -> UserPresenceDTO in
            if let row = byUser[uid] {
                return toDTO(row, now: now)
            }
            return UserPresenceDTO(userId: uid, state: .offline)
        }
        return .success(BulkPresenceResponse(presences: dtos))
    }

    // MARK: - Helpers

    private func upsertPresence(
        userId: UUID,
        on db: Database,
        mutate: (UserPresenceModel) -> Void
    ) async throws -> UserPresenceModel {
        if let existing = try await UserPresenceModel.query(on: db)
            .filter(\.$user.$id == userId)
            .first() {
            mutate(existing)
            try await existing.save(on: db)
            return existing
        }
        let row = UserPresenceModel(userId: userId, state: PresenceState.online.rawValue)
        mutate(row)
        try await row.save(on: db)
        return row
    }

    private func fetchOrPlaceholder(userId: UUID, on db: Database) async throws -> UserPresenceModel {
        if let existing = try await UserPresenceModel.query(on: db)
            .filter(\.$user.$id == userId)
            .first() {
            return existing
        }
        // Don't persist a placeholder — return a transient row so the DTO conversion works.
        return UserPresenceModel(userId: userId, state: PresenceState.offline.rawValue)
    }

    private func toDTO(_ row: UserPresenceModel, now: Date) -> UserPresenceDTO {
        let effectiveState = computeEffectiveState(row: row, now: now)
        let customExpired: Bool = {
            guard let expiresAt = row.customStatusExpiresAt else { return false }
            return expiresAt < now
        }()
        return UserPresenceDTO(
            userId: row.$user.id,
            state: effectiveState,
            customStatusEmoji: customExpired ? nil : row.customStatusEmoji,
            customStatusText: customExpired ? nil : row.customStatusText,
            customStatusExpiresAt: customExpired ? nil : row.customStatusExpiresAt,
            lastHeartbeatAt: row.lastHeartbeatAt
        )
    }

    private func computeEffectiveState(row: UserPresenceModel, now: Date) -> PresenceState {
        guard let lastHeartbeat = row.lastHeartbeatAt else {
            return .offline
        }
        let age = now.timeIntervalSince(lastHeartbeat)
        if age > Self.awayWindow {
            return .offline
        }
        // Respect explicit "away" set by the user.
        if row.state == PresenceState.away.rawValue {
            return .away
        }
        if age > Self.onlineWindow {
            return .away
        }
        return .online
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
