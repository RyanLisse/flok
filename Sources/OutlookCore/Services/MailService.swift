import Foundation

/// Service for Microsoft Graph Mail operations.
public actor MailService {
    private let client: GraphClient
    private let readOnly: Bool

    public init(client: GraphClient, readOnly: Bool = false) {
        self.client = client
        self.readOnly = readOnly
    }

    // MARK: - Read Operations

    /// List messages in a mail folder.
    public func listMessages(
        folder: String? = nil,
        unreadOnly: Bool = false,
        count: Int = 25,
        skip: Int = 0,
        includeBody: Bool = false
    ) async throws -> [Message] {
        let folderPath = folder ?? "inbox"
        let path = "/me/mailFolders/\(folderPath)/messages"

        var fields = "id,subject,from,toRecipients,ccRecipients,receivedDateTime,sentDateTime,isRead,isDraft,importance,flag,bodyPreview,hasAttachments,parentFolderId,conversationId,webLink"
        if includeBody { fields += ",body" }

        var params: [String: String] = [
            "$select": fields,
            "$orderby": "receivedDateTime desc",
            "$top": String(count),
            "$skip": String(skip),
        ]

        if unreadOnly {
            params["$filter"] = "isRead eq false"
        }

        return try await client.requestList(path: path, query: params)
    }

    /// Get a single message by ID.
    public func getMessage(id: String, includeBody: Bool = true) async throws -> Message {
        let path = "/me/messages/\(id)"
        var query = GraphQuery()
        if includeBody {
            query = query.select("id", "subject", "from", "toRecipients", "ccRecipients",
                                 "bccRecipients", "receivedDateTime", "sentDateTime", "isRead",
                                 "isDraft", "importance", "flag", "body", "bodyPreview",
                                 "hasAttachments", "parentFolderId", "conversationId", "webLink")
        }
        return try await client.request(.get, path: path, query: query.build())
    }

    /// Search messages using KQL.
    public func searchMessages(query: String, count: Int = 25) async throws -> [Message] {
        let path = "/me/messages"
        let params = GraphQuery()
            .search(query)
            .top(count)
            .select("id", "subject", "from", "receivedDateTime", "isRead", "bodyPreview", "hasAttachments")
            .build()
        return try await client.requestList(path: path, query: params)
    }

    /// List mail folders.
    public func listFolders() async throws -> [MailFolder] {
        let path = "/me/mailFolders"
        let params = GraphQuery()
            .select("id", "displayName", "totalItemCount", "unreadItemCount", "parentFolderId")
            .top(100)
            .build()
        return try await client.requestList(path: path, query: params)
    }

    // MARK: - Write Operations

    /// Send a new email.
    public func sendMessage(_ draft: DraftMessage) async throws {
        try guardWritable()
        let path = "/me/sendMail"
        let payload = SendMailPayload(message: draft, saveToSentItems: true)
        try await client.requestVoid(.post, path: path, body: payload)
    }

    /// Reply to a message.
    public func replyToMessage(id: String, body: String, replyAll: Bool = false) async throws {
        try guardWritable()
        let action = replyAll ? "replyAll" : "reply"
        let path = "/me/messages/\(id)/\(action)"
        let payload = ReplyPayload(comment: body)
        try await client.requestVoid(.post, path: path, body: payload)
    }

    /// Forward a message.
    public func forwardMessage(id: String, to: [String], comment: String? = nil) async throws {
        try guardWritable()
        let path = "/me/messages/\(id)/forward"
        let recipients = to.map { Recipient(emailAddress: EmailAddress(name: nil, address: $0)) }
        let payload = ForwardPayload(comment: comment ?? "", toRecipients: recipients)
        try await client.requestVoid(.post, path: path, body: payload)
    }

    /// Move a message to a different folder.
    public func moveMessage(id: String, destinationFolder: String) async throws {
        try guardWritable()
        let path = "/me/messages/\(id)/move"
        let payload = MovePayload(destinationId: destinationFolder)
        try await client.requestVoid(.post, path: path, body: payload)
    }

    /// Delete a message.
    public func deleteMessage(id: String) async throws {
        try guardWritable()
        let path = "/me/messages/\(id)"
        try await client.requestVoid(.delete, path: path)
    }

    /// Update message properties (mark read/unread, flag/unflag).
    public func updateMessage(id: String, isRead: Bool? = nil, flag: MessageFlag? = nil) async throws {
        try guardWritable()
        let path = "/me/messages/\(id)"
        var updates: [String: Any] = [:]
        if let isRead = isRead { updates["isRead"] = isRead }
        if let flag = flag { updates["flag"] = ["flagStatus": flag.flagStatus] }
        let payload = DictionaryPayload(updates)
        try await client.requestVoid(.patch, path: path, body: payload)
    }

    // MARK: - Attachments

    /// List attachments for a message.
    public func listAttachments(messageId: String) async throws -> [Attachment] {
        let path = "/me/messages/\(messageId)/attachments"
        let params = GraphQuery()
            .select("id", "name", "contentType", "size", "isInline")
            .build()
        return try await client.requestList(path: path, query: params)
    }

    // MARK: - Helpers

    private func guardWritable() throws {
        if readOnly { throw GraphError.readOnlyMode }
    }
}

// MARK: - Request Payloads

struct SendMailPayload: Encodable {
    let message: DraftMessage
    let saveToSentItems: Bool
}

struct ReplyPayload: Encodable {
    let comment: String
}

struct ForwardPayload: Encodable {
    let comment: String
    let toRecipients: [Recipient]
}

struct MovePayload: Encodable {
    let destinationId: String
}

/// Helper for encoding arbitrary dictionaries.
struct DictionaryPayload: Encodable {
    private let values: [String: Any]

    init(_ values: [String: Any]) {
        self.values = values
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in values {
            let codingKey = DynamicCodingKey(stringValue: key)!
            if let boolVal = value as? Bool {
                try container.encode(boolVal, forKey: codingKey)
            } else if let stringVal = value as? String {
                try container.encode(stringVal, forKey: codingKey)
            } else if let intVal = value as? Int {
                try container.encode(intVal, forKey: codingKey)
            } else if let dictVal = value as? [String: String] {
                try container.encode(dictVal, forKey: codingKey)
            }
        }
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
}
