import Domain

public protocol AuthSessionStoreProtocol: Sendable {
    func loadSession() -> AuthSession?
    func saveSession(_ session: AuthSession) throws
    func clearSession() throws
}

