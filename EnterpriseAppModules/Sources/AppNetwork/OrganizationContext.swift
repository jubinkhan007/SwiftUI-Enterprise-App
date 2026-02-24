import Foundation

/// A thread-safe singleton that manages the active organization (workspace) context.
/// Stores the current `orgId` and persists the last-used org for seamless app launches.
public final class OrganizationContext: @unchecked Sendable {
    public static let shared = OrganizationContext()

    private var _orgId: UUID?
    private let lock = NSLock()

    /// UserDefaults key for persisting the last-used org ID.
    private let defaultOrgKey = "com.enterprise.lastOrgId"

    private init() {
        // Restore last-used org from UserDefaults
        if let stored = UserDefaults.standard.string(forKey: defaultOrgKey),
           let uuid = UUID(uuidString: stored) {
            _orgId = uuid
        }
    }

    /// The currently active organization ID.
    public var orgId: UUID? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _orgId
        }
        set {
            lock.lock()
            _orgId = newValue
            lock.unlock()
            // Persist for next launch
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: defaultOrgKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultOrgKey)
            }
        }
    }

    /// Clear the active org context (e.g., on 403 or sign-out).
    public func clear() {
        orgId = nil
    }
}
