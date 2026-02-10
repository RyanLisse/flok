import Foundation

/// Manages token lifecycle: storage, refresh, and providing tokens to GraphClient.
public actor TokenManager: TokenProvider {
    private let storage: KeychainTokenStorage
    private let flow: DeviceCodeFlow
    private let account: String
    private var cachedToken: String?
    private var expiresAt: Date?

    public init(
        clientId: String,
        tenantId: String = "common",
        account: String = "default"
    ) {
        self.storage = KeychainTokenStorage()
        self.flow = DeviceCodeFlow(clientId: clientId, tenantId: tenantId)
        self.account = account
    }

    /// Get a valid access token, refreshing if needed.
    public func accessToken() async throws -> String {
        // Return cached if still valid (with 5-min buffer)
        if let token = cachedToken, let exp = expiresAt, exp > Date().addingTimeInterval(300) {
            return token
        }

        // Try loading from keychain
        if let token = storage.load(key: .accessToken, account: account),
           let expStr = storage.load(key: .expiresAt, account: account),
           let expInterval = TimeInterval(expStr) {
            let exp = Date(timeIntervalSince1970: expInterval)
            if exp > Date().addingTimeInterval(300) {
                cachedToken = token
                expiresAt = exp
                return token
            }
        }

        // Try refresh
        if let refreshToken = storage.load(key: .refreshToken, account: account) {
            do {
                let response = try await flow.refreshToken(refreshToken)
                try saveToken(response)
                return response.accessToken
            } catch {
                // Refresh failed, need re-auth
            }
        }

        throw AuthError.notAuthenticated
    }

    /// Run the interactive device code login flow.
    public func login() async throws -> DeviceCodeResponse {
        return try await flow.requestDeviceCode()
    }

    /// Complete login after user has authenticated in browser.
    public func completeLogin(deviceCode: String, interval: Int) async throws {
        let token = try await flow.pollForToken(deviceCode: deviceCode, interval: interval)
        try saveToken(token)
    }

    /// Clear stored tokens (logout).
    public func logout() {
        storage.deleteAll(account: account)
        cachedToken = nil
        expiresAt = nil
    }

    /// Check if we have stored credentials.
    public var isAuthenticated: Bool {
        storage.load(key: .refreshToken, account: account) != nil
    }

    private func saveToken(_ response: TokenResponse) throws {
        let exp = Date().addingTimeInterval(TimeInterval(response.expiresIn))

        try storage.save(response.accessToken, for: .accessToken, account: account)
        if let refresh = response.refreshToken {
            try storage.save(refresh, for: .refreshToken, account: account)
        }
        try storage.save(String(exp.timeIntervalSince1970), for: .expiresAt, account: account)

        cachedToken = response.accessToken
        expiresAt = exp
    }
}
