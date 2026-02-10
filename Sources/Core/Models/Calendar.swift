import Foundation

// MARK: - Calendar Models

public struct Event: Codable, Sendable, Identifiable {
    public let id: String
    public let subject: String?
    public let body: MessageBody?
    public let bodyPreview: String?
    public let start: DateTimeTimeZone?
    public let end: DateTimeTimeZone?
    public let location: Location?
    public let attendees: [Attendee]?
    public let organizer: EmailAddress?
    public let isAllDay: Bool?
    public let isCancelled: Bool?
    public let isOnlineMeeting: Bool?
    public let onlineMeetingUrl: String?
    public let recurrence: Recurrence?
    public let responseStatus: ResponseStatus?
    public let showAs: String?
    public let importance: String?
    public let sensitivity: String?
    public let categories: [String]?
    public let webLink: String?
}

public struct DateTimeTimeZone: Codable, Sendable {
    public let dateTime: String
    public let timeZone: String

    public init(dateTime: String, timeZone: String = "UTC") {
        self.dateTime = dateTime
        self.timeZone = timeZone
    }
}

public struct Location: Codable, Sendable {
    public let displayName: String?
    public let address: PhysicalAddress?

    public init(displayName: String) {
        self.displayName = displayName
        self.address = nil
    }
}

public struct PhysicalAddress: Codable, Sendable {
    public let street: String?
    public let city: String?
    public let state: String?
    public let countryOrRegion: String?
    public let postalCode: String?
}

public struct Attendee: Codable, Sendable {
    public let emailAddress: EmailAddressDetail
    public let type: String?   // required, optional, resource
    public let status: ResponseStatus?

    public init(email: String, name: String? = nil, type: String = "required") {
        self.emailAddress = EmailAddressDetail(name: name, address: email)
        self.type = type
        self.status = nil
    }
}

public struct ResponseStatus: Codable, Sendable {
    public let response: String?
    public let time: String?
}

public struct Recurrence: Codable, Sendable {
    public let pattern: RecurrencePattern?
    public let range: RecurrenceRange?
}

public struct RecurrencePattern: Codable, Sendable {
    public let type: String?
    public let interval: Int?
    public let daysOfWeek: [String]?
}

public struct RecurrenceRange: Codable, Sendable {
    public let type: String?
    public let startDate: String?
    public let endDate: String?
}

// MARK: - Free/Busy

public struct ScheduleRequest: Codable, Sendable {
    public let schedules: [String]
    public let startTime: DateTimeTimeZone
    public let endTime: DateTimeTimeZone
    public let availabilityViewInterval: Int?

    public init(emails: [String], start: DateTimeTimeZone, end: DateTimeTimeZone, interval: Int? = 30) {
        self.schedules = emails
        self.startTime = start
        self.endTime = end
        self.availabilityViewInterval = interval
    }
}

public struct ScheduleResponse: Codable, Sendable {
    public let value: [ScheduleInformation]
}

public struct ScheduleInformation: Codable, Sendable {
    public let scheduleId: String?
    public let availabilityView: String?
    public let scheduleItems: [ScheduleItem]?
}

public struct ScheduleItem: Codable, Sendable {
    public let status: String?
    public let start: DateTimeTimeZone?
    public let end: DateTimeTimeZone?
    public let subject: String?
    public let location: String?
}
