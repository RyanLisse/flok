import Foundation
import Core
import CLI

// MARK: - Flok Entry Point

/// Usage:
///   flok auth login          — Authenticate with Microsoft
///   flok auth logout         — Clear stored tokens
///   flok auth status         — Check auth status
///   flok mail list           — List inbox messages
///   flok serve               — Start MCP server (stdio)
///
/// Environment:
///   PIGEON_CLIENT_ID     — Azure AD app client ID (required)
///   PIGEON_TENANT_ID     — Azure AD tenant (default: common)
///   PIGEON_READ_ONLY     — Disable write operations (default: false)
///   PIGEON_ACCOUNT       — Account name for multi-account (default: default)

@main
struct Flok {
    static func main() async throws {
        let args = CommandLine.arguments.dropFirst()
        let config = FlokConfig()

        guard !config.clientId.isEmpty else {
            print("Error: PIGEON_CLIENT_ID is required.")
            print("Set it via environment variable or register an Azure AD app.")
            print("See: https://github.com/RyanLisse/Flok#setup")
            Foundation.exit(1)
        }

        guard let command = args.first else {
            printUsage()
            return
        }

        switch command {
        case "auth":
            let sub = args.dropFirst().first ?? "status"
            switch sub {
            case "login":
                try await AuthLoginCommand.run(clientId: config.clientId, tenantId: config.tenantId)
            case "logout":
                await AuthLogoutCommand.run(clientId: config.clientId, tenantId: config.tenantId)
            case "status":
                await AuthStatusCommand.run(clientId: config.clientId, tenantId: config.tenantId)
            default:
                print("Unknown auth command: \(sub)")
            }

        case "mail":
            let sub = args.dropFirst().first ?? "list"
            switch sub {
            case "list":
                try await MailListCommand.run(config: config, folder: "inbox", count: 25)
            default:
                print("Unknown mail command: \(sub)")
            }

        case "serve":
            try await ServeCommand.run(config: config)

        case "help", "--help", "-h":
            printUsage()

        case "version", "--version":
            print("Flok 0.1.0")

        default:
            print("Unknown command: \(command)")
            printUsage()
        }
    }

    static func printUsage() {
        print("""
        🐦 Flok — Microsoft 365 CLI + MCP Server

        USAGE:
          flok <command> [subcommand] [options]

        COMMANDS:
          auth login        Authenticate with Microsoft (device code flow)
          auth logout       Clear stored tokens
          auth status       Check authentication status
          mail list         List inbox messages
          serve             Start MCP server (stdio transport)
          version           Show version
          help              Show this help

        ENVIRONMENT:
          PIGEON_CLIENT_ID    Azure AD app client ID (required)
          PIGEON_TENANT_ID    Azure AD tenant ID (default: common)
          PIGEON_READ_ONLY    Disable write operations (true/false)
          PIGEON_ACCOUNT      Account name for multi-account support
        """)
    }
}
