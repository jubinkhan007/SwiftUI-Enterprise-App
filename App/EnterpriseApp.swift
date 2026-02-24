import SwiftUI
import FeatureAuth
import AppNetwork
import AppData
import Domain

@main
struct EnterpriseApp: App {
    var body: some Scene {
        WindowGroup {
            AuthGateView(configuration: AppNetwork.APIConfiguration.localVapor) { session, manager in
                // Temporary Dashboard Placeholder
                NavigationView {
                    VStack {
                        Text("Welcome, \(session.user.displayName)")
                            .font(.title)
                        Button("Sign Out") {
                            manager.signOut()
                        }
                        .padding()
                    }
                    .navigationTitle("Dashboard")
                }
            }
        }
    }
}
