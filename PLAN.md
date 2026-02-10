# OutlookCLI — Comprehensive Plan

> Swift CLI + MCP server for Microsoft 365 via Microsoft Graph API.
> Peekaboo architecture. Device Code Auth. Keychain Storage.

---

## 1. Goals & Intent

### What We're Building
A native Swift CLI and MCP server that provides full access to Microsoft 365 services (Mail, Calendar, Contacts, OneDrive) through the Microsoft Graph REST API. Think `gog` (Google Workspace CLI) but for Outlook/Microsoft 365.

### Why
- Ryan needs Outlook access for his work account
- No existing Swift-native tool exists — all current solutions are Python or TypeScript
- Fits the Peekaboo architecture pattern used across all other CLI+MCP projects
- Native Keychain storage > JSON file token caches
- MCP integration lets Claude/agents interact with Outlook directly

### Success Criteria
- `outlook mail list` shows recent emails in < 2 seconds
- `outlook mail send "person@work.com" --subject "Test" --body "Hello"` sends email
- `outlook cal list` shows upcoming calendar events
- `outlook mcp serve` starts MCP server with all tools available
- Device code auth works first try with clear instructions
- Tokens persist in macOS Keychain, auto-refresh silently
- Multi-account support (work + personal if needed)

---

## 2. Research Summary

### Studied Implementations

| Project | Language | Tools | Architecture | Key Insight |
|---------|----------|-------|-------------|-------------|
| **elyxlz/microsoft-mcp** | Python | 34 focused tools | FastMCP + httpx + MSAL | Best tool design, retry logic, multi-account |
| **merill/lokka** | TypeScript | 1 versatile tool | Official MCP SDK + Graph SDK | Flexible but requires AI to know Graph paths |
| **Softeria/ms-365-mcp** | TypeScript | 90+ auto-generated | OpenAPI-generated | TOON format (token optimization), tool presets |

### Design Decisions

1. **Focused tool set (~30 tools)** — Like elyxlz, not 90+ like Softeria. Each tool maps to a clear user action.
2. **Separate CLI commands AND MCP tools** — CLI for human use, MCP for agent use. Both share Core library.
3. **Device code flow only** — No browser redirect, no interactive auth. Works in any terminal, SSH, containers.
4. **Keychain-first** — macOS Keychain for token storage. File fallback for non-macOS (future).
5. **URLSession** — No external HTTP dependencies. Foundation is sufficient for Graph API.
6. **Read-only mode** — Safety flag that prevents send/create/delete operations (for agents).

---

## 3. Architecture

### Peekaboo Standard Structure

