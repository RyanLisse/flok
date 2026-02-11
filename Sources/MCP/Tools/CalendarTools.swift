import Foundation
import Core

// MARK: - Calendar Tool Handlers

/// Handler: list-events — List calendar events within a date range.
public struct ListEventsHandler: Sendable {
    let calendarService: CalendarService

    public func handle(startDate: String, endDate: String, top: Int = 25) async throws -> ToolResult {
        let from = ISO8601DateFormatter().date(from: startDate) ?? Date()
        let to = ISO8601DateFormatter().date(from: endDate) ?? Date()
        let events = try await calendarService.listEvents(from: from, to: to, count: top)
        let data = try JSONEncoder.graph.encode(events)
        return .ok(String(data: data, encoding: .utf8) ?? "[]", nextActions: ["get-event", "create-event"], approvalLevel: "auto")
    }
}

/// Handler: get-event — Get full event details.
public struct GetEventHandler: Sendable {
    let calendarService: CalendarService

    public func handle(eventId: String) async throws -> ToolResult {
        let event = try await calendarService.getEvent(id: eventId)
        let data = try JSONEncoder.graph.encode(event)
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["update-event", "respond-event"], approvalLevel: "auto")
    }
}

/// Handler: create-event — Create a new calendar event.
public struct CreateEventHandler: Sendable {
    let calendarService: CalendarService
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
        let draft = DraftEvent(subject: subject, start: start, end: end, location: location, attendees: attendees.isEmpty ? nil : attendees, body: body, isAllDay: isAllDay)
        let event = try await calendarService.createEvent(draft)
        let data = try JSONEncoder.graph.encode(event)
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["list-events"], approvalLevel: "explicit")
    }
}

/// Handler: respond-event — Accept, decline, or tentatively accept an event.
public struct RespondEventHandler: Sendable {
    let calendarService: CalendarService
    let readOnly: Bool

    public func handle(eventId: String, response: String, comment: String? = nil) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — respond-event is disabled") }
        switch response.lowercased() {
        case "accept", "decline", "tentative", "tentativelyaccept": break
        default: return .fail("Invalid response: \(response). Use accept/decline/tentative.")
        }
        try await calendarService.respondToEvent(id: eventId, response: response, comment: comment)
        let action = response.lowercased().hasPrefix("accept") ? "accepted" : (response.lowercased().hasPrefix("decline") ? "declined" : "tentatively accepted")
        return .ok("Event \(action)", nextActions: ["list-events"], approvalLevel: "explicit")
    }
}

/// Handler: check-availability — Check free/busy schedule.
public struct CheckAvailabilityHandler: Sendable {
    let calendarService: CalendarService

    public func handle(emails: [String], start: String, end: String, timeZone: String = "UTC") async throws -> ToolResult {
        let from = DateTimeTimeZone(dateTime: start, timeZone: timeZone)
        let to = DateTimeTimeZone(dateTime: end, timeZone: timeZone)
        let schedules = try await calendarService.checkAvailability(attendees: emails, from: from, to: to)
        let data = try JSONEncoder.graph.encode(schedules)
        return .ok(String(data: data, encoding: .utf8) ?? "[]", nextActions: ["create-event"], approvalLevel: "auto")
    }
}
