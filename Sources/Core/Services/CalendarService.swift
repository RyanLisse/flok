import Foundation

/// Calendar and event operations via Microsoft Graph.
public actor CalendarService {
    private let client: GraphClient

    public init(client: GraphClient) {
        self.client = client
    }

    // MARK: - Read

    public func listEvents(
        from: Date,
        to: Date,
        calendarId: String? = nil,
        count: Int = 25
    ) async throws -> [Event] {
        let formatter = ISO8601DateFormatter()
        let startStr = formatter.string(from: from)
        let endStr = formatter.string(from: to)
        let base = calendarId.map { "/me/calendars/\($0)" } ?? "/me"
        let path = "\(base)/calendarView"
        let query: [String: String] = [
            "startDateTime": startStr,
            "endDateTime": endStr,
            "$top": String(count),
            "$select": "id,subject,start,end,location,organizer,attendees,isAllDay,isCancelled,responseStatus,webLink",
            "$orderby": "start/dateTime",
        ]
        let data = try await client.get(path, query: query)
        let page = try JSONDecoder.graph.decode(GraphPage<Event>.self, from: data)
        return page.value
    }

    public func getEvent(id: String) async throws -> Event {
        let data = try await client.get("/me/events/\(id)")
        return try JSONDecoder.graph.decode(Event.self, from: data)
    }

    // MARK: - Write

    public func createEvent(_ draft: DraftEvent) async throws -> Event {
        var body: [String: Any] = [
            "subject": draft.subject,
            "start": ["dateTime": draft.start.dateTime, "timeZone": draft.start.timeZone],
            "end": ["dateTime": draft.end.dateTime, "timeZone": draft.end.timeZone],
            "isAllDay": draft.isAllDay,
        ]
        if let location = draft.location {
            body["location"] = ["displayName": location]
        }
        if let attendees = draft.attendees, !attendees.isEmpty {
            body["attendees"] = attendees.map { ["emailAddress": ["address": $0], "type": "required"] }
        }
        if let b = draft.body {
            body["body"] = ["contentType": "Text", "content": b]
        }
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let data = try await client.post("/me/events", body: jsonData)
        return try JSONDecoder.graph.decode(Event.self, from: data)
    }

    public func respondToEvent(id: String, response: String, comment: String? = nil) async throws {
        let action: String
        switch response.lowercased() {
        case "accept": action = "accept"
        case "decline": action = "decline"
        case "tentative", "tentativelyaccept": action = "tentativelyAccept"
        default: throw GraphError.invalidRequest("Invalid response: \(response). Use accept/decline/tentative.")
        }
        var payload: [String: Any] = ["sendResponse": true]
        if let comment { payload["comment"] = comment }
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.post("/me/events/\(id)/\(action)", body: body)
    }

    public func deleteEvent(id: String, notify: Bool = true) async throws {
        try await client.delete("/me/events/\(id)")
    }

    // MARK: - Free/Busy

    public func checkAvailability(
        attendees: [String],
        from: DateTimeTimeZone,
        to: DateTimeTimeZone,
        duration: Int? = nil
    ) async throws -> [ScheduleInformation] {
        let request = ScheduleRequest(emails: attendees, start: from, end: to, interval: duration ?? 30)
        let body = try JSONEncoder.graph.encode(request)
        let data = try await client.post("/me/calendar/getSchedule", body: body)
        let response = try JSONDecoder.graph.decode(ScheduleResponse.self, from: data)
        return response.value
    }
}
