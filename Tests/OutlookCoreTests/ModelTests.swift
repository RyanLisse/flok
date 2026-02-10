import XCTest
@testable import OutlookCore

final class ModelTests: XCTestCase {
    // MARK: - Message Tests

    func testMessageDecoding() throws {
        let json = """
        {
            "id": "msg-123",
            "subject": "Test Subject",
            "from": {
                "emailAddress": {
                    "name": "John Doe",
                    "address": "john@example.com"
                }
            },
            "toRecipients": [
                {
                    "emailAddress": {
                        "name": "Jane Smith",
                        "address": "jane@example.com"
                    }
                }
            ],
            "receivedDateTime": "2024-01-15T10:30:00Z",
            "isRead": false,
            "isDraft": false,
            "importance": "normal",
            "hasAttachments": false,
            "bodyPreview": "Hello, this is a test"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let message = try decoder.decode(Message.self, from: json)

        XCTAssertEqual(message.id, "msg-123")
        XCTAssertEqual(message.subject, "Test Subject")
        XCTAssertEqual(message.from?.emailAddress.address, "john@example.com")
        XCTAssertEqual(message.from?.emailAddress.name, "John Doe")
        XCTAssertEqual(message.toRecipients.count, 1)
        XCTAssertEqual(message.toRecipients[0].emailAddress.address, "jane@example.com")
        XCTAssertFalse(message.isRead)
        XCTAssertFalse(message.isDraft)
        XCTAssertEqual(message.importance, .normal)
        XCTAssertFalse(message.hasAttachments)
        XCTAssertEqual(message.bodyPreview, "Hello, this is a test")
    }

    func testDraftMessageCreation() throws {
        let draft = DraftMessage(
            subject: "Test Email",
            body: "Hello World",
            to: ["test@example.com"],
            cc: ["cc@example.com"],
            bcc: nil
        )

        XCTAssertEqual(draft.subject, "Test Email")
        XCTAssertEqual(draft.body.content, "Hello World")
        XCTAssertEqual(draft.body.contentType, "text")
        XCTAssertEqual(draft.toRecipients.count, 1)
        XCTAssertEqual(draft.toRecipients[0].emailAddress.address, "test@example.com")
        XCTAssertEqual(draft.ccRecipients?.count, 1)
        XCTAssertNil(draft.bccRecipients)
    }

    // MARK: - Event Tests

    func testEventDecoding() throws {
        let json = """
        {
            "id": "evt-456",
            "subject": "Team Meeting",
            "start": {
                "dateTime": "2024-01-15T14:00:00.0000000",
                "timeZone": "UTC"
            },
            "end": {
                "dateTime": "2024-01-15T15:00:00.0000000",
                "timeZone": "UTC"
            },
            "location": {
                "displayName": "Conference Room A"
            },
            "isAllDay": false,
            "isCancelled": false,
            "attendees": [
                {
                    "emailAddress": {
                        "name": "Bob",
                        "address": "bob@example.com"
                    },
                    "type": "required",
                    "status": {
                        "response": "accepted",
                        "time": "2024-01-14T10:00:00Z"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(Event.self, from: json)

        XCTAssertEqual(event.id, "evt-456")
        XCTAssertEqual(event.subject, "Team Meeting")
        XCTAssertEqual(event.start.dateTime, "2024-01-15T14:00:00.0000000")
        XCTAssertEqual(event.start.timeZone, "UTC")
        XCTAssertEqual(event.location?.displayName, "Conference Room A")
        XCTAssertFalse(event.isAllDay)
        XCTAssertFalse(event.isCancelled)
        XCTAssertEqual(event.attendees?.count, 1)
        XCTAssertEqual(event.attendees?[0].emailAddress.address, "bob@example.com")
        XCTAssertEqual(event.attendees?[0].status?.response, "accepted")
    }

    func testDraftEventCreation() {
        let draft = DraftEvent(
            subject: "Lunch",
            start: DateTimeTimeZone(dateTime: "2024-01-15T12:00:00", timeZone: "America/New_York"),
            end: DateTimeTimeZone(dateTime: "2024-01-15T13:00:00", timeZone: "America/New_York"),
            body: "Team lunch",
            location: "Cafeteria",
            attendees: ["alice@example.com", "bob@example.com"]
        )

        XCTAssertEqual(draft.subject, "Lunch")
        XCTAssertEqual(draft.start.timeZone, "America/New_York")
        XCTAssertEqual(draft.body?.content, "Team lunch")
        XCTAssertEqual(draft.location?.displayName, "Cafeteria")
        XCTAssertEqual(draft.attendees?.count, 2)
    }

    // MARK: - GraphResponse Tests

    func testGraphResponseDecoding() throws {
        let json = """
        {
            "value": [
                {
                    "id": "folder-1",
                    "displayName": "Inbox",
                    "totalItemCount": 150,
                    "unreadItemCount": 5
                },
                {
                    "id": "folder-2",
                    "displayName": "Sent Items",
                    "totalItemCount": 80,
                    "unreadItemCount": 0
                }
            ],
            "@odata.nextLink": "https://graph.microsoft.com/v1.0/me/mailFolders?$skip=2"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GraphResponse<MailFolder>.self, from: json)

        XCTAssertEqual(response.value.count, 2)
        XCTAssertEqual(response.value[0].displayName, "Inbox")
        XCTAssertEqual(response.value[0].unreadItemCount, 5)
        XCTAssertEqual(response.value[1].displayName, "Sent Items")
        XCTAssertNotNil(response.nextLink)
    }

    // MARK: - Config Tests

    func testOutputFormatDefault() {
        XCTAssertEqual(OutputFormat.default, .table)
    }

    func testOutputFormatCases() {
        XCTAssertEqual(OutputFormat(rawValue: "table"), .table)
        XCTAssertEqual(OutputFormat(rawValue: "json"), .json)
        XCTAssertEqual(OutputFormat(rawValue: "compact"), .compact)
    }

    // MARK: - Auth Error Tests

    func testAuthErrorDescriptions() {
        let errors: [AuthError] = [
            .authorizationPending,
            .declined,
            .expired,
            .noAccount,
            .noRefreshToken,
            .missingClientId,
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
        }
    }

    // MARK: - Graph Error Tests

    func testGraphErrorDescriptions() {
        let errors: [GraphError] = [
            .unauthorized("expired"),
            .forbidden("missing scope"),
            .notFound("message"),
            .rateLimited(retryAfter: 10),
            .serverError(500, "internal"),
            .readOnlyMode,
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
        }
    }
}
