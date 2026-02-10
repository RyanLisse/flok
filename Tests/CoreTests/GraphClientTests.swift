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

    @Test("FlokConfig explicit clientId overrides env var")
    func configClientIdOverride() {
        // Test that explicit parameter takes precedence even if env var is set
        let config = FlokConfig(clientId: "explicit-client-id")
        #expect(config.clientId == "explicit-client-id")
    }

    // MARK: - Auth Type Tests

    @Test("TokenResponse decodes from realistic Azure AD JSON")
    func tokenResponseDecoding() throws {
        let json = """
        {
          "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
          "token_type": "Bearer",
          "expires_in": 3599,
          "scope": "Mail.ReadWrite Calendars.ReadWrite User.Read",
          "refresh_token": "0.AQoAzNq..."
        }
        """
        let data = json.data(using: .utf8)!
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)

        #expect(token.accessToken == "eyJ0eXAiOiJKV1QiLCJhbGc...")
        #expect(token.tokenType == "Bearer")
        #expect(token.expiresIn == 3599)
        #expect(token.scope == "Mail.ReadWrite Calendars.ReadWrite User.Read")
        #expect(token.refreshToken == "0.AQoAzNq...")
    }

    @Test("TokenResponse decodes without optional refresh_token")
    func tokenResponseNoRefreshToken() throws {
        let json = """
        {
          "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
          "token_type": "Bearer",
          "expires_in": 3599
        }
        """
        let data = json.data(using: .utf8)!
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)

        #expect(token.accessToken == "eyJ0eXAiOiJKV1QiLCJhbGc...")
        #expect(token.refreshToken == nil)
    }

    @Test("DeviceCodeResponse decodes correctly")
    func deviceCodeResponseDecoding() throws {
        let json = """
        {
          "device_code": "BAQABAAEAAAAm-06blBE1TpVMil8KPQ41hF...",
          "user_code": "BQKG-JZYF",
          "verification_uri": "https://microsoft.com/devicelogin",
          "expires_in": 900,
          "interval": 5,
          "message": "To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code BQKG-JZYF to authenticate."
        }
        """
        let data = json.data(using: .utf8)!
        let deviceCode = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)

        #expect(deviceCode.deviceCode == "BAQABAAEAAAAm-06blBE1TpVMil8KPQ41hF...")
        #expect(deviceCode.userCode == "BQKG-JZYF")
        #expect(deviceCode.verificationUri == "https://microsoft.com/devicelogin")
        #expect(deviceCode.expiresIn == 900)
        #expect(deviceCode.interval == 5)
        #expect(deviceCode.message.contains("BQKG-JZYF"))
    }

    @Test("AuthError has meaningful descriptions for all cases")
    func authErrorDescriptions() {
        let errors: [AuthError] = [
            .declined,
            .expired,
            .oauthError("invalid_grant", "Invalid credentials"),
            .noRefreshToken,
            .notAuthenticated,
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("AuthError descriptions contain relevant details")
    func authErrorDescriptionsContent() {
        let oauthError = AuthError.oauthError("invalid_grant", "Token expired")
        #expect(oauthError.errorDescription?.contains("invalid_grant") == true)
        #expect(oauthError.errorDescription?.contains("Token expired") == true)

        let declined = AuthError.declined
        #expect(declined.errorDescription?.contains("declined") == true)

        let expired = AuthError.expired
        #expect(expired.errorDescription?.contains("expired") == true)
    }

    // MARK: - GraphError Additional Tests

    @Test("All GraphError cases have non-nil errorDescription")
    func graphErrorAllCasesHaveDescriptions() {
        let errors: [GraphError] = [
            .invalidResponse,
            .unauthorized,
            .forbidden,
            .notFound,
            .rateLimited,
            .serverError(500),
            .serverError(503),
            .httpError(400, "Bad Request"),
            .httpError(418, "I'm a teapot"),
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "GraphError case should have errorDescription: \(error)")
            #expect(!error.errorDescription!.isEmpty, "GraphError description should not be empty: \(error)")
        }
    }

    @Test("GraphError httpError includes status code and body in description")
    func graphErrorHttpErrorDetails() {
        let error = GraphError.httpError(418, "I'm a teapot - short and stout")
        let description = error.errorDescription!

        #expect(description.contains("418"))
        #expect(description.contains("I'm a teapot - short and stout"))
    }

    @Test("GraphError serverError includes status code in description")
    func graphErrorServerErrorDetails() {
        let error500 = GraphError.serverError(500)
        #expect(error500.errorDescription?.contains("500") == true)

        let error503 = GraphError.serverError(503)
        #expect(error503.errorDescription?.contains("503") == true)
    }
}

struct TestItem: Decodable {
    let id: String
}

// MARK: - GraphQuery Tests

@Suite("GraphQuery Tests")
struct GraphQueryTests {
    @Test("Empty query builder produces empty dictionary")
    func emptyBuilder() {
        let query = GraphQuery()
        let params = query.build()
        #expect(params.isEmpty)
    }

    @Test("Select adds $select parameter with single field")
    func selectSingleField() {
        let query = GraphQuery().select("id")
        let params = query.build()
        #expect(params["$select"] == "id")
    }

