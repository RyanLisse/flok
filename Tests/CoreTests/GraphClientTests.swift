import Foundation
import Testing
@testable import Core

@Suite("GraphClient Tests")
struct GraphClientTests {
    @Test("GraphError descriptions are meaningful")
    func errorDescriptions() {
        let errors: [GraphError] = [
            .unauthorized,
            .forbidden,
            .notFound,
            .rateLimited,
            .serverError(500),
            .httpError(400, "Bad Request"),
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("GraphPage decodes correctly")
    func pageDecoding() throws {
        let json = """
        {"value": [{"id": "1"}, {"id": "2"}], "@odata.nextLink": "https://graph.microsoft.com/next"}
        """
        let data = json.data(using: .utf8)!
        let page = try JSONDecoder().decode(GraphPage<TestItem>.self, from: data)
        #expect(page.value.count == 2)
        #expect(page.nextLink != nil)
    }

    // MARK: - Message Model Tests

    @Test("Message decodes from realistic Graph API JSON")
    func messageDecoding() throws {
        let json = """
        {
          "id": "AAMkAGI2THVSAAA=",
          "subject": "Test Subject",
          "bodyPreview": "Hello from Graph API...",
          "from": {
            "emailAddress": {
              "name": "Sender Name",
              "address": "sender@example.com"
            }
          },
          "receivedDateTime": "2024-01-15T10:30:00Z",
          "isRead": false,
          "hasAttachments": true
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let message = try decoder.decode(Message.self, from: data)

        #expect(message.id == "AAMkAGI2THVSAAA=")
        #expect(message.subject == "Test Subject")
        #expect(message.bodyPreview == "Hello from Graph API...")
        #expect(message.from?.emailAddress.address == "sender@example.com")
        #expect(message.from?.emailAddress.name == "Sender Name")
        #expect(message.isRead == false)
        #expect(message.hasAttachments == true)
        #expect(message.receivedDateTime != nil)
    }

    // MARK: - Event Model Tests

    @Test("Event decodes with DateTimeTimeZone, Location, and Attendee")
    func eventDecoding() throws {
        let json = """
        {
          "id": "AAMkAGI2TG93AAA=",
          "subject": "Team Meeting",
          "start": {
            "dateTime": "2024-01-20T14:00:00",
            "timeZone": "Pacific Standard Time"
          },
          "end": {
            "dateTime": "2024-01-20T15:00:00",
            "timeZone": "Pacific Standard Time"
          },
          "location": {
            "displayName": "Conference Room A",
            "address": {
              "street": "123 Main St",
              "city": "Seattle",
              "state": "WA",
              "postalCode": "98101",
              "countryOrRegion": "USA"
            }
          },
          "attendees": [
            {
              "emailAddress": {
                "name": "John Doe",
                "address": "john@example.com"
              },
              "type": "required",
              "status": {
                "response": "accepted",
                "time": "2024-01-15T08:00:00Z"
              }
            },
            {
              "emailAddress": {
                "name": "Jane Smith",
                "address": "jane@example.com"
              },
              "type": "optional"
            }
          ],
          "isAllDay": false,
          "isOnlineMeeting": true,
          "onlineMeetingUrl": "https://teams.microsoft.com/l/meetup-join/..."
        }
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(Event.self, from: data)

        #expect(event.id == "AAMkAGI2TG93AAA=")
        #expect(event.subject == "Team Meeting")
        #expect(event.start?.dateTime == "2024-01-20T14:00:00")
        #expect(event.start?.timeZone == "Pacific Standard Time")
        #expect(event.end?.dateTime == "2024-01-20T15:00:00")
        #expect(event.location?.displayName == "Conference Room A")
        #expect(event.location?.address?.city == "Seattle")
        #expect(event.attendees?.count == 2)
        #expect(event.attendees?[0].emailAddress.address == "john@example.com")
        #expect(event.attendees?[0].type == "required")
        #expect(event.attendees?[0].status?.response == "accepted")
        #expect(event.attendees?[1].type == "optional")
        #expect(event.isAllDay == false)
        #expect(event.isOnlineMeeting == true)
        #expect(event.onlineMeetingUrl != nil)
    }

    // MARK: - Contact Model Tests

    @Test("Contact decodes with emailAddresses array")
    func contactDecoding() throws {
        let json = """
        {
          "id": "AAMkAGI2AAA=",
          "displayName": "John Doe",
          "givenName": "John",
          "surname": "Doe",
          "emailAddresses": [
            {
              "name": "Work Email",
              "address": "john.doe@company.com"
            },
            {
              "name": "Personal Email",
              "address": "john@personal.com"
            }
          ],
          "businessPhones": ["+1-555-0100"],
          "mobilePhone": "+1-555-0199",
          "companyName": "Contoso Ltd",
          "jobTitle": "Software Engineer",
          "department": "Engineering"
        }
        """
        let data = json.data(using: .utf8)!
        let contact = try JSONDecoder().decode(Contact.self, from: data)

        #expect(contact.id == "AAMkAGI2AAA=")
        #expect(contact.displayName == "John Doe")
        #expect(contact.givenName == "John")
        #expect(contact.surname == "Doe")
        #expect(contact.emailAddresses?.count == 2)
        #expect(contact.emailAddresses?[0].address == "john.doe@company.com")
        #expect(contact.emailAddresses?[1].address == "john@personal.com")
        #expect(contact.businessPhones?[0] == "+1-555-0100")
        #expect(contact.mobilePhone == "+1-555-0199")
        #expect(contact.companyName == "Contoso Ltd")
        #expect(contact.jobTitle == "Software Engineer")
        #expect(contact.department == "Engineering")
    }

    // MARK: - DriveItem Model Tests

    @Test("DriveItem decodes with folder and file facets")
    func driveItemDecoding() throws {
        // Test folder
        let folderJson = """
        {
          "id": "01BYE5RZ6QN3VJFBFPNFAKDEG2UPVBFCZZ",
          "name": "Documents",
          "folder": {
            "childCount": 5
          },
          "webUrl": "https://contoso-my.sharepoint.com/Documents",
          "size": 0
        }
        """
        let folderData = folderJson.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let folder = try decoder.decode(DriveItem.self, from: folderData)

        #expect(folder.id == "01BYE5RZ6QN3VJFBFPNFAKDEG2UPVBFCZZ")
        #expect(folder.name == "Documents")
        #expect(folder.folder?.childCount == 5)
        #expect(folder.file == nil)
        #expect(folder.webUrl != nil)

        // Test file
        let fileJson = """
        {
          "id": "01BYE5RZ5MYLM2SMX75ZBIPQZIHT6OAYPB",
          "name": "report.pdf",
          "size": 524288,
          "file": {
            "mimeType": "application/pdf"
          },
          "webUrl": "https://contoso-my.sharepoint.com/Documents/report.pdf"
        }
        """
        let fileData = fileJson.data(using: .utf8)!
        let file = try decoder.decode(DriveItem.self, from: fileData)

        #expect(file.id == "01BYE5RZ5MYLM2SMX75ZBIPQZIHT6OAYPB")
        #expect(file.name == "report.pdf")
        #expect(file.size == 524288)
        #expect(file.file?.mimeType == "application/pdf")
        #expect(file.folder == nil)
    }

    // MARK: - SendMailRequest Encoding Tests

    @Test("SendMailRequest encodes correctly (round-trip)")
    func sendMailRequestEncoding() throws {
        let body = MessageBody(contentType: "HTML", content: "<p>Hello World</p>")
        let to = [Recipient(email: "recipient@example.com", name: "Recipient Name")]
        let cc = [Recipient(email: "cc@example.com", name: "CC Person")]

        let outgoingMessage = OutgoingMessage(
            subject: "Test Subject",
            body: body,
            to: to,
            cc: cc
        )

        let request = SendMailRequest(message: outgoingMessage, saveToSentItems: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encodedData = try encoder.encode(request)

        // Decode back to verify round-trip
        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(SendMailRequest.self, from: encodedData)

        #expect(decodedRequest.message.subject == "Test Subject")
        #expect(decodedRequest.message.body.content == "<p>Hello World</p>")
        #expect(decodedRequest.message.body.contentType == "HTML")
        #expect(decodedRequest.message.toRecipients.count == 1)
        #expect(decodedRequest.message.toRecipients[0].emailAddress.address == "recipient@example.com")
        #expect(decodedRequest.message.ccRecipients?.count == 1)
        #expect(decodedRequest.message.ccRecipients?[0].emailAddress.address == "cc@example.com")
        #expect(decodedRequest.saveToSentItems == true)
    }

    // MARK: - FlokConfig Tests

    @Test("FlokConfig uses init params with explicit precedence")
    func configPrecedence() {
        // Test explicit values take precedence
        let config = FlokConfig(
            clientId: "test-client",
            tenantId: "test-tenant",
            account: "test-account",
            readOnly: true,
            apiVersion: "v2.0"
        )

        #expect(config.clientId == "test-client")
        #expect(config.tenantId == "test-tenant")
        #expect(config.account == "test-account")
        #expect(config.readOnly == true)
        #expect(config.apiVersion == "v2.0")
    }

    @Test("FlokConfig uses defaults when no params provided")
    func configDefaults() {
        // Test defaults (note: env vars might be set, so we test the fallback logic)
        let config = FlokConfig()

        // These should either be from env vars or defaults
        #expect(!config.tenantId.isEmpty) // Default is "common"
        #expect(!config.account.isEmpty)  // Default is "default"
        #expect(!config.apiVersion.isEmpty) // Default is "v1.0"
    }
}

struct TestItem: Decodable {
    let id: String
}
