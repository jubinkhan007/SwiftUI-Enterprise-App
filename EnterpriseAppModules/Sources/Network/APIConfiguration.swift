import Foundation

public struct APIConfiguration: Sendable, Equatable {
    public var baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
}

public extension APIConfiguration {
    static var localVapor: APIConfiguration {
        APIConfiguration(baseURL: URL(string: "http://localhost:8080")!)
    }
}

