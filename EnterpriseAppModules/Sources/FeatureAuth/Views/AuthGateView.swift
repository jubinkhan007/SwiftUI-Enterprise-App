import Data
import Domain
import SwiftUI

public struct AuthGateView<AuthenticatedContent: View>: View {
    @StateObject private var authManager: AuthManager
    private let authenticatedContent: (AuthSession, AuthManager) -> AuthenticatedContent

    public init(
        authManager: AuthManager,
        @ViewBuilder authenticatedContent: @escaping (AuthSession, AuthManager) -> AuthenticatedContent
    ) {
        self._authManager = StateObject(wrappedValue: authManager)
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

