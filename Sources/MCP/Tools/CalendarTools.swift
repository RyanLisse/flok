import Foundation
import Core

// MARK: - Calendar Tool Handlers

/// Handler: list-events — List calendar events within a date range.
public struct ListEventsHandler: Sendable {
    let client: GraphClient

    public func handle(startDate: String, endDate: String, top: Int = 25) async throws -> ToolResult {
        let data = try await client.get("/me/calendarView", query: [
            "startDateTime": startDate,
            "endDateTime": endDate,
            "$top": String(top),
            "$select": "id,subject,start,end,location,organizer,isAllDay,showAs,responseStatus",
            "$orderby": "start/dateTime",
        ])
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["get-event", "create-event"])
    }
}

/// Handler: get-event — Get full event details.
public struct GetEventHandler: Sendable {
    let client: GraphClient

    public func handle(eventId: String) async throws -> ToolResult {
        let data = try await client.get("/me/events/\(eventId)")
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["update-event", "respond-event", "delete-event"])
    }
}

/// Handler: create-event — Create a new calendar event.
public struct CreateEventHandler: Sendable {
    let client: GraphClient
    let readOnly: Bool

    public func handle(
        subject: String,
        start: DateTimeTimeZone,
        end: DateTimeTimeZone,
        location: String? = nil,
        attendees: [String] = [],
        body: String? = nil,
        isAllDay: Bool = false
    ) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — create-event is disabled") }

        var event: [String: Any] = [
            "subject": subject,
            "start": ["dateTime": start.dateTime, "timeZone": start.timeZone],
            "end": ["dateTime": end.dateTime, "timeZone": end.timeZone],
            "isAllDay": isAllDay,
        ]
        if let location { event["location"] = ["displayName": location] }
        if !attendees.isEmpty {
            event["attendees"] = attendees.map { [
                "emailAddress": ["address": $0],
                "type": "required"
            ] }
        }
        if let body { event["body"] = ["contentType": "Text", "content": body] }

        let jsonData = try JSONSerialization.data(withJSONObject: event)
        let result = try await client.post("/me/events", body: jsonData)
        return .ok(String(data: result, encoding: .utf8) ?? "", nextActions: ["list-events"])
    }
}

/// Handler: respond-event — Accept, decline, or tentatively accept an event.
public struct RespondEventHandler: Sendable {
    let client: GraphClient
    let readOnly: Bool

    public func handle(eventId: String, response: String, comment: String? = nil) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — respond-event is disabled") }

        let action: String
        switch response.lowercased() {
        case "accept": action = "accept"
        case "decline": action = "decline"
        case "tentative", "tentativelyaccept": action = "tentativelyAccept"
        default: return .fail("Invalid response: \(response). Use accept/decline/tentative.")
        }

        var body: [String: Any] = ["sendResponse": true]
        if let comment { body["comment"] = comment }
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        _ = try await client.post("/me/events/\(eventId)/\(action)", body: jsonData)
        return .ok("Event \(action)ed", nextActions: ["list-events"])
    }
}

/// Handler: check-availability — Check free/busy schedule.
public struct CheckAvailabilityHandler: Sendable {
    let client: GraphClient

    public func handle(emails: [String], start: String, end: String, timeZone: String = "UTC") async throws -> ToolResult {
        let request = ScheduleRequest(
            emails: emails,
            start: DateTimeTimeZone(dateTime: start, timeZone: timeZone),
            end: DateTimeTimeZone(dateTime: end, timeZone: timeZone)
        )
        let encoded = try JSONEncoder.graph.encode(request)
        let data = try await client.post("/me/calendar/getSchedule", body: encoded)
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["create-event"])
    }
}
