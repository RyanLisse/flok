import Foundation
import OutlookCore

/// MCP tool definitions for mail operations.
/// This file provides the JSON Schema definitions for mail-related MCP tools.
public enum MailToolSchemas {
    public static let mailList: [String: Any] = [
        "name": "outlook_mail_list",
        "description": "List email messages from a mail folder",
        "inputSchema": [
            "type": "object",
            "properties": [
                "folder": ["type": "string", "description": "Mail folder name (default: inbox)"],
                "unread_only": ["type": "boolean", "description": "Only show unread messages"],
                "count": ["type": "integer", "description": "Number of messages to return (default: 25)"],
                "include_body": ["type": "boolean", "description": "Include message body in results"],
            ],
            "required": [] as [String],
        ] as [String: Any],
    ]

    public static let mailRead: [String: Any] = [
        "name": "outlook_mail_read",
        "description": "Read a specific email message with full body",
        "inputSchema": [
            "type": "object",
            "properties": [
                "message_id": ["type": "string", "description": "The message ID"],
            ],
            "required": ["message_id"],
        ] as [String: Any],
    ]

    public static let mailSend: [String: Any] = [
        "name": "outlook_mail_send",
        "description": "Send a new email",
        "inputSchema": [
            "type": "object",
            "properties": [
                "to": ["type": "string", "description": "Recipient email address"],
                "subject": ["type": "string", "description": "Email subject"],
                "body": ["type": "string", "description": "Email body text"],
                "cc": ["type": "string", "description": "CC recipients (comma-separated)"],
                "bcc": ["type": "string", "description": "BCC recipients (comma-separated)"],
            ],
            "required": ["to", "subject", "body"],
        ] as [String: Any],
    ]

    public static let mailReply: [String: Any] = [
        "name": "outlook_mail_reply",
        "description": "Reply to an email message",
        "inputSchema": [
            "type": "object",
            "properties": [
                "message_id": ["type": "string", "description": "The message ID to reply to"],
                "body": ["type": "string", "description": "Reply body text"],
                "reply_all": ["type": "boolean", "description": "Reply to all recipients"],
            ],
            "required": ["message_id", "body"],
        ] as [String: Any],
    ]

    public static let mailSearch: [String: Any] = [
        "name": "outlook_mail_search",
        "description": "Search email messages using KQL",
        "inputSchema": [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "Search query (KQL syntax)"],
                "count": ["type": "integer", "description": "Number of results to return"],
            ],
            "required": ["query"],
        ] as [String: Any],
    ]

    public static let mailFolders: [String: Any] = [
        "name": "outlook_mail_folders",
        "description": "List all mail folders",
        "inputSchema": [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String],
        ] as [String: Any],
    ]
}
