import Foundation
import Logging

/// Manages token lifecycle: acquire, refresh, and cache access tokens.
public actor TokenManager {
    private let config: OutlookConfig
    private let storage: TokenStorage
    private let deviceCodeFlow: DeviceCodeFlow
    private let logger: Logger

    private var cachedTokens: [String: CachedToken] = [:]

    struct CachedToken {
        let accessToken: String
        let expiresAt: Date
    }

    public init(config: OutlookConfig, storage: TokenStorage) {
        self.config = config
        self.storage = storage
        self.deviceCodeFlow = DeviceCodeFlow(config: config)
        self.logger = Logger(label: "OutlookCLI.TokenManager")
    }

    /// Get a valid access token for the given account, refreshing if needed.
    public func getAccessToken(for accountId: String? = nil) async throws -> String {
        let id = try resolveAccountId(accountId)

        // Check in-memory cache first
        if let cached = cachedTokens[id], cached.expiresAt > Date().addingTimeInterval(300) {
            return cached.accessToken
        }

        // Try to load and use refresh token
        if let refreshToken = try await storage.loadRefreshToken(for: id) {
            do {
                let response = try await deviceCodeFlow.refreshToken(refreshToken)
                try await cacheTokenResponse(response, for: id)
                return response.accessToken
            } catch {
                logger.warning("Token refresh failed for \(id): \(error.localizedDescription)")
            }
        }

        throw AuthError.noRefreshToken
    }

    /// Run the full device code authentication flow.
    public func authenticate(onDeviceCode: @escaping @Sendable (String, String) -> Void) async throws -> String {
        guard !config.clientId.isEmpty else {
            throw AuthError.missingClientId
        }

        let deviceCode = try await deviceCodeFlow.requestDeviceCode()
        onDeviceCode(deviceCode.userCode, deviceCode.verificationUri)

        let token = try await deviceCodeFlow.pollForToken(
            deviceCode: deviceCode.deviceCode,
            interval: deviceCode.interval,
            expiresIn: deviceCode.expiresIn
        )

        // Get user profile to determine account ID
        let profile = try await fetchUserProfile(accessToken: token.accessToken)
        let accountId = profile.email ?? profile.userPrincipalName ?? "unknown"

        // Store tokens
        try await cacheTokenResponse(token, for: accountId)

        // Save account info
        let accountInfo = AccountInfo(
            id: accountId,
            displayName: profile.displayName,
            email: profile.email ?? profile.userPrincipalName,
            tenantId: config.tenantId
        )
        try await storage.saveAccountInfo(accountInfo)

        return accountId
    }

    /// Resolve account ID, falling back to default account.
    private func resolveAccountId(_ accountId: String?) throws -> String {
        if let id = accountId { return id }
        if let envAccount = ProcessInfo.processInfo.environment["OUTLOOK_ACCOUNT"] {
            return envAccount
        }
        // Will need to get from storage in a real implementation
        throw AuthError.noAccount
    }

    private func cacheTokenResponse(_ response: DeviceCodeFlow.TokenResponse, for accountId: String) async throws {
        let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        cachedTokens[accountId] = CachedToken(accessToken: response.accessToken, expiresAt: expiresAt)

        try await storage.saveAccessToken(response.accessToken, for: accountId)
        if let refreshToken = response.refreshToken {
            try await storage.saveRefreshToken(refreshToken, for: accountId)
        }
    }

    private func fetchUserProfile(accessToken: String) async throws -> UserProfile {
        var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }
}

// MARK: - User Profile

struct UserProfile: Codable {
    let displayName: String?
    let mail: String?
    let userPrincipalName: String?

    var email: String? { mail }
}

// MARK: - Account Info

public struct AccountInfo: Codable, Sendable {
    public let id: String
    public let displayName: String?
    public let email: String?
    public let tenantId: String

    public init(id: String, displayName: String?, email: String?, tenantId: String) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.tenantId = tenantId
    }
}
