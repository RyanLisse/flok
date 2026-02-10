# AGENTS.md — Flok

## Project Overview

**Flok** is a Swift CLI + MCP server for Microsoft 365 (Mail, Calendar, Contacts, OneDrive) via Microsoft Graph API. It follows the [Peekaboo architecture](https://github.com/steipete/Peekaboo) pattern.

## Architecture

- **Core/** — Library with zero CLI deps. Graph client, auth (device code + Keychain), Codable models.
- **CLI/** — Commander subcommands that call Core providers.
- **MCP/** — MCP server with handler-per-tool pattern, resources, prompts, and escape hatch.
- **Executable/** — Entry point routing to CLI or MCP serve mode.

## Standards

- Swift 6 with StrictConcurrency, ExistentialAny, NonisolatedNonsendingByDefault
- URLSession for HTTP (not AsyncHTTPClient)
- Keychain-first token storage
- Config priority: CLI args > env vars > defaults
- Handler pattern for MCP tools
- Provider pattern for Graph API access
- All tool results include completion signals (`nextActions`)
- Read-only mode gate on all write operations

## Agent-Native Principles

1. **Parity** — CLI and MCP expose the same capabilities
2. **Granularity** — Each tool is one atomic Graph operation
3. **Composability** — Prompts compose tools into workflows
4. **Emergent Capability** — `graph-api` escape hatch for any endpoint
5. **Improvement Over Time** — Resources provide auto-context

## Key Files

- `Package.swift` — Dependencies and targets
- `Sources/Core/Graph/GraphClient.swift` — HTTP client with retry/pagination
- `Sources/Core/Auth/` — Device code flow, token manager, Keychain
- `Sources/MCP/Tools/` — One file per tool category
- `Sources/MCP/Resources.swift` — Context injection resources
- `Sources/MCP/Prompts.swift` — Workflow templates

## Global Standards

See also: [~/Developer/agent-scripts/AGENTS.MD](~/Developer/agent-scripts/AGENTS.MD) for global agent development standards.
