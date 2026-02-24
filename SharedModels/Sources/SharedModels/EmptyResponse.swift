import Foundation

/// A placeholder response structure for API endpoints that don't return a data body (e.g. 204 No Content).
public struct EmptyResponse: Codable, Sendable {
    public init() {}
}
