import Foundation

/// Protocol for token storage backends.
public protocol TokenStorage: Sendable {
    func saveAccessToken(_ token: String, for accountId: String) async throws
    func loadAccessToken(for accountId: String) async throws -> String?
    func saveRefreshToken(_ token: String, for accountId: String) async throws
    func loadRefreshToken(for accountId: String) async throws -> String?
    func saveAccountInfo(_ info: AccountInfo) async throws
    func loadAccountInfo(for accountId: String) async throws -> AccountInfo?
    func listAccounts() async throws -> [AccountInfo]
    func deleteAccount(_ accountId: String) async throws
    func loadDefaultAccount() async throws -> String?
    func setDefaultAccount(_ accountId: String) async throws
}

#if canImport(Security)
import Security

/// macOS Keychain-based token storage.
public final class KeychainTokenStorage: TokenStorage, @unchecked Sendable {
    private let service: String

    public init(service: String = OutlookConfig.keychainService) {
        self.service = service
    }

    public func saveAccessToken(_ token: String, for accountId: String) async throws {
        try save(key: "\(accountId).access_token", value: token)
    }

    public func loadAccessToken(for accountId: String) async throws -> String? {
        return load(key: "\(accountId).access_token")
    }

    public func saveRefreshToken(_ token: String, for accountId: String) async throws {
        try save(key: "\(accountId).refresh_token", value: token)
    }

    public func loadRefreshToken(for accountId: String) async throws -> String? {
        return load(key: "\(accountId).refresh_token")
    }

    public func saveAccountInfo(_ info: AccountInfo) async throws {
        let data = try JSONEncoder().encode(info)
        guard let json = String(data: data, encoding: .utf8) else { return }
        try save(key: "\(info.id).account_info", value: json)
    }

    public func loadAccountInfo(for accountId: String) async throws -> AccountInfo? {
        guard let json = load(key: "\(accountId).account_info"),
              let data = json.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(AccountInfo.self, from: data)
    }

    public func listAccounts() async throws -> [AccountInfo] {
        let allKeys = listKeys()
        var accounts: [AccountInfo] = []
        for key in allKeys where key.hasSuffix(".account_info") {
            if let json = load(key: key),
               let data = json.data(using: .utf8),
               let info = try? JSONDecoder().decode(AccountInfo.self, from: data) {
                accounts.append(info)
            }
        }
        return accounts
    }

    public func deleteAccount(_ accountId: String) async throws {
        delete(key: "\(accountId).access_token")
        delete(key: "\(accountId).refresh_token")
        delete(key: "\(accountId).account_info")
    }

    public func loadDefaultAccount() async throws -> String? {
        return load(key: "default_account")
    }

    public func setDefaultAccount(_ accountId: String) async throws {
        try save(key: "default_account", value: accountId)
    }

    // MARK: - Keychain Operations

    private func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key) // Remove existing before save

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StorageError.keychainError(status)
        }
    }

    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func listKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}
#endif

/// File-based fallback token storage for non-macOS platforms.
public actor FileTokenStorage: TokenStorage {
    private let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".outlookcli")
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func filePath(for key: String) -> URL {
        directory.appendingPathComponent(key)
    }

    public func saveAccessToken(_ token: String, for accountId: String) async throws {
        try ensureDirectory()
        try token.write(to: filePath(for: "\(accountId).access_token"), atomically: true, encoding: .utf8)
    }

    public func loadAccessToken(for accountId: String) async throws -> String? {
        try? String(contentsOf: filePath(for: "\(accountId).access_token"), encoding: .utf8)
    }

    public func saveRefreshToken(_ token: String, for accountId: String) async throws {
        try ensureDirectory()
        try token.write(to: filePath(for: "\(accountId).refresh_token"), atomically: true, encoding: .utf8)
    }

    public func loadRefreshToken(for accountId: String) async throws -> String? {
        try? String(contentsOf: filePath(for: "\(accountId).refresh_token"), encoding: .utf8)
    }

    public func saveAccountInfo(_ info: AccountInfo) async throws {
        try ensureDirectory()
        let data = try JSONEncoder().encode(info)
        try data.write(to: filePath(for: "\(info.id).account_info"))
    }

    public func loadAccountInfo(for accountId: String) async throws -> AccountInfo? {
        guard let data = try? Data(contentsOf: filePath(for: "\(accountId).account_info")) else { return nil }
        return try JSONDecoder().decode(AccountInfo.self, from: data)
    }

    public func listAccounts() async throws -> [AccountInfo] {
        try ensureDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var accounts: [AccountInfo] = []
        for file in files where file.lastPathComponent.hasSuffix(".account_info") {
            if let data = try? Data(contentsOf: file),
               let info = try? JSONDecoder().decode(AccountInfo.self, from: data) {
                accounts.append(info)
            }
        }
        return accounts
    }

    public func deleteAccount(_ accountId: String) async throws {
        let fm = FileManager.default
        for suffix in ["access_token", "refresh_token", "account_info"] {
            let path = filePath(for: "\(accountId).\(suffix)")
            try? fm.removeItem(at: path)
        }
    }

    public func loadDefaultAccount() async throws -> String? {
        try? String(contentsOf: filePath(for: "default_account"), encoding: .utf8)
    }

    public func setDefaultAccount(_ accountId: String) async throws {
        try ensureDirectory()
        try accountId.write(to: filePath(for: "default_account"), atomically: true, encoding: .utf8)
    }
}

// MARK: - Storage Error

public enum StorageError: Error, LocalizedError {
    case keychainError(Int32)
    case fileError(String)

    public var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain error (status: \(status))"
        case .fileError(let msg):
            return "File storage error: \(msg)"
        }
    }
}
