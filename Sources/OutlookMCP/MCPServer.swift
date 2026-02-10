import Foundation
import OutlookCore

/// MCP (Model Context Protocol) server for OutlookCLI.
/// Exposes Microsoft 365 operations as MCP tools for AI agents.
public actor OutlookMCPServer {
    private let config: OutlookConfig
    private let tokenManager: TokenManager
    private let client: GraphClient
    private let mailService: MailService
    private let calendarService: CalendarService

    public init(config: OutlookConfig) {
        self.config = config
        let storage = FileTokenStorage()
        self.tokenManager = TokenManager(config: config, storage: storage)
        self.client = GraphClient(tokenManager: tokenManager)
        self.mailService = MailService(client: client, readOnly: config.readOnly)
        self.calendarService = CalendarService(client: client, readOnly: config.readOnly)
    }

    /// List all available MCP tools.
    public func listTools() -> [MCPToolDefinition] {
        var tools: [MCPToolDefinition] = []
        tools.append(contentsOf: mailTools())
        tools.append(contentsOf: calendarTools())
        tools.append(contentsOf: utilityTools())
        return tools
    }

    /// Execute an MCP tool by name with given arguments.
    public func executeTool(name: String, arguments: [String: Any]) async throws -> MCPToolResult {
        switch name {
        // Mail tools
        case "outlook_mail_list":
            return try await executeMailList(arguments)
        case "outlook_mail_read":
            return try await executeMailRead(arguments)
        case "outlook_mail_send":
            return try await executeMailSend(arguments)
        case "outlook_mail_reply":
            return try await executeMailReply(arguments)
        case "outlook_mail_forward":
            return try await executeMailForward(arguments)
        case "outlook_mail_move":
            return try await executeMailMove(arguments)
        case "outlook_mail_delete":
            return try await executeMailDelete(arguments)
        case "outlook_mail_mark":
            return try await executeMailMark(arguments)
        case "outlook_mail_search":
            return try await executeMailSearch(arguments)
        case "outlook_mail_folders":
            return try await executeMailFolders()

        // Calendar tools
        case "outlook_cal_list":
            return try await executeCalList(arguments)
        case "outlook_cal_get":
            return try await executeCalGet(arguments)
        case "outlook_cal_create":
            return try await executeCalCreate(arguments)
        case "outlook_cal_update":
            return try await executeCalUpdate(arguments)
        case "outlook_cal_delete":
            return try await executeCalDelete(arguments)
        case "outlook_cal_respond":
            return try await executeCalRespond(arguments)
        case "outlook_cal_calendars":
            return try await executeCalCalendars()
        case "outlook_cal_search":
            return try await executeCalSearch(arguments)

        // Utility tools
        case "outlook_auth_status":
            return try await executeAuthStatus()

        default:
            return MCPToolResult(content: "Unknown tool: \(name)", isError: true)
        }
    }

    // MARK: - Mail Tool Implementations

    private func executeMailList(_ args: [String: Any]) async throws -> MCPToolResult {
        let folder = args["folder"] as? String
        let unreadOnly = args["unread_only"] as? Bool ?? false
        let count = args["count"] as? Int ?? 25
        let includeBody = args["include_body"] as? Bool ?? false

        let messages = try await mailService.listMessages(
            folder: folder, unreadOnly: unreadOnly, count: count, includeBody: includeBody
        )
        return MCPToolResult(content: toJSON(messages))
    }

    private func executeMailRead(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let messageId = args["message_id"] as? String else {
            return MCPToolResult(content: "Missing required parameter: message_id", isError: true)
        }
        let message = try await mailService.getMessage(id: messageId)
        return MCPToolResult(content: toJSON(message))
    }

    private func executeMailSend(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let to = args["to"] as? String,
              let subject = args["subject"] as? String,
              let body = args["body"] as? String else {
            return MCPToolResult(content: "Missing required parameters: to, subject, body", isError: true)
        }
        let cc = (args["cc"] as? String)?.split(separator: ",").map(String.init)
        let bcc = (args["bcc"] as? String)?.split(separator: ",").map(String.init)
        let draft = DraftMessage(subject: subject, body: body, to: [to], cc: cc, bcc: bcc)
        try await mailService.sendMessage(draft)
        return MCPToolResult(content: "Email sent to \(to)")
    }

    private func executeMailReply(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let messageId = args["message_id"] as? String,
              let body = args["body"] as? String else {
            return MCPToolResult(content: "Missing required parameters: message_id, body", isError: true)
        }
        let replyAll = args["reply_all"] as? Bool ?? false
        try await mailService.replyToMessage(id: messageId, body: body, replyAll: replyAll)
        return MCPToolResult(content: "Reply sent")
    }

    private func executeMailForward(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let messageId = args["message_id"] as? String,
              let to = args["to"] as? String else {
            return MCPToolResult(content: "Missing required parameters: message_id, to", isError: true)
        }
        let comment = args["comment"] as? String
        try await mailService.forwardMessage(id: messageId, to: [to], comment: comment)
        return MCPToolResult(content: "Message forwarded to \(to)")
    }

    private func executeMailMove(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let messageId = args["message_id"] as? String,
              let folder = args["folder"] as? String else {
            return MCPToolResult(content: "Missing required parameters: message_id, folder", isError: true)
        }
        try await mailService.moveMessage(id: messageId, destinationFolder: folder)
        return MCPToolResult(content: "Message moved to \(folder)")
    }

    private func executeMailDelete(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let messageId = args["message_id"] as? String else {
            return MCPToolResult(content: "Missing required parameter: message_id", isError: true)
        }
        try await mailService.deleteMessage(id: messageId)
        return MCPToolResult(content: "Message deleted")
    }

    private func executeMailMark(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let messageId = args["message_id"] as? String else {
            return MCPToolResult(content: "Missing required parameter: message_id", isError: true)
        }
        let isRead = args["is_read"] as? Bool
        let flag = (args["flag"] as? String).map { MessageFlag(flagStatus: $0) }
        try await mailService.updateMessage(id: messageId, isRead: isRead, flag: flag)
        return MCPToolResult(content: "Message updated")
    }

    private func executeMailSearch(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let query = args["query"] as? String else {
            return MCPToolResult(content: "Missing required parameter: query", isError: true)
        }
        let count = args["count"] as? Int ?? 25
        let messages = try await mailService.searchMessages(query: query, count: count)
        return MCPToolResult(content: toJSON(messages))
    }

    private func executeMailFolders() async throws -> MCPToolResult {
        let folders = try await mailService.listFolders()
        return MCPToolResult(content: toJSON(folders))
    }

    // MARK: - Calendar Tool Implementations

    private func executeCalList(_ args: [String: Any]) async throws -> MCPToolResult {
        let calendarId = args["calendar_id"] as? String
        let count = args["count"] as? Int ?? 25
        let formatter = ISO8601DateFormatter()

        let from = (args["from"] as? String).flatMap { formatter.date(from: $0) } ?? Date()
        let to = (args["to"] as? String).flatMap { formatter.date(from: $0) }
            ?? Foundation.Calendar.current.date(byAdding: .day, value: 7, to: from)!

        let events = try await calendarService.listEvents(
            from: from, to: to, calendarId: calendarId, count: count
        )
        return MCPToolResult(content: toJSON(events))
    }

    private func executeCalGet(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let eventId = args["event_id"] as? String else {
            return MCPToolResult(content: "Missing required parameter: event_id", isError: true)
        }
        let event = try await calendarService.getEvent(id: eventId)
        return MCPToolResult(content: toJSON(event))
    }

    private func executeCalCreate(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let subject = args["subject"] as? String,
              let start = args["start"] as? String,
              let end = args["end"] as? String else {
            return MCPToolResult(content: "Missing required parameters: subject, start, end", isError: true)
        }
        let tz = TimeZone.current.identifier
        let attendeeList = (args["attendees"] as? String)?.split(separator: ",").map(String.init)
        let draft = DraftEvent(
            subject: subject,
            start: DateTimeTimeZone(dateTime: start, timeZone: tz),
            end: DateTimeTimeZone(dateTime: end, timeZone: tz),
            body: args["body"] as? String,
            location: args["location"] as? String,
            attendees: attendeeList
        )
        let event = try await calendarService.createEvent(draft)
        return MCPToolResult(content: toJSON(event))
    }

    private func executeCalUpdate(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let eventId = args["event_id"] as? String else {
            return MCPToolResult(content: "Missing required parameter: event_id", isError: true)
        }
        let tz = TimeZone.current.identifier
        let updates = EventUpdate(
            subject: args["subject"] as? String,
            start: (args["start"] as? String).map { DateTimeTimeZone(dateTime: $0, timeZone: tz) },
            end: (args["end"] as? String).map { DateTimeTimeZone(dateTime: $0, timeZone: tz) },
            location: args["location"] as? String
        )
        let event = try await calendarService.updateEvent(id: eventId, updates: updates)
        return MCPToolResult(content: toJSON(event))
    }

    private func executeCalDelete(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let eventId = args["event_id"] as? String else {
            return MCPToolResult(content: "Missing required parameter: event_id", isError: true)
        }
        try await calendarService.deleteEvent(id: eventId)
        return MCPToolResult(content: "Event deleted")
    }

    private func executeCalRespond(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let eventId = args["event_id"] as? String,
              let responseStr = args["response"] as? String else {
            return MCPToolResult(content: "Missing required parameters: event_id, response", isError: true)
        }
        guard let response = EventResponse(rawValue: responseStr) else {
            return MCPToolResult(content: "Invalid response. Use: accept, decline, tentativelyAccept", isError: true)
        }
        let message = args["message"] as? String
        try await calendarService.respondToEvent(id: eventId, response: response, message: message)
        return MCPToolResult(content: "Response sent: \(responseStr)")
    }

    private func executeCalCalendars() async throws -> MCPToolResult {
        let calendars = try await calendarService.listCalendars()
        return MCPToolResult(content: toJSON(calendars))
    }

    private func executeCalSearch(_ args: [String: Any]) async throws -> MCPToolResult {
        guard let query = args["query"] as? String else {
            return MCPToolResult(content: "Missing required parameter: query", isError: true)
        }
        let events = try await calendarService.searchEvents(query: query)
        return MCPToolResult(content: toJSON(events))
    }

    // MARK: - Utility Tool Implementations

    private func executeAuthStatus() async throws -> MCPToolResult {
        let storage = FileTokenStorage()
        let accountManager = AccountManager(storage: storage)
        do {
            let defaultId = try await accountManager.getDefaultAccount()
            let info = try await accountManager.getAccountInfo(defaultId)
            return MCPToolResult(content: toJSON(info))
        } catch {
            return MCPToolResult(content: "Not authenticated", isError: true)
        }
    }

    // MARK: - Tool Definitions

    private func mailTools() -> [MCPToolDefinition] {
        [
            MCPToolDefinition(name: "outlook_mail_list", description: "List email messages",
                              parameters: ["folder": "string?", "unread_only": "bool?", "count": "int?", "include_body": "bool?"]),
            MCPToolDefinition(name: "outlook_mail_read", description: "Read a specific email message",
                              parameters: ["message_id": "string"]),
            MCPToolDefinition(name: "outlook_mail_send", description: "Send an email",
                              parameters: ["to": "string", "subject": "string", "body": "string", "cc": "string?", "bcc": "string?"]),
            MCPToolDefinition(name: "outlook_mail_reply", description: "Reply to an email",
                              parameters: ["message_id": "string", "body": "string", "reply_all": "bool?"]),
            MCPToolDefinition(name: "outlook_mail_forward", description: "Forward an email",
                              parameters: ["message_id": "string", "to": "string", "comment": "string?"]),
            MCPToolDefinition(name: "outlook_mail_move", description: "Move email to folder",
                              parameters: ["message_id": "string", "folder": "string"]),
            MCPToolDefinition(name: "outlook_mail_delete", description: "Delete an email",
                              parameters: ["message_id": "string"]),
            MCPToolDefinition(name: "outlook_mail_mark", description: "Mark email as read/unread or flag/unflag",
                              parameters: ["message_id": "string", "is_read": "bool?", "flag": "string?"]),
            MCPToolDefinition(name: "outlook_mail_search", description: "Search emails",
                              parameters: ["query": "string", "count": "int?"]),
            MCPToolDefinition(name: "outlook_mail_folders", description: "List mail folders",
                              parameters: [:]),
        ]
    }

    private func calendarTools() -> [MCPToolDefinition] {
        [
            MCPToolDefinition(name: "outlook_cal_list", description: "List calendar events",
                              parameters: ["from": "string?", "to": "string?", "calendar_id": "string?", "count": "int?"]),
            MCPToolDefinition(name: "outlook_cal_get", description: "Get event details",
                              parameters: ["event_id": "string"]),
            MCPToolDefinition(name: "outlook_cal_create", description: "Create a calendar event",
                              parameters: ["subject": "string", "start": "string", "end": "string", "location": "string?", "attendees": "string?", "body": "string?"]),
            MCPToolDefinition(name: "outlook_cal_update", description: "Update a calendar event",
                              parameters: ["event_id": "string", "subject": "string?", "start": "string?", "end": "string?", "location": "string?"]),
            MCPToolDefinition(name: "outlook_cal_delete", description: "Delete a calendar event",
                              parameters: ["event_id": "string"]),
            MCPToolDefinition(name: "outlook_cal_respond", description: "Respond to event invitation (accept/decline/tentative)",
                              parameters: ["event_id": "string", "response": "string", "message": "string?"]),
            MCPToolDefinition(name: "outlook_cal_calendars", description: "List available calendars",
                              parameters: [:]),
            MCPToolDefinition(name: "outlook_cal_search", description: "Search calendar events",
                              parameters: ["query": "string"]),
        ]
    }

    private func utilityTools() -> [MCPToolDefinition] {
        [
            MCPToolDefinition(name: "outlook_auth_status", description: "Show authentication status",
                              parameters: [:]),
        ]
    }

    // MARK: - Helpers

    private func toJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

// MARK: - MCP Types

public struct MCPToolDefinition: Sendable {
    public let name: String
    public let description: String
    public let parameters: [String: String]

    public init(name: String, description: String, parameters: [String: String]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

public struct MCPToolResult: Sendable {
    public let content: String
    public let isError: Bool

    public init(content: String, isError: Bool = false) {
        self.content = content
        self.isError = isError
    }
}
