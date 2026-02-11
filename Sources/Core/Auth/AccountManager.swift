import Foundation

/// Minimal account info for list/switch. ID is the key used in Keychain (e.g. "default" or email).
public struct AccountInfo: Sendable, Codable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

/// Manages multiple authenticated accounts and current-account persistence.
public struct AccountManager: Sendable {
    private let storage: KeychainTokenStorage
    private let currentAccountURL: URL

    public init(storage: KeychainTokenStorage = KeychainTokenStorage(), currentAccountURL: URL? = nil) {
        self.storage = storage
        self.currentAccountURL = currentAccountURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".flok", isDirectory: true)
            .appendingPathComponent("current-account", isDirectory: false)
    }

    /// List all account IDs that have tokens in Keychain.
    public func listAccounts() -> [AccountInfo] {
        storage.listAccountIDs().map { AccountInfo(id: $0) }
    }

    /// Read the persisted current account ID (from ~/.flok/current-account).
    public func getDefaultAccount() -> String? {
        try? String(contentsOf: currentAccountURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    /// Persist the current account ID.
    public func setDefaultAccount(_ accountId: String) throws {
        let dir = currentAccountURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try accountId.write(to: currentAccountURL, atomically: true, encoding: .utf8)
    }

    /// Resolve which account to use: explicit > env FLOK_ACCOUNT > stored default > only account; else throws.
    public func resolveAccount(explicit: String?) throws -> String {
        if let explicit, !explicit.isEmpty { return explicit }
        if let env = ProcessInfo.processInfo.environment["FLOK_ACCOUNT"], !env.isEmpty { return env }
        if let defaultId = getDefaultAccount() { return defaultId }
        let all = storage.listAccountIDs()
        if all.isEmpty { throw AccountError.notAuthenticated }
        if all.count == 1 { return all[0] }
        throw AccountError.multipleAccounts(ids: all)
    }

    /// Remove an account's tokens from Keychain.
    public func removeAccount(_ accountId: String) {
        storage.deleteAll(account: accountId)
    }
}

public enum AccountError: Error, LocalizedError {
    case notAuthenticated
    case multipleAccounts(ids: [String])

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Not authenticated. Run `flok auth login`."
        case .multipleAccounts(let ids): "Multiple accounts (\(ids.joined(separator: ", "))). Set FLOK_ACCOUNT or use `flok switch <account>`."
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
