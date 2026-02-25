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
        if let restoredSession = restored, !Self.isTokenExpired(restoredSession.token) {
            self.session = restoredSession
            TokenStore.shared.token = restoredSession.token
        } else if restored != nil {
            // Token is expired — clear keychain so user goes straight to login
            try? sessionStore.clearSession()
            self.session = nil
        }

        // Force logout on 401
        NotificationCenter.default.addObserver(forName: .apiUnauthorized, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.signOut() }
        }
    }

    /// Decode the JWT payload (no verification) and check the `exp` claim.
    private static func isTokenExpired(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return true }

        var base64 = String(parts[1])
        // Pad to a multiple of 4 for standard base64 decoding
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        // base64url → base64
        base64 = base64.replacingOccurrences(of: "-", with: "+")
                       .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else { return true }

        return Date().timeIntervalSince1970 >= exp
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

