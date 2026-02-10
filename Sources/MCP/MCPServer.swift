import Foundation
import Core
import MCP

// MARK: - MCP Server Entry Point

/// Flok MCP Server — exposes Microsoft 365 tools via Model Context Protocol.
///
/// Agent-native design:
/// - MCP Resources for context injection (inbox summary, calendar today)
/// - MCP Prompts for composable workflows (triage, schedule, draft)
/// - Raw Graph API escape hatch for unanticipated use
/// - Completion signals in all tool results
/// - Read-only mode support
public struct FlokMCPServer: Sendable {
    let config: FlokConfig
    let tokenManager: TokenManager
    let graphClient: GraphClient
    let server: Server

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

        // Create MCP server with all capabilities
        self.server = Server(
            name: "flok",
            version: "0.1.0",
            capabilities: .init(
                prompts: .init(listChanged: false),
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)
            )
        )
    }

    /// Start the MCP server on stdio transport.
    public func start() async throws {
        // Register all handlers before starting transport
        await registerToolHandlers()
        await registerResourceHandlers()
        await registerPromptHandlers()

        // Start server on stdio transport
        let transport = StdioTransport()
        try await server.start(transport: transport)
    }

    // MARK: - Handler Registration

    /// Register all tool handlers with the MCP server.
    private func registerToolHandlers() async {
        // List all available tools
        await server.withMethodHandler(ListTools.self) { _ in
            let tools = [
                // Mail tools
                Tool(
                    name: "list-mail",
                    description: "List messages from inbox or specified folder with filtering and pagination",
                    inputSchema: .object([
                        "properties": .object([
                            "folder": .string("Folder name (default: inbox)"),
                            "top": .int(25),
                            "filter": .string("OData filter expression (optional)")
                        ])
                    ])
                ),
                Tool(
                    name: "read-mail",
                    description: "Get full message content including body and attachments",
                    inputSchema: .object([
                        "properties": .object([
                            "messageId": .string("Message ID")
                        ]),
                        "required": .array([.string("messageId")])
                    ])
                ),
                Tool(
                    name: "send-mail",
                    description: "Send a new email (disabled in read-only mode)",
                    inputSchema: .object([
                        "properties": .object([
                            "to": .array([.string("recipient@example.com")]),
                            "subject": .string("Email subject"),
                            "body": .string("Email body text or HTML"),
                            "cc": .array([.string("cc@example.com")]),
                            "isHTML": .bool(false)
                        ]),
                        "required": .array([.string("to"), .string("subject"), .string("body")])
                    ])
                ),
                Tool(
                    name: "reply-mail",
                    description: "Reply to a message (disabled in read-only mode)",
                    inputSchema: .object([
                        "properties": .object([
                            "messageId": .string("Message ID to reply to"),
                            "comment": .string("Reply text")
                        ]),
                        "required": .array([.string("messageId"), .string("comment")])
                    ])
                ),
                Tool(
                    name: "search-mail",
                    description: "Search messages using Microsoft Graph search syntax",
                    inputSchema: .object([
                        "properties": .object([
                            "query": .string("Search query"),
                            "top": .int(25)
                        ]),
                        "required": .array([.string("query")])
                    ])
                ),
                Tool(
                    name: "move-mail",
                    description: "Move a message to a different folder (disabled in read-only mode)",
                    inputSchema: .object([
                        "properties": .object([
                            "messageId": .string("Message ID"),
                            "destinationFolder": .string("Destination folder ID or name")
                        ]),
                        "required": .array([.string("messageId"), .string("destinationFolder")])
                    ])
                ),
                Tool(
                    name: "delete-mail",
                    description: "Delete a message (disabled in read-only mode)",
                    inputSchema: .object([
                        "properties": .object([
                            "messageId": .string("Message ID")
                        ]),
                        "required": .array([.string("messageId")])
                    ])
                ),

                // Calendar tools
                Tool(
                    name: "list-events",
                    description: "List calendar events within a date range (ISO 8601 format)",
                    inputSchema: .object([
                        "properties": .object([
                            "startDate": .string("Start date (ISO 8601)"),
                            "endDate": .string("End date (ISO 8601)"),
                            "top": .int(25)
                        ]),
                        "required": .array([.string("startDate"), .string("endDate")])
                    ])
                ),
                Tool(
                    name: "get-event",
                    description: "Get full event details including attendees and recurrence",
                    inputSchema: .object([
                        "properties": .object([
                            "eventId": .string("Event ID")
                        ]),
                        "required": .array([.string("eventId")])
                    ])
                ),
                Tool(
                    name: "create-event",
                    description: "Create a new calendar event (disabled in read-only mode)",
                    inputSchema: .object([
                        "properties": .object([
                            "subject": .string("Event subject"),
                            "start": .object([
                                "dateTime": .string("Start date/time"),
                                "timeZone": .string("Time zone")
                            ]),
                            "end": .object([
                                "dateTime": .string("End date/time"),
                                "timeZone": .string("Time zone")
                            ]),
                            "location": .string("Location (optional)"),
                            "attendees": .array([.string("attendee@example.com")]),
                            "body": .string("Event description (optional)"),
                            "isAllDay": .bool(false)
                        ]),
                        "required": .array([.string("subject"), .string("start"), .string("end")])
                    ])
                ),
                Tool(
                    name: "respond-event",
                    description: "Respond to a calendar event invitation (disabled in read-only mode)",
                    inputSchema: .object([
                        "properties": .object([
                            "eventId": .string("Event ID"),
                            "response": .string("accept, tentative, or decline"),
                            "comment": .string("Optional comment")
                        ]),
                        "required": .array([.string("eventId"), .string("response")])
                    ])
                ),
                Tool(
                    name: "check-availability",
                    description: "Check availability for specified attendees and time range",
                    inputSchema: .object([
                        "properties": .object([
                            "attendees": .array([.string("attendee@example.com")]),
                            "startTime": .string("Start time (ISO 8601)"),
                            "endTime": .string("End time (ISO 8601)")
                        ]),
                        "required": .array([.string("attendees"), .string("startTime"), .string("endTime")])
                    ])
                ),

                // Contact tools
                Tool(
                    name: "list-contacts",
                    description: "List contacts with optional search filter",
                    inputSchema: .object([
                        "properties": .object([
                            "top": .int(50),
                            "search": .string("Search query (optional)")
                        ])
                    ])
                ),
                Tool(
                    name: "get-contact",
                    description: "Get full contact details by ID",
                    inputSchema: .object([
                        "properties": .object([
                            "contactId": .string("Contact ID")
                        ]),
                        "required": .array([.string("contactId")])
                    ])
                ),
                Tool(
                    name: "create-contact",
                    description: "Create a new contact (disabled in read-only mode)",
                    inputSchema: .object([
                        "properties": .object([
                            "displayName": .string("Full name"),
                            "email": .string("Email address (optional)"),
                            "phone": .string("Phone number (optional)"),
                            "companyName": .string("Company (optional)"),
                            "jobTitle": .string("Job title (optional)")
                        ]),
                        "required": .array([.string("displayName")])
                    ])
                ),

                // Drive tools
                Tool(
                    name: "list-files",
                    description: "List OneDrive files and folders at a path",
                    inputSchema: .object([
                        "properties": .object([
                            "path": .string("Folder path (default: root)"),
                            "top": .int(50)
                        ])
                    ])
                ),
                Tool(
                    name: "get-file",
                    description: "Get file or folder metadata by item ID",
                    inputSchema: .object([
                        "properties": .object([
                            "itemId": .string("Item ID")
                        ]),
                        "required": .array([.string("itemId")])
                    ])
                ),
                Tool(
                    name: "search-files",
                    description: "Search OneDrive files by query",
                    inputSchema: .object([
                        "properties": .object([
                            "query": .string("Search query"),
                            "top": .int(50)
                        ]),
                        "required": .array([.string("query")])
                    ])
                ),

                // Graph API escape hatch
                Tool(
                    name: "graph-api",
                    description: "Call any Microsoft Graph API endpoint directly (emergent capability escape hatch)",
                    inputSchema: .object([
                        "properties": .object([
                            "method": .string("HTTP method (GET, POST, PATCH, PUT, DELETE)"),
                            "path": .string("API path (e.g., /me/messages)"),
                            "query": .object([:]),
                            "body": .string("Request body JSON (optional)"),
                            "headers": .object([:])
                        ]),
                        "required": .array([.string("method"), .string("path")])
                    ])
                ),
            ]
            return .init(tools: tools)
        }

        // Handle tool calls
        await server.withMethodHandler(CallTool.self) { [self] params in
            do {
                let result: ToolResult
                switch params.name {
                // Mail tools
                case "list-mail":
                    let handler = ListMailHandler(client: graphClient, readOnly: config.readOnly)
                    let folder = params.arguments?["folder"]?.stringValue ?? "inbox"
                    let top = params.arguments?["top"]?.intValue ?? 25
                    let filter = params.arguments?["filter"]?.stringValue
                    result = try await handler.handle(folder: folder, top: top, filter: filter)

                case "read-mail":
                    guard let messageId = params.arguments?["messageId"]?.stringValue else {
                        return .init(content: [.text("Missing required parameter: messageId")], isError: true)
                    }
                    let handler = ReadMailHandler(client: graphClient)
                    result = try await handler.handle(messageId: messageId)

                case "send-mail":
                    guard let to = params.arguments?["to"]?.arrayValue?.compactMap({ $0.stringValue }),
                          let subject = params.arguments?["subject"]?.stringValue,
                          let body = params.arguments?["body"]?.stringValue else {
                        return .init(content: [.text("Missing required parameters: to, subject, body")], isError: true)
                    }
                    let cc = params.arguments?["cc"]?.arrayValue?.compactMap({ $0.stringValue }) ?? []
                    let isHTML = params.arguments?["isHTML"]?.boolValue ?? false
                    let handler = SendMailHandler(client: graphClient, readOnly: config.readOnly)
                    result = try await handler.handle(to: to, subject: subject, body: body, cc: cc, isHTML: isHTML)

                case "reply-mail":
                    guard let messageId = params.arguments?["messageId"]?.stringValue,
                          let comment = params.arguments?["comment"]?.stringValue else {
                        return .init(content: [.text("Missing required parameters: messageId, comment")], isError: true)
                    }
                    let handler = ReplyMailHandler(client: graphClient, readOnly: config.readOnly)
                    result = try await handler.handle(messageId: messageId, comment: comment)

                case "search-mail":
                    guard let query = params.arguments?["query"]?.stringValue else {
                        return .init(content: [.text("Missing required parameter: query")], isError: true)
                    }
                    let top = params.arguments?["top"]?.intValue ?? 25
                    let handler = SearchMailHandler(client: graphClient)
                    result = try await handler.handle(query: query, top: top)

                case "move-mail":
                    guard let messageId = params.arguments?["messageId"]?.stringValue,
                          let destinationFolder = params.arguments?["destinationFolder"]?.stringValue else {
                        return .init(content: [.text("Missing required parameters: messageId, destinationFolder")], isError: true)
                    }
                    let handler = MoveMailHandler(client: graphClient, readOnly: config.readOnly)
                    result = try await handler.handle(messageId: messageId, destinationFolder: destinationFolder)

                case "delete-mail":
                    guard let messageId = params.arguments?["messageId"]?.stringValue else {
                        return .init(content: [.text("Missing required parameter: messageId")], isError: true)
                    }
                    let handler = DeleteMailHandler(client: graphClient, readOnly: config.readOnly)
                    result = try await handler.handle(messageId: messageId)

                // Calendar tools
                case "list-events":
                    guard let startDate = params.arguments?["startDate"]?.stringValue,
                          let endDate = params.arguments?["endDate"]?.stringValue else {
                        return .init(content: [.text("Missing required parameters: startDate, endDate")], isError: true)
                    }
                    let top = params.arguments?["top"]?.intValue ?? 25
                    let handler = ListEventsHandler(client: graphClient)
                    result = try await handler.handle(startDate: startDate, endDate: endDate, top: top)

                case "get-event":
                    guard let eventId = params.arguments?["eventId"]?.stringValue else {
                        return .init(content: [.text("Missing required parameter: eventId")], isError: true)
                    }
                    let handler = GetEventHandler(client: graphClient)
                    result = try await handler.handle(eventId: eventId)

                case "create-event":
                    guard let subject = params.arguments?["subject"]?.stringValue,
                          let startObj = params.arguments?["start"]?.objectValue,
                          let startDateTime = startObj["dateTime"]?.stringValue,
                          let startTimeZone = startObj["timeZone"]?.stringValue,
                          let endObj = params.arguments?["end"]?.objectValue,
                          let endDateTime = endObj["dateTime"]?.stringValue,
                          let endTimeZone = endObj["timeZone"]?.stringValue else {
                        return .init(content: [.text("Missing required parameters: subject, start, end")], isError: true)
                    }
                    let location = params.arguments?["location"]?.stringValue
                    let attendees = params.arguments?["attendees"]?.arrayValue?.compactMap({ $0.stringValue }) ?? []
                    let body = params.arguments?["body"]?.stringValue
                    let isAllDay = params.arguments?["isAllDay"]?.boolValue ?? false
                    let handler = CreateEventHandler(client: graphClient, readOnly: config.readOnly)
                    result = try await handler.handle(
                        subject: subject,
                        start: DateTimeTimeZone(dateTime: startDateTime, timeZone: startTimeZone),
                        end: DateTimeTimeZone(dateTime: endDateTime, timeZone: endTimeZone),
                        location: location,
                        attendees: attendees,
                        body: body,
                        isAllDay: isAllDay
                    )

                case "respond-event":
                    guard let eventId = params.arguments?["eventId"]?.stringValue,
                          let response = params.arguments?["response"]?.stringValue else {
                        return .init(content: [.text("Missing required parameters: eventId, response")], isError: true)
                    }
                    let comment = params.arguments?["comment"]?.stringValue
                    let handler = RespondEventHandler(client: graphClient, readOnly: config.readOnly)
                    result = try await handler.handle(eventId: eventId, response: response, comment: comment)

                case "check-availability":
                    guard let attendees = params.arguments?["attendees"]?.arrayValue?.compactMap({ $0.stringValue }),
                          let startTime = params.arguments?["startTime"]?.stringValue,
                          let endTime = params.arguments?["endTime"]?.stringValue else {
                        return .init(content: [.text("Missing required parameters: attendees, startTime, endTime")], isError: true)
                    }
                    let timeZone = params.arguments?["timeZone"]?.stringValue ?? "UTC"
                    let handler = CheckAvailabilityHandler(client: graphClient)
                    result = try await handler.handle(emails: attendees, start: startTime, end: endTime, timeZone: timeZone)

                // Contact tools
                case "list-contacts":
                    let top = params.arguments?["top"]?.intValue ?? 50
                    let search = params.arguments?["search"]?.stringValue
                    let handler = ListContactsHandler(client: graphClient)
                    result = try await handler.handle(top: top, search: search)

                case "get-contact":
                    guard let contactId = params.arguments?["contactId"]?.stringValue else {
                        return .init(content: [.text("Missing required parameter: contactId")], isError: true)
                    }
                    let handler = GetContactHandler(client: graphClient)
                    result = try await handler.handle(contactId: contactId)

                case "create-contact":
                    guard let displayName = params.arguments?["displayName"]?.stringValue else {
                        return .init(content: [.text("Missing required parameter: displayName")], isError: true)
                    }
                    // displayName is mapped to givenName as the primary field
                    let email = params.arguments?["email"]?.stringValue
                    let phone = params.arguments?["phone"]?.stringValue
                    let company = params.arguments?["companyName"]?.stringValue
                    let jobTitle = params.arguments?["jobTitle"]?.stringValue
                    let handler = CreateContactHandler(client: graphClient, readOnly: config.readOnly)
                    result = try await handler.handle(
                        givenName: displayName,
                        surname: nil,
                        email: email,
                        phone: phone,
                        company: company,
                        jobTitle: jobTitle
                    )

                // Drive tools
                case "list-files":
                    let path = params.arguments?["path"]?.stringValue ?? ""
                    let top = params.arguments?["top"]?.intValue ?? 50
                    let handler = ListFilesHandler(client: graphClient)
                    result = try await handler.handle(path: path, top: top)

                case "get-file":
                    guard let itemId = params.arguments?["itemId"]?.stringValue else {
                        return .init(content: [.text("Missing required parameter: itemId")], isError: true)
                    }
                    let handler = GetFileHandler(client: graphClient)
                    result = try await handler.handle(itemId: itemId)

                case "search-files":
                    guard let query = params.arguments?["query"]?.stringValue else {
                        return .init(content: [.text("Missing required parameter: query")], isError: true)
                    }
                    let top = params.arguments?["top"]?.intValue ?? 50
                    let handler = SearchFilesHandler(client: graphClient)
                    result = try await handler.handle(query: query, top: top)

                // Graph API escape hatch
                case "graph-api":
                    guard let method = params.arguments?["method"]?.stringValue,
                          let path = params.arguments?["path"]?.stringValue else {
                        return .init(content: [.text("Missing required parameters: method, path")], isError: true)
                    }
                    let query = params.arguments?["query"]?.objectValue?.reduce(into: [String: String]()) { dict, pair in
                        if let val = pair.value.stringValue { dict[pair.key] = val }
                    } ?? [:]
                    let body = params.arguments?["body"]?.stringValue
                    let headers = params.arguments?["headers"]?.objectValue?.reduce(into: [String: String]()) { dict, pair in
                        if let val = pair.value.stringValue { dict[pair.key] = val }
                    } ?? [:]
                    let handler = GraphAPIHandler(client: graphClient, readOnly: config.readOnly)
                    result = try await handler.handle(method: method, path: path, query: query, body: body, headers: headers)

                default:
                    return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
                }

                // Convert ToolResult to MCP CallTool.Result
                return convertToolResult(result)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }
        }
    }

    /// Register resource handlers.
    private func registerResourceHandlers() async {
        let resources = FlokResources(client: graphClient)

        await server.withMethodHandler(ListResources.self) { _ in
            return .init(resources: [
                Resource(
                    name: "Inbox Summary",
                    uri: "flok://inbox/summary",
                    description: "Recent inbox messages with unread count"
                ),
                Resource(
                    name: "Today's Calendar",
                    uri: "flok://calendar/today",
                    description: "Today's calendar events"
                ),
                Resource(
                    name: "User Profile",
                    uri: "flok://me/profile",
                    description: "Current user profile information"
                ),
            ])
        }

        await server.withMethodHandler(ReadResource.self) { [resources] params in
            do {
                let content: String
                switch params.uri {
                case "flok://inbox/summary":
                    content = try await resources.inboxSummary()
                case "flok://calendar/today":
                    content = try await resources.calendarToday()
                case "flok://me/profile":
                    content = try await resources.userProfile()
                default:
                    throw MCPError.invalidParams("Unknown resource URI: \(params.uri)")
                }
                return .init(contents: [Resource.Content.text(content, uri: params.uri, mimeType: "application/json")])
            } catch {
                throw MCPError.internalError("Failed to read resource: \(error.localizedDescription)")
            }
        }
    }

    /// Register prompt handlers.
    private func registerPromptHandlers() async {
        await server.withMethodHandler(ListPrompts.self) { _ in
            return .init(prompts: [
                Prompt(
                    name: "triage",
                    description: "Triage inbox: categorize and prioritize unread messages"
                ),
                Prompt(
                    name: "schedule",
                    description: "Schedule a meeting: find availability and create event"
                ),
                Prompt(
                    name: "draft",
                    description: "Draft and review: compose an email with review step"
                ),
                Prompt(
                    name: "briefing",
                    description: "Daily briefing: summarize today's schedule and urgent mail"
                ),
                Prompt(
                    name: "contact-lookup",
                    description: "Contact lookup: find and display contact info"
                ),
            ])
        }

        await server.withMethodHandler(GetPrompt.self) { params in
            let (description, messages): (String, [Prompt.Message])
            switch params.name {
            case "triage":
                description = "Triage inbox workflow"
                messages = [.user(.text(text: FlokPrompts.triageInbox))]
            case "schedule":
                description = "Schedule meeting workflow"
                messages = [.user(.text(text: FlokPrompts.scheduleMeeting))]
            case "draft":
                description = "Draft and review email workflow"
                messages = [.user(.text(text: FlokPrompts.draftAndReview))]
            case "briefing":
                description = "Daily briefing workflow"
                messages = [.user(.text(text: FlokPrompts.dailyBriefing))]
            case "contact-lookup":
                description = "Contact lookup workflow"
                messages = [.user(.text(text: FlokPrompts.contactLookup))]
            default:
                throw MCPError.invalidParams("Unknown prompt: \(params.name)")
            }
            return .init(description: description, messages: messages)
        }
    }

    /// Convert our ToolResult to MCP CallTool.Result.
    private func convertToolResult(_ result: ToolResult) -> CallTool.Result {
        if result.success {
            var content = result.data ?? ""
            if let nextActions = result.nextActions {
                content += "\n\n[Next actions: \(nextActions.joined(separator: ", "))]"
            }
            return .init(content: [.text(content)], isError: false)
        } else {
            return .init(content: [.text(result.error ?? "Unknown error")], isError: true)
        }
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
