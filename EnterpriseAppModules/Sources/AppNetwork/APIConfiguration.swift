import Foundation

public struct APIConfiguration: Sendable, Equatable {
    public var baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
}

public extension APIConfiguration {
    static var localVapor: APIConfiguration {
        // Use 127.0.0.1 to avoid any IPv6/IPv4 ambiguity with "localhost".
        APIConfiguration(baseURL: URL(string: "http://127.0.0.1:8080")!)
    }
}
