import Foundation
import Core

// MARK: - MCP Server Entry Point

/// Flok MCP Server — exposes Microsoft 365 tools via Model Context Protocol.
///
/// Agent-native design:
/// - MCP Resources for context injection (inbox summary, calendar today)
/// - MCP Prompts for composable workflows (triage, schedule, draft)
/// - Raw Graph API escape hatch for unanticipated use
/// - Completion signals in all tool results
/// - Read-only mode support
public struct FlokMCPServer {
    let config: FlokConfig
    let tokenManager: TokenManager
    let graphClient: GraphClient

    public init(config: FlokConfig) {
        self.config = config
        self.tokenManager = TokenManager(
            clientId: config.clientId,
            tenantId: config.tenantId,
            account: config.account
        )
        self.graphClient = GraphClient(
            tokenProvider: tokenManager,
            apiVersion: config.apiVersion
        )
    }
}

// MARK: - Tool Result with Completion Signal

/// Standard tool result with completion signal for agents.
public struct ToolResult: Codable, Sendable {
    public let success: Bool
    public let data: String?
    public let error: String?
    public let nextActions: [String]?

    public static func ok(_ data: String, nextActions: [String] = []) -> ToolResult {
        ToolResult(success: true, data: data, error: nil, nextActions: nextActions.isEmpty ? nil : nextActions)
    }

    public static func fail(_ error: String) -> ToolResult {
        ToolResult(success: false, data: nil, error: error, nextActions: nil)
    }
}
