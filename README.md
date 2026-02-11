# 🐦 Flok

**Your carrier flok for Microsoft 365.** Swift CLI + MCP server for Mail, Calendar, Contacts, and OneDrive — all via Microsoft Graph API.

![Swift 6](https://img.shields.io/badge/Swift-6.0-orange) ![macOS](https://img.shields.io/badge/macOS-14+-blue) ![License](https://img.shields.io/badge/license-MIT-green)

---

## What It Does

Flok gives you (and your AI agents) full access to Microsoft 365:

- **📬 Mail** — List, read, send, reply, search, move, delete
- **📅 Calendar** — Events, scheduling, free/busy, accept/decline
- **👤 Contacts** — CRUD + search
- **📁 OneDrive** — Browse, download, search files
- **🔓 Auth** — Device code flow + Keychain token storage
- **🤖 MCP Server** — 20+ tools for AI agents via stdio

## Architecture

```
Sources/
├── Core/           # Graph client, auth, models (zero CLI deps)
│   ├── Auth/       # Device code flow, Keychain storage, token manager
│   ├── Graph/      # HTTP client with retry, pagination
│   └── Models/     # Mail, Calendar, Contact, Drive types
├── CLI/            # Commander subcommands
├── MCP/            # MCP server, tools, resources, prompts
│   ├── Tools/      # Handler per operation (mail, calendar, etc.)
│   ├── Resources/  # Context injection (inbox summary, today's calendar)
│   └── Prompts/    # Workflow templates (triage, schedule, brief)
└── Executable/     # Entry point
```

**Key decisions:**
- **URLSession** for HTTP (not AsyncHTTPClient) — simpler, sufficient
- **Keychain-first** token storage — macOS native, secure
- **Device code flow** — works in any terminal, headless, SSH
- **Swift 6** with StrictConcurrency, ExistentialAny
- **Handler pattern** for MCP tools, **Provider pattern** for Graph API

## Quick Start

### 1. Register an Azure AD App

1. Go to [Azure Portal → App registrations](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps)
2. New registration → Name: "Flok" → Personal + Work accounts
3. **Allow public client flows** = Yes
4. Copy the **Application (client) ID**

### 2. Install & Authenticate

```bash
# Clone and build
git clone https://github.com/RyanLisse/Flok.git
cd Flok
swift build

# Set your client ID
export FLOK_CLIENT_ID="your-app-client-id"

# Login (opens browser for device code)
flok auth login

# Verify
flok auth status
```

### 3. Use the CLI

```bash
flok mail list              # List inbox
flok auth status            # Check auth
flok serve                  # Start MCP server
```

### 4. Use as MCP Server

Add to your MCP client config:

```json
{
  "mcpServers": {
    "flok": {
      "command": "/path/to/flok",
      "args": ["serve"],
      "env": {
        "FLOK_CLIENT_ID": "your-client-id"
      }
    }
  }
}
```

## MCP Tools

| Tool | Description | Write? |
|------|-------------|--------|
| `list-mail` | List messages from inbox/folder | No |
| `read-mail` | Get full message content | No |
| `send-mail` | Send a new email | Yes |
| `reply-mail` | Reply to a message | Yes |
| `search-mail` | Search messages | No |
| `move-mail` | Move to folder | Yes |
| `delete-mail` | Delete message | Yes |
| `list-events` | List calendar events | No |
| `get-event` | Get event details | No |
| `create-event` | Create calendar event | Yes |
| `respond-event` | Accept/decline/tentative | Yes |
| `check-availability` | Free/busy lookup | No |
| `list-contacts` | List/search contacts | No |
| `get-contact` | Get contact details | No |
| `create-contact` | Create new contact | Yes |
| `list-files` | Browse OneDrive | No |
| `get-file` | Get file metadata | No |
| `search-files` | Search OneDrive | No |
| **`graph-api`** | **Raw Graph API escape hatch** | Depends |

### Agent-Native Features

- **MCP Resources** — Auto-injected context: `flok://inbox/summary`, `flok://calendar/today`, `flok://me/profile`
- **MCP Prompts** — Composable workflows: triage-inbox, schedule-meeting, draft-and-review, daily-briefing, contact-lookup
- **Escape Hatch** — `graph-api` tool calls ANY Graph endpoint directly
- **Completion Signals** — Every tool result includes `nextActions` suggestions
- **Read-Only Mode** — Set `FLOK_READ_ONLY=true` to disable all write operations

## Configuration

| Setting | CLI | Env Var | Default |
|---------|-----|---------|---------|
| Client ID | — | `FLOK_CLIENT_ID` | (required) |
| Tenant ID | — | `FLOK_TENANT_ID` | `common` |
| Account | — | `FLOK_ACCOUNT` | `default` |
| Read-only | — | `FLOK_READ_ONLY` | `false` |
| API version | — | `FLOK_API_VERSION` | `v1.0` |

## Required Azure Permissions

```
Mail.ReadWrite
Calendars.ReadWrite
Contacts.ReadWrite
Files.ReadWrite
User.Read
offline_access
```

## Dependencies

| Package | Purpose |
|---------|---------|
| [steipete/Commander](https://github.com/steipete/Commander) | CLI framework |
| [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) | MCP server |

## License

MIT
