import Foundation
import Logging

/// OAuth2 Device Code Flow for Microsoft identity platform.
public actor DeviceCodeFlow {
    private let config: OutlookConfig
    private let session: URLSession
    private let logger: Logger

    public struct DeviceCodeResponse: Codable, Sendable {
        public let deviceCode: String
        public let userCode: String
        public let verificationUri: String
        public let expiresIn: Int
        public let interval: Int
        public let message: String

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationUri = "verification_uri"
            case expiresIn = "expires_in"
            case interval
            case message
        }
    }

    public struct TokenResponse: Codable, Sendable {
        public let accessToken: String
        public let refreshToken: String?
        public let expiresIn: Int
        public let tokenType: String
        public let scope: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case tokenType = "token_type"
            case scope
        }
    }

    struct ErrorResponse: Codable {
        let error: String
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
        }
    }

    public init(config: OutlookConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.logger = Logger(label: "OutlookCLI.DeviceCodeFlow")
    }

    /// Step 1: Request a device code from Azure AD.
    public func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: config.authorizeURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(config.clientId)&scope=\(config.scopes.joined(separator: " "))"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AuthError.authorizationFailed(errorResponse.errorDescription ?? errorResponse.error)
            }
            throw AuthError.authorizationFailed("HTTP \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    /// Step 2: Poll for the token after user completes authentication.
    public func pollForToken(deviceCode: String, interval: Int, expiresIn: Int) async throws -> TokenResponse {
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
        let pollInterval = max(interval, 5) // Minimum 5 seconds per Microsoft docs

        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)

            do {
                let token = try await requestToken(deviceCode: deviceCode)
                return token
            } catch AuthError.authorizationPending {
                logger.debug("Authorization pending, polling again...")
                continue
            } catch AuthError.slowDown {
                logger.debug("Slow down request, increasing interval...")
                try await Task.sleep(nanoseconds: 5_000_000_000)
                continue
            }
        }

        throw AuthError.expired
    }

    /// Exchange device code for tokens.
    private func requestToken(deviceCode: String) async throws -> TokenResponse {
        var request = URLRequest(url: config.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=urn:ietf:params:oauth:grant-type:device_code",
            "client_id=\(config.clientId)",
            "device_code=\(deviceCode)",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        }

        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            switch errorResponse.error {
            case "authorization_pending":
                throw AuthError.authorizationPending
            case "slow_down":
                throw AuthError.slowDown
            case "authorization_declined":
                throw AuthError.declined
            case "expired_token":
                throw AuthError.expired
            default:
                throw AuthError.authorizationFailed(errorResponse.errorDescription ?? errorResponse.error)
            }
        }

        throw AuthError.authorizationFailed("HTTP \(httpResponse.statusCode)")
    }

    /// Refresh an existing token using a refresh token.
    public func refreshToken(_ refreshToken: String) async throws -> TokenResponse {
        var request = URLRequest(url: config.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=refresh_token",
            "client_id=\(config.clientId)",
            "refresh_token=\(refreshToken)",
            "scope=\(config.scopes.joined(separator: " "))",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AuthError.refreshFailed(errorResponse.errorDescription ?? errorResponse.error)
            }
            throw AuthError.refreshFailed("HTTP \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
}

// MARK: - Auth Errors

public enum AuthError: Error, LocalizedError {
    case authorizationPending
    case slowDown
    case declined
    case expired
    case authorizationFailed(String)
    case refreshFailed(String)
    case networkError(String)
    case noAccount
    case noRefreshToken
    case missingClientId

    public var errorDescription: String? {
        switch self {
        case .authorizationPending:
            return "Authorization pending — waiting for user"
        case .slowDown:
            return "Polling too fast — slowing down"
        case .declined:
            return "Authorization was declined by the user"
        case .expired:
            return "Device code expired — please try again"
        case .authorizationFailed(let msg):
            return "Authorization failed: \(msg)"
        case .refreshFailed(let msg):
            return "Token refresh failed: \(msg)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .noAccount:
            return "No account found. Run 'outlook auth login' to authenticate."
        case .noRefreshToken:
            return "No refresh token available. Run 'outlook auth login' to re-authenticate."
        case .missingClientId:
            return "No client ID configured. Set OUTLOOK_CLIENT_ID environment variable."
        }
    }
}
