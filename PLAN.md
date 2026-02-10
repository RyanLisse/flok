# Flok — Microsoft 365 CLI + MCP Server

> *Your flock of Microsoft 365 tools.* 🐦

A native Swift CLI and MCP server for Microsoft 365 (Outlook Mail, Calendar, Contacts, OneDrive) built on the Peekaboo architecture. Agent-native from day one.

---

## 1. Vision & Goals

**What:** A fast, focused CLI + MCP server that gives humans and AI agents first-class access to Microsoft 365 via the Graph API.

**Why:** Existing solutions are Python/TypeScript, bloated (90+ tools), or poorly architected. We need something that fits our Swift ecosystem (alongside Caly, Contactbook, Briefly, Quorum) and follows agent-native principles.

**Who:** Ryan (primary user), AI agents (Clawdbot, Claude Code, coding agents), anyone who wants CLI access to their Microsoft 365.

**Key Differentiators:**
- Swift-native, macOS-first (Keychain, URLSession)
- Agent-native architecture (MCP resources, prompts, escape hatch)
- Focused tool set (~25 tools covering 95% of use cases)
- Device code auth (works in any terminal, SSH, headless)
- Multi-account support from day one

---

## 2. Architecture

### Peekaboo Pattern

```
Sources/
├── FlokCore/              # Framework-agnostic library
│   ├── Graph/
│   │   ├── GraphClient.swift       # HTTP client with retry + pagination
│   │   ├── GraphEndpoints.swift    # Typed endpoint definitions
│   │   ├── GraphError.swift        # Error types + Graph error parsing
│   │   └── RateLimiter.swift       # Token bucket + Retry-After respect
│   ├── Auth/
│   │   ├── DeviceCodeFlow.swift    # OAuth 2.0 device code grant
│   │   ├── TokenManager.swift      # Silent refresh + multi-account
│   │   ├── KeychainStorage.swift   # macOS Keychain wrapper
│   │   └── AuthTypes.swift         # Token, Account models
│   ├── Mail/
│   │   ├── MailService.swift       # Mail operations
│   │   └── MailModels.swift        # Message, Attachment, Folder
│   ├── Calendar/
│   │   ├── CalendarService.swift   # Event operations
│   │   └── CalendarModels.swift    # Event, Attendee, FreeBusy
│   ├── Contacts/
│   │   ├── ContactService.swift    # Contact operations
│   │   └── ContactModels.swift     # Contact, EmailAddress
│   ├── Drive/
│   │   ├── DriveService.swift      # OneDrive operations
│   │   ├── DriveModels.swift       # DriveItem, Folder
│   │   └── ChunkedUpload.swift     # Large file upload sessions
│   └── Search/
│       └── UnifiedSearch.swift     # Cross-service search
│
├── FlokCLI/               # Commander subcommands
│   ├── MainCommand.swift
│   ├── AuthCommands/
│   │   ├── LoginCommand.swift      # flok login
│   │   ├── LogoutCommand.swift     # flok logout
│   │   ├── AccountsCommand.swift   # flok accounts
│   │   └── SwitchCommand.swift     # flok switch <account>
│   ├── MailCommands/
│   │   ├── InboxCommand.swift      # flok inbox [--unread] [--top N]
│   │   ├── ReadCommand.swift       # flok read <id>
│   │   ├── SendCommand.swift       # flok send --to --subject --body
│   │   ├── ReplyCommand.swift      # flok reply <id> --body
│   │   ├── MoveCommand.swift       # flok move <id> --to <folder>
│   │   ├── DeleteCommand.swift     # flok delete <id>
│   │   └── SearchCommand.swift     # flok search "query"
│   ├── CalendarCommands/
│   │   ├── EventsCommand.swift     # flok events [--from --to]
│   │   ├── CreateEventCommand.swift # flok event create --title --start --end
│   │   ├── RespondCommand.swift    # flok event respond <id> --accept|decline
│   │   └── FreeBusyCommand.swift   # flok freebusy --start --end
│   ├── ContactCommands/
│   │   ├── ContactsCommand.swift   # flok contacts [--search]
│   │   └── ContactCRUD.swift       # flok contact create|update|delete
│   ├── DriveCommands/
│   │   ├── FilesCommand.swift      # flok files [path]
│   │   ├── DownloadCommand.swift   # flok download <path> [--out]
│   │   ├── UploadCommand.swift     # flok upload <file> [--to path]
│   │   └── SearchFilesCommand.swift # flok files search "query"
│   └── MCPCommand.swift            # flok mcp serve
│
├── FlokMCP/               # MCP server
│   ├── FlokMCPServer.swift
│   ├── Tools/
│   │   ├── MailTools.swift         # 7 tools
│   │   ├── CalendarTools.swift     # 5 tools
│   │   ├── ContactTools.swift      # 4 tools
│   │   ├── DriveTools.swift        # 5 tools
│   │   ├── SearchTools.swift       # 1 unified search tool
│   │   ├── AuthTools.swift         # 2 tools
│   │   └── GraphTool.swift         # 1 raw escape hatch
│   ├── Resources/
│   │   ├── AccountResource.swift   # Current account info
│   │   ├── InboxSummary.swift      # Unread count, recent subjects
│   │   └── TodayEvents.swift       # Today's calendar events
│   ├── Prompts/
│   │   ├── EmailTriagePrompt.swift # Triage unread inbox
│   │   ├── ScheduleMeeting.swift   # Find time + create event
│   │   └── DailyBriefPrompt.swift  # Morning email + calendar brief
│   └── MCPTypes.swift
│
└── Flok/                  # Executable entry point
    └── main.swift
```

