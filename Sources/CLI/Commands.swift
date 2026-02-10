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

/// CLI entry: `flok mail read <id>`
public struct MailReadCommand {
    public static func run(config: FlokConfig, messageId: String) async throws {
        let manager = TokenManager(clientId: config.clientId, tenantId: config.tenantId, account: config.account)
        let client = GraphClient(tokenProvider: manager, apiVersion: config.apiVersion)

        let data = try await client.get("/me/messages/\(messageId)", query: [
            "$select": "subject,from,receivedDateTime,body,toRecipients,ccRecipients",
        ])

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let subject = json["subject"] as? String ?? "(no subject)"
            let from = ((json["from"] as? [String: Any])?["emailAddress"] as? [String: Any])?["address"] as? String ?? "unknown"
            let date = json["receivedDateTime"] as? String ?? ""
            let body = ((json["body"] as? [String: Any])?["content"] as? String) ?? ""

            print("📧 \(subject)")
            print("From: \(from)")
            print("Date: \(date)")
            print()
            print(body)
        }
    }
}

/// CLI entry: `flok mail send --to <email> --subject <subj> --body <body>`
public struct MailSendCommand {
    public static func run(config: FlokConfig, to: String, subject: String, body: String) async throws {
        if config.readOnly {
            print("❌ Error: Cannot send mail in read-only mode")
            return
        }

        let manager = TokenManager(clientId: config.clientId, tenantId: config.tenantId, account: config.account)
        let client = GraphClient(tokenProvider: manager, apiVersion: config.apiVersion)

        let messageBody = MessageBody(contentType: "Text", content: body)
        let recipient = Recipient(email: to)
        let outgoingMessage = OutgoingMessage(subject: subject, body: messageBody, to: [recipient])
        let request = SendMailRequest(message: outgoingMessage, saveToSentItems: true)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(request)

        _ = try await client.post("/me/sendMail", body: jsonData)
        print("✅ Mail sent to \(to)")
    }
}

