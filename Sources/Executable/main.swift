import OutlookCLI
import Foundation

// Entry point: route to CLI or MCP mode
// MCP mode will be activated when called with `outlook mcp serve`
// For now, just run the CLI
await OutlookCommand.main()