### Package.swift Dependencies

```swift
dependencies: [
    // CLI
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    
    // MCP
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.1.0"),
    
    // Logging
    .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
],
targets: [
    .target(name: "FlokCore", dependencies: [
        .product(name: "Logging", package: "swift-log"),
    ], swiftSettings: swift6Settings),
    
    .target(name: "FlokCLI", dependencies: [
        "FlokCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
    ], swiftSettings: swift6Settings),
    
    .target(name: "FlokMCP", dependencies: [
        "FlokCore",
        .product(name: "ModelContextProtocol", package: "swift-sdk"),
    ], swiftSettings: swift6Settings),
    
    .executableTarget(name: "Flok", dependencies: [
        "FlokCLI", "FlokMCP"
    ]),
    
    .testTarget(name: "FlokCoreTests", dependencies: ["FlokCore"]),
    .testTarget(name: "FlokCLITests", dependencies: ["FlokCLI"]),
    .testTarget(name: "FlokMCPTests", dependencies: ["FlokMCP"]),
]
```

### Swift 6 Settings

```swift
let swift6Settings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]
```

---

## 3. Authentication

### Device Code Flow (Primary)

```
User runs: flok login
  → App requests device code from Azure AD
  → Shows: "Visit https://microsoft.com/devicelogin, enter code: ABCD-EFGH"
  → User authenticates in browser
  → App polls for token
  → Stores access + refresh token in Keychain
  → Done. All subsequent commands use silent refresh.
```

### Token Management

| Component | Implementation |
|-----------|---------------|
| Storage | macOS Keychain (service: `com.flok.tokens`) |
| Refresh | Silent `acquire_token_silent` before every API call |
| Multi-account | Separate Keychain entries per account email |
| Fallback | File-based cache at `~/.flok/tokens.json` (0600 perms) |

### Azure App Registration

**Required setup (one-time):**
1. Register app at https://portal.azure.com → App registrations
2. Set "Allow public client flows" = Yes
3. Supported account types: Personal + Work/School
4. Add permissions: `Mail.ReadWrite`, `Calendars.ReadWrite`, `Contacts.ReadWrite`, `Files.ReadWrite`, `User.Read`
5. No client secret needed

**Config:**
```bash
export PIGEON_CLIENT_ID="your-app-client-id"
export PIGEON_TENANT_ID="common"  # or specific tenant
```

---

## 4. Core Services

