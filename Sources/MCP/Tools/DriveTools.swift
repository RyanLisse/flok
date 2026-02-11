import Foundation
import Core

// MARK: - OneDrive Tool Handlers

public struct ListFilesHandler: Sendable {
    let driveService: DriveService

    public func handle(path: String = "", top: Int = 50) async throws -> ToolResult {
        let items = try await driveService.listChildren(path: path, top: top)
        let data = try JSONEncoder.graph.encode(items)
        return .ok(String(data: data, encoding: .utf8) ?? "[]", nextActions: ["list-files", "get-file"], approvalLevel: "auto")
    }
}

public struct GetFileHandler: Sendable {
    let driveService: DriveService

    public func handle(itemId: String) async throws -> ToolResult {
        let item = try await driveService.getItem(id: itemId)
        let data = try JSONEncoder.graph.encode(item)
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["list-files"], approvalLevel: "auto")
    }
}

public struct SearchFilesHandler: Sendable {
    let driveService: DriveService

    public func handle(query: String, top: Int = 50) async throws -> ToolResult {
        let items = try await driveService.searchFiles(query: query, top: top)
        let data = try JSONEncoder.graph.encode(items)
        return .ok(String(data: data, encoding: .utf8) ?? "[]", nextActions: ["get-file"], approvalLevel: "auto")
    }
}
