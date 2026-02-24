import Foundation

/// A lightweight, thread-safe static store for the current auth token.
/// The auth layer writes to this after login, and API endpoints read from it.
public final class TokenStore: @unchecked Sendable {
    public static let shared = TokenStore()
    
    private var _token: String?
    private let lock = NSLock()
    
    private init() {}
    
    public var token: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _token
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _token = newValue
        }
    }
    
    public func clear() {
        token = nil
    }
}
