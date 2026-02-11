import Foundation
import Core

// MARK: - Mail Tool Handlers

/// Handler: list-mail — List messages from inbox or specified folder.
public struct ListMailHandler: Sendable {
    let mailService: MailService
    let readOnly: Bool

    public func handle(folder: String = "inbox", top: Int = 25, filter: String? = nil) async throws -> ToolResult {
        let (messages, _) = try await mailService.listMessages(folder: folder, count: top, includeBody: false)
        let data = try JSONEncoder.graph.encode(messages)
        return .ok(String(data: data, encoding: .utf8) ?? "[]", nextActions: ["read-mail", "reply-mail"], approvalLevel: "auto")
    }
}

/// Handler: read-mail — Get full message content by ID.
public struct ReadMailHandler: Sendable {
    let mailService: MailService

    public func handle(messageId: String) async throws -> ToolResult {
        let msg = try await mailService.getMessage(id: messageId, includeBody: true)
        let data = try JSONEncoder.graph.encode(msg)
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["reply-mail", "move-mail"], approvalLevel: "auto")
    }
}

/// Handler: send-mail — Send a new email.
public struct SendMailHandler: Sendable {
    let mailService: MailService
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
        try await mailService.sendMessage(request)
        return .ok("Email sent to \(to.joined(separator: ", "))", nextActions: ["list-mail"], approvalLevel: "explicit")
    }
}

/// Handler: reply-mail — Reply to a message.
public struct ReplyMailHandler: Sendable {
    let mailService: MailService
    let readOnly: Bool

    public func handle(messageId: String, comment: String) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — reply-mail is disabled") }
        try await mailService.replyToMessage(id: messageId, body: comment, replyAll: false)
        return .ok("Reply sent", nextActions: ["list-mail"], approvalLevel: "explicit")
    }
}

/// Handler: search-mail — Search messages using Graph search API.
public struct SearchMailHandler: Sendable {
    let mailService: MailService

    public func handle(query: String, top: Int = 25) async throws -> ToolResult {
        let messages = try await mailService.searchMessages(query: query, count: top)
        let data = try JSONEncoder.graph.encode(messages)
        return .ok(String(data: data, encoding: .utf8) ?? "[]", nextActions: ["read-mail"], approvalLevel: "auto")
    }
}

/// Handler: move-mail — Move a message to a different folder.
public struct MoveMailHandler: Sendable {
    let mailService: MailService
    let readOnly: Bool

    public func handle(messageId: String, destinationFolder: String) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — move-mail is disabled") }
        _ = try await mailService.moveMessage(id: messageId, destinationFolder: destinationFolder)
        return .ok("Message moved to \(destinationFolder)", nextActions: ["list-mail"], approvalLevel: "explicit")
    }
}

/// Handler: delete-mail — Delete a message.
public struct DeleteMailHandler: Sendable {
    let mailService: MailService
    let readOnly: Bool

    public func handle(messageId: String) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — delete-mail is disabled") }
        try await mailService.deleteMessage(id: messageId)
        return .ok("Message deleted", nextActions: ["list-mail"], approvalLevel: "explicit")
    }
}
