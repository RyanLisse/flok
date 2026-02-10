import Foundation
import Core

// MARK: - Mail Tool Handlers

/// Handler: list-mail — List messages from inbox or specified folder.
public struct ListMailHandler: Sendable {
    let client: GraphClient
    let readOnly: Bool

    public func handle(folder: String = "inbox", top: Int = 25, filter: String? = nil) async throws -> ToolResult {
        var query: [String: String] = [
            "$top": String(top),
            "$select": "id,subject,from,receivedDateTime,isRead,bodyPreview,hasAttachments",
            "$orderby": "receivedDateTime desc",
        ]
        if let filter { query["$filter"] = filter }

        let data = try await client.get("/me/mailFolders/\(folder)/messages", query: query)
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["read-mail", "reply-mail"])
    }
}

/// Handler: read-mail — Get full message content by ID.
public struct ReadMailHandler: Sendable {
    let client: GraphClient

    public func handle(messageId: String) async throws -> ToolResult {
        let data = try await client.get("/me/messages/\(messageId)", query: [
            "$select": "id,subject,from,toRecipients,ccRecipients,body,receivedDateTime,hasAttachments,conversationId"
        ])
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["reply-mail", "forward-mail", "move-mail"])
    }
}

/// Handler: send-mail — Send a new email.
public struct SendMailHandler: Sendable {
    let client: GraphClient
    let readOnly: Bool

    public func handle(to: [String], subject: String, body: String, cc: [String] = [], isHTML: Bool = false) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — send-mail is disabled") }

        let request = SendMailRequest(
            message: OutgoingMessage(
                subject: subject,
                body: MessageBody(contentType: isHTML ? "HTML" : "Text", content: body),
                to: to.map { Recipient(email: $0) },
                cc: cc.isEmpty ? nil : cc.map { Recipient(email: $0) }
            )
        )
        let encoded = try JSONEncoder.graph.encode(request)
        _ = try await client.post("/me/sendMail", body: encoded)
        return .ok("Email sent to \(to.joined(separator: ", "))", nextActions: ["list-mail"])
    }
}

/// Handler: reply-mail — Reply to a message.
public struct ReplyMailHandler: Sendable {
    let client: GraphClient
    let readOnly: Bool

    public func handle(messageId: String, comment: String) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — reply-mail is disabled") }

        let body = try JSONEncoder.graph.encode(["comment": comment])
        _ = try await client.post("/me/messages/\(messageId)/reply", body: body)
        return .ok("Reply sent", nextActions: ["list-mail"])
    }
}

/// Handler: search-mail — Search messages using Graph search API.
public struct SearchMailHandler: Sendable {
    let client: GraphClient

    public func handle(query: String, top: Int = 25) async throws -> ToolResult {
        let data = try await client.get("/me/messages", query: [
            "$search": "\"\(query)\"",
            "$top": String(top),
            "$select": "id,subject,from,receivedDateTime,bodyPreview",
        ])
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["read-mail"])
    }
}

/// Handler: move-mail — Move a message to a different folder.
public struct MoveMailHandler: Sendable {
    let client: GraphClient
    let readOnly: Bool

    public func handle(messageId: String, destinationFolder: String) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — move-mail is disabled") }

        let body = try JSONEncoder.graph.encode(["destinationId": destinationFolder])
        _ = try await client.post("/me/messages/\(messageId)/move", body: body)
        return .ok("Message moved to \(destinationFolder)", nextActions: ["list-mail"])
    }
}

/// Handler: delete-mail — Delete a message.
public struct DeleteMailHandler: Sendable {
    let client: GraphClient
    let readOnly: Bool

    public func handle(messageId: String) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — delete-mail is disabled") }

        try await client.delete("/me/messages/\(messageId)")
        return .ok("Message deleted", nextActions: ["list-mail"])
    }
}
