import Foundation
import OutlookCore

/// MCP tool definitions for calendar operations.
public enum CalendarToolSchemas {
    public static let calList: [String: Any] = [
        "name": "outlook_cal_list",
        "description": "List calendar events within a date range",
        "inputSchema": [
            "type": "object",
            "properties": [
                "from": ["type": "string", "description": "Start date (ISO 8601)"],
                "to": ["type": "string", "description": "End date (ISO 8601)"],
                "calendar_id": ["type": "string", "description": "Specific calendar ID"],
                "count": ["type": "integer", "description": "Number of events to return"],
            ],
            "required": [] as [String],
        ] as [String: Any],
    ]

    public static let calGet: [String: Any] = [
        "name": "outlook_cal_get",
        "description": "Get detailed information about a calendar event",
        "inputSchema": [
            "type": "object",
            "properties": [
                "event_id": ["type": "string", "description": "The event ID"],
            ],
            "required": ["event_id"],
        ] as [String: Any],
    ]

    public static let calCreate: [String: Any] = [
        "name": "outlook_cal_create",
        "description": "Create a new calendar event",
        "inputSchema": [
            "type": "object",
            "properties": [
                "subject": ["type": "string", "description": "Event subject/title"],
                "start": ["type": "string", "description": "Start datetime (ISO 8601)"],
                "end": ["type": "string", "description": "End datetime (ISO 8601)"],
                "location": ["type": "string", "description": "Event location"],
                "attendees": ["type": "string", "description": "Attendee emails (comma-separated)"],
                "body": ["type": "string", "description": "Event description"],
            ],
            "required": ["subject", "start", "end"],
        ] as [String: Any],
    ]

    public static let calRespond: [String: Any] = [
        "name": "outlook_cal_respond",
        "description": "Respond to an event invitation (accept, decline, or tentatively accept)",
        "inputSchema": [
            "type": "object",
            "properties": [
                "event_id": ["type": "string", "description": "The event ID"],
                "response": ["type": "string", "description": "Response: accept, decline, or tentativelyAccept"],
                "message": ["type": "string", "description": "Optional response message"],
            ],
            "required": ["event_id", "response"],
        ] as [String: Any],
    ]

    public static let calSearch: [String: Any] = [
        "name": "outlook_cal_search",
        "description": "Search calendar events",
        "inputSchema": [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "Search query"],
            ],
            "required": ["query"],
        ] as [String: Any],
    ]

    public static let calCalendars: [String: Any] = [
        "name": "outlook_cal_calendars",
        "description": "List available calendars",
        "inputSchema": [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String],
        ] as [String: Any],
    ]
}
