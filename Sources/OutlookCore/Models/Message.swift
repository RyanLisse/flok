import Foundation

// MARK: - Message

public struct Message: Codable, Identifiable, Sendable {
    public let id: String
    public let subject: String?
    public let from: Recipient?
    public let toRecipients: [Recipient]
    public let ccRecipients: [Recipient]?
    public let bccRecipients: [Recipient]?
    public let receivedDateTime: Date
    public let sentDateTime: Date?
    public let isRead: Bool
    public let isDraft: Bool
    public let importance: Importance
    public let flag: MessageFlag?
    public let body: MessageBody?
    public let bodyPreview: String?
    public let hasAttachments: Bool
    public let parentFolderId: String?
    public let conversationId: String?
    public let webLink: String?

    public init(
        id: String,
        subject: String? = nil,
        from: Recipient? = nil,
        toRecipients: [Recipient] = [],
        ccRecipients: [Recipient]? = nil,
        bccRecipients: [Recipient]? = nil,
        receivedDateTime: Date = Date(),
        sentDateTime: Date? = nil,
        isRead: Bool = false,
        isDraft: Bool = false,
        importance: Importance = .normal,
        flag: MessageFlag? = nil,
        body: MessageBody? = nil,
        bodyPreview: String? = nil,
        hasAttachments: Bool = false,
        parentFolderId: String? = nil,
        conversationId: String? = nil,
        webLink: String? = nil
    ) {
        self.id = id
        self.subject = subject
        self.from = from
        self.toRecipients = toRecipients
        self.ccRecipients = ccRecipients
        self.bccRecipients = bccRecipients
        self.receivedDateTime = receivedDateTime
        self.sentDateTime = sentDateTime
        self.isRead = isRead
        self.isDraft = isDraft
        self.importance = importance
        self.flag = flag
        self.body = body
        self.bodyPreview = bodyPreview
        self.hasAttachments = hasAttachments
        self.parentFolderId = parentFolderId
        self.conversationId = conversationId
        self.webLink = webLink
    }
}

// MARK: - Draft Message

public struct DraftMessage: Codable, Sendable {
    public let subject: String
    public let body: MessageBody
    public let toRecipients: [Recipient]
    public let ccRecipients: [Recipient]?
    public let bccRecipients: [Recipient]?

    public init(
        subject: String,
        body: String,
        to: [String],
        cc: [String]? = nil,
        bcc: [String]? = nil
    ) {
        self.subject = subject
        self.body = MessageBody(contentType: "text", content: body)
        self.toRecipients = to.map { Recipient(emailAddress: EmailAddress(name: nil, address: $0)) }
        self.ccRecipients = cc?.map { Recipient(emailAddress: EmailAddress(name: nil, address: $0)) }
        self.bccRecipients = bcc?.map { Recipient(emailAddress: EmailAddress(name: nil, address: $0)) }
    }
}

// MARK: - Mail Folder

public struct MailFolder: Codable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let totalItemCount: Int
    public let unreadItemCount: Int
    public let parentFolderId: String?

    public init(id: String, displayName: String, totalItemCount: Int = 0, unreadItemCount: Int = 0, parentFolderId: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.totalItemCount = totalItemCount
        self.unreadItemCount = unreadItemCount
        self.parentFolderId = parentFolderId
    }
}

// MARK: - Attachment

public struct Attachment: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let contentType: String
    public let size: Int
    public let isInline: Bool

    public init(id: String, name: String, contentType: String, size: Int, isInline: Bool = false) {
        self.id = id
        self.name = name
        self.contentType = contentType
        self.size = size
        self.isInline = isInline
    }
}

// MARK: - Shared Types

public struct Recipient: Codable, Sendable {
    public let emailAddress: EmailAddress

    public init(emailAddress: EmailAddress) {
        self.emailAddress = emailAddress
    }
}

public struct EmailAddress: Codable, Sendable {
    public let name: String?
    public let address: String

    public init(name: String?, address: String) {
        self.name = name
        self.address = address
    }
}

public struct MessageBody: Codable, Sendable {
    public let contentType: String
    public let content: String

    public init(contentType: String, content: String) {
        self.contentType = contentType
        self.content = content
    }
}

public enum Importance: String, Codable, Sendable {
    case low
    case normal
    case high
}

public struct MessageFlag: Codable, Sendable {
    public let flagStatus: String

    public init(flagStatus: String) {
        self.flagStatus = flagStatus
    }
}

// MARK: - Graph API Response Wrapper

public struct GraphResponse<T: Codable & Sendable>: Codable, Sendable {
    public let value: [T]
    public let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}
