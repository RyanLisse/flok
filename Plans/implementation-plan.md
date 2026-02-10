# Flok Implementation Plan

## Current State
- Core infrastructure exists: GraphClient, Auth (DeviceCodeFlow, Keychain, TokenManager), Models (all 4 domains), Config
- MCP tool handlers exist for all domains (Mail 7, Calendar 5, Contact 3, Drive 3, GraphEscapeHatch 1)
- MCP Resources and Prompts exist
- CLI has auth (login/logout/status) + mail list + serve (stub)
- **Build is broken**: Package.swift references Commander 0.9.0 but max available is 0.2.1
- MCP server not wired to swift-sdk ModelContextProtocol
- Most CLI commands missing (mail read/send/reply/search/move/delete, all calendar, contacts, drive)

## Phase 1: Fix Build (Blocking)

### Task 1.1: Fix Package.swift dependencies
- Commander: change `from: "0.9.0"` → `from: "0.2.0"`
- Verify swift-sdk 0.9.0 exists (confirmed)
- Run `swift build` to verify resolution

## Phase 2: Wire MCP Server to swift-sdk (Critical Path)

### Task 2.1: Implement FlokMCPServer with ModelContextProtocol
- Import ModelContextProtocol in MCPServer.swift
- Register all 20+ tool handlers as MCP tools with proper JSON Schema input definitions
- Register 3 resources (inbox/summary, calendar/today, me/profile)
- Register 5 prompts (triage, schedule, draft, briefing, contact-lookup)
- Wire ServeCommand to actually start the MCP stdio transport

## Phase 3: Complete CLI Commands (Parallelizable)

### Task 3.1: Mail CLI commands
- mail read <id>, mail send, mail reply, mail search, mail move, mail delete

### Task 3.2: Calendar CLI commands
- calendar list, calendar create, calendar respond, calendar freebusy

### Task 3.3: Contact CLI commands
- contacts list, contact get, contact create

### Task 3.4: Drive CLI commands
- files list, files get, files search

### Task 3.5: Wire serve command to MCP server
- Replace stub in ServeCommand with actual FlokMCPServer start

## Phase 4: Tests (Parallelizable)

### Task 4.1: Core model tests
- Test all Codable models encode/decode correctly with Graph API JSON

### Task 4.2: MCP tool handler tests
- Mock GraphClient, test each handler returns correct ToolResult

### Task 4.3: Auth tests
- Test TokenManager lifecycle, FlokConfig env var priority

## Phase 5: Polish

### Task 5.1: JSON output mode for CLI (--json flag)
### Task 5.2: Read-only mode verification across all tools
### Task 5.3: Update README with accurate build/test instructions