### GraphClient

The backbone — handles all HTTP communication with Microsoft Graph.

**Features:**
- URLSession-based (no external HTTP deps)
- Automatic retry with exponential backoff on 429/5xx
- Respects `Retry-After` header
- Auto-pagination via `@odata.nextLink`
- `$select`, `$filter`, `$orderby`, `$top` query parameter support
- Request/response logging (debug mode)

**Key patterns from research:**
```swift
// Retry logic (from microsoft-mcp)
if response.statusCode == 429 {
    let retryAfter = response.headers["Retry-After"].flatMap(Int.init) ?? 5
    try await Task.sleep(for: .seconds(min(retryAfter, 60)))
    continue
}

// Pagination (from Lokka PageIterator pattern)
var allItems: [T] = []
var nextLink: String? = initialURL
while let url = nextLink {
    let page = try await fetch(url)
    allItems.append(contentsOf: page.value)
    nextLink = page.odataNextLink
}
```

### Rate Limiting

| Resource | Limit | Strategy |
|----------|-------|----------|
| Graph API per app | 10,000 req/10 min | Token bucket |
| Mailbox operations | 10,000 req/10 min | Per-user tracking |
| OneDrive | 1,200 req/min | Separate bucket |
| Calendar | 1,200 req/min | Separate bucket |

### Error Handling

```swift
enum FlokError: Error {
    case notAuthenticated
    case tokenExpired
    case rateLimited(retryAfter: Int)
    case graphError(code: String, message: String)
    case networkError(underlying: Error)
    case permissionDenied(scope: String)
}
```

---

## 5. MCP Tools (25 total)

### Mail Tools (7)

| Tool | Description | Parameters |
|------|-------------|------------|
| `flok_inbox` | List inbox messages | `top`, `unread_only`, `folder` |
| `flok_read_email` | Read full email with attachments | `message_id`, `include_attachments` |
| `flok_send_email` | Send new email | `to`, `cc`, `bcc`, `subject`, `body`, `attachments` |
| `flok_reply_email` | Reply to email | `message_id`, `body`, `reply_all` |
| `flok_move_email` | Move email to folder | `message_id`, `destination_folder` |
| `flok_delete_email` | Delete email | `message_id` |
| `flok_search_email` | Search emails | `query`, `folder`, `from`, `date_range` |

### Calendar Tools (5)

| Tool | Description | Parameters |
|------|-------------|------------|
| `flok_events` | List calendar events | `start`, `end`, `calendar_id` |
| `flok_create_event` | Create calendar event | `title`, `start`, `end`, `location`, `attendees`, `body` |
| `flok_update_event` | Update event | `event_id`, fields to update |
| `flok_respond_event` | Accept/decline/tentative | `event_id`, `response` |
| `flok_freebusy` | Check availability | `start`, `end`, `attendees` |

### Contact Tools (4)

| Tool | Description | Parameters |
|------|-------------|------------|
| `flok_contacts` | List/search contacts | `search`, `top` |
| `flok_create_contact` | Create contact | `name`, `email`, `phone`, etc. |
| `flok_update_contact` | Update contact | `contact_id`, fields |
| `flok_delete_contact` | Delete contact | `contact_id` |

### Drive Tools (5)

| Tool | Description | Parameters |
|------|-------------|------------|
| `flok_files` | List files/folders | `path`, `search` |
| `flok_download` | Download file | `item_id` or `path`, `output_path` |
| `flok_upload` | Upload file | `local_path`, `remote_path` |
| `flok_delete_file` | Delete file/folder | `item_id` or `path` |
| `flok_search_files` | Search OneDrive | `query` |

### Utility Tools (4)

| Tool | Description | Parameters |
|------|-------------|------------|
| `flok_search` | Unified cross-service search | `query`, `entity_types` |
| `flok_login` | Start device code auth | `tenant_id` |
| `flok_accounts` | List authenticated accounts | — |
| `flok_graph` | **Raw Graph API escape hatch** | `method`, `path`, `body`, `query_params` |

