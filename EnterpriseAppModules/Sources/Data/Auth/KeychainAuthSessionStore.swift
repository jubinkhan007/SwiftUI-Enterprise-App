import Foundation
import Domain
import Network
import Security

public struct KeychainAuthSessionStore: AuthSessionStoreProtocol {
    private let service: String
    private let account: String

    public init(
        service: String = Bundle.main.bundleIdentifier ?? "com.enterprise.enterpriseapp",
        account: String = "auth_session"
    ) {
        self.service = service
        self.account = account
    }

    public func loadSession() -> AuthSession? {
        guard let data = loadData() else { return nil }
        return try? JSONCoding.decoder.decode(AuthSession.self, from: data)
    }

    public func saveSession(_ session: AuthSession) throws {
        let data = try JSONCoding.encoder.encode(session)
        try saveData(data)
    }

    public func clearSession() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Keychain Helpers

    private func loadData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            return nil
        }
    }

    private func saveData(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        var attributesWithAccessibility = attributes
        #if os(iOS) || os(tvOS) || os(watchOS)
        // Keep token available after first unlock; "ThisDeviceOnly" prevents iCloud Keychain sync.
        attributesWithAccessibility[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesWithAccessibility as CFDictionary)
            if updateStatus != errSecSuccess {
                throw KeychainError(status: updateStatus)
            }
        } else {
            var item = query
            attributesWithAccessibility.forEach { item[$0.key] = $0.value }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw KeychainError(status: addStatus)
            }
        }
    }
}

public struct KeychainError: Error, LocalizedError, Sendable, Equatable {
    public let status: OSStatus

    public init(status: OSStatus) {
        self.status = status
    }

    public var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "Keychain error (\(status))."
    }
}
