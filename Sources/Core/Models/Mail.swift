import Foundation

// MARK: - Mail Models

public struct Message: Codable, Sendable, Identifiable {
    public let id: String
    public let subject: String?
    public let bodyPreview: String?
    public let body: MessageBody?
    public let from: EmailAddress?
    public let toRecipients: [Recipient]?
    public let ccRecipients: [Recipient]?
    public let bccRecipients: [Recipient]?
    public let receivedDateTime: Date?
    public let sentDateTime: Date?
    public let isRead: Bool?
    public let isDraft: Bool?
    public let importance: String?
    public let hasAttachments: Bool?
    public let conversationId: String?
    public let parentFolderId: String?
    public let flag: MessageFlag?
    public let categories: [String]?
}

public struct MessageBody: Codable, Sendable {
    public let contentType: String
    public let content: String

    public init(contentType: String = "HTML", content: String) {
        self.contentType = contentType
        self.content = content
    }
}

public struct EmailAddress: Codable, Sendable {
    public let emailAddress: EmailAddressDetail

    public init(email: String, name: String? = nil) {
        self.emailAddress = EmailAddressDetail(name: name, address: email)
    }
}

public struct EmailAddressDetail: Codable, Sendable {
    public let name: String?
    public let address: String

    public init(name: String? = nil, address: String) {
        self.name = name
        self.address = address
    }
}

public struct Recipient: Codable, Sendable {
    public let emailAddress: EmailAddressDetail

    public init(email: String, name: String? = nil) {
        self.emailAddress = EmailAddressDetail(name: name, address: email)
    }
}

public struct MessageFlag: Codable, Sendable {
    public let flagStatus: String?
}

public struct MailFolder: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let totalItemCount: Int?
    public let unreadItemCount: Int?
}

public struct Attachment: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let contentType: String?
    public let size: Int?
    public let isInline: Bool?
    public let contentBytes: String?  // Base64
}

// MARK: - Send Mail Request

public struct SendMailRequest: Codable, Sendable {
    public let message: OutgoingMessage
    public let saveToSentItems: Bool

    public init(message: OutgoingMessage, saveToSentItems: Bool = true) {
        self.message = message
        self.saveToSentItems = saveToSentItems
    }
}

public struct OutgoingMessage: Codable, Sendable {
    public let subject: String
    public let body: MessageBody
    public let toRecipients: [Recipient]
    public let ccRecipients: [Recipient]?
    public let bccRecipients: [Recipient]?

    public init(
        subject: String,
        body: MessageBody,
        to: [Recipient],
        cc: [Recipient]? = nil,
        bcc: [Recipient]? = nil
    ) {
        self.subject = subject
        self.body = body
        self.toRecipients = to
        self.ccRecipients = cc
        self.bccRecipients = bcc
    }
}