### Agent-Native: The Escape Hatch

The `flok_graph` tool gives agents access to ANY Graph API endpoint:

```json
{
  "method": "GET",
  "path": "/me/mailFolders/Inbox/messageRules",
  "query_params": { "$top": "10" }
}
```

This is critical — agents will discover use cases we didn't anticipate.

---

## 6. MCP Resources (Context Injection)

Resources prevent context starvation — agents always know the current state.

| Resource URI | Description | Auto-refresh |
|-------------|-------------|--------------|
| `flok://account` | Current account email, name, tenant | On auth change |
| `flok://inbox/summary` | Unread count, last 5 subjects, flagged count | Every 5 min |
| `flok://calendar/today` | Today's events with times + locations | Every 15 min |
| `flok://calendar/next` | Next upcoming event | Every 5 min |

---

## 7. MCP Prompts (Composable Workflows)

| Prompt | Description | Uses Tools |
|--------|-------------|------------|
| `email-triage` | "Review my unread inbox, categorize by urgency, draft responses for routine items" | inbox, read, reply |
| `schedule-meeting` | "Find a free slot with [attendees] this week and create the event" | freebusy, create_event |
| `daily-brief` | "Summarize today's emails and calendar — what needs my attention?" | inbox, events |
| `find-file` | "Search OneDrive for [query] and summarize what you find" | search_files, download |

---

## 8. CLI Commands

```bash
# Authentication
flok login                          # Device code flow
flok logout [--all]                 # Remove tokens
flok accounts                       # List accounts
flok switch <email>                 # Switch active account

# Mail
flok inbox [--unread] [--top 20]   # List inbox
flok read <id>                      # Read email
flok send --to <email> --subject "..." --body "..."
flok reply <id> [--all] --body "..."
flok move <id> --to Archive
flok delete <id>
flok search "quarterly report"

# Calendar
flok events [--from today --to +7d]
flok event create --title "..." --start "..." --end "..."
flok event respond <id> --accept|--decline|--tentative
flok freebusy --start "..." --end "..." [--attendees a@b.com]

# Contacts
flok contacts [--search "name"]
flok contact create --name "..." --email "..."
flok contact update <id> --phone "..."
flok contact delete <id>

# OneDrive
flok files [/path/to/folder]
flok download <path> [--out ./local]
flok upload ./file.pdf [--to /Documents/]
flok files search "presentation"

# MCP
flok mcp serve                      # Start MCP server (stdio)
flok mcp tools                      # List available tools

# Utility
flok whoami                         # Current account info
flok search "query"                 # Unified search
```

### Output Formats

```bash
flok inbox                    # Human-friendly table
flok inbox --json             # JSON (for piping/agents)
flok inbox --json --compact   # Minimal JSON (fewer tokens)
```

---

## 9. Phased Implementation

### Phase 1 — Core MVP (Week 1-2)

**Goal:** Auth works, can read/send email, list calendar events.

| # | Task | Depends On |
|---|------|------------|
| 1.1 | Package.swift + project structure | — |
| 1.2 | GraphClient (URLSession, retry, pagination) | — |
| 1.3 | DeviceCodeFlow + TokenManager | — |
| 1.4 | KeychainStorage | — |
| 1.5 | Auth CLI commands (login, logout, accounts) | 1.3, 1.4 |
| 1.6 | Mail models + MailService | 1.2 |
| 1.7 | Mail CLI commands (inbox, read, send, reply) | 1.5, 1.6 |
| 1.8 | Calendar models + CalendarService | 1.2 |
| 1.9 | Calendar CLI commands (events, create, respond) | 1.5, 1.8 |
| 1.10 | MCP server skeleton + mail tools | 1.6 |
| 1.11 | MCP calendar tools | 1.8, 1.10 |
| 1.12 | MCP resources (account, inbox summary, today events) | 1.10 |
| 1.13 | Unit tests for Core | 1.2-1.8 |
| 1.14 | Integration tests (mock Graph responses) | 1.13 |

### Phase 2 — Extended (Week 3-4)