```
OutlookCLI/
├── Package.swift
├── Sources/
│   ├── OutlookCore/              # Library — no CLI dependencies
│   │   ├── Auth/
│   │   │   ├── DeviceCodeFlow.swift      # OAuth2 device code implementation
│   │   │   ├── TokenManager.swift        # Token lifecycle (acquire, refresh, cache)
│   │   │   ├── KeychainStorage.swift     # macOS Keychain wrapper
│   │   │   └── AccountManager.swift      # Multi-account support
│   │   ├── Graph/
│   │   │   ├── GraphClient.swift         # HTTP client with retry, pagination, rate limiting
│   │   │   ├── GraphRequest.swift        # Request builder (select, filter, orderby, top)
│   │   │   └── GraphError.swift          # Error types with Graph-specific handling
│   │   ├── Models/
│   │   │   ├── Message.swift             # Mail message + attachment models
│   │   │   ├── Event.swift               # Calendar event models
│   │   │   ├── Contact.swift             # Contact models
│   │   │   ├── DriveItem.swift           # OneDrive file/folder models
│   │   │   └── SearchResult.swift        # Unified search result
│   │   ├── Services/
│   │   │   ├── MailService.swift         # Mail operations (list, read, send, reply, move, delete)
│   │   │   ├── CalendarService.swift     # Calendar operations (list, create, respond, free/busy)
│   │   │   ├── ContactService.swift      # Contact operations (CRUD + search)
│   │   │   ├── DriveService.swift        # OneDrive operations (browse, download, upload, search)
│   │   │   └── SearchService.swift       # Unified search across services
│   │   └── Config/
│   │       ├── OutlookConfig.swift       # App configuration (client ID, tenant, scopes)
│   │       └── OutputFormatter.swift     # JSON, table, and compact output formats
│   ├── OutlookCLI/                       # Commander subcommands
│   │   ├── Commands/
│   │   │   ├── AuthCommands.swift        # login, logout, accounts, status
│   │   │   ├── MailCommands.swift        # mail list, read, send, reply, reply-all, forward, move, delete, search
│   │   │   ├── CalendarCommands.swift    # cal list, get, create, update, delete, respond, free-busy
│   │   │   ├── ContactCommands.swift     # contact list, get, create, update, delete, search
│   │   │   ├── DriveCommands.swift       # drive list, get, download, upload, delete, search
│   │   │   └── SearchCommands.swift      # search (unified across services)
│   │   └── Formatters/
│   │       ├── MailFormatter.swift       # Pretty-print mail messages
│   │       ├── CalendarFormatter.swift   # Pretty-print events
│   │       └── TableFormatter.swift      # Generic table output
│   ├── OutlookMCP/                       # MCP server
│   │   ├── MCPServer.swift               # Server setup + tool registration
│   │   ├── Tools/
│   │   │   ├── MailTools.swift           # MCP tools for mail operations
│   │   │   ├── CalendarTools.swift       # MCP tools for calendar operations
│   │   │   ├── ContactTools.swift        # MCP tools for contact operations
│   │   │   ├── DriveTools.swift          # MCP tools for drive operations
│   │   │   └── SearchTools.swift         # MCP tools for unified search
│   │   └── MCPConfig.swift              # MCP-specific configuration (read-only mode, tool filtering)
│   └── Executable/
│       └── main.swift                    # Entry point — routes to CLI or MCP
├── Tests/
│   ├── OutlookCoreTests/
│   │   ├── AuthTests.swift
│   │   ├── GraphClientTests.swift
│   │   ├── MailServiceTests.swift
│   │   ├── CalendarServiceTests.swift
│   │   ├── ContactServiceTests.swift
│   │   └── DriveServiceTests.swift
│   └── OutlookCLITests/
│       ├── CommandParsingTests.swift
│       └── FormatterTests.swift
├── AGENTS.md
├── PLAN.md
└── README.md
```

### Package Dependencies

```swift
// Package.swift
let package = Package(
    name: "OutlookCLI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OutlookCore", targets: ["OutlookCore"]),
        .executable(name: "outlook", targets: ["Executable"]),
    ],
    dependencies: [
        // CLI framework
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        // MCP server
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.9.0"),
        // Logging
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "OutlookCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .target(
            name: "OutlookCLI",
            dependencies: [
                "OutlookCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "OutlookMCP",
            dependencies: [
                "OutlookCore",
                .product(name: "ModelContextProtocol", package: "swift-sdk"),
            ]
        ),
        .executableTarget(
            name: "Executable",
            dependencies: ["OutlookCLI", "OutlookMCP"]
        ),
        .testTarget(name: "OutlookCoreTests", dependencies: ["OutlookCore"]),
        .testTarget(name: "OutlookCLITests", dependencies: ["OutlookCLI"]),
    ]
)
```

---

## 4. Authentication System

### Device Code Flow

The entire auth flow in detail:

1. **CLI requests device code** from Azure AD
   - POST to `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/devicecode`
   - Returns: `user_code`, `verification_uri`, `device_code`, `interval`

2. **CLI displays instructions to user**
   ```
   To sign in, visit: https://microsoft.com/devicelogin
   Enter code: ABCD-EFGH
   Waiting for authentication...
   ```

