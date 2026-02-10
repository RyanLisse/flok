import Foundation

/// Handles device code authentication flow with Azure AD.
public struct DeviceCodeFlow: Sendable {
    private let clientId: String
    private let tenantId: String
    private let scopes: [String]

    public static let defaultScopes = [
        "Mail.ReadWrite",
        "Calendars.ReadWrite",
        "Contacts.ReadWrite",
        "Files.ReadWrite",
        "User.Read",
        "offline_access",
    ]

    public init(
        clientId: String,
        tenantId: String = "common",
        scopes: [String] = DeviceCodeFlow.defaultScopes
    ) {
        self.clientId = clientId
        self.tenantId = tenantId
        self.scopes = scopes
    }

    /// Request a device code from Azure AD.
    public func requestDeviceCode() async throws -> DeviceCodeResponse {
        let url = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/devicecode")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let scopeString = scopes.joined(separator: " ")
        let body = "client_id=\(clientId)&scope=\(scopeString)"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    /// Poll Azure AD until the user completes authentication.
    public func pollForToken(deviceCode: String, interval: Int) async throws -> TokenResponse {
        let url = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token")!
        let bodyString = "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=\(clientId)&device_code=\(deviceCode)"

        while true {
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyString.data(using: .utf8)

            let (data, _) = try await URLSession.shared.data(for: request)

            // Try to decode as token
            if let token = try? JSONDecoder().decode(TokenResponse.self, from: data) {
                return token
            }

            // Check for error
            if let error = try? JSONDecoder().decode(OAuthError.self, from: data) {
                switch error.error {
                case "authorization_pending":
                    continue
                case "slow_down":
                    try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                    continue
                case "authorization_declined":
                    throw AuthError.declined
                case "expired_token":
                    throw AuthError.expired
                default:
                    throw AuthError.oauthError(error.error, error.errorDescription ?? "Unknown error")
                }
            }
        }
    }

    /// Refresh an expired access token using a refresh token.
    public func refreshToken(_ refreshToken: String) async throws -> TokenResponse {
        let url = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let scopeString = scopes.joined(separator: " ")
        let body = "grant_type=refresh_token&client_id=\(clientId)&refresh_token=\(refreshToken)&scope=\(scopeString)"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
}

// MARK: - Error Types

struct OAuthError: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

public enum AuthError: Error, LocalizedError {
    case declined
    case expired
    case oauthError(String, String)
    case noRefreshToken
    case notAuthenticated

    public var errorDescription: String? {
        switch self {
        case .declined: "Authentication was declined by user"
        case .expired: "Device code expired — please try again"
        case .oauthError(let code, let desc): "OAuth error (\(code)): \(desc)"
        case .noRefreshToken: "No refresh token available — please re-authenticate"
        case .notAuthenticated: "Not authenticated. Run `flok auth login` first."
        }
    }
}
