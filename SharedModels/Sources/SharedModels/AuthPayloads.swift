import Foundation

// MARK: - Authentication Payloads

/// Request payload for user registration.
public struct RegisterRequest: Codable, Sendable {
    public let email: String
    public let password: String
    public let displayName: String

    public init(email: String, password: String, displayName: String) {
        self.email = email
        self.password = password
        self.displayName = displayName
    }
}

/// Request payload for user login.
public struct LoginRequest: Codable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

/// Response payload returned after successful authentication.
public struct AuthResponse: Codable, Sendable {
    public let token: String
    public let user: UserDTO

    public init(token: String, user: UserDTO) {
        self.token = token
        self.user = user
    }
}

/// Response payload for token refresh.
public struct TokenRefreshResponse: Codable, Sendable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}
