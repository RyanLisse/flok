import Foundation

/// Output format for CLI commands
public enum OutputFormat: String, Sendable {
    case text
    case json

    /// Global output format, set by main.swift
    @MainActor
    public static var current: OutputFormat = .text
}

/// Configuration with priority: CLI args > env vars > defaults.
public struct FlokConfig: Sendable {
    public let clientId: String
    public let tenantId: String
    public let account: String
    public let readOnly: Bool
    public let apiVersion: String

    public init(
        clientId: String? = nil,
        tenantId: String? = nil,
        account: String? = nil,
        readOnly: Bool = false,
        apiVersion: String? = nil
    ) {
        self.clientId = clientId
            ?? ProcessInfo.processInfo.environment["PIGEON_CLIENT_ID"]
            ?? ""
        self.tenantId = tenantId
            ?? ProcessInfo.processInfo.environment["PIGEON_TENANT_ID"]
            ?? "common"
        self.account = account
            ?? ProcessInfo.processInfo.environment["PIGEON_ACCOUNT"]
            ?? "default"
        self.readOnly = readOnly
            || ProcessInfo.processInfo.environment["PIGEON_READ_ONLY"] == "true"
        self.apiVersion = apiVersion
            ?? ProcessInfo.processInfo.environment["PIGEON_API_VERSION"]
            ?? "v1.0"
    }
}
