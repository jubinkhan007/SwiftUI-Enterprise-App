import Domain
import Foundation

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
        self.session = sessionStore.loadSession()
    }

    public func signIn(email: String, password: String) async throws {
        isSubmitting = true
        defer { isSubmitting = false }

        let newSession = try await authService.login(email: email, password: password)
        try sessionStore.saveSession(newSession)
        session = newSession
    }

    public func register(email: String, password: String, displayName: String) async throws {
        isSubmitting = true
        defer { isSubmitting = false }

        let newSession = try await authService.register(email: email, password: password, displayName: displayName)
        try sessionStore.saveSession(newSession)
        session = newSession
    }

    public func signOut() {
        try? sessionStore.clearSession()
        session = nil
    }
}

