import Foundation
import Core

// MARK: - CLI Command Stubs
// Full Commander integration will wire these up.
// Each command maps to a Core provider call.

/// CLI entry: `flok auth login`
public struct AuthLoginCommand {
    public static func run(clientId: String, tenantId: String) async throws {
        let manager = TokenManager(clientId: clientId, tenantId: tenantId)
        let deviceCode = try await manager.login()

        print(deviceCode.message)
        print()
        print("Waiting for authentication...")

        try await manager.completeLogin(
            deviceCode: deviceCode.deviceCode,
            interval: deviceCode.interval
        )
        print("✅ Authenticated successfully!")
    }
}

/// CLI entry: `flok auth logout`
public struct AuthLogoutCommand {
    public static func run(clientId: String, tenantId: String) async {
        let manager = TokenManager(clientId: clientId, tenantId: tenantId)
        await manager.logout()
        print("✅ Logged out. Tokens cleared from Keychain.")
    }
}

/// CLI entry: `flok auth status`
public struct AuthStatusCommand {
    public static func run(clientId: String, tenantId: String) async {
        let manager = TokenManager(clientId: clientId, tenantId: tenantId)
        let authenticated = await manager.isAuthenticated
        if authenticated {
            print("✅ Authenticated (tokens stored in Keychain)")
        } else {
            print("❌ Not authenticated. Run `flok auth login`.")
        }
    }
}

/// CLI entry: `flok mail list`
public struct MailListCommand {
    public static func run(config: FlokConfig, folder: String, count: Int) async throws {
        let manager = TokenManager(clientId: config.clientId, tenantId: config.tenantId, account: config.account)
        let client = GraphClient(tokenProvider: manager, apiVersion: config.apiVersion)

        let data = try await client.get("/me/mailFolders/\(folder)/messages", query: [
            "$top": String(count),
            "$select": "subject,from,receivedDateTime,isRead",
            "$orderby": "receivedDateTime desc",
        ])

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let messages = json["value"] as? [[String: Any]] {
            for msg in messages {
                let read = (msg["isRead"] as? Bool == true) ? "  " : "📩"
                let subject = msg["subject"] as? String ?? "(no subject)"
                let from = ((msg["from"] as? [String: Any])?["emailAddress"] as? [String: Any])?["address"] as? String ?? "unknown"
                print("\(read) \(subject) — \(from)")
            }
        }
    }
}

/// CLI entry: `flok serve` — Start MCP server on stdio.
public struct ServeCommand {
    public static func run(config: FlokConfig) async throws {
        print("Starting Flok MCP server on stdio...")
        print("Config: clientId=\(config.clientId.prefix(8))..., tenant=\(config.tenantId), readOnly=\(config.readOnly)")
        // MCP server stdio transport will be wired here
        // For now, placeholder
        print("MCP server ready. Waiting for connections...")
    }
}