3. **CLI polls for token** at specified interval
   - POST to `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token`
   - Handle: `authorization_pending` (keep polling), `authorization_declined`, `expired_token`

4. **On success**: Store access_token + refresh_token in Keychain

5. **On subsequent runs**: Try silent token acquisition first
   - Load refresh_token from Keychain
   - Exchange for new access_token
   - If refresh_token expired → re-run device code flow

### Token Storage

```
Keychain Service: "com.outlookcli.auth"
Items per account:
  - {email}.access_token   → short-lived (~1 hour)
  - {email}.refresh_token   → long-lived (~90 days)
  - {email}.account_info    → JSON with tenant, scopes, etc.
```

### Multi-Account Support

- `outlook auth login` — Start device code flow, add new account
- `outlook auth login --tenant {id}` — Specific tenant
- `outlook auth accounts` — List all authenticated accounts
- `outlook auth switch {email}` — Set default account
- `outlook auth logout {email}` — Remove account from Keychain
- `outlook auth status` — Show current account, token expiry, scopes

### Required Azure AD App Registration

Users need to register an app in Azure portal (or we provide a shared client ID):

```
App Registration Settings:
  - Name: OutlookCLI
  - Supported account types: Personal + Work/School
  - Platform: Mobile and desktop applications
  - Redirect URI: (none needed for device code)
  - "Allow public client flows": Yes
  - No client secret needed
```

### Required Permissions (Delegated)

```
Mail.ReadWrite          — Read and write mail
Calendars.ReadWrite     — Read and write calendars
Contacts.ReadWrite      — Read and write contacts
Files.ReadWrite         — Read and write OneDrive files
People.Read             — Read people for search
User.Read               — Read user profile
offline_access          — Refresh tokens
```

---

## 5. Graph Client

### Core HTTP Client

```swift
actor GraphClient {
    let tokenManager: TokenManager
    let baseURL = "https://graph.microsoft.com/v1.0"
    let session = URLSession.shared
    
    // Retry configuration
    let maxRetries = 3
    let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    
    func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        query: [String: String]? = nil,
        body: (any Encodable)? = nil,
        accountId: String? = nil
    ) async throws -> T
    
    // Pagination support
    func requestAll<T: Decodable>(
        path: String,
        query: [String: String]? = nil,
        accountId: String? = nil
    ) async throws -> [T]  // Follows @odata.nextLink automatically
}
```

### Request Builder

OData query parameter builder for clean API:

```swift
let messages = try await client.request(
    .get,
    path: "/me/mailFolders/inbox/messages",
    query: GraphQuery()
        .select("id", "subject", "from", "receivedDateTime", "isRead")
        .filter("isRead eq false")
        .orderBy("receivedDateTime desc")
        .top(25)
        .build()
)
```

### Rate Limiting & Retry

```swift
// On 429: Read Retry-After header, wait, retry
// On 5xx: Exponential backoff (1s, 2s, 4s)
// On 401: Refresh token, retry once
// On other errors: Throw immediately with descriptive error
```

### Error Handling

```swift
enum GraphError: Error, LocalizedError {
    case unauthorized(String)           // 401 — token expired or invalid
    case forbidden(String)              // 403 — missing permissions
    case notFound(String)               // 404 — resource not found
    case rateLimited(retryAfter: Int)   // 429 — throttled
    case serverError(Int, String)       // 5xx — Graph API error
    case networkError(Error)            // Connection issues
    case decodingError(Error)           // Response parsing failed
    
    var errorDescription: String? { ... }
}
```

---

## 6. Services (Core Library)

### MailService