**Goal:** Full contacts, OneDrive, multi-account, unified search.

| # | Task | Depends On |
|---|------|------------|
| 2.1 | Contact models + ContactService | 1.2 |
| 2.2 | Contact CLI commands | 2.1 |
| 2.3 | MCP contact tools | 2.1 |
| 2.4 | Drive models + DriveService | 1.2 |
| 2.5 | ChunkedUpload for large files (>4MB) | 2.4 |
| 2.6 | Drive CLI commands | 2.4 |
| 2.7 | MCP drive tools | 2.4 |
| 2.8 | UnifiedSearch service | 1.2 |
| 2.9 | Search CLI + MCP tool | 2.8 |
| 2.10 | Multi-account support | 1.3 |
| 2.11 | Raw Graph API escape hatch tool | 1.2 |
| 2.12 | MCP prompts (email-triage, schedule-meeting, daily-brief) | 1.10 |
| 2.13 | Tests for Phase 2 | 2.1-2.12 |

### Phase 3 — Polish (Week 5+)

**Goal:** Production-ready, robust, documented.

| # | Task | Depends On |
|---|------|------------|
| 3.1 | Read-only mode (env flag disables write operations) | All |
| 3.2 | Completion signals in all tool results | All tools |
| 3.3 | context.md generation (auto-document usage patterns) | 3.2 |
| 3.4 | Homebrew formula | 3.1 |
| 3.5 | E2E test suite (real Graph API with test account) | All |
| 3.6 | Approval flow matrix (stakes × reversibility) | All |
| 3.7 | Performance benchmarks | 3.5 |
| 3.8 | ClawdHub skill publication | 3.4 |

---

## 10. Agent-Native Checklist

Every item is mandatory per project standards:

- [ ] **Parity** — CLI commands mirror MCP tools 1:1
- [ ] **Granularity** — Each tool does one thing (no `manage_email` mega-tool)
- [ ] **Composability** — MCP prompts compose tools into workflows
- [ ] **Emergent Capability** — `flok_graph` escape hatch for any Graph endpoint
- [ ] **Improvement Over Time** — context.md captures agent usage patterns
- [ ] **MCP Resources** — Account, inbox summary, today's calendar
- [ ] **MCP Prompts** — Email triage, schedule meeting, daily brief
- [ ] **Completion Signals** — Every tool result includes success/failure + next steps
- [ ] **Approval Flow** — Delete/send require confirmation, read operations don't

---

## 11. Security

### Permissions Scoping

| Operation Type | Required Scope | Risk Level |
|---------------|---------------|------------|
| Read email | `Mail.Read` | Low |
| Send/modify email | `Mail.ReadWrite` | Medium |
| Read calendar | `Calendars.Read` | Low |
| Create/modify events | `Calendars.ReadWrite` | Medium |
| Read contacts | `Contacts.Read` | Low |
| Modify contacts | `Contacts.ReadWrite` | Medium |
| Read files | `Files.Read` | Low |
| Upload/delete files | `Files.ReadWrite` | High |

### Read-Only Mode

```bash
export PIGEON_READ_ONLY=true  # Disables all write operations
```

In read-only mode:
- Send, reply, create, update, delete → error with clear message
- List, read, search, download → work normally
- MCP tools respect the same flag

---

## 12. Integration with Clawdbot

### Briefly Integration
Flok replaces the current `gog` (Google) email/calendar in the morning brief when Microsoft 365 is the primary account.

### Daily Workflow
```
Morning Brief → flok://inbox/summary + flok://calendar/today
Email Triage  → email-triage prompt
Scheduling    → schedule-meeting prompt
File Lookup   → flok files search
```

### ClawdHub Skill
```yaml
name: flok
description: Microsoft 365 CLI + MCP for mail, calendar, contacts, and OneDrive
commands:
  - flok inbox
  - flok events
  - flok contacts
  - flok files
  - flok mcp serve
```

---

*Last updated: 2026-02-10*
*Research source: ~/clawd/research/outlook-cli-mcp/research.md*
