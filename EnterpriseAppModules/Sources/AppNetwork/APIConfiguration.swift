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

    /// Applies the production server setting to all environments.
    static var current: APIConfiguration {
        return .production
    }
}
