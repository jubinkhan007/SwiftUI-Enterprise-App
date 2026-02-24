import Domain
import Foundation
import AppNetwork

@MainActor
public final class AuthManager: ObservableObject {
    @Published public private(set) var session: AuthSession?
    @Published public private(set) var isSubmitting = false

    private let authService: AuthServiceProtocol
    private let sessionStore: AuthSessionStoreProtocol

    public init(
        authService: AuthServiceProtocol,
        sessionStore: AuthSessionStoreProtocol = KeychainAuthSessionStore()
    ) {
        self.authService = authService
        self.sessionStore = sessionStore
        let restored = sessionStore.loadSession()
        self.session = restored
        TokenStore.shared.token = restored?.token
    }

    public func signIn(email: String, password: String) async throws {
        isSubmitting = true
        defer { isSubmitting = false }

        let newSession = try await authService.login(email: email, password: password)
        try sessionStore.saveSession(newSession)
        session = newSession
        TokenStore.shared.token = newSession.token
    }

    public func register(email: String, password: String, displayName: String) async throws {
        isSubmitting = true
        defer { isSubmitting = false }

        let newSession = try await authService.register(email: email, password: password, displayName: displayName)
        try sessionStore.saveSession(newSession)
        session = newSession
        TokenStore.shared.token = newSession.token
    }

    public func signOut() {
        try? sessionStore.clearSession()
        session = nil
        TokenStore.shared.clear()
    }
}

