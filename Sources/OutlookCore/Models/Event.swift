import Foundation

// MARK: - Event

public struct Event: Codable, Identifiable, Sendable {
    public let id: String
    public let subject: String?
    public let body: MessageBody?
    public let start: DateTimeTimeZone
    public let end: DateTimeTimeZone
    public let location: Location?
    public let attendees: [Attendee]?
    public let organizer: Recipient?
    public let isAllDay: Bool
    public let isCancelled: Bool
    public let responseStatus: ResponseStatus?
    public let recurrence: Recurrence?
    public let onlineMeeting: OnlineMeeting?
    public let webLink: String?

    public init(
        id: String,
        subject: String? = nil,
        body: MessageBody? = nil,
        start: DateTimeTimeZone,
        end: DateTimeTimeZone,
        location: Location? = nil,
        attendees: [Attendee]? = nil,
        organizer: Recipient? = nil,
        isAllDay: Bool = false,
        isCancelled: Bool = false,
        responseStatus: ResponseStatus? = nil,
        recurrence: Recurrence? = nil,
        onlineMeeting: OnlineMeeting? = nil,
        webLink: String? = nil
    ) {
        self.id = id
        self.subject = subject
        self.body = body
        self.start = start
        self.end = end
        self.location = location
        self.attendees = attendees
        self.organizer = organizer
        self.isAllDay = isAllDay
        self.isCancelled = isCancelled
        self.responseStatus = responseStatus
        self.recurrence = recurrence
        self.onlineMeeting = onlineMeeting
        self.webLink = webLink
    }
}

// MARK: - Draft Event

public struct DraftEvent: Codable, Sendable {
    public let subject: String
    public let body: MessageBody?
    public let start: DateTimeTimeZone
    public let end: DateTimeTimeZone
    public let location: Location?
    public let attendees: [Attendee]?
    public let isAllDay: Bool?

    public init(
        subject: String,
        start: DateTimeTimeZone,
        end: DateTimeTimeZone,
        body: String? = nil,
        location: String? = nil,
        attendees: [String]? = nil,
        isAllDay: Bool? = nil
    ) {
        self.subject = subject
        self.start = start
        self.end = end
        self.body = body.map { MessageBody(contentType: "text", content: $0) }
        self.location = location.map { Location(displayName: $0) }
        self.attendees = attendees?.map {
            Attendee(
                emailAddress: EmailAddress(name: nil, address: $0),
                type: "required",
                status: nil
            )
        }
        self.isAllDay = isAllDay
    }
}

// MARK: - Event Update

public struct EventUpdate: Codable, Sendable {
    public var subject: String?
    public var start: DateTimeTimeZone?
    public var end: DateTimeTimeZone?
    public var location: Location?
    public var body: MessageBody?

    public init(
        subject: String? = nil,
        start: DateTimeTimeZone? = nil,
        end: DateTimeTimeZone? = nil,
        location: String? = nil,
        body: String? = nil
    ) {
        self.subject = subject
        self.start = start
        self.end = end
        self.location = location.map { Location(displayName: $0) }
        self.body = body.map { MessageBody(contentType: "text", content: $0) }
    }
}

// MARK: - Event Response

public enum EventResponse: String, Codable, Sendable {
    case accept
    case decline
    case tentativelyAccept = "tentativelyAccept"
}

// MARK: - Supporting Types

public struct DateTimeTimeZone: Codable, Sendable {
    public let dateTime: String
    public let timeZone: String

    public init(dateTime: String, timeZone: String) {
        self.dateTime = dateTime
        self.timeZone = timeZone
    }

    public init(date: Date, timeZone: TimeZone = .current) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = timeZone
        self.dateTime = formatter.string(from: date)
        self.timeZone = timeZone.identifier
    }
}

public struct Location: Codable, Sendable {
    public let displayName: String

    public init(displayName: String) {
        self.displayName = displayName
    }
}

public struct Attendee: Codable, Sendable {
    public let emailAddress: EmailAddress
    public let type: String
    public let status: ResponseStatus?

    public init(emailAddress: EmailAddress, type: String, status: ResponseStatus?) {
        self.emailAddress = emailAddress
        self.type = type
        self.status = status
    }
}

public struct ResponseStatus: Codable, Sendable {
    public let response: String?
    public let time: String?

    public init(response: String?, time: String?) {
        self.response = response
        self.time = time
    }
}

public struct Recurrence: Codable, Sendable {
    public let pattern: RecurrencePattern?
    public let range: RecurrenceRange?

    public init(pattern: RecurrencePattern?, range: RecurrenceRange?) {
        self.pattern = pattern
        self.range = range
    }
}

public struct RecurrencePattern: Codable, Sendable {
    public let type: String
    public let interval: Int

    public init(type: String, interval: Int) {
        self.type = type
        self.interval = interval
    }
}

public struct RecurrenceRange: Codable, Sendable {
    public let type: String
    public let startDate: String?
    public let endDate: String?

    public init(type: String, startDate: String?, endDate: String?) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
    }
}

public struct OnlineMeeting: Codable, Sendable {
    public let joinUrl: String?

    public init(joinUrl: String?) {
        self.joinUrl = joinUrl
    }
}

// MARK: - Calendar

public struct Calendar: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let color: String?
    public let isDefaultCalendar: Bool?
    public let canEdit: Bool?

    public init(id: String, name: String, color: String? = nil, isDefaultCalendar: Bool? = nil, canEdit: Bool? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.isDefaultCalendar = isDefaultCalendar
        self.canEdit = canEdit
    }
}

// MARK: - Schedule Info (Free/Busy)

public struct ScheduleInfo: Codable, Sendable {
    public let scheduleId: String
    public let availabilityView: String
    public let scheduleItems: [ScheduleItem]?

    public init(scheduleId: String, availabilityView: String, scheduleItems: [ScheduleItem]?) {
        self.scheduleId = scheduleId
        self.availabilityView = availabilityView
        self.scheduleItems = scheduleItems
    }
}

public struct ScheduleItem: Codable, Sendable {
    public let status: String
    public let start: DateTimeTimeZone
    public let end: DateTimeTimeZone
    public let subject: String?

    public init(status: String, start: DateTimeTimeZone, end: DateTimeTimeZone, subject: String?) {
        self.status = status
        self.start = start
        self.end = end
        self.subject = subject
    }
}