```swift
protocol MailServiceProtocol: Sendable {
    // Read
    func listMessages(folder: String?, unreadOnly: Bool, count: Int, skip: Int, includeBody: Bool) async throws -> [Message]
    func getMessage(id: String, includeBody: Bool) async throws -> Message
    func searchMessages(query: String, count: Int) async throws -> [Message]
    func listFolders() async throws -> [MailFolder]
    
    // Write
    func sendMessage(_ draft: DraftMessage) async throws
    func createDraft(_ draft: DraftMessage) async throws -> Message
    func replyToMessage(id: String, body: String, replyAll: Bool) async throws
    func forwardMessage(id: String, to: [String], comment: String?) async throws
    func moveMessage(id: String, destinationFolder: String) async throws
    func deleteMessage(id: String) async throws
    func updateMessage(id: String, isRead: Bool?, flag: MessageFlag?) async throws
    
    // Attachments
    func listAttachments(messageId: String) async throws -> [Attachment]
    func getAttachment(messageId: String, attachmentId: String) async throws -> AttachmentContent
    func downloadAttachment(messageId: String, attachmentId: String, to: URL) async throws
}
```

### CalendarService

```swift
protocol CalendarServiceProtocol: Sendable {
    // Read
    func listEvents(from: Date, to: Date, calendarId: String?) async throws -> [Event]
    func getEvent(id: String) async throws -> Event
    func searchEvents(query: String) async throws -> [Event]
    func listCalendars() async throws -> [Calendar]
    func checkAvailability(attendees: [String], from: Date, to: Date, duration: Int) async throws -> [ScheduleInfo]
    
    // Write
    func createEvent(_ draft: DraftEvent) async throws -> Event
    func updateEvent(id: String, updates: EventUpdate) async throws -> Event
    func deleteEvent(id: String, notify: Bool) async throws
    func respondToEvent(id: String, response: EventResponse) async throws  // accept, decline, tentative
}
```

### ContactService

```swift
protocol ContactServiceProtocol: Sendable {
    func listContacts(count: Int, skip: Int) async throws -> [Contact]
    func getContact(id: String) async throws -> Contact
    func searchContacts(query: String) async throws -> [Contact]
    func createContact(_ draft: DraftContact) async throws -> Contact
    func updateContact(id: String, updates: ContactUpdate) async throws -> Contact
    func deleteContact(id: String) async throws
}
```

### DriveService

```swift
protocol DriveServiceProtocol: Sendable {
    func listItems(path: String?, folderId: String?) async throws -> [DriveItem]
    func getItem(id: String) async throws -> DriveItem
    func downloadFile(id: String, to: URL) async throws
    func uploadFile(from: URL, to: String) async throws -> DriveItem  // Handles chunked upload for >4MB
    func deleteItem(id: String) async throws
    func searchFiles(query: String) async throws -> [DriveItem]
}
```

### SearchService

```swift
protocol SearchServiceProtocol: Sendable {
    func unifiedSearch(query: String, entityTypes: [SearchEntityType], count: Int) async throws -> [SearchResult]
}

enum SearchEntityType: String, Codable {
    case message, event, driveItem, contact
}
```

---

## 7. CLI Commands

### Command Structure

