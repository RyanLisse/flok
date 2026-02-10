import Foundation
import Security

/// Stores and retrieves tokens from the macOS Keychain.
public struct KeychainTokenStorage: Sendable {
    private static let service = "dev.flok.tokens"

    public enum Key: String, Sendable {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case account = "account_id"
    }

    public init() {}

    public func save(_ value: String, for key: Key, account: String = "default") throws {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: "\(account).\(key.rawValue)",
            kSecValueData as String: data,
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    public func load(key: Key, account: String = "default") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: "\(account).\(key.rawValue)",
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    public func delete(key: Key, account: String = "default") {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: "\(account).\(key.rawValue)",
        ]
        SecItemDelete(query as CFDictionary)
    }

    public func deleteAll(account: String = "default") {
        for key in [Key.accessToken, .refreshToken, .expiresAt, .account] {
            delete(key: key, account: account)
        }
    }
}

public enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            "Keychain save failed with status \(status)"
        }
    }
}