    @Test("Select with multiple fields joins with comma")
    func selectMultipleFields() {
        let query = GraphQuery().select("id", "subject", "from")
        let params = query.build()
        #expect(params["$select"] == "id,subject,from")
    }

    @Test("Multiple select calls append fields")
    func selectChaining() {
        let query = GraphQuery()
            .select("id", "subject")
            .select("from", "receivedDateTime")
        let params = query.build()
        #expect(params["$select"] == "id,subject,from,receivedDateTime")
    }

    @Test("Filter adds $filter parameter")
    func filterExpression() {
        let query = GraphQuery().filter("receivedDateTime ge 2024-01-01")
        let params = query.build()
        #expect(params["$filter"] == "receivedDateTime ge 2024-01-01")
    }

    @Test("OrderBy adds $orderby parameter ascending by default")
    func orderByAscending() {
        let query = GraphQuery().orderBy("receivedDateTime")
        let params = query.build()
        #expect(params["$orderby"] == "receivedDateTime")
    }

    @Test("OrderBy with descending appends desc")
    func orderByDescending() {
        let query = GraphQuery().orderBy("receivedDateTime", descending: true)
        let params = query.build()
        #expect(params["$orderby"] == "receivedDateTime desc")
    }

    @Test("Multiple orderBy calls comma-separate")
    func orderByMultiple() {
        let query = GraphQuery()
            .orderBy("importance", descending: true)
            .orderBy("receivedDateTime")
        let params = query.build()
        #expect(params["$orderby"] == "importance desc,receivedDateTime")
    }

    @Test("Top adds $top parameter")
    func topLimit() {
        let query = GraphQuery().top(25)
        let params = query.build()
        #expect(params["$top"] == "25")
    }

    @Test("Skip adds $skip parameter")
    func skipOffset() {
        let query = GraphQuery().skip(50)
        let params = query.build()
        #expect(params["$skip"] == "50")
    }

    @Test("Search wraps value in escaped quotes")
    func searchQuoting() {
        let query = GraphQuery().search("meeting notes")
        let params = query.build()
        #expect(params["$search"] == "\"meeting notes\"")
    }

    @Test("Expand adds $expand parameter")
    func expandField() {
        let query = GraphQuery().expand("attachments")
        let params = query.build()
        #expect(params["$expand"] == "attachments")
    }

    @Test("Count with true sets $count to true")
    func countTrue() {
        let query = GraphQuery().count(true)
        let params = query.build()
        #expect(params["$count"] == "true")
    }

    @Test("Count with false sets $count to false")
    func countFalse() {
        let query = GraphQuery().count(false)
        let params = query.build()
        #expect(params["$count"] == "false")
    }

    @Test("Count defaults to true")
    func countDefault() {
        let query = GraphQuery().count()
        let params = query.build()
        #expect(params["$count"] == "true")
    }

    @Test("Chaining multiple methods produces correct query")
    func complexChaining() {
        let query = GraphQuery()
            .select("id", "subject", "from")
            .filter("isRead eq false")
            .orderBy("receivedDateTime", descending: true)
            .top(10)
            .count()
        let params = query.build()

        #expect(params["$select"] == "id,subject,from")
        #expect(params["$filter"] == "isRead eq false")
        #expect(params["$orderby"] == "receivedDateTime desc")
        #expect(params["$top"] == "10")
        #expect(params["$count"] == "true")
        #expect(params.count == 5)
    }

    @Test("Realistic email query scenario")
    func realisticEmailQuery() {
        let query = GraphQuery()
            .select("id", "subject", "from", "receivedDateTime", "bodyPreview")
            .filter("receivedDateTime ge 2024-01-01T00:00:00Z")
            .search("project status")
            .orderBy("receivedDateTime", descending: true)
            .top(25)
        let params = query.build()

        #expect(params["$select"] == "id,subject,from,receivedDateTime,bodyPreview")
        #expect(params["$filter"] == "receivedDateTime ge 2024-01-01T00:00:00Z")
        #expect(params["$search"] == "\"project status\"")
        #expect(params["$orderby"] == "receivedDateTime desc")
        #expect(params["$top"] == "25")
    }

    @Test("Realistic calendar query scenario")
    func realisticCalendarQuery() {
        let query = GraphQuery()
            .select("id", "subject", "start", "end", "location")
            .filter("start/dateTime ge '2024-02-01T00:00:00'")
            .orderBy("start/dateTime")
            .expand("attendees")
            .top(50)
        let params = query.build()

        #expect(params["$select"] == "id,subject,start,end,location")
        #expect(params["$filter"] == "start/dateTime ge '2024-02-01T00:00:00'")
        #expect(params["$orderby"] == "start/dateTime")
        #expect(params["$expand"] == "attendees")
        #expect(params["$top"] == "50")
    }

    @Test("Pagination scenario with skip and top")
    func paginationScenario() {
        let query = GraphQuery()
            .select("id", "displayName")
            .skip(100)
            .top(50)
            .orderBy("displayName")
        let params = query.build()

        #expect(params["$select"] == "id,displayName")
        #expect(params["$skip"] == "100")
        #expect(params["$top"] == "50")
        #expect(params["$orderby"] == "displayName")
    }
}
