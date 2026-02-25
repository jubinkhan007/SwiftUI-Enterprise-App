import AppData
import Domain
import AppNetwork
import SwiftUI

public struct AuthGateView<AuthenticatedContent: View>: View {
    @ObservedObject private var authManager: AppData.AuthManager
    private let authenticatedContent: (Domain.AuthSession, AppData.AuthManager) -> AuthenticatedContent

    public init(
        authManager: AppData.AuthManager,
        authenticatedContent: @escaping (Domain.AuthSession, AppData.AuthManager) -> AuthenticatedContent
    ) {
        self._authManager = ObservedObject(wrappedValue: authManager)
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
#if DEBUG
        .onChange(of: authManager.session?.token) { _, newValue in
            print("AuthGateView sessionChanged hasSession=\(newValue != nil)")
        }
#endif
    }
}
