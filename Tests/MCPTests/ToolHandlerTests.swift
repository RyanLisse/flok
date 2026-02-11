import Foundation
import Testing
@testable import FlokMCP
@testable import Core

// MARK: - Mock TokenProvider

/// Mock token provider for testing — no real auth needed
struct MockTokenProvider: TokenProvider {
    func accessToken() async throws -> String {
        "mock-access-token"
    }
}

// MARK: - Tool Handler Tests

@Suite("Tool Handler Tests")
struct ToolHandlerTests {

    // MARK: - Mail Tool Handler Tests

    @Test("SendMailHandler returns fail when readOnly=true")
    func sendMailReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = SendMailHandler(client: client, readOnly: true)

        let result = try await handler.handle(
            to: ["test@example.com"],
            subject: "Test",
            body: "Test body"
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("send-mail is disabled") == true)
    }

    @Test("ReplyMailHandler returns fail when readOnly=true")
    func replyMailReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = ReplyMailHandler(client: client, readOnly: true)

        let result = try await handler.handle(
            messageId: "test-message-id",
            comment: "Test reply"
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("reply-mail is disabled") == true)
    }

    @Test("MoveMailHandler returns fail when readOnly=true")
    func moveMailReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = MoveMailHandler(client: client, readOnly: true)

        let result = try await handler.handle(
            messageId: "test-message-id",
            destinationFolder: "Archive"
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("move-mail is disabled") == true)
    }

    @Test("DeleteMailHandler returns fail when readOnly=true")
    func deleteMailReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = DeleteMailHandler(client: client, readOnly: true)

        let result = try await handler.handle(messageId: "test-message-id")

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("delete-mail is disabled") == true)
    }

    // MARK: - Calendar Tool Handler Tests

    @Test("CreateEventHandler returns fail when readOnly=true")
    func createEventReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = CreateEventHandler(client: client, readOnly: true)

        let start = DateTimeTimeZone(dateTime: "2026-02-11T10:00:00", timeZone: "UTC")
        let end = DateTimeTimeZone(dateTime: "2026-02-11T11:00:00", timeZone: "UTC")

        let result = try await handler.handle(
            subject: "Test Meeting",
            start: start,
            end: end
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("create-event is disabled") == true)
    }

    @Test("RespondEventHandler returns fail when readOnly=true")
    func respondEventReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = RespondEventHandler(client: client, readOnly: true)

        let result = try await handler.handle(
            eventId: "test-event-id",
            response: "accept"
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("respond-event is disabled") == true)
    }

    @Test("RespondEventHandler returns fail for invalid response string")
    func respondEventInvalidResponse() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        // Test with readOnly=false to ensure validation happens BEFORE read-only check
        let handler = RespondEventHandler(client: client, readOnly: false)

        let result = try await handler.handle(
            eventId: "test-event-id",
            response: "invalid-response"
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Invalid response") == true)
        #expect(result.error?.contains("accept/decline/tentative") == true)
    }

    @Test("RespondEventHandler validates response options")
    func respondEventValidResponseOptions() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = RespondEventHandler(client: client, readOnly: false)

        // Test various invalid responses
        let invalidResponses = ["maybe", "confirm", "reject", "unknown", ""]

        for invalidResponse in invalidResponses {
            let result = try await handler.handle(
                eventId: "test-event-id",
                response: invalidResponse
            )

            #expect(result.success == false, "Response '\(invalidResponse)' should be invalid")
            #expect(result.error?.contains("Invalid response") == true, "Should contain 'Invalid response'")
        }
    }

    // MARK: - Contact Tool Handler Tests

    @Test("CreateContactHandler returns fail when readOnly=true")
    func createContactReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = CreateContactHandler(client: client, readOnly: true)

        let result = try await handler.handle(
            givenName: "Test",
            surname: "User",
            email: "test@example.com",
            phone: nil,
            company: nil,
            jobTitle: nil
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("create-contact is disabled") == true)
    }

    // MARK: - Graph API Escape Hatch Tests

    @Test("GraphAPIHandler returns fail for POST when readOnly=true")
    func graphAPIPostReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = GraphAPIHandler(client: client, readOnly: true)

        let result = try await handler.handle(
            method: "POST",
            path: "/me/messages",
            query: [:],
            body: nil,
            headers: [:]
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("POST is disabled") == true)
    }

    @Test("GraphAPIHandler returns fail for PATCH when readOnly=true")
    func graphAPIPatchReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = GraphAPIHandler(client: client, readOnly: true)

        let result = try await handler.handle(
            method: "PATCH",
            path: "/me/events/123",
            query: [:],
            body: "{}",
            headers: [:]
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("PATCH is disabled") == true)
    }

    @Test("GraphAPIHandler returns fail for PUT when readOnly=true")
    func graphAPIPutReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = GraphAPIHandler(client: client, readOnly: true)

        let result = try await handler.handle(
            method: "PUT",
            path: "/me/contacts/123",
            query: [:],
            body: "{}",
            headers: [:]
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("PUT is disabled") == true)
    }

    @Test("GraphAPIHandler returns fail for DELETE when readOnly=true")
    func graphAPIDeleteReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = GraphAPIHandler(client: client, readOnly: true)

        let result = try await handler.handle(
            method: "DELETE",
            path: "/me/messages/123",
            query: [:],
            body: nil,
            headers: [:]
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Read-only mode") == true)
        #expect(result.error?.contains("DELETE is disabled") == true)
    }

    @Test("GraphAPIHandler returns fail for unsupported HTTP method")
    func graphAPIUnsupportedMethod() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = GraphAPIHandler(client: client, readOnly: false)

        let result = try await handler.handle(
            method: "OPTIONS",
            path: "/me",
            query: [:],
            body: nil,
            headers: [:]
        )

        #expect(result.success == false)
        #expect(result.error?.contains("Unsupported HTTP method") == true)
    }

    @Test("GraphAPIHandler case-insensitive method matching")
    func graphAPIMethodCaseInsensitive() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)
        let handler = GraphAPIHandler(client: client, readOnly: true)

        // Test lowercase POST
        let resultLower = try await handler.handle(
            method: "post",
            path: "/me/messages",
            query: [:],
            body: nil,
            headers: [:]
        )

        #expect(resultLower.success == false)
        #expect(resultLower.error?.contains("Read-only mode") == true)

        // Test mixed case DELETE
        let resultMixed = try await handler.handle(
            method: "DeLeTe",
            path: "/me/messages/123",
            query: [:],
            body: nil,
            headers: [:]
        )

        #expect(resultMixed.success == false)
        #expect(resultMixed.error?.contains("Read-only mode") == true)
    }

    // MARK: - Read-Only Mode Configuration Tests

    @Test("All write operations fail consistently with read-only mode")
    func allWriteOperationsFailInReadOnlyMode() async throws {
        let tokenProvider = MockTokenProvider()
        let client = GraphClient(tokenProvider: tokenProvider)

        // Mail operations
        let sendMail = SendMailHandler(client: client, readOnly: true)
        let sendResult = try await sendMail.handle(to: ["test@example.com"], subject: "Test", body: "Body")
        #expect(sendResult.success == false)

        let replyMail = ReplyMailHandler(client: client, readOnly: true)
        let replyResult = try await replyMail.handle(messageId: "123", comment: "Reply")
        #expect(replyResult.success == false)

        let moveMail = MoveMailHandler(client: client, readOnly: true)
        let moveResult = try await moveMail.handle(messageId: "123", destinationFolder: "Archive")
        #expect(moveResult.success == false)

        let deleteMail = DeleteMailHandler(client: client, readOnly: true)
        let deleteResult = try await deleteMail.handle(messageId: "123")
        #expect(deleteResult.success == false)

        // Calendar operations
        let createEvent = CreateEventHandler(client: client, readOnly: true)
        let start = DateTimeTimeZone(dateTime: "2026-02-11T10:00:00", timeZone: "UTC")
        let end = DateTimeTimeZone(dateTime: "2026-02-11T11:00:00", timeZone: "UTC")
        let createResult = try await createEvent.handle(subject: "Test", start: start, end: end)
        #expect(createResult.success == false)

        let respondEvent = RespondEventHandler(client: client, readOnly: true)
        let respondResult = try await respondEvent.handle(eventId: "123", response: "accept")
        #expect(respondResult.success == false)

        // Contact operations
        let createContact = CreateContactHandler(client: client, readOnly: true)
        let contactResult = try await createContact.handle(
            givenName: "Test",
            surname: nil,
            email: nil,
            phone: nil,
            company: nil,
            jobTitle: nil
        )
        #expect(contactResult.success == false)

        // Graph API escape hatch
        let graphAPI = GraphAPIHandler(client: client, readOnly: true)
        let postResult = try await graphAPI.handle(method: "POST", path: "/test", query: [:], body: nil, headers: [:])
        #expect(postResult.success == false)

        let patchResult = try await graphAPI.handle(method: "PATCH", path: "/test", query: [:], body: nil, headers: [:])
        #expect(patchResult.success == false)

        let deleteApiResult = try await graphAPI.handle(method: "DELETE", path: "/test", query: [:], body: nil, headers: [:])
        #expect(deleteApiResult.success == false)
    }
}
