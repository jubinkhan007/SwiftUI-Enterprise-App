import AppData
import Domain
import AppNetwork
import SwiftUI

public struct AuthGateView<AuthenticatedContent: View>: View {
    @StateObject private var authManager: AppData.AuthManager
    private let authenticatedContent: (Domain.AuthSession, AppData.AuthManager) -> AuthenticatedContent

    public init(
        authManager: AppData.AuthManager,
        authenticatedContent: @escaping (Domain.AuthSession, AppData.AuthManager) -> AuthenticatedContent
    ) {
        self._authManager = StateObject(wrappedValue: authManager)
        self.authenticatedContent = authenticatedContent
    }

    public init(
        configuration: AppNetwork.APIConfiguration = .localVapor,
        authenticatedContent: @escaping (Domain.AuthSession, AppData.AuthManager) -> AuthenticatedContent
    ) {
        let service = AppData.LiveAuthService.mappedErrors(configuration: configuration)
        self._authManager = StateObject(wrappedValue: AppData.AuthManager(authService: service))
        self.authenticatedContent = authenticatedContent
    }

    public var body: some View {
        Group {
            if let session = authManager.session {
                authenticatedContent(session, authManager)
            } else {
                AuthFlowView(authManager: authManager)
            }
        }
    }
}

