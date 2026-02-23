import Domain
import Foundation
import Network
import SharedModels

public struct LiveAuthService: AuthServiceProtocol {
    private let apiClient: APIClientProtocol
    private let configuration: APIConfiguration

    public init(
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .localVapor
    ) {
        self.apiClient = apiClient
        self.configuration = configuration
    }

    public func login(email: String, password: String) async throws -> AuthSession {
        let payload = LoginRequest(email: email, password: password)
        let endpoint = AuthEndpoint.login(payload, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<AuthResponse>.self)
        return try mapAuthResponse(response)
    }

    public func register(email: String, password: String, displayName: String) async throws -> AuthSession {
        let payload = RegisterRequest(email: email, password: password, displayName: displayName)
        let endpoint = AuthEndpoint.register(payload, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<AuthResponse>.self)
        return try mapAuthResponse(response)
    }

    private func mapAuthResponse(_ response: APIResponse<AuthResponse>) throws -> AuthSession {
        guard response.success, let data = response.data else {
            if let apiError = response.error {
                throw AuthError.server(apiError.message)
            }
            throw AuthError.unknown
        }
        return AuthSession(token: data.token, user: data.user)
    }
}

public extension LiveAuthService {
    static func mappedErrors(
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .localVapor
    ) -> AuthServiceProtocol {
        MappedAuthService(base: LiveAuthService(apiClient: apiClient, configuration: configuration))
    }
}

private struct MappedAuthService: AuthServiceProtocol {
    let base: LiveAuthService

    func login(email: String, password: String) async throws -> AuthSession {
        do {
            return try await base.login(email: email, password: password)
        } catch {
            throw map(error)
        }
    }

    func register(email: String, password: String, displayName: String) async throws -> AuthSession {
        do {
            return try await base.register(email: email, password: password, displayName: displayName)
        } catch {
            throw map(error)
        }
    }

    private func map(_ error: Error) -> AuthError {
        if let authError = error as? AuthError { return authError }

        switch error {
        case NetworkError.offline:
            return .offline

        case NetworkError.unauthorized:
            return .invalidCredentials

        case NetworkError.serverError(let statusCode, let message):
            if statusCode == 400, let message, !message.isEmpty { return .invalidInput(message) }
            if statusCode == 409 { return .emailAlreadyInUse }
            if let message, !message.isEmpty { return .server(message) }
            return .unknown

        case NetworkError.decodingFailed:
            return .unknown

        default:
            return .unknown
        }
    }
}
