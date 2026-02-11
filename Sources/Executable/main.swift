import Foundation
import Core
import CLI

// MARK: - Flok Entry Point

@main
struct Flok {
    @MainActor
    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())

        // Parse global --output flag
        if let outputIndex = args.firstIndex(of: "--output"),
           outputIndex + 1 < args.count {
            let outputValue = args[outputIndex + 1]
            if let format = OutputFormat(rawValue: outputValue) {
                OutputFormat.current = format
            } else {
                print("Error: Invalid output format '\(outputValue)'. Use 'text' or 'json'.")
                Foundation.exit(1)
            }
            args.remove(at: outputIndex + 1)
            args.remove(at: outputIndex)
        }

        guard let command = args.first else {
            printUsage()
            return
        }

        // Commands that don't require config
        switch command {
        case "help", "--help", "-h":
            printUsage()
            return
        case "version", "--version":
            print("Flok 0.1.0")
            return
        default:
            break
        }

        // All other commands require PIGEON_CLIENT_ID
        let config = FlokConfig()
        guard !config.clientId.isEmpty else {
            print("Error: PIGEON_CLIENT_ID is required.")
            print("Set it via environment variable or register an Azure AD app.")
            print("See: https://github.com/RyanLisse/Flok#setup")
            Foundation.exit(1)
        }

        do {
            try await runCommand(command, args: args, config: config)
        } catch let error as AuthError {
            print("Authentication error: \(error.localizedDescription)")
            if case .notAuthenticated = error {
                print("Run `flok auth login` to authenticate.")
            }
            Foundation.exit(1)
        } catch let error as GraphError {
            print("Graph API error: \(error.localizedDescription)")
            Foundation.exit(1)
        } catch {
            print("Error: \(error.localizedDescription)")
            Foundation.exit(1)
        }
    }

    @MainActor
    static func runCommand(_ command: String, args: [String], config: FlokConfig) async throws {
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
            let subArgs = Array(args.dropFirst().dropFirst())
            switch sub {
            case "list":
                try await MailListCommand.run(config: config, folder: "inbox", count: 25)
            case "read":
                guard let messageId = subArgs.first else {
                    print("Error: message ID required")
                    return
                }
                try await MailReadCommand.run(config: config, messageId: messageId)
            case "send":
                guard let toIndex = subArgs.firstIndex(of: "--to"),
                      toIndex + 1 < subArgs.count,
                      let subjIndex = subArgs.firstIndex(of: "--subject"),
                      subjIndex + 1 < subArgs.count,
                      let bodyIndex = subArgs.firstIndex(of: "--body"),
                      bodyIndex + 1 < subArgs.count else {
                    print("Error: --to, --subject, and --body required")
                    return
                }
                try await MailSendCommand.run(config: config, to: subArgs[toIndex + 1], subject: subArgs[subjIndex + 1], body: subArgs[bodyIndex + 1])
            case "search":
                guard let query = subArgs.first else {
                    print("Error: search query required")
                    return
                }
                try await MailSearchCommand.run(config: config, query: query)
            case "delete":
                guard let messageId = subArgs.first else {
                    print("Error: message ID required")
                    return
                }
                try await MailDeleteCommand.run(config: config, messageId: messageId)
            default:
                print("Unknown mail command: \(sub)")
            }

        case "calendar":
            let sub = args.dropFirst().first ?? "list"
            let subArgs = Array(args.dropFirst().dropFirst())
            switch sub {
            case "list":
                var days = 7
                if let daysIndex = subArgs.firstIndex(of: "--days"),
                   daysIndex + 1 < subArgs.count,
                   let daysValue = Int(subArgs[daysIndex + 1]) {
                    days = daysValue
                }
                try await CalendarListCommand.run(config: config, days: days)
            case "create":
                guard let titleIndex = subArgs.firstIndex(of: "--title"),
                      titleIndex + 1 < subArgs.count,
                      let startIndex = subArgs.firstIndex(of: "--start"),
                      startIndex + 1 < subArgs.count,
                      let endIndex = subArgs.firstIndex(of: "--end"),
                      endIndex + 1 < subArgs.count else {
                    print("Error: --title, --start, and --end required")
                    return
                }
                try await CalendarCreateCommand.run(config: config, title: subArgs[titleIndex + 1], start: subArgs[startIndex + 1], end: subArgs[endIndex + 1])
            default:
                print("Unknown calendar command: \(sub)")
            }

        case "contacts":
            let sub = args.dropFirst().first ?? "list"
            let subArgs = Array(args.dropFirst().dropFirst())
            switch sub {
            case "list":
                var search: String?
                if let searchIndex = subArgs.firstIndex(of: "--search"),
                   searchIndex + 1 < subArgs.count {
                    search = subArgs[searchIndex + 1]
                }
                try await ContactListCommand.run(config: config, search: search)
            default:
                print("Unknown contacts command: \(sub)")
            }

        case "files":
            let sub = args.dropFirst().first ?? "list"
            let subArgs = Array(args.dropFirst().dropFirst())
            switch sub {
            case "list":
                try await DriveListCommand.run(config: config, path: subArgs.first)
            case "search":
                guard let query = subArgs.first else {
                    print("Error: search query required")
                    return
                }
                try await DriveSearchCommand.run(config: config, query: query)
            default:
                print("Unknown files command: \(sub)")
            }

        case "serve":
            try await ServeCommand.run(config: config)

        default:
            print("Unknown command: \(command)")
            printUsage()
        }
    }

    static func printUsage() {
        print("""
        🐦 Flok — Microsoft 365 CLI + MCP Server

        USAGE:
          flok [--output text|json] <command> [subcommand] [options]

        GLOBAL OPTIONS:
          --output text|json           Output format (default: text)

        COMMANDS:
          auth login                   Authenticate with Microsoft (device code flow)
          auth logout                  Clear stored tokens
          auth status                  Check authentication status

          mail list                    List inbox messages
          mail read <id>               Read a message by ID
          mail send --to <email> --subject <subject> --body <body>
          mail search <query>          Search messages
          mail delete <id>             Delete a message

          calendar list [--days N]     List upcoming events (default: 7 days)
          calendar create --title <title> --start <ISO8601> --end <ISO8601>

          contacts list [--search <query>]

          files list [path]            List files in OneDrive
          files search <query>         Search OneDrive files

          serve                        Start MCP server (stdio transport)
          version                      Show version
          help                         Show this help

        ENVIRONMENT:
          PIGEON_CLIENT_ID    Azure AD app client ID (required)
          PIGEON_TENANT_ID    Azure AD tenant ID (default: common)
          PIGEON_READ_ONLY    Disable write operations (true/false)
          PIGEON_ACCOUNT      Account name for multi-account support

        EXAMPLES:
          flok mail send --to user@example.com --subject "Hello" --body "Test message"
          flok calendar create --title "Team Meeting" --start "2026-02-15T14:00:00" --end "2026-02-15T15:00:00"
          flok contacts list --search "John"
          flok files search "budget"
          flok --output json mail list
        """)
    }
}
