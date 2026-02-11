import Foundation

/// Mail operations via Microsoft Graph. Wraps GraphClient with mail-specific paths and model decoding.
public actor MailService {
    private let client: GraphClient

    public init(client: GraphClient) {
        self.client = client
    }

    // MARK: - Read

    public func listMessages(
        folder: String = "inbox",
        unreadOnly: Bool = false,
        count: Int = 25,
        skip: Int = 0,
        includeBody: Bool = false
    ) async throws -> (messages: [Message], nextLink: String?) {
        var query = GraphQuery()
            .select("id", "subject", "from", "receivedDateTime", "isRead", "bodyPreview", "hasAttachments")
            .orderBy("receivedDateTime", descending: true)
            .top(count)
            .skip(skip)
        if unreadOnly {
            query = query.filter("isRead eq false")
        }
        if includeBody {
            query = query.select("body")
        }
        let path = "/me/mailFolders/\(folder)/messages"
        let data = try await client.get(path, query: query.build())
        let page = try JSONDecoder.graph.decode(GraphPage<Message>.self, from: data)
        return (page.value, page.nextLink)
    }

    public func getMessage(id: String, includeBody: Bool = true) async throws -> Message {
        var select = "id,subject,from,toRecipients,ccRecipients,receivedDateTime,isRead,hasAttachments,conversationId"
        if includeBody { select += ",body" }
        let data = try await client.get("/me/messages/\(id)", query: ["$select": select])
        return try JSONDecoder.graph.decode(Message.self, from: data)
    }

    public func searchMessages(query: String, count: Int = 25) async throws -> [Message] {
        let q = GraphQuery().search(query).top(count)
            .select("id", "subject", "from", "receivedDateTime", "bodyPreview")
            .orderBy("receivedDateTime", descending: true)
        let data = try await client.get("/me/messages", query: q.build())
        let page = try JSONDecoder.graph.decode(GraphPage<Message>.self, from: data)
        return page.value
    }

    public func listFolders() async throws -> [MailFolder] {
        let data = try await client.get("/me/mailFolders", query: ["$select": "id,displayName,totalItemCount,unreadItemCount"])
        let page = try JSONDecoder.graph.decode(GraphPage<MailFolder>.self, from: data)
        return page.value
    }

    // MARK: - Write

    public func sendMessage(_ request: SendMailRequest) async throws {
        let body = try JSONEncoder.graph.encode(request)
        _ = try await client.post("/me/sendMail", body: body)
    }

    public func replyToMessage(id: String, body: String, replyAll: Bool = false) async throws {
        let payload = try JSONEncoder.graph.encode(["comment": body])
        let path = replyAll ? "/me/messages/\(id)/replyAll" : "/me/messages/\(id)/reply"
        _ = try await client.post(path, body: payload)
    }

    public func moveMessage(id: String, destinationFolder: String) async throws -> Message {
        let body = try JSONEncoder.graph.encode(["destinationId": destinationFolder])
        let data = try await client.post("/me/messages/\(id)/move", body: body)
        return try JSONDecoder.graph.decode(Message.self, from: data)
    }

    public func deleteMessage(id: String) async throws {
        try await client.delete("/me/messages/\(id)")
    }
}
