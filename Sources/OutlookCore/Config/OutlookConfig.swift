import Foundation

/// Central configuration for the OutlookCLI application.
public struct OutlookConfig: Sendable {
    public let clientId: String
    public let tenantId: String
    public let scopes: [String]
    public let readOnly: Bool

    public static let defaultScopes = [
        "Mail.ReadWrite",
        "Calendars.ReadWrite",
        "Contacts.ReadWrite",
        "Files.ReadWrite",
        "People.Read",
        "User.Read",
        "offline_access",
    ]

    public static let keychainService = "com.outlookcli.auth"

    public init(
        clientId: String? = nil,
        tenantId: String? = nil,
        scopes: [String]? = nil,
        readOnly: Bool = false
    ) {
        self.clientId = clientId
            ?? ProcessInfo.processInfo.environment["OUTLOOK_CLIENT_ID"]
            ?? ""
        self.tenantId = tenantId
            ?? ProcessInfo.processInfo.environment["OUTLOOK_TENANT_ID"]
            ?? "common"
        self.scopes = scopes ?? Self.defaultScopes
        self.readOnly = readOnly
            || (ProcessInfo.processInfo.environment["OUTLOOK_READ_ONLY"]?.lowercased() == "true")
    }

    public var authorizeURL: URL {
        URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/devicecode")!
    }

    public var tokenURL: URL {
        URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token")!
    }
}

/// Output format options.
public enum OutputFormat: String, Sendable, CaseIterable {
    case table
    case json
    case compact

    public static var `default`: OutputFormat {
        if let env = ProcessInfo.processInfo.environment["OUTLOOK_FORMAT"],
           let format = OutputFormat(rawValue: env.lowercased()) {
            return format
        }
        return .table
    }
}
