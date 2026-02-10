import ArgumentParser
import OutlookCore
import Foundation

struct CalCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cal",
        abstract: "Manage calendar events",
        subcommands: [
            List.self, Get.self, Create.self, Update.self,
            Delete.self, Respond.self, FreeBusy.self,
            Calendars.self, Search.self,
        ]
    )
}

// MARK: - List

extension CalCommand {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List upcoming calendar events"
        )

        @Option(name: .long, help: "Start date (ISO 8601)")
        var from: String?

        @Option(name: .long, help: "End date (ISO 8601)")
        var to: String?

        @Option(name: .long, help: "Calendar ID")
        var calendar: String?

        @Option(name: .long, help: "Number of events to show")
        var count: Int = 25

        @OptionGroup var formatOption: FormatOption
        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, calService) = try await createCalendarService(account: accountOption.account)

            let formatter = ISO8601DateFormatter()
            let startDate = from.flatMap { formatter.date(from: $0) } ?? Date()
            let endDate = to.flatMap { formatter.date(from: $0) }
                ?? Foundation.Calendar.current.date(byAdding: .day, value: 7, to: startDate)!

            let events = try await calService.listEvents(
                from: startDate,
                to: endDate,
                calendarId: calendar,
                count: count
            )
            let outputFormatter = OutputFormatter(format: formatOption.outputFormat)
            print(outputFormatter.formatEvents(events))
        }
    }
}

// MARK: - Get

extension CalCommand {
    struct Get: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get event details"
        )

        @Argument(help: "Event ID")
        var eventId: String

        @OptionGroup var formatOption: FormatOption
        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, calService) = try await createCalendarService(account: accountOption.account)
            let event = try await calService.getEvent(id: eventId)
            let formatter = OutputFormatter(format: formatOption.outputFormat)
            print(formatter.formatEvent(event))
        }
    }
}

// MARK: - Create

extension CalCommand {
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new calendar event"
        )

        @Option(name: .long, help: "Event subject")
        var subject: String

        @Option(name: .long, help: "Start datetime (ISO 8601)")
        var start: String

        @Option(name: .long, help: "End datetime (ISO 8601)")
        var end: String

        @Option(name: .long, help: "Location")
        var location: String?

        @Option(name: .long, help: "Attendee emails (comma-separated)")
        var attendees: String?

        @Option(name: .long, help: "Event body/description")
        var body: String?

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, calService) = try await createCalendarService(account: accountOption.account)

            let tz = TimeZone.current.identifier
            let startDTZ = DateTimeTimeZone(dateTime: start, timeZone: tz)
            let endDTZ = DateTimeTimeZone(dateTime: end, timeZone: tz)
            let attendeeList = attendees?.split(separator: ",").map(String.init)

            let draft = DraftEvent(
                subject: subject,
                start: startDTZ,
                end: endDTZ,
                body: body,
                location: location,
                attendees: attendeeList
            )

            let event = try await calService.createEvent(draft)
            print("Event created: \(event.subject ?? "(no subject)") (ID: \(event.id))")
        }
    }
}

// MARK: - Update

extension CalCommand {
    struct Update: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Update a calendar event"
        )

        @Argument(help: "Event ID")
        var eventId: String

        @Option(name: .long, help: "New subject")
        var subject: String?

        @Option(name: .long, help: "New start datetime (ISO 8601)")
        var start: String?

        @Option(name: .long, help: "New end datetime (ISO 8601)")
        var end: String?

        @Option(name: .long, help: "New location")
        var location: String?

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, calService) = try await createCalendarService(account: accountOption.account)

            let tz = TimeZone.current.identifier
            let updates = EventUpdate(
                subject: subject,
                start: start.map { DateTimeTimeZone(dateTime: $0, timeZone: tz) },
                end: end.map { DateTimeTimeZone(dateTime: $0, timeZone: tz) },
                location: location
            )

            let event = try await calService.updateEvent(id: eventId, updates: updates)
            print("Event updated: \(event.subject ?? "(no subject)")")
        }
    }
}

