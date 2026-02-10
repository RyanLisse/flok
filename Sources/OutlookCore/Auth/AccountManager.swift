import Foundation

/// Manages multiple authenticated accounts.
public actor AccountManager {
    private let storage: TokenStorage
    private var defaultAccountId: String?

    public init(storage: TokenStorage) {
        self.storage = storage
    }

    /// Get the default account ID.
    public func getDefaultAccount() async throws -> String {
        if let cached = defaultAccountId {
            return cached
        }

        if let stored = try await storage.loadDefaultAccount() {
            defaultAccountId = stored
            return stored
        }

        // Fall back to first available account
        let accounts = try await storage.listAccounts()
        guard let first = accounts.first else {
            throw AuthError.noAccount
        }
        defaultAccountId = first.id
        return first.id
    }

    /// Set the default account.
    public func setDefaultAccount(_ accountId: String) async throws {
        let accounts = try await storage.listAccounts()
        guard accounts.contains(where: { $0.id == accountId }) else {
            throw AuthError.noAccount
        }
        try await storage.setDefaultAccount(accountId)
        defaultAccountId = accountId
    }

    /// List all authenticated accounts.
    public func listAccounts() async throws -> [AccountInfo] {
        try await storage.listAccounts()
    }

    /// Get account info.
    public func getAccountInfo(_ accountId: String) async throws -> AccountInfo? {
        try await storage.loadAccountInfo(for: accountId)
    }

    /// Remove an account and its tokens.
    public func removeAccount(_ accountId: String) async throws {
        try await storage.deleteAccount(accountId)
        if defaultAccountId == accountId {
            defaultAccountId = nil
            let accounts = try await storage.listAccounts()
            if let first = accounts.first {
                try await storage.setDefaultAccount(first.id)
                defaultAccountId = first.id
            }
        }
    }
}
