import Fluent
import JWT
import SharedModels
import Vapor

/// Handles user registration and login.
struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
    }

    // MARK: - POST /api/auth/register

    @Sendable
    func register(req: Request) async throws -> APIResponse<AuthResponse> {
        req.logger.info("Register request received")
        let payload = try req.content.decode(RegisterRequest.self)
        req.logger.info("Payload decoded for \(payload.email)")

        // Validate input
        guard payload.email.contains("@") else {
            throw Abort(.badRequest, reason: "Invalid email address.")
        }
        guard payload.password.count >= 8 else {
            throw Abort(.badRequest, reason: "Password must be at least 8 characters.")
        }
        guard !payload.displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Display name is required.")
        }

        // Check for existing user
        let existingUser = try await UserModel.query(on: req.db)
            .filter(\.$email == payload.email.lowercased())
            .first()
        guard existingUser == nil else {
            throw Abort(.conflict, reason: "A user with this email already exists.")
        }

        // Create user — cost 4 is very fast even on weak CPUs
        req.logger.info("Beginning password hashing...")
        let passwordHash = try Bcrypt.hash(payload.password, cost: 4)
        req.logger.info("Password hashed successfully")

        let user = UserModel(
            email: payload.email.lowercased(),
            displayName: payload.displayName,
            passwordHash: passwordHash
        )
        try await user.save(on: req.db)

        // Generate token
        let token = try await generateToken(for: user, on: req)

        return .success(AuthResponse(token: token, user: user.toDTO()))
    }

    // MARK: - POST /api/auth/login

    @Sendable
    func login(req: Request) async throws -> APIResponse<AuthResponse> {
        req.logger.info("Login request received")
        let payload = try req.content.decode(LoginRequest.self)
        req.logger.info("Payload decoded for \(payload.email)")

        // Find user
        guard let user = try await UserModel.query(on: req.db)
            .filter(\.$email == payload.email.lowercased())
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }

        // Verify password — cost is embedded in the hash, no need to specify
        req.logger.info("Verifying password...")
        guard try Bcrypt.verify(payload.password, created: user.passwordHash) else {
            req.logger.info("Password verification failed")
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }
        req.logger.info("Password verified successfully")

        // Generate token
        let token = try await generateToken(for: user, on: req)

        return .success(AuthResponse(token: token, user: user.toDTO()))
    }

    // MARK: - Helpers

    private func generateToken(for user: UserModel, on req: Request) async throws -> String {
        guard let userId = user.id else {
            throw Abort(.internalServerError, reason: "User record is missing an id.")
        }
        let payload = JWTAuthPayload(
            subject: .init(value: userId.uuidString),
            expiration: .init(value: Date().addingTimeInterval(60 * 60 * 24 * 7)), // 7 days
            role: user.role.rawValue
        )
        return try req.jwt.sign(payload)
    }
}
