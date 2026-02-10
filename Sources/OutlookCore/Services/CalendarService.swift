import Foundation

/// Service for Microsoft Graph Calendar operations.
public actor CalendarService {
    private let client: GraphClient
    private let readOnly: Bool

    public init(client: GraphClient, readOnly: Bool = false) {
        self.client = client
        self.readOnly = readOnly
    }

    // MARK: - Read Operations

    /// List calendar events within a date range.
    public func listEvents(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        calendarId: String? = nil,
        count: Int = 25
    ) async throws -> [Event] {
        let basePath: String
        if let calId = calendarId {
            basePath = "/me/calendars/\(calId)/events"
        } else {
            basePath = "/me/events"
        }

        var query = GraphQuery()
            .select("id", "subject", "body", "start", "end", "location", "attendees",
                    "organizer", "isAllDay", "isCancelled", "responseStatus",
                    "recurrence", "onlineMeeting", "webLink")
            .orderBy("start/dateTime")
            .top(count)

        // Use calendarView for date range queries
        if let start = startDate, let end = endDate {
            let formatter = ISO8601DateFormatter()
            let path = calendarId != nil
                ? "/me/calendars/\(calendarId!)/calendarView"
                : "/me/calendarView"
            var params = query.build()
            params["startDateTime"] = formatter.string(from: start)
            params["endDateTime"] = formatter.string(from: end)
            return try await client.requestList(path: path, query: params)
        }

        return try await client.requestList(path: basePath, query: query.build())
    }

    /// Get a single event by ID.
    public func getEvent(id: String) async throws -> Event {
        let path = "/me/events/\(id)"
        return try await client.request(.get, path: path)
    }

    /// Search calendar events.
    public func searchEvents(query: String) async throws -> [Event] {
        let path = "/me/events"
        let params = GraphQuery()
            .filter("contains(subject, '\(query)')")
            .select("id", "subject", "start", "end", "location", "attendees",
                    "isAllDay", "isCancelled", "webLink")
            .top(25)
            .build()
        return try await client.requestList(path: path, query: params)
    }

    /// List available calendars.
    public func listCalendars() async throws -> [Calendar] {
        let path = "/me/calendars"
        let params = GraphQuery()
            .select("id", "name", "color", "isDefaultCalendar", "canEdit")
            .build()
        return try await client.requestList(path: path, query: params)
    }

    // MARK: - Write Operations

    /// Create a new calendar event.
    public func createEvent(_ draft: DraftEvent) async throws -> Event {
        try guardWritable()
        let path = "/me/events"
        return try await client.request(.post, path: path, body: draft)
    }

    /// Update an existing event.
    public func updateEvent(id: String, updates: EventUpdate) async throws -> Event {
        try guardWritable()
        let path = "/me/events/\(id)"
        return try await client.request(.patch, path: path, body: updates)
    }

    /// Delete a calendar event.
    public func deleteEvent(id: String) async throws {
        try guardWritable()
        let path = "/me/events/\(id)"
        try await client.requestVoid(.delete, path: path)
    }

    /// Respond to an event invitation (accept, decline, tentatively accept).
    public func respondToEvent(id: String, response: EventResponse, message: String? = nil) async throws {
        try guardWritable()
        let path = "/me/events/\(id)/\(response.rawValue)"
        let payload = EventResponsePayload(sendResponse: true, comment: message)
        try await client.requestVoid(.post, path: path, body: payload)
    }

    /// Check free/busy availability for attendees.
    public func checkAvailability(
        attendees: [String],
        from start: Date,
        to end: Date,
        duration: Int = 30
    ) async throws -> [ScheduleInfo] {
        let path = "/me/calendar/getSchedule"
        let formatter = ISO8601DateFormatter()
        let payload = ScheduleRequest(
            schedules: attendees,
            startTime: DateTimeTimeZone(dateTime: formatter.string(from: start), timeZone: TimeZone.current.identifier),
            endTime: DateTimeTimeZone(dateTime: formatter.string(from: end), timeZone: TimeZone.current.identifier),
            availabilityViewInterval: duration
        )
        let response: ScheduleResponse = try await client.request(.post, path: path, body: payload)
        return response.value
    }

    // MARK: - Helpers

    private func guardWritable() throws {
        if readOnly { throw GraphError.readOnlyMode }
    }
}

// MARK: - Request/Response Payloads

struct EventResponsePayload: Encodable {
    let sendResponse: Bool
    let comment: String?
}

struct ScheduleRequest: Encodable {
    let schedules: [String]
    let startTime: DateTimeTimeZone
    let endTime: DateTimeTimeZone
    let availabilityViewInterval: Int
}

struct ScheduleResponse: Decodable {
    let value: [ScheduleInfo]
}
