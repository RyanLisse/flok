import Foundation

/// Formats output for CLI display in table, JSON, or compact formats.
public struct OutputFormatter: Sendable {
    public let format: OutputFormat

    public init(format: OutputFormat = .default) {
        self.format = format
    }

    public func formatMessages(_ messages: [Message]) -> String {
        switch format {
        case .table:
            return formatMessagesTable(messages)
        case .json:
            return toJSON(messages)
        case .compact:
            return messages.map { formatMessageCompact($0) }.joined(separator: "\n")
        }
    }

    public func formatMessage(_ message: Message) -> String {
        switch format {
        case .table:
            return formatMessageDetail(message)
        case .json:
            return toJSON(message)
        case .compact:
            return formatMessageCompact(message)
        }
    }

    public func formatEvents(_ events: [Event]) -> String {
        switch format {
        case .table:
            return formatEventsTable(events)
        case .json:
            return toJSON(events)
        case .compact:
            return events.map { formatEventCompact($0) }.joined(separator: "\n")
        }
    }

    public func formatEvent(_ event: Event) -> String {
        switch format {
        case .table:
            return formatEventDetail(event)
        case .json:
            return toJSON(event)
        case .compact:
            return formatEventCompact(event)
        }
    }

    // MARK: - Messages

    private func formatMessagesTable(_ messages: [Message]) -> String {
        guard !messages.isEmpty else { return "No messages found." }

        var lines: [String] = []
        let header = String(format: "%-6s %-1s %-30s %-50s %s", "ID", " ", "FROM", "SUBJECT", "DATE")
        lines.append(header)
        lines.append(String(repeating: "-", count: 120))

        for msg in messages {
            let readMarker = msg.isRead ? " " : "*"
            let from = msg.from?.emailAddress.address ?? "(unknown)"
            let subject = msg.subject ?? "(no subject)"
            let date = formatDate(msg.receivedDateTime)
            let shortId = String(msg.id.suffix(8))

            let line = String(
                format: "%-6s %-1s %-30s %-50s %s",
                shortId,
                readMarker,
                String(from.prefix(30)),
                String(subject.prefix(50)),
                date
            )
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    private func formatMessageDetail(_ message: Message) -> String {
        var lines: [String] = []
        lines.append("Subject: \(message.subject ?? "(no subject)")")
        lines.append("From:    \(message.from?.emailAddress.address ?? "(unknown)")")
        lines.append("To:      \(message.toRecipients.map { $0.emailAddress.address }.joined(separator: ", "))")
        if let cc = message.ccRecipients, !cc.isEmpty {
            lines.append("CC:      \(cc.map { $0.emailAddress.address }.joined(separator: ", "))")
        }
        lines.append("Date:    \(formatDate(message.receivedDateTime))")
        lines.append("Read:    \(message.isRead ? "Yes" : "No")")
        lines.append("ID:      \(message.id)")
        if message.hasAttachments {
            lines.append("Attachments: Yes")
        }
        if let body = message.body {
            lines.append("")
            lines.append(String(repeating: "-", count: 60))
            lines.append(body.content)
        }
        return lines.joined(separator: "\n")
    }

    private func formatMessageCompact(_ message: Message) -> String {
        let read = message.isRead ? " " : "*"
        let from = message.from?.emailAddress.address ?? "?"
        let subject = message.subject ?? "(no subject)"
        return "\(read) \(String(from.prefix(25))) | \(String(subject.prefix(60))) | \(formatDate(message.receivedDateTime))"
    }

    // MARK: - Events

    private func formatEventsTable(_ events: [Event]) -> String {
        guard !events.isEmpty else { return "No events found." }

        var lines: [String] = []
        let header = String(format: "%-6s %-40s %-20s %-20s %s", "ID", "SUBJECT", "START", "END", "LOCATION")
        lines.append(header)
        lines.append(String(repeating: "-", count: 120))

        for event in events {
            let shortId = String(event.id.suffix(8))
            let subject = event.subject ?? "(no subject)"
            let start = event.start.dateTime.prefix(16)
            let end = event.end.dateTime.prefix(16)
            let location = event.location?.displayName ?? ""

            let line = String(
                format: "%-6s %-40s %-20s %-20s %s",
                shortId,
                String(subject.prefix(40)),
                String(start),
                String(end),
                String(location.prefix(30))
            )
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    private func formatEventDetail(_ event: Event) -> String {
        var lines: [String] = []
        lines.append("Subject:  \(event.subject ?? "(no subject)")")
        lines.append("Start:    \(event.start.dateTime) (\(event.start.timeZone))")
        lines.append("End:      \(event.end.dateTime) (\(event.end.timeZone))")
        if let location = event.location?.displayName, !location.isEmpty {
            lines.append("Location: \(location)")
        }
        if let attendees = event.attendees, !attendees.isEmpty {
            let list = attendees.map { $0.emailAddress.address }.joined(separator: ", ")
            lines.append("Attendees: \(list)")
        }
        if event.isAllDay {
            lines.append("All Day:  Yes")
        }
        lines.append("ID:       \(event.id)")
        if let body = event.body {
            lines.append("")
            lines.append(String(repeating: "-", count: 60))
            lines.append(body.content)
        }
        return lines.joined(separator: "\n")
    }

    private func formatEventCompact(_ event: Event) -> String {
        let subject = event.subject ?? "(no subject)"
        let start = event.start.dateTime.prefix(16)
        let location = event.location?.displayName ?? ""
        return "\(start) | \(String(subject.prefix(50))) | \(location)"
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func toJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}
