import Foundation

public extension Notification.Name {
    /// Posted when the API returns a 401 Unauthorized status.
    static let apiUnauthorized = Notification.Name("com.enterprise.api.unauthorized")

    /// Posted when a task is updated (e.g., saved from Task Details) so list/board UIs can update
    /// without a full refresh. Notification `object` is a `TaskItemDTO`.
    static let taskDidUpdate = Notification.Name("com.enterprise.task.didUpdate")
}
