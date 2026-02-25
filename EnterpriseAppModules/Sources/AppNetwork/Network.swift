import Foundation

public extension Notification.Name {
    /// Posted when the API returns a 401 Unauthorized status.
    static let apiUnauthorized = Notification.Name("com.enterprise.api.unauthorized")
}
