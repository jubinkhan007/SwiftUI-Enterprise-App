import Foundation

public struct APIConfiguration: Sendable, Equatable {
    public var baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
}

public extension APIConfiguration {
    /// Production server — your live Contabo VPS behind Nginx + SSL.
    static var production: APIConfiguration {
        APIConfiguration(baseURL: URL(string: "https://enterpriseapp.chickenkiller.com")!)
    }

    /// Local Vapor dev server (Simulator only).
    static var localVapor: APIConfiguration {
        if let override = ProcessInfo.processInfo.environment["ENTERPRISE_API_BASE_URL"],
           let url = URL(string: override) {
            return APIConfiguration(baseURL: url)
        }
        return APIConfiguration(baseURL: URL(string: "http://127.0.0.1:8080")!)
    }

    /// Uses local Vapor server in Simulator/DEBUG, production otherwise.
    static var current: APIConfiguration {
        #if DEBUG
        // In the simulator TARGET_OS_SIMULATOR is 1; on a real device use production.
        #if targetEnvironment(simulator)
        return .localVapor
        #else
        return .production
        #endif
        #else
        return .production
        #endif
    }
}
