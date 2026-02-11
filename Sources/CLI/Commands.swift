import Foundation
import Core
import FlokMCP

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
    @MainActor
    public static func run(config: FlokConfig, folder: String, count: Int) async throws {
        let ctx = FlokContext(config: config)
        let (messages, _) = try await ctx.mailService.listMessages(folder: folder, count: count)

        if OutputFormat.current == .json {
            let data = try JSONEncoder.graph.encode(messages)
            if let jsonString = String(data: data, encoding: .utf8) { print(jsonString) }
        } else {
            for msg in messages {
                let read = (msg.isRead == true) ? "  " : "📩"
                let subject = msg.subject ?? "(no subject)"
                let from = msg.from?.emailAddress.address ?? "unknown"
                print("\(read) \(subject) — \(from)")
            }
        }
    }
}

/// CLI entry: `flok mail read <id>`
public struct MailReadCommand {
    public static func run(config: FlokConfig, messageId: String) async throws {
        let ctx = FlokContext(config: config)
        let msg = try await ctx.mailService.getMessage(id: messageId, includeBody: true)
        let subject = msg.subject ?? "(no subject)"
        let from = msg.from?.emailAddress.address ?? "unknown"
        let date = msg.receivedDateTime.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        let body = msg.body?.content ?? ""
        print("📧 \(subject)")
        print("From: \(from)")
        print("Date: \(date)")
        print()
        print(body)
    }
}

/// CLI entry: `flok mail send --to <email> --subject <subj> --body <body>`
public struct MailSendCommand {
    public static func run(config: FlokConfig, to: String, subject: String, body: String) async throws {
        if config.readOnly {
            print("❌ Error: Cannot send mail in read-only mode")
            return
        }
        let ctx = FlokContext(config: config)
        let request = SendMailRequest(
            message: OutgoingMessage(subject: subject, body: MessageBody(contentType: "Text", content: body), to: [Recipient(email: to)]),
            saveToSentItems: true
        )
        try await ctx.mailService.sendMessage(request)
        print("✅ Mail sent to \(to)")
    }
}

/// CLI entry: `flok mail search <query>`
public struct MailSearchCommand {
    public static func run(config: FlokConfig, query: String) async throws {
        let ctx = FlokContext(config: config)
        let messages = try await ctx.mailService.searchMessages(query: query, count: 25)
        print("Found \(messages.count) messages matching '\(query)':")
        for msg in messages {
            let read = (msg.isRead == true) ? "  " : "📩"
            let subject = msg.subject ?? "(no subject)"
            let from = msg.from?.emailAddress.address ?? "unknown"
            print("\(read) \(subject) — \(from)")
        }
    }
}

/// CLI entry: `flok mail delete <id>`
public struct MailDeleteCommand {
    public static func run(config: FlokConfig, messageId: String) async throws {
        if config.readOnly {
            print("❌ Error: Cannot delete mail in read-only mode")
            return
        }
        let ctx = FlokContext(config: config)
        try await ctx.mailService.deleteMessage(id: messageId)
        print("✅ Message deleted")
    }
}

/// CLI entry: `flok calendar list [--days N]`
public struct CalendarListCommand {
    public static func run(config: FlokConfig, days: Int) async throws {
        let ctx = FlokContext(config: config)
        let now = Date()
        let endDate = Foundation.Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        let events = try await ctx.calendarService.listEvents(from: now, to: endDate, count: 50)
        print("📅 Upcoming events (next \(days) days):")
        for event in events {
            let subject = event.subject ?? "(no subject)"
            let start = event.start?.dateTime ?? ""
            let location = event.location?.displayName
            let isOnline = event.isOnlineMeeting == true
            var eventStr = "  📌 \(subject) — \(start)"
            if let loc = location, !loc.isEmpty { eventStr += " @ \(loc)" }
            if isOnline { eventStr += " 💻" }
            print(eventStr)
        }
    }
}

/// CLI entry: `flok calendar create --title <t> --start <s> --end <e>`
public struct CalendarCreateCommand {
    public static func run(config: FlokConfig, title: String, start: String, end: String) async throws {
        if config.readOnly {
            print("❌ Error: Cannot create event in read-only mode")
            return
        }
        let ctx = FlokContext(config: config)
        let draft = DraftEvent(subject: title, start: DateTimeTimeZone(dateTime: start, timeZone: "UTC"), end: DateTimeTimeZone(dateTime: end, timeZone: "UTC"))
        _ = try await ctx.calendarService.createEvent(draft)
        print("✅ Event created: \(title)")
    }
}

/// CLI entry: `flok contacts list [--search <q>]`
public struct ContactListCommand {
    public static func run(config: FlokConfig, search: String?) async throws {
        let ctx = FlokContext(config: config)
        let contacts = try await ctx.contactService.listContacts(search: search, top: 50)
        print("👥 Contacts (\(contacts.count)):")
        for c in contacts {
            let name = c.displayName ?? "(no name)"
            let emails = c.emailAddresses?.map(\.address).joined(separator: ", ") ?? ""
            let phone = c.mobilePhone ?? ""
            let company = c.companyName ?? ""
            var line = "  📇 \(name)"
            if !emails.isEmpty { line += " — \(emails)" }
            if !phone.isEmpty { line += " 📱 \(phone)" }
            if !company.isEmpty { line += " (\(company))" }
            print(line)
        }
    }
}

/// CLI entry: `flok files list [path]`
public struct DriveListCommand {
    public static func run(config: FlokConfig, path: String?) async throws {
        let ctx = FlokContext(config: config)
        let pathStr = path ?? ""
        let items = try await ctx.driveService.listChildren(path: pathStr, top: 100)
        let displayPath = path ?? "root"
        print("📁 Files in \(displayPath) (\(items.count) items):")
        for item in items {
            let size = Int(item.size ?? 0)
            let sizeStr = formatFileSize(size)
            if item.folder != nil {
                print("  📂 \(item.name)/")
            } else {
                print("  📄 \(item.name) — \(sizeStr)")
            }
        }
    }

    private static func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        if gb >= 1.0 { return String(format: "%.2f GB", gb) }
        if mb >= 1.0 { return String(format: "%.2f MB", mb) }
        if kb >= 1.0 { return String(format: "%.2f KB", kb) }
        return "\(bytes) bytes"
    }
}

/// CLI entry: `flok files search <query>`
public struct DriveSearchCommand {
    public static func run(config: FlokConfig, query: String) async throws {
        let ctx = FlokContext(config: config)
        let items = try await ctx.driveService.searchFiles(query: query, top: 25)
        print("🔍 Search results for '\(query)' (\(items.count) items):")
        for item in items {
            print("  📄 \(item.name)")
            if let url = item.webUrl, !url.isEmpty { print("     \(url)") }
        }
    }
}

/// CLI entry: `flok serve` — Start MCP server on stdio.
public struct ServeCommand {
    public static func run(config: FlokConfig) async throws {
        let mcpServer = FlokMCPServer(config: config)
        try await mcpServer.start()
    }
}

