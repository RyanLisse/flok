import ArgumentParser
import OutlookCore
import Foundation

struct MailCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mail",
        abstract: "Manage email messages",
        subcommands: [
            List.self, Read.self, Send.self, Reply.self,
            Forward.self, Move.self, Delete.self, Mark.self,
            Folders.self, Search.self,
        ]
    )
}

// MARK: - Shared Options

struct FormatOption: ParsableArguments {
    @Option(name: .long, help: "Output format: table, json, compact")
    var format: String?

    var outputFormat: OutputFormat {
        if let f = format, let fmt = OutputFormat(rawValue: f.lowercased()) {
            return fmt
        }
        return .default
    }
}

struct AccountOption: ParsableArguments {
    @Option(name: .long, help: "Account email to use")
    var account: String?
}

// MARK: - List

extension MailCommand {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List email messages"
        )

        @Option(name: .long, help: "Mail folder (default: inbox)")
        var folder: String?

        @Flag(name: .long, help: "Show only unread messages")
        var unread = false

        @Option(name: .long, help: "Number of messages to show")
        var count: Int = 25

        @Flag(name: .long, help: "Include message body")
        var body = false

        @OptionGroup var formatOption: FormatOption
        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, mailService) = try await createServices(account: accountOption.account)
            let messages = try await mailService.listMessages(
                folder: folder,
                unreadOnly: unread,
                count: count,
                includeBody: body
            )
            let formatter = OutputFormatter(format: formatOption.outputFormat)
            print(formatter.formatMessages(messages))
        }
    }
}

// MARK: - Read

extension MailCommand {
    struct Read: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Read a specific email message"
        )

        @Argument(help: "Message ID")
        var messageId: String

        @OptionGroup var formatOption: FormatOption
        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, mailService) = try await createServices(account: accountOption.account)
            let message = try await mailService.getMessage(id: messageId)
            let formatter = OutputFormatter(format: formatOption.outputFormat)
            print(formatter.formatMessage(message))
        }
    }
}

// MARK: - Send

extension MailCommand {
    struct Send: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Send an email"
        )

        @Argument(help: "Recipient email address")
        var to: String

        @Option(name: .long, help: "Email subject")
        var subject: String

        @Option(name: .long, help: "Email body text")
        var body: String

        @Option(name: .long, help: "CC recipients (comma-separated)")
        var cc: String?

        @Option(name: .long, help: "BCC recipients (comma-separated)")
        var bcc: String?

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, mailService) = try await createServices(account: accountOption.account)
            let ccList = cc?.split(separator: ",").map(String.init)
            let bccList = bcc?.split(separator: ",").map(String.init)
            let draft = DraftMessage(subject: subject, body: body, to: [to], cc: ccList, bcc: bccList)
            try await mailService.sendMessage(draft)
            print("Email sent to \(to)")
        }
    }
}

// MARK: - Reply

extension MailCommand {
    struct Reply: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Reply to a message"
        )

        @Argument(help: "Message ID to reply to")
        var messageId: String

        @Option(name: .long, help: "Reply body text")
        var body: String

        @Flag(name: .long, help: "Reply to all recipients")
        var all = false

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, mailService) = try await createServices(account: accountOption.account)
            try await mailService.replyToMessage(id: messageId, body: body, replyAll: all)
            print("Reply sent")
        }
    }
}

// MARK: - Forward

extension MailCommand {
    struct Forward: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Forward a message"
        )

        @Argument(help: "Message ID to forward")
        var messageId: String

        @Option(name: .long, help: "Recipient email address")
        var to: String

        @Option(name: .long, help: "Comment to include")
        var comment: String?

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, mailService) = try await createServices(account: accountOption.account)
            try await mailService.forwardMessage(id: messageId, to: [to], comment: comment)
            print("Message forwarded to \(to)")
        }
    }
}

// MARK: - Move

extension MailCommand {
    struct Move: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Move a message to a folder"
        )

        @Argument(help: "Message ID")
        var messageId: String

        @Option(name: .long, help: "Destination folder name or ID")
        var to: String

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, mailService) = try await createServices(account: accountOption.account)
            try await mailService.moveMessage(id: messageId, destinationFolder: to)
            print("Message moved to \(to)")
        }
    }
}

// MARK: - Delete

extension MailCommand {
    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a message"
        )

        @Argument(help: "Message ID")
        var messageId: String

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, mailService) = try await createServices(account: accountOption.account)
            try await mailService.deleteMessage(id: messageId)
            print("Message deleted")
        }
    }
}

// MARK: - Mark

extension MailCommand {
    struct Mark: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Mark a message as read/unread or flagged/unflagged"
        )

        @Argument(help: "Message ID")
        var messageId: String

        @Flag(name: .long, help: "Mark as read")
        var read = false

        @Flag(name: .long, help: "Mark as unread")
        var unread = false

        @Flag(name: .long, help: "Flag the message")
        var flag = false

        @Flag(name: .long, help: "Unflag the message")
        var unflag = false

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, mailService) = try await createServices(account: accountOption.account)

            var isRead: Bool?
            if read { isRead = true }
            if unread { isRead = false }

            var msgFlag: MessageFlag?
            if flag { msgFlag = MessageFlag(flagStatus: "flagged") }
            if unflag { msgFlag = MessageFlag(flagStatus: "notFlagged") }

            try await mailService.updateMessage(id: messageId, isRead: isRead, flag: msgFlag)
            print("Message updated")
        }
    }
}

// MARK: - Folders

extension MailCommand {
    struct Folders: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List mail folders"
        )

        @OptionGroup var formatOption: FormatOption
        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, mailService) = try await createServices(account: accountOption.account)
            let folders = try await mailService.listFolders()

            switch formatOption.outputFormat {
            case .json:
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let data = try? encoder.encode(folders), let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
            default:
                for folder in folders {
                    print("  \(folder.displayName) (\(folder.unreadItemCount) unread / \(folder.totalItemCount) total)")
                }
            }
        }
    }
}

// MARK: - Search

extension MailCommand {
    struct Search: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Search email messages"
        )

        @Argument(help: "Search query")
        var query: String

        @Option(name: .long, help: "Number of results")
        var count: Int = 25

        @OptionGroup var formatOption: FormatOption
        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, mailService) = try await createServices(account: accountOption.account)
            let messages = try await mailService.searchMessages(query: query, count: count)
            let formatter = OutputFormatter(format: formatOption.outputFormat)
            print(formatter.formatMessages(messages))
        }
    }
}

// MARK: - Service Factory

func createServices(account: String? = nil, readOnly: Bool = false) async throws -> (GraphClient, MailService) {
    let config = OutlookConfig(readOnly: readOnly)
    let storage = FileTokenStorage()
    let tokenManager = TokenManager(config: config, storage: storage)
    let client = GraphClient(tokenManager: tokenManager)
    let mailService = MailService(client: client, readOnly: config.readOnly)
    return (client, mailService)
}

func createCalendarService(account: String? = nil, readOnly: Bool = false) async throws -> (GraphClient, CalendarService) {
    let config = OutlookConfig(readOnly: readOnly)
    let storage = FileTokenStorage()
    let tokenManager = TokenManager(config: config, storage: storage)
    let client = GraphClient(tokenManager: tokenManager)
    let calService = CalendarService(client: client, readOnly: config.readOnly)
    return (client, calService)
}
