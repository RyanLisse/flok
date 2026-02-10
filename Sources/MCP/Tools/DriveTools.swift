import Foundation
import Core

// MARK: - OneDrive Tool Handlers

public struct ListFilesHandler: Sendable {
    let client: GraphClient

    public func handle(path: String = "", top: Int = 50) async throws -> ToolResult {
        let endpoint = path.isEmpty
            ? "/me/drive/root/children"
            : "/me/drive/root:/\(path):/children"
        let data = try await client.get(endpoint, query: [
            "$top": String(top),
            "$select": "id,name,size,webUrl,folder,file,lastModifiedDateTime",
        ])
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["list-files", "get-file"])
    }
}

public struct GetFileHandler: Sendable {
    let client: GraphClient

    public func handle(itemId: String) async throws -> ToolResult {
        let data = try await client.get("/me/drive/items/\(itemId)")
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["list-files"])
    }
}

public struct SearchFilesHandler: Sendable {
    let client: GraphClient

    public func handle(query: String) async throws -> ToolResult {
        let data = try await client.get("/me/drive/root/search(q='\(query)')")
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["get-file"])
    }
}
