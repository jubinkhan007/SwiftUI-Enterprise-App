import Foundation

public protocol AuthServiceProtocol: Sendable {
    func login(email: String, password: String) async throws -> AuthSession
    func register(email: String, password: String, displayName: String) async throws -> AuthSession
}