```
outlook
├── auth
│   ├── login [--tenant ID] [--client-id ID]
│   ├── logout [EMAIL]
│   ├── accounts
│   ├── switch EMAIL
│   └── status
├── mail
│   ├── list [--folder FOLDER] [--unread] [--count N] [--body]
│   ├── read MESSAGE_ID [--raw]
│   ├── send TO [--cc CC] [--bcc BCC] --subject SUBJECT --body BODY [--attach FILE...]
│   ├── reply MESSAGE_ID --body BODY [--all]
│   ├── forward MESSAGE_ID --to TO [--comment TEXT]
│   ├── move MESSAGE_ID --to FOLDER
│   ├── delete MESSAGE_ID [--force]
│   ├── mark MESSAGE_ID [--read|--unread] [--flag|--unflag]
│   ├── folders
│   ├── search QUERY [--count N]
│   └── attachments MESSAGE_ID [--download DIR]
├── cal
│   ├── list [--from DATE] [--to DATE] [--calendar ID] [--count N]
│   ├── get EVENT_ID
│   ├── create --subject SUBJECT --start DATETIME --end DATETIME [--location LOC] [--attendees EMAIL...]
│   ├── update EVENT_ID [--subject] [--start] [--end] [--location]
│   ├── delete EVENT_ID [--notify]
│   ├── respond EVENT_ID --accept|--decline|--tentative [--message TEXT]
│   ├── free-busy --attendees EMAIL... --from DATE --to DATE [--duration MIN]
│   ├── calendars
│   └── search QUERY
├── contact
│   ├── list [--count N]
│   ├── get CONTACT_ID
│   ├── create --name NAME [--email EMAIL] [--phone PHONE] [--company COMPANY]
│   ├── update CONTACT_ID [--name] [--email] [--phone]
│   ├── delete CONTACT_ID
│   └── search QUERY
├── drive
│   ├── list [PATH] [--folder-id ID]
│   ├── get ITEM_ID
│   ├── download ITEM_ID [--output DIR]
│   ├── upload FILE --to PATH
│   ├── delete ITEM_ID
│   └── search QUERY
├── search QUERY [--type message,event,driveItem,contact] [--count N]
└── mcp
    ├── serve [--read-only] [--tools mail,calendar,contacts,drive]
    └── tools
```

### Output Formats

All commands support `--format` flag:

```
--format table    (default, human-readable)
--format json     (structured, for piping)
--format compact  (one-line-per-item, for grep)
```

### Environment Variables

```bash
OUTLOOK_CLIENT_ID       # Azure app client ID (required for first login)
OUTLOOK_TENANT_ID       # Azure tenant ID (default: "common")
OUTLOOK_ACCOUNT         # Default account email
OUTLOOK_FORMAT          # Default output format
OUTLOOK_READ_ONLY       # Disable write operations
```

---

## 8. MCP Server

### Tool Design

Following elyxlz's focused approach — each tool maps to a clear action:

#### Mail Tools (11)

| Tool | Parameters | Description |
|------|-----------|-------------|
| `outlook_mail_list` | folder?, unread_only?, count?, include_body? | List messages |
| `outlook_mail_read` | message_id | Read full message with body |
| `outlook_mail_send` | to, subject, body, cc?, bcc?, attachments? | Send email |
| `outlook_mail_reply` | message_id, body, reply_all? | Reply to message |
| `outlook_mail_forward` | message_id, to, comment? | Forward message |
| `outlook_mail_move` | message_id, folder | Move to folder |
| `outlook_mail_delete` | message_id | Delete message |
| `outlook_mail_mark` | message_id, is_read?, flag? | Mark read/unread/flagged |
| `outlook_mail_search` | query, count? | Search messages |
| `outlook_mail_folders` | | List mail folders |
| `outlook_mail_attachments` | message_id, download_path? | List/download attachments |

#### Calendar Tools (9)

| Tool | Parameters | Description |
|------|-----------|-------------|
| `outlook_cal_list` | from?, to?, calendar_id?, count? | List events |
| `outlook_cal_get` | event_id | Get event details |
| `outlook_cal_create` | subject, start, end, location?, attendees?, body? | Create event |
| `outlook_cal_update` | event_id, subject?, start?, end?, location? | Update event |
| `outlook_cal_delete` | event_id, notify? | Delete event |
| `outlook_cal_respond` | event_id, response, message? | Accept/decline/tentative |
| `outlook_cal_free_busy` | attendees, from, to, duration? | Check availability |
| `outlook_cal_calendars` | | List calendars |
| `outlook_cal_search` | query | Search events |

#### Contact Tools (6)

| Tool | Parameters | Description |
|------|-----------|-------------|
| `outlook_contact_list` | count?, skip? | List contacts |
| `outlook_contact_get` | contact_id | Get contact details |
| `outlook_contact_create` | name, email?, phone?, company? | Create contact |
| `outlook_contact_update` | contact_id, name?, email?, phone? | Update contact |
| `outlook_contact_delete` | contact_id | Delete contact |
| `outlook_contact_search` | query | Search contacts |

