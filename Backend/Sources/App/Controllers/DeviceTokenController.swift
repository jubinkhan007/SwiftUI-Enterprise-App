import Fluent
import Vapor
import SharedModels

extension DeviceTokenDTO: Content {}
extension PushNotificationPayload: Content {}
extension RegisterDeviceTokenRequest: Content {}

struct DeviceTokenController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let me = routes.grouped("me", "device-tokens")

        me.post(use: register)
        me.get(use: list)
        me.delete(":token", use: unregister)
        me.post("test", use: sendTestPush)
    }

    // MARK: - POST /api/me/device-tokens
    @Sendable
    func register(req: Request) async throws -> APIResponse<DeviceTokenDTO> {
        let auth = try req.authContext
        let userId = auth.userId
        let payload = try req.content.decode(RegisterDeviceTokenRequest.self)

        guard !payload.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Device token cannot be empty.")
        }

        // Check if token already exists
        let existing = try await DeviceTokenModel.query(on: req.db)
            .filter(\.$token == payload.token)
            .first()

        let device: DeviceTokenModel
        if let existing = existing {
            existing.$user.id = userId
            existing.platform = payload.platform
            existing.environment = payload.environment
            try await existing.save(on: req.db)
            device = existing
        } else {
            device = DeviceTokenModel(
                userId: userId,
                token: payload.token,
                platform: payload.platform,
                environment: payload.environment
            )
            try await device.save(on: req.db)
        }

        req.logger.info("Registered device token for user \(userId) [\(payload.platform)]")
        return .success(try device.toDTO())
    }

    // MARK: - GET /api/me/device-tokens
    @Sendable
    func list(req: Request) async throws -> APIResponse<[DeviceTokenDTO]> {
        let auth = try req.authContext
        let userId = auth.userId

        let tokens = try await DeviceTokenModel.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()

        let dtos = try tokens.map { try $0.toDTO() }
        return .success(dtos)
    }

    // MARK: - DELETE /api/me/device-tokens/:token
    @Sendable
    func unregister(req: Request) async throws -> APIResponse<EmptyResponse> {
        let auth = try req.authContext
        let userId = auth.userId
        guard let token = req.parameters.get("token") else {
            throw Abort(.badRequest, reason: "Token parameter is missing.")
        }

        try await DeviceTokenModel.query(on: req.db)
            .filter(\.$user.$id == userId)
            .filter(\.$token == token)
            .delete()

        req.logger.info("Unregistered device token for user \(userId)")
        return .success(EmptyResponse())
    }

    // MARK: - POST /api/me/device-tokens/test
    @Sendable
    func sendTestPush(req: Request) async throws -> APIResponse<PushNotificationPayload> {
        let auth = try req.authContext
        let userId = auth.userId

        struct TestPushRequest: Content {
            let entityType: String?
            let entityId: String?
            let title: String?
            let body: String?
        }

        let input = (try? req.content.decode(TestPushRequest.self))
        let entityType = input?.entityType ?? "task"
        let entityId = input?.entityId ?? UUID().uuidString
        let title = input?.title ?? "Taskflow Test Alert"
        let body = input?.body ?? "Tap to open the linked entity via universal deep link."

        let deepLink = PushNotificationService.buildDeepLink(for: entityType, entityId: entityId)
        await PushNotificationService.dispatch(
            to: userId,
            title: title,
            body: body,
            entityType: entityType,
            entityId: entityId,
            on: req.db,
            logger: req.logger
        )

        let payload = PushNotificationPayload(
            title: title,
            body: body,
            deepLink: deepLink,
            entityType: entityType,
            entityId: entityId
        )
        return .success(payload)
    }
}
