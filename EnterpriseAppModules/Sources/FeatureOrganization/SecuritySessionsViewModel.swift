import Foundation
import SharedModels
import AppNetwork
import Combine

/// ViewModel for the self-service "Security & Sessions" sheet.
/// Lists the signed-in user's active sessions and lets them revoke any of them.
/// Available to every role — it only ever touches the caller's own sessions.
@MainActor
public final class SecuritySessionsViewModel: ObservableObject {
    @Published public var sessions: [UserSessionDTO] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var revokingIds: Set<UUID> = []
    @Published public var sessionPendingRevoke: UserSessionDTO?

    private let apiClient: APIClientProtocol
    private let configuration: APIConfiguration

    public init(
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .current
    ) {
        self.apiClient = apiClient
        self.configuration = configuration
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let endpoint = SessionEndpoint.listMine(configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[UserSessionDTO]>.self)
            sessions = response.data ?? []
        } catch {
            handle(error)
        }
    }

    /// Revokes a session. Returns `true` on success so the view can show a toast.
    @discardableResult
    public func revoke(_ session: UserSessionDTO) async -> Bool {
        revokingIds.insert(session.id)
        defer { revokingIds.remove(session.id) }

        do {
            let endpoint = SessionEndpoint.revokeMine(sessionId: session.id, configuration: configuration)
            _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
            sessions.removeAll { $0.id == session.id }
            return true
        } catch {
            handle(error)
            return false
        }
    }

    private func handle(_ error: Error) {
        if case NetworkError.unauthorized = error {
            // Most likely the user just revoked the session this device is using.
            TokenStore.shared.clear()
            NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
        } else {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Display helpers

public extension UserSessionDTO {
    /// Human-friendly device/client label derived from the user agent.
    var clientLabel: String {
        let ua = userAgent.lowercased()
        let client: String
        if ua.contains("okhttp") || ua.contains("android") { client = "Android App" }
        else if ua.contains("cfnetwork") || ua.contains("darwin") || ua.contains("enterpriseapp") { client = "iOS App" }
        else if ua.contains("edg/") { client = "Edge" }
        else if ua.contains("chrome") { client = "Chrome" }
        else if ua.contains("firefox") { client = "Firefox" }
        else if ua.contains("safari") { client = "Safari" }
        else if ua.contains("curl") { client = "Command Line" }
        else { client = deviceType.isEmpty ? "Unknown client" : deviceType.capitalized }
        return client
    }

    var deviceSymbol: String {
        let t = (deviceType + " " + userAgent).lowercased()
        if t.contains("ios") || t.contains("iphone") || t.contains("android") || t.contains("mobile") || t.contains("cfnetwork") || t.contains("okhttp") {
            return "iphone"
        }
        if t.contains("ipad") || t.contains("tablet") { return "ipad" }
        return "laptopcomputer"
    }
}

