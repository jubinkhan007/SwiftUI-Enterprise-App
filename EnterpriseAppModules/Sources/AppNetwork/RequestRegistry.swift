import Foundation

/// Tracks in-flight URLSessionTask references keyed by organization ID.
/// When the active org changes, all tasks for the previous org are cancelled.
public final class RequestRegistry: @unchecked Sendable {
    public static let shared = RequestRegistry()

    private var tasks: [UUID: [URLSessionTask]] = [:]
    private let lock = NSLock()

    private init() {}

    /// Register a URLSessionTask for the given org context.
    public func register(_ task: URLSessionTask, for orgId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        tasks[orgId, default: []].append(task)
    }

    /// Cancel all in-flight requests for a specific org and remove them.
    public func cancelAll(for orgId: UUID) {
        lock.lock()
        let orgTasks = tasks.removeValue(forKey: orgId) ?? []
        lock.unlock()

        for task in orgTasks {
            task.cancel()
        }
    }

    /// Remove completed tasks from tracking (housekeeping).
    public func prune(for orgId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        tasks[orgId]?.removeAll { $0.state == .completed || $0.state == .canceling }
    }

    /// Cancel ALL outstanding requests across all orgs.
    public func cancelAll() {
        lock.lock()
        let allTasks = tasks.values.flatMap { $0 }
        tasks.removeAll()
        lock.unlock()

        for task in allTasks {
            task.cancel()
        }
    }
}