// MARK: - Delete

extension CalCommand {
    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a calendar event"
        )

        @Argument(help: "Event ID")
        var eventId: String

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, calService) = try await createCalendarService(account: accountOption.account)
            try await calService.deleteEvent(id: eventId)
            print("Event deleted")
        }
    }
}

// MARK: - Respond

extension CalCommand {
    struct Respond: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Respond to an event invitation"
        )

        @Argument(help: "Event ID")
        var eventId: String

        @Flag(name: .long, help: "Accept the invitation")
        var accept = false

        @Flag(name: .long, help: "Decline the invitation")
        var decline = false

        @Flag(name: .long, help: "Tentatively accept")
        var tentative = false

        @Option(name: .long, help: "Response message")
        var message: String?

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, calService) = try await createCalendarService(account: accountOption.account)

            let response: EventResponse
            if accept {
                response = .accept
            } else if decline {
                response = .decline
            } else if tentative {
                response = .tentativelyAccept
            } else {
                print("Error: Specify --accept, --decline, or --tentative")
                throw ExitCode.failure
            }

            try await calService.respondToEvent(id: eventId, response: response, message: message)
            print("Response sent: \(response.rawValue)")
        }
    }
}

// MARK: - Free/Busy

extension CalCommand {
    struct FreeBusy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "free-busy",
            abstract: "Check free/busy availability"
        )

        @Option(name: .long, help: "Attendee emails (comma-separated)")
        var attendees: String

        @Option(name: .long, help: "Start datetime (ISO 8601)")
        var from: String

        @Option(name: .long, help: "End datetime (ISO 8601)")
        var to: String

        @Option(name: .long, help: "Duration in minutes")
        var duration: Int = 30

        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, calService) = try await createCalendarService(account: accountOption.account)

            let formatter = ISO8601DateFormatter()
            guard let startDate = formatter.date(from: from),
                  let endDate = formatter.date(from: to) else {
                print("Error: Invalid date format. Use ISO 8601 (e.g., 2024-01-15T09:00:00Z)")
                throw ExitCode.failure
            }

            let attendeeList = attendees.split(separator: ",").map(String.init)
            let schedules = try await calService.checkAvailability(
                attendees: attendeeList,
                from: startDate,
                to: endDate,
                duration: duration
            )

            for schedule in schedules {
                print("\(schedule.scheduleId):")
                print("  Availability: \(schedule.availabilityView)")
                if let items = schedule.scheduleItems {
                    for item in items {
                        print("  \(item.start.dateTime) - \(item.end.dateTime): \(item.status)")
                    }
                }
                print()
            }
        }
    }
}

// MARK: - Calendars

extension CalCommand {
    struct Calendars: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List available calendars"
        )

        @OptionGroup var formatOption: FormatOption
        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, calService) = try await createCalendarService(account: accountOption.account)
            let calendars = try await calService.listCalendars()

            switch formatOption.outputFormat {
            case .json:
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let data = try? encoder.encode(calendars), let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
            default:
                for cal in calendars {
                    let defaultMarker = cal.isDefaultCalendar == true ? " (default)" : ""
                    print("  \(cal.name)\(defaultMarker) — ID: \(cal.id)")
                }
            }
        }
    }
}

// MARK: - Search

extension CalCommand {
    struct Search: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Search calendar events"
        )

        @Argument(help: "Search query")
        var query: String

        @OptionGroup var formatOption: FormatOption
        @OptionGroup var accountOption: AccountOption

        func run() async throws {
            let (_, calService) = try await createCalendarService(account: accountOption.account)
            let events = try await calService.searchEvents(query: query)
            let formatter = OutputFormatter(format: formatOption.outputFormat)
            print(formatter.formatEvents(events))
        }
    }
}