#### Drive Tools (6)

| Tool | Parameters | Description |
|------|-----------|-------------|
| `outlook_drive_list` | path?, folder_id? | List files/folders |
| `outlook_drive_get` | item_id | Get file metadata |
| `outlook_drive_download` | item_id, output_path? | Download file |
| `outlook_drive_upload` | file_path, destination_path | Upload file |
| `outlook_drive_delete` | item_id | Delete file/folder |
| `outlook_drive_search` | query | Search files |

#### Utility Tools (3)

| Tool | Parameters | Description |
|------|-----------|-------------|
| `outlook_search` | query, entity_types?, count? | Unified search |
| `outlook_auth_status` | | Show auth status |
| `outlook_accounts` | | List accounts |

**Total: 35 tools** — comprehensive but focused.

### Read-Only Mode

When `--read-only` flag is set or `OUTLOOK_READ_ONLY=true`:
- All read/list/search tools work normally
- All create/update/delete/send tools return error: "Read-only mode enabled"
- Useful for agent safety — let Claude read email without risk of sending

### Tool Filtering

```bash
# Only expose mail tools
outlook mcp serve --tools mail

# Mail + calendar only
outlook mcp serve --tools mail,calendar
```

---

## 9. Models (Codable Types)

### Message

```swift
struct Message: Codable, Identifiable, Sendable {
    let id: String
    let subject: String?
    let from: EmailAddress?
    let toRecipients: [EmailAddress]
    let ccRecipients: [EmailAddress]?
    let bccRecipients: [EmailAddress]?
    let receivedDateTime: Date
    let sentDateTime: Date?
    let isRead: Bool
    let isDraft: Bool
    let importance: Importance
    let flag: MessageFlag?
    let body: MessageBody?
    let bodyPreview: String?
    let hasAttachments: Bool
    let parentFolderId: String?
    let conversationId: String?
    let webLink: String?
}

struct EmailAddress: Codable, Sendable {
    let name: String?
    let address: String
}

struct MessageBody: Codable, Sendable {
    let contentType: String  // "text" or "html"
    let content: String
}

enum Importance: String, Codable, Sendable {
    case low, normal, high
}
```

### Event

```swift
struct Event: Codable, Identifiable, Sendable {
    let id: String
    let subject: String?
    let body: MessageBody?
    let start: DateTimeTimeZone
    let end: DateTimeTimeZone
    let location: Location?
    let attendees: [Attendee]?
    let organizer: EmailAddress?
    let isAllDay: Bool
    let isCancelled: Bool
    let responseStatus: ResponseStatus?
    let recurrence: Recurrence?
    let onlineMeeting: OnlineMeeting?
    let webLink: String?
}

struct DateTimeTimeZone: Codable, Sendable {
    let dateTime: String
    let timeZone: String
}

struct Attendee: Codable, Sendable {
    let emailAddress: EmailAddress
    let type: String  // required, optional, resource
    let status: ResponseStatus?
}
```

### Contact

```swift
struct Contact: Codable, Identifiable, Sendable {
    let id: String
    let displayName: String?
    let givenName: String?
    let surname: String?
    let emailAddresses: [TypedEmailAddress]?
    let businessPhones: [String]?
    let mobilePhone: String?
    let companyName: String?
    let jobTitle: String?
    let department: String?
    let businessAddress: PhysicalAddress?
    let birthday: String?
}
```

### DriveItem

```swift
struct DriveItem: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let size: Int64?
    let createdDateTime: Date?
    let lastModifiedDateTime: Date?
    let webUrl: String?
    let folder: FolderFacet?     // non-nil if folder
    let file: FileFacet?         // non-nil if file
    let parentReference: ItemReference?
}

struct FolderFacet: Codable, Sendable {
    let childCount: Int
}

struct FileFacet: Codable, Sendable {
    let mimeType: String
}
```