/// CLI entry: `flok mail search <query>`
public struct MailSearchCommand {
    public static func run(config: FlokConfig, query: String) async throws {
        let manager = TokenManager(clientId: config.clientId, tenantId: config.tenantId, account: config.account)
        let client = GraphClient(tokenProvider: manager, apiVersion: config.apiVersion)

        let data = try await client.get("/me/messages", query: [
            "$search": "\"\(query)\"",
            "$select": "subject,from,receivedDateTime,isRead",
            "$orderby": "receivedDateTime desc",
            "$top": "25",
        ])

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let messages = json["value"] as? [[String: Any]] {
            print("Found \(messages.count) messages matching '\(query)':")
            for msg in messages {
                let read = (msg["isRead"] as? Bool == true) ? "  " : "📩"
                let subject = msg["subject"] as? String ?? "(no subject)"
                let from = ((msg["from"] as? [String: Any])?["emailAddress"] as? [String: Any])?["address"] as? String ?? "unknown"
                print("\(read) \(subject) — \(from)")
            }
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

        let manager = TokenManager(clientId: config.clientId, tenantId: config.tenantId, account: config.account)
        let client = GraphClient(tokenProvider: manager, apiVersion: config.apiVersion)

        _ = try await client.delete("/me/messages/\(messageId)")
        print("✅ Message deleted")
    }
}

/// CLI entry: `flok calendar list [--days N]`
public struct CalendarListCommand {
    public static func run(config: FlokConfig, days: Int) async throws {
        let manager = TokenManager(clientId: config.clientId, tenantId: config.tenantId, account: config.account)
        let client = GraphClient(tokenProvider: manager, apiVersion: config.apiVersion)

        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        let formatter = ISO8601DateFormatter()
        let startStr = formatter.string(from: now)
        let endStr = formatter.string(from: endDate)

        let data = try await client.get("/me/calendarView", query: [
            "startDateTime": startStr,
            "endDateTime": endStr,
            "$select": "subject,start,end,location,isOnlineMeeting",
            "$orderby": "start/dateTime",
        ])

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let events = json["value"] as? [[String: Any]] {
            print("📅 Upcoming events (next \(days) days):")
            for event in events {
                let subject = event["subject"] as? String ?? "(no subject)"
                let start = ((event["start"] as? [String: Any])?["dateTime"] as? String) ?? ""
                let location = (event["location"] as? [String: Any])?["displayName"] as? String
                let isOnline = event["isOnlineMeeting"] as? Bool == true

                var eventStr = "  📌 \(subject) — \(start)"
                if let loc = location, !loc.isEmpty {
                    eventStr += " @ \(loc)"
                }
                if isOnline {
                    eventStr += " 💻"
                }
                print(eventStr)
            }
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

        let manager = TokenManager(clientId: config.clientId, tenantId: config.tenantId, account: config.account)
        let client = GraphClient(tokenProvider: manager, apiVersion: config.apiVersion)

        let eventDict: [String: Any] = [
            "subject": title,
            "start": ["dateTime": start, "timeZone": "UTC"],
            "end": ["dateTime": end, "timeZone": "UTC"],
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: eventDict)
        _ = try await client.post("/me/events", body: jsonData)
        print("✅ Event created: \(title)")
    }
}

/// CLI entry: `flok contacts list [--search <q>]`
public struct ContactListCommand {
    public static func run(config: FlokConfig, search: String?) async throws {
        let manager = TokenManager(clientId: config.clientId, tenantId: config.tenantId, account: config.account)
        let client = GraphClient(tokenProvider: manager, apiVersion: config.apiVersion)

        var query: [String: String] = [
            "$select": "displayName,emailAddresses,mobilePhone,companyName",
            "$top": "50",
        ]

        if let searchQuery = search {
            query["$search"] = "\"\(searchQuery)\""
        }

        let data = try await client.get("/me/contacts", query: query)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let contacts = json["value"] as? [[String: Any]] {
            print("👥 Contacts (\(contacts.count)):")
            for contact in contacts {
                let name = contact["displayName"] as? String ?? "(no name)"
                let emails = (contact["emailAddresses"] as? [[String: Any]])?.compactMap { $0["address"] as? String }.joined(separator: ", ") ?? ""
                let phone = contact["mobilePhone"] as? String ?? ""
                let company = contact["companyName"] as? String ?? ""

                var contactStr = "  📇 \(name)"
                if !emails.isEmpty {
                    contactStr += " — \(emails)"
                }
                if !phone.isEmpty {
                    contactStr += " 📱 \(phone)"
                }
                if !company.isEmpty {
                    contactStr += " (\(company))"
                }
                print(contactStr)
            }
        }
    }
}

/// CLI entry: `flok files list [path]`
public struct DriveListCommand {
    public static func run(config: FlokConfig, path: String?) async throws {
        let manager = TokenManager(clientId: config.clientId, tenantId: config.tenantId, account: config.account)
        let client = GraphClient(tokenProvider: manager, apiVersion: config.apiVersion)

        let endpoint: String
        if let itemPath = path, !itemPath.isEmpty {
            endpoint = "/me/drive/root:/\(itemPath):/children"
        } else {
            endpoint = "/me/drive/root/children"
        }

        let data = try await client.get(endpoint, query: [
            "$select": "name,size,folder,file,lastModifiedDateTime",
            "$orderby": "name",
        ])

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["value"] as? [[String: Any]] {
            let displayPath = path ?? "root"
            print("📁 Files in \(displayPath) (\(items.count) items):")
            for item in items {
                let name = item["name"] as? String ?? "(unknown)"
                let isFolder = item["folder"] != nil
                let size = item["size"] as? Int ?? 0
                let sizeStr = formatFileSize(size)

                if isFolder {
                    print("  📂 \(name)/")
                } else {
                    print("  📄 \(name) — \(sizeStr)")
                }
            }
        }
    }

    private static func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0

        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) bytes"
        }
    }
}

/// CLI entry: `flok files search <query>`
public struct DriveSearchCommand {
    public static func run(config: FlokConfig, query: String) async throws {
        let manager = TokenManager(clientId: config.clientId, tenantId: config.tenantId, account: config.account)
        let client = GraphClient(tokenProvider: manager, apiVersion: config.apiVersion)

        let data = try await client.get("/me/drive/root/search(q='\(query)')", query: [
            "$select": "name,size,webUrl,lastModifiedDateTime",
            "$top": "25",
        ])

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["value"] as? [[String: Any]] {
            print("🔍 Search results for '\(query)' (\(items.count) items):")
            for item in items {
                let name = item["name"] as? String ?? "(unknown)"
                let url = item["webUrl"] as? String ?? ""
                print("  📄 \(name)")
                if !url.isEmpty {
                    print("     \(url)")
                }
            }
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

