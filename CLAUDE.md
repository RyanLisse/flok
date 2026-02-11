# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
swift build                          # Build all targets
swift test                           # Run all tests
swift test --filter CoreTests        # Run only Core tests
swift test --filter MCPTests         # Run only MCP tests
swift build -c release               # Release build
.build/debug/flok                    # Run after build
```

## Architecture

Swift 6 project (macOS 14+) with strict concurrency. Four targets with a strict dependency graph:

```
Executable → CLI → Core
           → MCP → Core
```

- **Core** — Zero dependencies. Graph API client, auth (device code flow + Keychain), and models (Mail, Calendar, Contact, Drive). This is a library product (`FlokCore`) usable independently.
- **CLI** — Commander-based subcommands. Depends only on Core.
- **MCP** — MCP server (stdio) with handler-per-operation pattern in `Tools/`. Also has `Resources.swift` (auto-injected context) and `Prompts.swift` (workflow templates). Depends only on Core.
- **Executable** — Entry point (`main.swift`), wires CLI and MCP together.

## Key Patterns

- **Handler pattern** for MCP tools: each file in `Sources/MCP/Tools/` registers tools for one domain (mail, calendar, contacts, drive, graph escape hatch)
- **Provider pattern** for Graph API: `GraphClient` handles HTTP, retry, pagination; auth via `TokenProvider` protocol
- **Keychain-first** token storage with `TokenManager` coordinating `DeviceCodeFlow` + `KeychainTokenStorage`
- All env vars use `FLOK_` prefix (e.g., `FLOK_CLIENT_ID`, `FLOK_READ_ONLY`)

## Swift Settings

StrictConcurrency, ExistentialAny, and NonisolatedNonsendingByDefault are all enabled. All new code must be concurrency-safe.