---

## 10. Implementation Phases

### Phase 1: Foundation (MVP)
- Project scaffold (Package.swift, folder structure)
- Device code authentication flow
- Keychain token storage
- GraphClient with retry + rate limiting
- MailService: list, read, send, reply
- CalendarService: list, create, respond
- CLI commands for mail + calendar
- MCP server with mail + calendar tools
- Basic tests

### Phase 2: Full Coverage
- ContactService full CRUD
- DriveService: browse, download, upload (including chunked >4MB)
- Search service (unified)
- Multi-account support
- Mail attachments (list, download, add to outgoing)
- All remaining CLI commands
- All remaining MCP tools
- Read-only mode
- Comprehensive tests

### Phase 3: Polish
- Tool filtering for MCP
- Output formatters (table, json, compact)
- Mail folder management
- Calendar free/busy scheduling
- Error messages and help text
- README with setup guide
- AGENTS.md with pointer to agent-scripts
- Performance optimization (parallel requests where safe)
- E2E test suite

---

## 11. Azure App Registration Guide

Include in README for users:

1. Go to https://portal.azure.com → Azure Active Directory → App registrations
2. New registration:
   - Name: "OutlookCLI"
   - Supported account types: "Accounts in any org directory + personal Microsoft accounts"
   - Redirect URI: leave empty
3. After creation:
   - Copy **Application (client) ID** → this is your `OUTLOOK_CLIENT_ID`
   - Copy **Directory (tenant) ID** → this is your `OUTLOOK_TENANT_ID` (or use "common")
4. Authentication → Advanced settings:
   - "Allow public client flows" → **Yes**
5. API permissions → Add:
   - Microsoft Graph (delegated): Mail.ReadWrite, Calendars.ReadWrite, Contacts.ReadWrite, Files.ReadWrite, People.Read, User.Read
   - Grant admin consent (if available)

---

## 12. Technical Considerations

### Rate Limits
- 10,000 requests per 10 minutes per app per tenant
- Implement exponential backoff with jitter on 429
- Respect `Retry-After` header
- Cache where appropriate (e.g., folder list)

### Token Refresh
- Access tokens expire in ~1 hour
- Refresh tokens last ~90 days
- Always try silent refresh before device code
- If refresh fails, prompt user to re-authenticate

### Large File Upload (OneDrive)
- Files < 4MB: Simple PUT
- Files > 4MB: Create upload session, chunked PUT (4.8MB chunks)
- Resume support for interrupted uploads

### Timezone Handling
- Calendar events use `Prefer: outlook.timezone` header
- Default to system timezone
- `--timezone` flag for override
- Store dates as ISO 8601

### Personal vs Work Accounts
- Personal accounts: Limited API surface (no Teams, SharePoint)
- Work accounts: Full API surface
- Use `tenant_id = "common"` to support both
- Gracefully degrade when features unavailable

---

## 13. Testing Strategy

### Unit Tests (OutlookCoreTests)
- **AuthTests**: Token parsing, keychain mock, refresh logic
- **GraphClientTests**: Request building, retry logic, pagination, error handling
- **MailServiceTests**: Message parsing, draft creation, folder operations
- **CalendarServiceTests**: Event parsing, date handling, recurrence
- **ContactServiceTests**: Contact parsing, search query building
- **DriveServiceTests**: Item parsing, upload session logic

### Integration Tests (Manual/CI)
- Full auth flow with real Azure AD
- Send + receive email roundtrip
- Calendar create + read + delete
- Contact CRUD cycle
- File upload + download + delete

### CLI Tests (OutlookCLITests)
- Command parsing (ArgumentParser validation)
- Output formatting (table, json, compact)
- Error presentation

---

*This plan is the single source of truth. All beads will be derived from this document.*
*Version: 1.0 — 2026-02-10*
