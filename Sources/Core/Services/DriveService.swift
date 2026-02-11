import Foundation

/// OneDrive file operations via Microsoft Graph.
public actor DriveService {
    private let client: GraphClient

    public init(client: GraphClient) {
        self.client = client
    }

    // MARK: - Read

    public func listChildren(path: String = "", top: Int = 50) async throws -> [DriveItem] {
        let endpoint = path.isEmpty
            ? "/me/drive/root/children"
            : "/me/drive/root:/\(path):/children"
        let query: [String: String] = [
            "$top": String(top),
            "$select": "id,name,size,webUrl,folder,file,lastModifiedDateTime,createdDateTime",
        ]
        let data = try await client.get(endpoint, query: query)
        let page = try JSONDecoder.graph.decode(GraphPage<DriveItem>.self, from: data)
        return page.value
    }

    public func getItem(id: String) async throws -> DriveItem {
        let data = try await client.get("/me/drive/items/\(id)")
        return try JSONDecoder.graph.decode(DriveItem.self, from: data)
    }

    public func searchFiles(query: String, top: Int = 50) async throws -> [DriveItem] {
        let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        let path = "/me/drive/root/search(q='\(escaped)')"
        let data = try await client.get(path, query: ["$top": String(top)])
        let page = try JSONDecoder.graph.decode(GraphPage<DriveItem>.self, from: data)
        return page.value
    }
}
