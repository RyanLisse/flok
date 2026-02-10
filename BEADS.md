# BEADS.md — OutlookCLI Execution Plan

> 9 waves, ~50 beads. Each bead is self-contained — never consult PLAN.md during implementation.
> Swift CLI + MCP server for Microsoft 365 via Microsoft Graph API. Agent-native architecture. Peekaboo structure.

---

# Wave 1 — Foundation (No Dependencies)

## BD-001: Package.swift Scaffold & Project Structure
- **Type:** foundation
- **Priority:** P0 (blocking)
- **Depends on:** none
- **Blocks:** BD-006, BD-007, BD-008, BD-009, BD-010, BD-011, BD-012, BD-013, BD-014, BD-015 (everything)
- **Estimated effort:** M (half-day)

### Background
OutlookCLI follows the Peekaboo architecture: OutlookCore (library, no CLI deps), OutlookCLI (Commander/ArgumentParser subcommands), OutlookMCP (MCP server + tools), and Executable (entry point routing to CLI or MCP). This bead creates the entire directory structure and Package.swift with all targets and dependencies wired up. macOS 14+ only. Swift 6 concurrency features enabled.

### Scope
Create:
- `Package.swift` with 4 targets: OutlookCore, OutlookCLI, OutlookMCP, Executable
- Dependencies: swift-argument-parser 1.5+, swift-sdk (MCP) 0.9+, swift-log 1.6+
- All source directories (empty files with `// placeholder` as needed):
  ```
  Sources/OutlookCore/Auth/
  Sources/OutlookCore/Graph/
  Sources/OutlookCore/Models/
  Sources/OutlookCore/Services/
  Sources/OutlookCore/Config/
  Sources/OutlookCLI/Commands/
  Sources/OutlookCLI/Formatters/
  Sources/OutlookMCP/Tools/
  Sources/Executable/main.swift
  Tests/OutlookCoreTests/
  Tests/OutlookCLITests/
  ```
- Swift settings: `StrictConcurrency`, `ExistentialAny`
- Products: `.library(name: "OutlookCore")`, `.executable(name: "outlook")`

Package.swift specifics:
```swift
platforms: [.macOS(.v14)]
// OutlookCore depends on: swift-log (Logging)
// OutlookCLI depends on: OutlookCore, swift-argument-parser (ArgumentParser)
// OutlookMCP depends on: OutlookCore, swift-sdk (ModelContextProtocol)
// Executable depends on: OutlookCLI, OutlookMCP
// Test targets: OutlookCoreTests (depends: OutlookCore), OutlookCLITests (depends: OutlookCLI)
```

### Success Criteria
- `swift build` compiles with zero errors
- `swift test` runs (even if no tests yet)
- All directories exist and match the Peekaboo structure

### Test Plan
- `swift build` succeeds
- `swift package describe` shows correct target graph

### Considerations
- Use `NonisolatedNonsendingByDefault` upcoming feature if swift-sdk requires it
- The MCP swift-sdk package name may be `ModelContextProtocol` or `MCP` — verify at resolution time
- Executable's main.swift should parse top-level command and route to CLI or MCP serve subcommand


## BD-002: Codable Models
- **Type:** foundation
- **Priority:** P0 (blocking)
- **Depends on:** BD-001
- **Blocks:** BD-015, BD-016, BD-017, BD-018, BD-019
- **Estimated effort:** L (full day)

### Background
All Microsoft Graph API responses are JSON. We need comprehensive Codable models that map to Graph API v1.0 schemas. These models are used by every service, CLI formatter, and MCP tool. All models must be Sendable (Swift 6 concurrency).

### Scope
Create the following files in `Sources/OutlookCore/Models/`:

**Message.swift:**
- `Message` — id, subject, from (EmailAddress), toRecipients, ccRecipients, bccRecipients, receivedDateTime (Date), sentDateTime, isRead (Bool), isDraft, importance (Importance enum: low/normal/high), flag (MessageFlag?), body (MessageBody?), bodyPreview, hasAttachments, parentFolderId, conversationId, webLink
- `EmailAddress` — name (String?), address (String). Note: Graph API nests this as `{"emailAddress": {"name": ..., "address": ...}}` in recipients
- `MessageBody` — contentType (String: "text" or "html"), content (String)
- `Importance` — enum: low, normal, high (raw String, Codable)
- `MessageFlag` — flagStatus (String: "notFlagged", "flagged", "complete")
- `DraftMessage` — struct for composing: to ([String]), cc, bcc, subject, body, bodyContentType, attachmentPaths
- `MailFolder` — id, displayName, parentFolderId, childFolderCount, unreadItemCount, totalItemCount
- `Attachment` — id, name, contentType, size, isInline
- `AttachmentContent` — extends Attachment with contentBytes (Base64 Data)

**Event.swift:**
- `Event` — id, subject, body (MessageBody?), start (DateTimeTimeZone), end (DateTimeTimeZone), location (Location?), attendees ([Attendee]?), organizer (EmailAddress?), isAllDay, isCancelled, responseStatus (ResponseStatus?), recurrence (Recurrence?), onlineMeeting (OnlineMeeting?), webLink
- `DateTimeTimeZone` — dateTime (String, ISO 8601), timeZone (String)
- `Location` — displayName, address (PhysicalAddress?), coordinates
- `Attendee` — emailAddress (EmailAddress), type (String: required/optional/resource), status (ResponseStatus?)
- `ResponseStatus` — response (String: none/organizer/accepted/declined/tentativelyAccepted), time (String?)
- `Recurrence` — pattern (RecurrencePattern), range (RecurrenceRange) — simplified
- `OnlineMeeting` — joinUrl (String?)
- `DraftEvent` — subject, start, end, location, attendees, body, isAllDay
- `EventUpdate` — optional fields for PATCH
- `EventResponse` — enum: accept, decline, tentative
- `Calendar` — id, name, color, isDefaultCalendar, canEdit
- `ScheduleInfo` — scheduleId, availabilityView, scheduleItems

**Contact.swift:**
- `Contact` — id, displayName, givenName, surname, emailAddresses ([TypedEmailAddress]?), businessPhones, mobilePhone, companyName, jobTitle, department, businessAddress (PhysicalAddress?), birthday
- `TypedEmailAddress` — address, name, type (if available)
- `PhysicalAddress` — street, city, state, countryOrRegion, postalCode
- `DraftContact` — for creation
- `ContactUpdate` — optional fields for PATCH

**DriveItem.swift:**
- `DriveItem` — id, name, size (Int64?), createdDateTime, lastModifiedDateTime, webUrl, folder (FolderFacet?), file (FileFacet?), parentReference (ItemReference?)
- `FolderFacet` — childCount (Int)
- `FileFacet` — mimeType (String)
- `ItemReference` — driveId, id, path

**SearchResult.swift:**
- `SearchResult` — entityType (SearchEntityType), hitId, summary, resource (can be Message, Event, DriveItem, Contact)
- `SearchEntityType` — enum: message, event, driveItem, contact
- `GraphPagedResponse<T: Decodable>` — value ([T]), odataNextLink (String?) with CodingKeys mapping `@odata.nextLink`

### Success Criteria
- All models compile, conform to Codable + Sendable + Identifiable (where applicable)
- JSON round-trip test: encode → decode produces identical values
- Graph API sample JSON payloads decode without error

### Test Plan
- Unit tests with real Graph API JSON fixtures for each model type
- Test edge cases: nil optional fields, empty arrays, HTML body content
- Test `GraphPagedResponse` with and without nextLink
- Test `EmailAddress` nested structure (Graph wraps in `emailAddress` key for recipients)

### Considerations
- Graph API uses camelCase JSON keys — Swift default Codable handles this
- **Recipients** in Graph API are `[{"emailAddress": {"name": "...", "address": "..."}}]` — need custom CodingKeys or wrapper struct `Recipient` containing `emailAddress: EmailAddress`
- Dates from Graph come as ISO 8601 strings — use custom DateFormatter or `.iso8601` strategy
- `DateTimeTimeZone` is NOT a Date — it's a string pair. Don't auto-decode as Date.
- Some fields like `body` are only returned when explicitly requested via `$select` or single-item GET
- `SearchResult.resource` is polymorphic — may need manual decoding based on `entityType`


## BD-003: GraphError Types
- **Type:** foundation
- **Priority:** P0 (blocking)
- **Depends on:** BD-001
- **Blocks:** BD-012
- **Estimated effort:** S (hours)

### Background
Graph API returns structured error responses. We need a comprehensive error enum that maps HTTP status codes to actionable Swift errors with user-friendly descriptions. These errors propagate through services → CLI/MCP for display.

### Scope
Create `Sources/OutlookCore/Graph/GraphError.swift`:

```swift
enum GraphError: Error, LocalizedError, Sendable {
    case unauthorized(String)           // 401
    case forbidden(String)              // 403 — missing permissions
    case notFound(String)               // 404
    case conflict(String)               // 409
    case rateLimited(retryAfter: Int)   // 429 — include Retry-After seconds
    case serverError(statusCode: Int, message: String)  // 5xx
    case networkError(underlying: Error)  // URLSession errors
    case decodingError(underlying: Error) // JSON decode failures
    case invalidRequest(String)         // Client-side validation
    case authenticationRequired         // No token available
    case readOnlyMode(toolName: String) // Write attempted in read-only mode
    case tokenExpired                   // Refresh needed
    
    var errorDescription: String? { ... }  // Human-readable
}
```

Also parse Graph API error response body:
```swift
struct GraphAPIError: Decodable {
    let error: GraphAPIErrorBody
}
struct GraphAPIErrorBody: Decodable {
    let code: String
    let message: String
}
```

### Success Criteria
- All error cases compile and provide meaningful `errorDescription`
- Graph API error JSON parses into appropriate `GraphError` case

### Test Plan
- Unit test: each error case has non-empty description
- Unit test: parse Graph API error JSON → correct GraphError
- Test `rateLimited` extracts retry-after value

### Considerations
- `networkError` wraps URLError — keep the underlying error for debugging
- `readOnlyMode` is client-side, not from Graph API
- Graph error codes include things like "ErrorItemNotFound", "ErrorAccessDenied" — map these to our enum


## BD-004: KeychainStorage Wrapper
- **Type:** foundation
- **Priority:** P0 (blocking)
- **Depends on:** BD-001
- **Blocks:** BD-006, BD-007
- **Estimated effort:** M (half-day)

### Background
Tokens must persist securely in macOS Keychain. This wrapper provides a simple async-compatible API for CRUD on keychain items. Service name: "com.outlookcli.auth". Each account stores access_token, refresh_token, and account_info JSON.

### Scope
Create `Sources/OutlookCore/Auth/KeychainStorage.swift`:

```swift
struct KeychainStorage: Sendable {
    let service: String  // "com.outlookcli.auth"
    
    func save(key: String, data: Data) throws
    func load(key: String) throws -> Data?
    func delete(key: String) throws
    func listKeys(prefix: String?) throws -> [String]
}
```

Key naming convention:
- `{email}.access_token` — short-lived (~1 hour)
- `{email}.refresh_token` — long-lived (~90 days)  
- `{email}.account_info` — JSON with tenant, scopes, display name

Use Security framework (`SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete`).

### Success Criteria
- Save/load/delete round-trip works
- Listing keys with prefix filter works
- Errors are descriptive (not raw OSStatus codes)

### Test Plan
- Integration test: save → load → verify data matches
- Test: load nonexistent key returns nil
- Test: delete → load returns nil
- Test: listKeys with prefix filtering
- Test: overwrite existing key with save

### Considerations
- Keychain operations are synchronous — wrap in Task if needed
- Handle `errSecItemNotFound` gracefully (return nil, don't throw)
- Handle `errSecDuplicateItem` by updating instead of failing
- Tests should use a unique service name to avoid polluting real keychain
- Consider `kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for security


## BD-005: OutlookConfig
- **Type:** foundation
- **Priority:** P0 (blocking)
- **Depends on:** BD-001
- **Blocks:** BD-006, BD-007, BD-008
- **Estimated effort:** S (hours)

### Background
Central configuration for the app — client ID, tenant ID, scopes, default settings. Reads from environment variables with sensible defaults.

### Scope
Create `Sources/OutlookCore/Config/OutlookConfig.swift`:

```swift
struct OutlookConfig: Sendable {
    let clientId: String          // OUTLOOK_CLIENT_ID (required for first login)
    let tenantId: String          // OUTLOOK_TENANT_ID (default: "common")
    let defaultAccount: String?   // OUTLOOK_ACCOUNT
    let outputFormat: OutputFormat // OUTLOOK_FORMAT (default: .table)
    let readOnly: Bool            // OUTLOOK_READ_ONLY (default: false)
    
    // OAuth endpoints
    var deviceCodeURL: URL { ... }   // login.microsoftonline.com/{tenant}/oauth2/v2.0/devicecode
    var tokenURL: URL { ... }        // login.microsoftonline.com/{tenant}/oauth2/v2.0/token
    
    // Scopes
    static let defaultScopes: [String] = [
        "Mail.ReadWrite", "Calendars.ReadWrite", "Contacts.ReadWrite",
        "Files.ReadWrite", "People.Read", "User.Read", "offline_access"
    ]
    
    init(clientId: String? = nil, tenantId: String? = nil, ...) {
        // Read from params, fall back to env vars, fall back to defaults
    }
}

enum OutputFormat: String, Sendable {
    case table, json, compact
}
```

### Success Criteria
- Config reads from environment variables correctly
- OAuth URLs are correctly constructed with tenant ID
- Default scopes match Graph API requirements

### Test Plan
- Unit test: default values when no env vars set
- Unit test: env var override works
- Unit test: OAuth URLs constructed correctly for different tenants

### Considerations
- `clientId` is required for auth but not for all operations (e.g., if tokens already cached)
- "common" tenant supports both personal and work accounts
- Don't hardcode a client ID — user must register their own Azure app


---

# Wave 2 — Auth (Depends on Wave 1)

## BD-006: DeviceCodeFlow
- **Type:** feature
- **Priority:** P0 (blocking)
- **Depends on:** BD-001, BD-004, BD-005
- **Blocks:** BD-007, BD-008
- **Estimated effort:** L (full day)

### Background
Device Code Flow is the only auth method we support. It works in any terminal (including SSH, containers) without needing a browser redirect. The user visits a URL, enters a code, and the CLI polls for the token.

### Scope
Create `Sources/OutlookCore/Auth/DeviceCodeFlow.swift`:

```swift
actor DeviceCodeFlow {
    let config: OutlookConfig
    
    struct DeviceCodeResponse: Decodable {
        let deviceCode: String
        let userCode: String
        let verificationUri: String
        let expiresIn: Int
        let interval: Int
        let message: String
    }
    
    struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int
        let scope: String
        let tokenType: String
    }
    
    // Step 1: Request device code
    func requestDeviceCode() async throws -> DeviceCodeResponse
    
    // Step 2: Poll for token (with callback for UI updates)
    func pollForToken(
        deviceCode: String, 
        interval: Int,
        onWaiting: @Sendable () -> Void
    ) async throws -> TokenResponse
    
    // Step 3: Refresh existing token
    func refreshToken(_ refreshToken: String) async throws -> TokenResponse
}
```

HTTP details:
- Device code request: POST to `{tokenURL}/../devicecode` with `client_id` and `scope`
- Token poll: POST to `{tokenURL}` with `grant_type=urn:ietf:params:oauth:grant-type:device_code`, `client_id`, `device_code`
- Poll responses: `authorization_pending` (keep going), `authorization_declined` (throw), `expired_token` (throw), `slow_down` (increase interval)
- Refresh: POST to `{tokenURL}` with `grant_type=refresh_token`, `client_id`, `refresh_token`

### Success Criteria
- Device code request returns valid user_code and verification URL
- Polling respects interval, handles all response types
- Token refresh works with valid refresh token
- Errors are clear and actionable

### Test Plan
- Unit test with mocked URLSession: device code request parsing
- Unit test: poll handles authorization_pending (loops)
- Unit test: poll handles authorization_declined (throws)
- Unit test: poll handles expired_token (throws)
- Unit test: poll handles slow_down (increases interval)
- Unit test: refresh token request/response parsing
- Unit test: malformed responses handled gracefully

### Considerations
- Use `URLSession.shared` — no external HTTP deps
- Poll interval is usually 5 seconds — respect the server's value
- Device codes expire (usually 15 min) — handle timeout gracefully
- The `message` field from device code response is pre-formatted for display — use it
- Content-Type for all requests: `application/x-www-form-urlencoded`


## BD-007: TokenManager
- **Type:** feature
- **Priority:** P0 (blocking)
- **Depends on:** BD-004, BD-005, BD-006
- **Blocks:** BD-012
- **Estimated effort:** M (half-day)

### Background
TokenManager orchestrates the token lifecycle: acquire (via device code), refresh (silent), cache (keychain), and provide valid tokens to GraphClient. It's the single point of contact for "get me a valid access token."

### Scope
Create `Sources/OutlookCore/Auth/TokenManager.swift`:

```swift
actor TokenManager {
    let keychain: KeychainStorage
    let config: OutlookConfig
    let deviceCodeFlow: DeviceCodeFlow
    
    // Get valid access token (refresh silently if needed)
    func getAccessToken(for account: String? = nil) async throws -> String
    
    // Full login flow (device code)
    func login(onDeviceCode: @Sendable (DeviceCodeFlow.DeviceCodeResponse) -> Void) async throws -> AccountInfo
    
    // Remove tokens for account
    func logout(account: String) async throws
    
    // Check if we have tokens for an account
    func hasTokens(for account: String) -> Bool
    
    // Get account info
    func getAccountInfo(for account: String) async throws -> AccountInfo?
}

struct AccountInfo: Codable, Sendable {
    let email: String
    let displayName: String?
    let tenantId: String
    let scopes: [String]
    let tokenExpiry: Date
}
```

Token acquisition logic:
1. Load access_token from keychain → check if expired (decode JWT exp claim or track expiry time)
2. If expired → load refresh_token → call `DeviceCodeFlow.refreshToken()` → save new tokens
3. If no refresh token or refresh fails → throw `authenticationRequired`
4. After device code login → extract user info from access token (JWT decode) or call `/me` endpoint → save all to keychain

### Success Criteria
- `getAccessToken()` returns valid token silently when refresh_token exists
- `login()` runs device code flow and stores tokens in keychain
- `logout()` removes all tokens for specified account

### Test Plan
- Unit test: getAccessToken with valid cached token returns immediately
- Unit test: getAccessToken with expired token triggers refresh
- Unit test: getAccessToken with no tokens throws authenticationRequired
- Unit test: login stores tokens in keychain
- Unit test: logout removes tokens

### Considerations
- JWT decoding for expiry: only need to decode the payload (base64), check `exp` claim. Don't validate signature (we trust Azure AD).
- Alternatively, store `expiresAt` timestamp alongside the token in keychain
- Race condition: multiple concurrent `getAccessToken` calls during refresh — use actor isolation to serialize
- Refresh tokens can also expire (~90 days) — handle gracefully


## BD-008: AccountManager (Multi-Account)
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-004, BD-005, BD-007
- **Blocks:** BD-009, BD-010
- **Estimated effort:** M (half-day)

### Background
Users may have work + personal Microsoft accounts. AccountManager tracks all authenticated accounts and provides a "current account" concept.

### Scope
Create `Sources/OutlookCore/Auth/AccountManager.swift`:

```swift
actor AccountManager {
    let keychain: KeychainStorage
    let tokenManager: TokenManager
    
    // List all accounts
    func listAccounts() throws -> [AccountInfo]
    
    // Get/set default account
    func getDefaultAccount() throws -> String?
    func setDefaultAccount(_ email: String) throws
    
    // Get current account (explicit > env var > default > only account)
    func resolveAccount(_ explicit: String?) throws -> String
    
    // Add account (after login)
    func addAccount(_ info: AccountInfo) throws
    
    // Remove account
    func removeAccount(_ email: String) throws
}
```

Default account resolution order:
1. Explicitly passed account parameter
2. `OUTLOOK_ACCOUNT` environment variable
3. Stored default account in keychain (`_default_account` key)
4. If only one account exists, use it
5. Error: "Multiple accounts found, specify which one"

### Success Criteria
- Can manage multiple accounts in keychain
- Account resolution follows priority order
- Default account persists across sessions

### Test Plan
- Unit test: single account auto-resolves
- Unit test: explicit account overrides default
- Unit test: env var overrides stored default
- Unit test: multiple accounts with no default throws helpful error

### Considerations
- Store default account as a special keychain entry (`_default_account`)
- `listAccounts` scans keychain for `*.account_info` entries
- Account removal should also clean up access_token and refresh_token entries


---

# Wave 3 — Graph Client (Depends on Wave 2)

## BD-009: GraphClient Actor
- **Type:** feature
- **Priority:** P0 (blocking)
- **Depends on:** BD-003, BD-007, BD-008
- **Blocks:** BD-015, BD-016, BD-017, BD-018, BD-019
- **Estimated effort:** L (full day)

### Background
The central HTTP client for all Graph API calls. Actor-isolated for thread safety. Handles authentication header injection, retry with exponential backoff, rate limiting (429), and JSON decoding.

### Scope
Create `Sources/OutlookCore/Graph/GraphClient.swift`:

```swift
actor GraphClient {
    let tokenManager: TokenManager
    let accountManager: AccountManager
    let baseURL = "https://graph.microsoft.com/v1.0"
    let session: URLSession
    
    let maxRetries = 3
    let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    
    // Core request method
    func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        query: [String: String]? = nil,
        body: (any Encodable)? = nil,
        headers: [String: String]? = nil,
        accountId: String? = nil
    ) async throws -> T
    
    // Void response variant (for DELETE, etc.)
    func request(
        _ method: HTTPMethod,
        path: String,
        query: [String: String]? = nil,
        body: (any Encodable)? = nil,
        accountId: String? = nil
    ) async throws
    
    // Raw data response (for file downloads)
    func requestData(
        _ method: HTTPMethod,
        path: String,
        accountId: String? = nil
    ) async throws -> Data
    
    // Upload with data body
    func upload(
        path: String,
        data: Data,
        contentType: String,
        accountId: String? = nil
    ) async throws -> DriveItem
}

enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}
```

Retry logic:
- On 429: Read `Retry-After` header (seconds), sleep, retry
- On 5xx: Exponential backoff with jitter (1s, 2s, 4s base + random 0-500ms)
- On 401: Attempt token refresh via TokenManager, retry once
- On other 4xx: Throw immediately with parsed Graph API error
- Network errors: Retry up to maxRetries with backoff

Request construction:
- Authorization: Bearer {token}
- Content-Type: application/json (for body)
- Prefer: outlook.timezone="{systemTimezone}" (for calendar requests)

### Success Criteria
- Authenticated requests work against Graph API
- 429 responses trigger wait + retry
- 401 triggers token refresh + retry
- 5xx triggers exponential backoff
- Clean JSON decoding with descriptive errors on failure

### Test Plan
- Unit test with mock URLSession: successful request decodes correctly
- Unit test: 429 response triggers retry with correct delay
- Unit test: 401 triggers token refresh then retry
- Unit test: 5xx triggers exponential backoff
- Unit test: max retries exhausted throws error
- Unit test: network error retries
- Unit test: 404 throws notFound immediately (no retry)
- Unit test: malformed JSON throws decodingError

### Considerations
- Use a custom URLProtocol subclass for unit testing (mock responses)
- `Prefer: outlook.timezone` header should use `TimeZone.current.identifier`
- JSON decoder should handle ISO 8601 dates with `dateDecodingStrategy`
- Consider a `Logging.Logger` for request/response debug logging
- File downloads return raw Data, not JSON — need separate method


## BD-010: GraphRequest Builder (OData Query Params)
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-001
- **Blocks:** BD-015, BD-016, BD-017, BD-018, BD-019
- **Estimated effort:** S (hours)

### Background
Graph API uses OData query parameters ($select, $filter, $orderby, $top, $skip, $search, $expand). A builder pattern makes constructing these clean and type-safe.

### Scope
Create `Sources/OutlookCore/Graph/GraphRequest.swift`:

```swift
struct GraphQuery: Sendable {
    private var params: [String: String] = [:]
    
    func select(_ fields: String...) -> GraphQuery
    func filter(_ expression: String) -> GraphQuery
    func orderBy(_ field: String, descending: Bool = false) -> GraphQuery
    func top(_ count: Int) -> GraphQuery
    func skip(_ count: Int) -> GraphQuery
    func search(_ query: String) -> GraphQuery  // $search requires quotes
    func expand(_ field: String) -> GraphQuery
    func count(_ include: Bool = true) -> GraphQuery  // $count=true
    
    func build() -> [String: String]
}
```

Usage example:
```swift
GraphQuery()
    .select("id", "subject", "from", "receivedDateTime", "isRead")
    .filter("isRead eq false")
    .orderBy("receivedDateTime", descending: true)
    .top(25)
    .build()
// → ["$select": "id,subject,from,receivedDateTime,isRead", "$filter": "isRead eq false", ...]
```

### Success Criteria
- Builder produces correct OData query parameter dictionaries
- All OData operators supported: $select, $filter, $orderby, $top, $skip, $search, $expand, $count

### Test Plan
- Unit test: each method produces correct key-value
- Unit test: chaining multiple methods combines correctly
- Unit test: `search` wraps query in double quotes
- Unit test: `orderBy` with descending flag appends " desc"
- Unit test: empty builder produces empty dictionary

### Considerations
- `$search` values must be wrapped in double quotes: `$search: "\"meeting notes\""`
- `$filter` expressions use OData syntax (e.g., `isRead eq false`, `receivedDateTime ge 2024-01-01`)
- Multiple `orderBy` calls should comma-separate: `receivedDateTime desc,subject asc`
- Builder should be immutable (return new instance each time) for safety


## BD-011: Pagination Support
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-002, BD-009
- **Blocks:** BD-015, BD-016, BD-017, BD-018, BD-019
- **Estimated effort:** M (half-day)

### Background
Graph API paginates large result sets using `@odata.nextLink`. Services need both manual pagination (return page + nextLink) and automatic pagination (follow all pages, return combined results).

### Scope
Extend `GraphClient` with pagination methods:

```swift
extension GraphClient {
    // Fetch single page (returns items + optional nextLink)
    func requestPage<T: Decodable>(
        path: String,
        query: [String: String]? = nil,
        accountId: String? = nil
    ) async throws -> (items: [T], nextLink: String?)
    
    // Fetch all pages automatically (follows @odata.nextLink)
    func requestAll<T: Decodable>(
        path: String,
        query: [String: String]? = nil,
        maxPages: Int = 10,  // Safety limit
        accountId: String? = nil
    ) async throws -> [T]
    
    // Fetch next page from a nextLink URL
    func requestNextPage<T: Decodable>(
        nextLink: String,
        accountId: String? = nil
    ) async throws -> (items: [T], nextLink: String?)
}
```

Uses `GraphPagedResponse<T>` model (from BD-002) which decodes `value` array and `@odata.nextLink`.

### Success Criteria
- Single page request returns items and nextLink when present
- `requestAll` follows nextLink until exhausted or maxPages reached
- `requestNextPage` works with full URL from @odata.nextLink

### Test Plan
- Unit test: single page with no nextLink returns items only
- Unit test: single page with nextLink returns both
- Unit test: requestAll follows 3 pages of mock data
- Unit test: requestAll stops at maxPages limit
- Unit test: requestNextPage works with absolute URL

### Considerations
- `@odata.nextLink` is an absolute URL — don't prepend baseURL
- maxPages safety limit prevents runaway pagination (e.g., 10,000 contacts)
- MCP tools should expose `hasMore` + `nextLink` for agents to paginate manually
- Delta queries (`@odata.deltaLink`) are out of scope for now


---

# Wave 4 — Services (Depends on Wave 3)

## BD-012: MailService
- **Type:** feature
- **Priority:** P0 (blocking)
- **Depends on:** BD-002, BD-003, BD-009, BD-010, BD-011
- **Blocks:** BD-020, BD-025
- **Estimated effort:** XL (multi-day)

### Background
Mail is the primary use case. MailService wraps GraphClient with mail-specific business logic. It maps to `/me/messages`, `/me/mailFolders`, and related endpoints.

### Scope
Create `Sources/OutlookCore/Services/MailService.swift`:

```swift
actor MailService {
    let client: GraphClient
    
    // Read operations
    func listMessages(folder: String?, unreadOnly: Bool, count: Int, skip: Int, includeBody: Bool) async throws -> (messages: [Message], nextLink: String?)
    func getMessage(id: String, includeBody: Bool) async throws -> Message
    func searchMessages(query: String, count: Int) async throws -> [Message]
    func listFolders() async throws -> [MailFolder]
    
    // Write operations
    func sendMessage(_ draft: DraftMessage) async throws
    func createDraft(_ draft: DraftMessage) async throws -> Message
    func replyToMessage(id: String, body: String, replyAll: Bool) async throws
    func forwardMessage(id: String, to: [String], comment: String?) async throws
    func moveMessage(id: String, destinationFolder: String) async throws -> Message
    func deleteMessage(id: String) async throws
    func updateMessage(id: String, isRead: Bool?, flag: MessageFlag?) async throws
    
    // Attachments
    func listAttachments(messageId: String) async throws -> [Attachment]
    func getAttachment(messageId: String, attachmentId: String) async throws -> AttachmentContent
    func downloadAttachment(messageId: String, attachmentId: String, to: URL) async throws
}
```

API paths:
- List messages: GET `/me/mailFolders/{folder}/messages` or `/me/messages`
- Default folder: "inbox"
- Send: POST `/me/sendMail` with `{"message": {...}, "saveToSentItems": true}`
- Create draft: POST `/me/messages`
- Reply: POST `/me/messages/{id}/reply` with `{"comment": "body"}`
- Reply all: POST `/me/messages/{id}/replyAll`
- Forward: POST `/me/messages/{id}/forward` with `{"comment": "...", "toRecipients": [...]}`
- Move: POST `/me/messages/{id}/move` with `{"destinationId": "folder-id-or-name"}`
- Delete: DELETE `/me/messages/{id}`
- Update: PATCH `/me/messages/{id}` with fields
- Folders: GET `/me/mailFolders`
- Attachments: GET `/me/messages/{id}/attachments`

Message body for sendMail:
```json
{
    "message": {
        "subject": "...",
        "body": {"contentType": "Text", "content": "..."},
        "toRecipients": [{"emailAddress": {"address": "person@example.com"}}],
        "ccRecipients": [...],
        "bccRecipients": [...]
    },
    "saveToSentItems": true
}
```

### Success Criteria
- All CRUD operations work against Graph API
- Folder operations use folder display name or ID
- Attachments can be listed and downloaded
- Proper `$select` fields for list vs detail views

### Test Plan
- Unit test with mock: listMessages parses response correctly
- Unit test: sendMessage constructs correct request body
- Unit test: moveMessage with folder name vs ID
- Unit test: searchMessages uses `$search` parameter
- Unit test: attachment download writes file correctly
- Integration test: list → read → reply roundtrip

### Considerations
- `sendMail` endpoint wraps message in `{"message": ..., "saveToSentItems": true}` — different from creating a draft
- Folder names like "inbox", "sentitems", "drafts" are well-known names that Graph accepts directly
- Custom folders need their ID — may need folder lookup by name
- For `includeBody: false`, use `$select` without "body" field to save bandwidth
- HTML body conversion: when displaying in CLI, strip HTML tags or show raw
- Attachments > 3MB use reference attachments — out of scope, document limitation


## BD-013: CalendarService
- **Type:** feature
- **Priority:** P0 (blocking)
- **Depends on:** BD-002, BD-003, BD-009, BD-010, BD-011
- **Blocks:** BD-021, BD-026
- **Estimated effort:** L (full day)

### Background
Calendar management: list events, create meetings, respond to invitations, check free/busy. Uses `/me/events`, `/me/calendarView`, `/me/calendars`.

### Scope
Create `Sources/OutlookCore/Services/CalendarService.swift`:

```swift
actor CalendarService {
    let client: GraphClient
    
    // Read
    func listEvents(from: Date, to: Date, calendarId: String?, count: Int) async throws -> [Event]
    func getEvent(id: String) async throws -> Event
    func searchEvents(query: String) async throws -> [Event]
    func listCalendars() async throws -> [Calendar]
    func checkAvailability(attendees: [String], from: Date, to: Date, duration: Int) async throws -> [ScheduleInfo]
    
    // Write
    func createEvent(_ draft: DraftEvent) async throws -> Event
    func updateEvent(id: String, updates: EventUpdate) async throws -> Event
    func deleteEvent(id: String, notify: Bool) async throws
    func respondToEvent(id: String, response: EventResponse, message: String?) async throws
}
```

API paths:
- List (date range): GET `/me/calendarView?startDateTime=...&endDateTime=...` (expands recurring events)
- Get: GET `/me/events/{id}`
- Create: POST `/me/events`
- Update: PATCH `/me/events/{id}`
- Delete: DELETE `/me/events/{id}`
- Respond: POST `/me/events/{id}/accept`, `/decline`, `/tentativelyAccept`
- Free/busy: POST `/me/calendar/getSchedule`
- Calendars: GET `/me/calendars`
- Search: GET `/me/events` with `$filter` or `$search`

Use `Prefer: outlook.timezone` header for all calendar requests.

### Success Criteria
- CalendarView expands recurring events in date range
- Event creation includes attendees, location, body
- Free/busy shows availability for multiple attendees
- Timezone handling is correct

### Test Plan
- Unit test: listEvents constructs calendarView request with correct date params
- Unit test: createEvent builds correct JSON body
- Unit test: respondToEvent calls correct endpoint per response type
- Unit test: checkAvailability request/response parsing
- Unit test: date formatting for API params

### Considerations
- Use `/me/calendarView` (not `/me/events`) for date ranges — it expands recurring events
- `startDateTime` and `endDateTime` are required for calendarView
- Dates must be ISO 8601 format for query params
- `Prefer: outlook.timezone` header defaults to system timezone
- Free/busy `getSchedule` requires `Schedules.Read` or similar — may need additional scope
- All-day events have no time component — handle in display


## BD-014: ContactService
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-002, BD-003, BD-009, BD-010, BD-011
- **Blocks:** BD-022, BD-027
- **Estimated effort:** M (half-day)

### Background
Contact CRUD + search. Uses `/me/contacts` and `/me/people` (for intelligent search).

### Scope
Create `Sources/OutlookCore/Services/ContactService.swift`:

```swift
actor ContactService {
    let client: GraphClient
    
    func listContacts(count: Int, skip: Int) async throws -> (contacts: [Contact], nextLink: String?)
    func getContact(id: String) async throws -> Contact
    func searchContacts(query: String) async throws -> [Contact]
    func createContact(_ draft: DraftContact) async throws -> Contact
    func updateContact(id: String, updates: ContactUpdate) async throws -> Contact
    func deleteContact(id: String) async throws
}
```

API paths:
- List: GET `/me/contacts` with `$top`, `$skip`, `$select`, `$orderby`
- Get: GET `/me/contacts/{id}`
- Search: GET `/me/people?$search="query"` (People API for relevance) + fallback to `/me/contacts?$filter=...`
- Create: POST `/me/contacts`
- Update: PATCH `/me/contacts/{id}`
- Delete: DELETE `/me/contacts/{id}`

### Success Criteria
- Full CRUD operations work
- Search uses People API for relevance-ranked results
- Pagination works for large contact lists

### Test Plan
- Unit test: listContacts with pagination
- Unit test: createContact builds correct JSON
- Unit test: searchContacts uses People API
- Unit test: updateContact sends only changed fields

### Considerations
- People API (`/me/people`) requires `People.Read` scope and returns relevance-ranked results
- People API results differ from Contacts — may need mapping
- Personal accounts may have limited People API support — fall back to contacts search


## BD-015: DriveService
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-002, BD-003, BD-009, BD-010, BD-011
- **Blocks:** BD-023, BD-028
- **Estimated effort:** L (full day)

### Background
OneDrive file operations. Browse folders, download files, upload (with chunked upload for large files), search.

### Scope
Create `Sources/OutlookCore/Services/DriveService.swift`:

```swift
actor DriveService {
    let client: GraphClient
    
    func listItems(path: String?, folderId: String?) async throws -> [DriveItem]
    func getItem(id: String) async throws -> DriveItem
    func downloadFile(id: String, to: URL) async throws
    func uploadFile(from: URL, to: String) async throws -> DriveItem
    func deleteItem(id: String) async throws
    func searchFiles(query: String) async throws -> [DriveItem]
}
```

API paths:
- List root: GET `/me/drive/root/children`
- List by path: GET `/me/drive/root:/{path}:/children`
- List by ID: GET `/me/drive/items/{id}/children`
- Get: GET `/me/drive/items/{id}`
- Download: GET `/me/drive/items/{id}/content` (returns redirect or bytes)
- Upload small (< 4MB): PUT `/me/drive/root:/{path}:/content` with file bytes
- Upload large (≥ 4MB): Create upload session → chunked PUT
- Delete: DELETE `/me/drive/items/{id}`
- Search: GET `/me/drive/root/search(q='{query}')`

**Chunked upload for large files:**
1. POST `/me/drive/root:/{path}:/createUploadSession`
2. PUT chunks of ~4.8MB with `Content-Range: bytes {start}-{end}/{total}`
3. Last chunk returns the created DriveItem

### Success Criteria
- Browse folders by path or ID
- Download files to local path
- Small file upload works (< 4MB)
- Large file upload works with chunked session (≥ 4MB)
- Search finds files by name/content

### Test Plan
- Unit test: listItems constructs correct path for root/path/ID
- Unit test: uploadFile chooses simple vs chunked based on size
- Unit test: chunked upload sends correct Content-Range headers
- Unit test: downloadFile writes data to specified URL
- Unit test: search constructs correct URL

### Considerations
- Download may return 302 redirect — follow it or use `@microsoft.graph.downloadUrl` from metadata
- Chunked upload requires tracking session URL and resuming on failure
- File path encoding: spaces and special chars must be URL-encoded
- Search is eventually consistent — newly uploaded files may take time to appear


## BD-016: SearchService
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-002, BD-003, BD-009, BD-010
- **Blocks:** BD-024, BD-029
- **Estimated effort:** M (half-day)

### Background
Unified search across mail, calendar, contacts, and drive using Graph Search API.

### Scope
Create `Sources/OutlookCore/Services/SearchService.swift`:

```swift
actor SearchService {
    let client: GraphClient
    
    func unifiedSearch(
        query: String,
        entityTypes: [SearchEntityType],
        count: Int
    ) async throws -> [SearchResult]
}
```

API: POST `/search/query` with body:
```json
{
    "requests": [{
        "entityTypes": ["message", "event", "driveItem"],
        "query": {"queryString": "budget report"},
        "from": 0,
        "size": 25
    }]
}
```

Response includes `hitsContainers` → `hits` with `summary`, `resource` (polymorphic).

### Success Criteria
- Search across multiple entity types in one call
- Results include summaries and typed resources
- Count/pagination works

### Test Plan
- Unit test: request body constructed correctly for different entity types
- Unit test: polymorphic response parsing (message vs event vs driveItem)
- Unit test: empty results handled gracefully

### Considerations
- Search API response structure is nested: `value[0].hitsContainers[0].hits`
- Resource type must be inferred from `entityType` for decoding
- Some tenants may not have Search API enabled
- Personal accounts may have limited search support


---

# Wave 5 — CLI Commands (Depends on Wave 4)

## BD-017: Output Formatters
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-002
- **Blocks:** BD-018, BD-019, BD-020, BD-021, BD-022, BD-023, BD-024
- **Estimated effort:** M (half-day)

### Background
All CLI commands support `--format table|json|compact`. Need generic formatting infrastructure plus type-specific formatters for mail, calendar, contacts, drive items.

### Scope
Create `Sources/OutlookCore/Config/OutputFormatter.swift` and `Sources/OutlookCLI/Formatters/`:

**OutputFormatter.swift (in Core):**
```swift
enum OutputFormat: String, CaseIterable, Sendable {
    case table, json, compact
}

protocol FormattableOutput {
    func formatTable() -> String
    func formatCompact() -> String
    // JSON uses Codable automatically
}
```

**MailFormatter.swift:**
- `formatMessageList([Message])` — table with columns: From, Subject, Date, Read status
- `formatMessage(Message)` — full message with headers and body
- Compact: one line per message "📧 [unread] From: subject (date)"

**CalendarFormatter.swift:**
- `formatEventList([Event])` — table with: Time, Subject, Location, Attendees count
- `formatEvent(Event)` — full event with all details
- Compact: "📅 10:00-11:00 Sprint Planning @Room 1 (5 attendees)"

**TableFormatter.swift:**
- Generic table renderer: column headers, alignment, truncation for terminal width
- Use terminal width detection (`ioctl` or `COLUMNS` env)

**ContactFormatter / DriveFormatter** — similar patterns.

### Success Criteria
- `--format table` produces aligned, readable tables
- `--format json` outputs valid JSON (Codable encoding)
- `--format compact` outputs one line per item
- Terminal width is respected (truncate long fields)

### Test Plan
- Unit test: table formatter with various column widths
- Unit test: compact format for each model type
- Unit test: JSON output parses back correctly
- Unit test: empty list produces appropriate output

### Considerations
- HTML email bodies need to be stripped for table/compact display — use regex or simple tag removal
- Date formatting should be human-friendly ("2h ago", "Yesterday", "Jan 15")
- Unicode width: emoji and CJK characters take 2 columns — handle in table alignment
- Consider colorized output (ANSI) for unread messages, event status, etc.


## BD-018: AuthCommands
- **Type:** feature
- **Priority:** P0 (blocking)
- **Depends on:** BD-007, BD-008, BD-017
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
CLI commands for authentication: login, logout, accounts, switch, status. Uses swift-argument-parser.

### Scope
Create `Sources/OutlookCLI/Commands/AuthCommands.swift`:

```swift
struct AuthCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        subcommands: [Login.self, Logout.self, Accounts.self, Switch.self, Status.self]
    )
}

struct Login: AsyncParsableCommand {
    @Option var tenant: String?      // --tenant
    @Option var clientId: String?    // --client-id
    // Runs device code flow, prints instructions, waits for auth
}

struct Logout: AsyncParsableCommand {
    @Argument var email: String?     // optional — if omitted, logout current
}

struct Accounts: AsyncParsableCommand {
    // Lists all accounts, marks default with *
}

struct Switch: AsyncParsableCommand {
    @Argument var email: String
    // Sets default account
}

struct Status: AsyncParsableCommand {
    // Shows current account, token expiry, scopes
}
```

### Success Criteria
- `outlook auth login` initiates device code flow with clear instructions
- `outlook auth accounts` lists all accounts
- `outlook auth status` shows token info
- `outlook auth switch` changes default account

### Test Plan
- CLI parsing test: all subcommands parse correctly
- CLI parsing test: --tenant and --client-id options work
- Integration test: login → status → accounts → logout flow

### Considerations
- Login should auto-open browser with `open` command on macOS (optional, nice-to-have)
- Display the pre-formatted `message` from device code response
- Status should show human-friendly token expiry ("expires in 45 minutes")


## BD-019: MailCommands
- **Type:** feature
- **Priority:** P0 (blocking)
- **Depends on:** BD-012, BD-017
- **Blocks:** none
- **Estimated effort:** L (full day)

### Background
CLI commands for mail operations. The most comprehensive command group.

### Scope
Create `Sources/OutlookCLI/Commands/MailCommands.swift`:

Commands:
- `outlook mail list [--folder FOLDER] [--unread] [--count N] [--body] [--format FORMAT]`
- `outlook mail read MESSAGE_ID [--raw] [--format FORMAT]`
- `outlook mail send TO --subject SUBJECT --body BODY [--cc CC] [--bcc BCC] [--attach FILE...]`
- `outlook mail reply MESSAGE_ID --body BODY [--all]`
- `outlook mail forward MESSAGE_ID --to TO [--comment TEXT]`
- `outlook mail move MESSAGE_ID --to FOLDER`
- `outlook mail delete MESSAGE_ID [--force]`
- `outlook mail mark MESSAGE_ID [--read|--unread] [--flag|--unflag]`
- `outlook mail folders`
- `outlook mail search QUERY [--count N]`
- `outlook mail attachments MESSAGE_ID [--download DIR]`

Each command:
1. Resolves account via AccountManager
2. Calls appropriate MailService method
3. Formats output via OutputFormatter

### Success Criteria
- All 11 mail subcommands work
- Output respects --format flag
- Error messages are clear and actionable

### Test Plan
- Command parsing tests for each subcommand
- Test: --format flag produces correct output type
- Test: missing required args produce helpful errors

### Considerations
- `mail send` is high-stakes — consider confirmation prompt unless `--force`
- `mail delete` should prompt unless `--force`
- `mail read --raw` shows original HTML body
- Multiple `--attach` flags for multiple attachments
- `--cc` and `--bcc` accept comma-separated emails


## BD-020: CalendarCommands
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-013, BD-017
- **Blocks:** none
- **Estimated effort:** L (full day)

### Background
CLI commands for calendar operations.

### Scope
Create `Sources/OutlookCLI/Commands/CalendarCommands.swift`:

Commands:
- `outlook cal list [--from DATE] [--to DATE] [--calendar ID] [--count N]`
- `outlook cal get EVENT_ID`
- `outlook cal create --subject SUBJECT --start DATETIME --end DATETIME [--location LOC] [--attendees EMAIL...]`
- `outlook cal update EVENT_ID [--subject S] [--start DT] [--end DT] [--location L]`
- `outlook cal delete EVENT_ID [--notify]`
- `outlook cal respond EVENT_ID --accept|--decline|--tentative [--message TEXT]`
- `outlook cal free-busy --attendees EMAIL... --from DATE --to DATE [--duration MIN]`
- `outlook cal calendars`
- `outlook cal search QUERY`

Default date range for `list`: today to +7 days.

### Success Criteria
- All 9 calendar subcommands work
- Date input parsing is flexible (ISO 8601, "tomorrow", "next monday")
- Free/busy shows availability grid

### Test Plan
- Command parsing tests for each subcommand
- Test: date input parsing for various formats
- Test: default date range (today to +7 days)

### Considerations
- Date parsing: support ISO 8601 at minimum, consider natural language (Foundation's date parsing)
- `--notify` on delete sends cancellation to attendees — default should be true for events with attendees
- `--attendees` accepts comma-separated or multiple flags
- Free/busy display: consider ASCII time grid or simple table


## BD-021: ContactCommands
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-014, BD-017
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
CLI commands for contact CRUD and search.

### Scope
Create `Sources/OutlookCLI/Commands/ContactCommands.swift`:

Commands:
- `outlook contact list [--count N]`
- `outlook contact get CONTACT_ID`
- `outlook contact create --name NAME [--email EMAIL] [--phone PHONE] [--company COMPANY]`
- `outlook contact update CONTACT_ID [--name N] [--email E] [--phone P]`
- `outlook contact delete CONTACT_ID`
- `outlook contact search QUERY`

### Success Criteria
- All 6 contact subcommands work
- Search uses People API for relevance

### Test Plan
- Command parsing tests for each subcommand
- Test: create with all optional fields
- Test: search returns formatted results

### Considerations
- Contact IDs are opaque Graph IDs — consider showing a short hash in list view for usability
- People API results may include non-contact people (e.g., frequent email correspondents)


## BD-022: DriveCommands
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-015, BD-017
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
CLI commands for OneDrive file operations.

### Scope
Create `Sources/OutlookCLI/Commands/DriveCommands.swift`:

Commands:
- `outlook drive list [PATH] [--folder-id ID]`
- `outlook drive get ITEM_ID`
- `outlook drive download ITEM_ID [--output DIR]`
- `outlook drive upload FILE --to PATH`
- `outlook drive delete ITEM_ID`
- `outlook drive search QUERY`

### Success Criteria
- All 6 drive subcommands work
- Upload shows progress for large files
- Download saves to correct location

### Test Plan
- Command parsing tests for each subcommand
- Test: download creates file at specified path
- Test: upload with --to path

### Considerations
- Large file upload should show progress (bytes uploaded / total)
- Download: default output is current directory with original filename
- `list` with no path shows root drive contents
- File sizes should be human-formatted (KB, MB, GB)


## BD-023: SearchCommands
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-016, BD-017
- **Blocks:** none
- **Estimated effort:** S (hours)

### Background
Unified search CLI command that searches across all entity types.

### Scope
Create `Sources/OutlookCLI/Commands/SearchCommands.swift`:

```
outlook search QUERY [--type message,event,driveItem,contact] [--count N]
```

Default: search all types. Results grouped by type with appropriate formatting.

### Success Criteria
- Search across multiple types in one command
- Results grouped and formatted by type
- --type flag filters to specific entity types

### Test Plan
- Command parsing test: --type with comma-separated values
- Test: results grouped correctly by type

### Considerations
- Default entity types: all four (message, event, driveItem, contact)
- Display search hit summaries from Graph API (keyword highlighting)


## BD-024: Main Entry Point & Root Command
- **Type:** feature
- **Priority:** P0 (blocking)
- **Depends on:** BD-018, BD-019, BD-020, BD-021, BD-022, BD-023
- **Blocks:** none
- **Estimated effort:** S (hours)

### Background
The Executable target's main.swift that wires everything together. Root command with subcommands: auth, mail, cal, contact, drive, search, mcp.

### Scope
Create/update `Sources/Executable/main.swift`:

```swift
@main
struct OutlookCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outlook",
        abstract: "Microsoft 365 CLI — mail, calendar, contacts, drive",
        subcommands: [
            AuthCommand.self,
            MailCommand.self,
            CalendarCommand.self,
            ContactCommand.self,
            DriveCommand.self,
            SearchCommand.self,
            MCPCommand.self,
        ]
    )
}
```

Global options (inherited by all subcommands):
- `--account EMAIL` — override default account
- `--format table|json|compact` — output format
- `--verbose` — enable debug logging

### Success Criteria
- `outlook --help` shows all subcommands
- `outlook mail --help` shows mail subcommands
- Global options propagate to subcommands

### Test Plan
- Test: root command help output
- Test: global options parsed before subcommands

### Considerations
- Use `@OptionGroup` for shared global options
- `--verbose` should set swift-log level to debug
- Version flag: `--version` showing build version


---

# Wave 6 — MCP Server (Depends on Wave 4)

## BD-025: MCPServer Setup & Tool Registration
- **Type:** feature
- **Priority:** P0 (blocking)
- **Depends on:** BD-009, BD-012, BD-013, BD-014, BD-015, BD-016
- **Blocks:** BD-026, BD-027, BD-028, BD-029, BD-030, BD-031, BD-032, BD-033, BD-034, BD-035
- **Estimated effort:** L (full day)

### Background
MCP (Model Context Protocol) server enables AI agents to interact with Outlook. Uses the official swift-sdk. Starts via `outlook mcp serve`. The server registers all tools, resources, and prompts.

### Scope
Create `Sources/OutlookMCP/MCPServer.swift`:

```swift
actor OutlookMCPServer {
    let config: OutlookConfig
    let mailService: MailService
    let calendarService: CalendarService
    let contactService: ContactService
    let driveService: DriveService
    let searchService: SearchService
    
    // Configuration
    let readOnly: Bool
    let enabledTools: Set<String>  // "mail", "calendar", "contacts", "drive", "search"
    
    func start() async throws {
        // Register tools, resources, prompts
        // Start stdio transport
    }
}
```

Create `Sources/OutlookMCP/MCPConfig.swift`:
```swift
struct MCPConfig: Sendable {
    let readOnly: Bool          // Disable write operations
    let enabledToolSets: Set<String>  // Filter tool categories
}
```

Create `Sources/OutlookCLI/Commands/MCPCommand.swift`:
```swift
struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "mcp")
    
    struct Serve: AsyncParsableCommand {
        @Flag var readOnly: Bool = false
        @Option var tools: String?  // comma-separated: "mail,calendar"
    }
    
    struct Tools: AsyncParsableCommand {
        // List all available tools
    }
}
```

### Success Criteria
- `outlook mcp serve` starts MCP server on stdio
- `outlook mcp tools` lists all available tools
- `--read-only` disables write tools
- `--tools mail,calendar` filters to specified categories

### Test Plan
- Test: server starts without error
- Test: tool list matches expected count
- Test: read-only mode rejects write tools
- Test: tool filtering works by category

### Considerations
- MCP swift-sdk uses stdio transport by default
- Each tool needs: name, description, input schema (JSON Schema), handler
- Tool names use `outlook_` prefix for namespace
- Read-only check should happen at tool handler level, not registration (so tools are visible but return errors)


## BD-026: MailTools (MCP)
- **Type:** feature
- **Priority:** P0 (blocking)
- **Depends on:** BD-012, BD-025
- **Blocks:** none
- **Estimated effort:** L (full day)

### Background
11 MCP tools for mail operations. Each tool is an atomic primitive that agents compose.

### Scope
Create `Sources/OutlookMCP/Tools/MailTools.swift`:

Tools:
1. `outlook_mail_list` — params: folder?, unread_only?, count?, include_body? → List messages
2. `outlook_mail_read` — params: message_id → Full message with body
3. `outlook_mail_send` — params: to, subject, body, cc?, bcc? → Send email (**requires approval**)
4. `outlook_mail_reply` — params: message_id, body, reply_all? → Reply
5. `outlook_mail_forward` — params: message_id, to, comment? → Forward
6. `outlook_mail_move` — params: message_id, folder → Move to folder
7. `outlook_mail_delete` — params: message_id → Delete message
8. `outlook_mail_mark` — params: message_id, is_read?, flag? → Mark read/unread/flagged
9. `outlook_mail_search` — params: query, count? → Search messages
10. `outlook_mail_folders` — no params → List mail folders
11. `outlook_mail_attachments` — params: message_id, download_path? → List/download attachments

Each tool handler:
1. Parse input parameters from JSON
2. Check read-only mode (for write operations)
3. Call appropriate MailService method
4. Return structured JSON result with `hasMore`, `nextLink` for pagination

Tool result format:
```json
{
    "success": true,
    "data": { ... },
    "hasMore": false,
    "nextLink": null
}
```

### Success Criteria
- All 11 tools registered and functional
- Write tools blocked in read-only mode
- Results include pagination hints
- Tool descriptions are clear for AI agents

### Test Plan
- Unit test: each tool handler with mock MailService
- Test: read-only mode blocks send/reply/forward/move/delete/mark
- Test: pagination info included in list results

### Considerations
- Tool descriptions should be detailed enough for an AI agent to understand when/how to use them
- `outlook_mail_send` is high-stakes — tool description should note this requires explicit approval
- Include `bodyPreview` in list results to help agents decide which messages to read fully
- Attachment download needs a writable path — MCP may not have filesystem access in all contexts


## BD-027: CalendarTools (MCP)
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-013, BD-025
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
9 MCP tools for calendar operations.

### Scope
Create `Sources/OutlookMCP/Tools/CalendarTools.swift`:

Tools:
1. `outlook_cal_list` — params: from?, to?, calendar_id?, count?
2. `outlook_cal_get` — params: event_id
3. `outlook_cal_create` — params: subject, start, end, location?, attendees?, body?
4. `outlook_cal_update` — params: event_id, subject?, start?, end?, location?
5. `outlook_cal_delete` — params: event_id, notify?
6. `outlook_cal_respond` — params: event_id, response (accept/decline/tentative), message?
7. `outlook_cal_free_busy` — params: attendees, from, to, duration?
8. `outlook_cal_calendars` — no params
9. `outlook_cal_search` — params: query

### Success Criteria
- All 9 tools registered and functional
- Date parameters accept ISO 8601
- Free/busy returns structured availability

### Test Plan
- Unit test: each tool handler with mock CalendarService
- Test: read-only blocks create/update/delete
- Test: date parameter parsing

### Considerations
- Default date range for list: today to +7 days (same as CLI)
- `outlook_cal_delete` with `notify: true` is high-stakes — description should note this
- `outlook_cal_respond` maps to three separate endpoints in Graph


## BD-028: ContactTools (MCP)
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-014, BD-025
- **Blocks:** none
- **Estimated effort:** S (hours)

### Background
6 MCP tools for contact operations.

### Scope
Create `Sources/OutlookMCP/Tools/ContactTools.swift`:

Tools:
1. `outlook_contact_list` — params: count?, skip?
2. `outlook_contact_get` — params: contact_id
3. `outlook_contact_create` — params: name, email?, phone?, company?
4. `outlook_contact_update` — params: contact_id, name?, email?, phone?
5. `outlook_contact_delete` — params: contact_id
6. `outlook_contact_search` — params: query

### Success Criteria
- All 6 tools registered and functional
- Search uses People API for relevance

### Test Plan
- Unit test: each tool handler
- Test: read-only blocks create/update/delete

### Considerations
- Contact search should explain in description that it uses People API for intelligent matching


## BD-029: DriveTools (MCP)
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-015, BD-025
- **Blocks:** none
- **Estimated effort:** S (hours)

### Background
6 MCP tools for OneDrive operations.

### Scope
Create `Sources/OutlookMCP/Tools/DriveTools.swift`:

Tools:
1. `outlook_drive_list` — params: path?, folder_id?
2. `outlook_drive_get` — params: item_id
3. `outlook_drive_download` — params: item_id, output_path?
4. `outlook_drive_upload` — params: file_path, destination_path
5. `outlook_drive_delete` — params: item_id
6. `outlook_drive_search` — params: query

### Success Criteria
- All 6 tools registered and functional
- Upload handles large files

### Test Plan
- Unit test: each tool handler
- Test: read-only blocks upload/delete

### Considerations
- File download in MCP context: return file content as base64? Or save to path?
- Upload: agent needs to provide a file path that exists on the server machine


## BD-030: SearchTools (MCP)
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-016, BD-025
- **Blocks:** none
- **Estimated effort:** S (hours)

### Background
Unified search MCP tool + auth status tools.

### Scope
Create `Sources/OutlookMCP/Tools/SearchTools.swift`:

Tools:
1. `outlook_search` — params: query, entity_types?, count? → Unified search
2. `outlook_auth_status` — no params → Show auth status
3. `outlook_accounts` — no params → List accounts

### Success Criteria
- Unified search works across entity types
- Auth tools provide account info to agents

### Test Plan
- Unit test: each tool handler
- Test: entity type filtering

### Considerations
- Auth tools are always available (not affected by read-only or tool filtering)


## BD-031: Raw Graph API Tool
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-009, BD-025
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
Escape hatch tool that lets agents call ANY Graph API endpoint directly. Enables emergent capability — Teams, SharePoint, Planner, To Do, OneNote, Excel — without building specific tools.

### Scope
Add to `Sources/OutlookMCP/Tools/` (or in MCPServer.swift):

Tool: `outlook_graph_raw`
Parameters:
- `method`: GET|POST|PUT|PATCH|DELETE
- `path`: e.g., "/me/messages" (any Graph v1.0 path)
- `query_params`: optional dict of query parameters
- `body`: optional JSON body (for POST/PUT/PATCH)
- `api_version`: "v1.0" (default) | "beta"
- `fetch_all`: bool — auto-paginate following @odata.nextLink

Handler:
1. Validate method is allowed (respect read-only for non-GET)
2. Construct URL: `https://graph.microsoft.com/{api_version}{path}`
3. Add query params
4. Execute via GraphClient
5. Return raw JSON response

### Success Criteria
- Any Graph API endpoint accessible via this tool
- `api_version: "beta"` works for beta endpoints
- `fetch_all` auto-paginates
- Read-only mode blocks non-GET requests

### Test Plan
- Unit test: URL construction with path and query params
- Unit test: api_version switches base URL
- Unit test: read-only blocks POST/PUT/PATCH/DELETE
- Unit test: fetch_all pagination

### Considerations
- This is powerful — the tool description should explain it's for advanced use when specific tools don't cover the need
- Response is raw JSON (not decoded into our models) — just pass through
- Consider response size limits to avoid returning megabytes of data


## BD-032: MCP Resources
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-025, BD-012, BD-013
- **Blocks:** BD-036
- **Estimated effort:** M (half-day)

### Background
MCP Resources provide context injection — agents get awareness of the account, folder structure, calendars, and recent activity without making tool calls. This is key to the agent-native pattern.

### Scope
Register MCP resources in MCPServer:

1. **`outlook://context`** — Full context.md resource:
   - Account info (email, tenant, scopes)
   - Mail folder structure with unread counts
   - Calendar list
   - Recent activity summary (new messages count, today's events)
   - Patterns (from context.md if it exists)

2. **`outlook://folders`** — Mail folder tree:
   - All folders with displayName, unreadItemCount, totalItemCount
   - Hierarchical structure (parent/child)

3. **`outlook://calendars`** — Calendar list:
   - All calendars with name, color, canEdit, isDefault

4. **`outlook://account`** — Current account:
   - Email, display name, tenant
   - Token expiry
   - Granted scopes
   - Read-only mode status

### Success Criteria
- All 4 resources return correct data
- Resources update on each read (not cached forever)
- `outlook://context` aggregates multiple data sources

### Test Plan
- Unit test: each resource returns expected structure
- Test: context resource includes folder counts and today's events
- Test: account resource shows correct scopes

### Considerations
- Resources should be relatively fast — don't make 10 API calls per resource read
- Cache folder list for ~60 seconds (folders don't change often)
- `outlook://context` is the most important — agents read this first to understand the landscape
- Consider making context generation reusable (shared with BD-036 context.md)


## BD-033: MCP Prompts
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-025
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
Pre-built prompt templates for common agent workflows. These are NOT hardcoded features — just suggested compositions of atomic tools that agents can use or ignore.

### Scope
Register MCP prompts in MCPServer:

1. **`outlook://prompts/inbox-triage`**
   "Review my unread messages. For each message: summarize it in one line, suggest an action (reply, archive, flag, or ignore), and draft a reply if one is needed. Start with the most recent."

2. **`outlook://prompts/meeting-prep`**
   "Check my calendar for the next upcoming meeting. Find any related emails (search by meeting subject and attendee names). Summarize the context I need and list any action items from previous interactions."

3. **`outlook://prompts/weekly-review`**
   "Summarize my email activity this week: count sent and received messages, list any flagged or unread messages still pending, and show my calendar for the coming week."

4. **`outlook://prompts/contact-lookup`**
   Arguments: `person` (name or email)
   "Find all information about {person}: their contact details, recent emails exchanged, upcoming meetings together, and any shared files."

### Success Criteria
- All 4 prompts registered and accessible
- `contact-lookup` accepts a `person` argument
- Prompts are well-written for AI agent consumption

### Test Plan
- Test: all prompts are registered
- Test: contact-lookup prompt substitutes person argument
- Test: prompt list endpoint returns all prompts

### Considerations
- Prompts should reference specific tool names so agents know what to call
- Prompts are suggestions — agents can ignore them and compose their own workflows
- Keep prompts focused on outcome, not step-by-step instructions (agents are smart enough)


## BD-034: Read-Only Mode Implementation
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-025, BD-026, BD-027, BD-028, BD-029
- **Blocks:** none
- **Estimated effort:** S (hours)

### Background
Safety mechanism: when enabled, all write operations return an error. Useful for letting agents read email without risk of sending. Activated via `--read-only` flag or `OUTLOOK_READ_ONLY=true` env var.

### Scope
Implement read-only checks in all MCP tool handlers:

- Classify each tool as read or write
- Write tools: send, reply, forward, move, delete, mark, create, update (for all categories)
- Read tools: list, get, search, folders, calendars, attachments, auth_status, accounts
- On write attempt in read-only mode: return `GraphError.readOnlyMode(toolName:)` with clear message

Also implement in CLI commands (check `config.readOnly` before write operations).

### Success Criteria
- All write operations blocked when read-only enabled
- Error messages clearly state read-only mode is the cause
- Read operations unaffected
- Works for both CLI and MCP

### Test Plan
- Unit test: each write tool returns error in read-only mode
- Unit test: read tools work normally in read-only mode
- Test: env var enables read-only mode
- Test: CLI flag enables read-only mode

### Considerations
- Tool should still be VISIBLE in read-only mode (registered, listed) — just return error on execution
- This enables safe agent exploration — agent can see what tools exist but can't cause damage
- `outlook_graph_raw` with non-GET methods should also be blocked


## BD-035: Tool Filtering
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-025
- **Blocks:** none
- **Estimated effort:** S (hours)

### Background
Allow filtering which tool categories are exposed in MCP. `--tools mail,calendar` only registers mail and calendar tools. Reduces noise for agents that only need specific capabilities.

### Scope
Implement in MCPServer:

- Parse `--tools` comma-separated string into set of categories
- Categories: "mail", "calendar", "contacts", "drive", "search"
- Only register tools from enabled categories
- Auth tools and raw graph tool always available
- Resources and prompts always available

### Success Criteria
- `--tools mail` only exposes mail tools + auth + raw
- `--tools mail,calendar` exposes both + auth + raw
- No flag = all tools enabled

### Test Plan
- Unit test: filtering with single category
- Unit test: filtering with multiple categories
- Unit test: auth tools always present
- Unit test: no flag = all tools

### Considerations
- This is a registration-time filter — tools not in the set are never registered
- Different from read-only (which registers but blocks execution)
- Resources should still include all data regardless of tool filter (agent might need context)


---

# Wave 7 — Agent-Native Features (Depends on Wave 6)

## BD-036: context.md Generation & Persistence
- **Type:** feature
- **Priority:** P1 (critical)
- **Depends on:** BD-032
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
The context.md pattern: MCP server maintains a persistent file that accumulates knowledge about the user's Outlook — folder structure, frequent contacts, meeting patterns. Agents read this for awareness. It gets richer over time.

### Scope
Create context generation logic (can be in OutlookCore or OutlookMCP):

```swift
struct ContextGenerator {
    func generateContext(
        account: AccountInfo,
        folders: [MailFolder],
        calendars: [Calendar],
        recentMessages: [Message],
        todayEvents: [Event]
    ) -> String  // Returns markdown
}
```

Context.md format:
```markdown
# Outlook Context

## Account
- Email: {email}
- Tenant: {tenant}
- Scopes: {scopes}

## Folder Structure
{for each folder: "- {name} ({unreadCount} unread)"}

## Calendar
{for each calendar: "- {name} ({color})"}

## Today's Events
{for each event: "- {time} {subject} @{location} ({attendee count} attendees)"}

## Recent Activity
- {unread count} unread messages
- {today event count} events today
- Next event: "{subject}" in {minutes} min

## Patterns Learned
{loaded from persistent context file if exists}
```

Persistence:
- Store at `~/.config/outlookcli/context.md`
- Update on MCP server start and periodically (every 5 min?)
- Resource `outlook://context` reads from this

### Success Criteria
- context.md generates with accurate account and folder info
- Persists to disk and reloads
- MCP resource `outlook://context` serves this content

### Test Plan
- Unit test: context generation with mock data
- Test: file persistence and reload
- Test: MCP resource returns context content

### Considerations
- Don't make too many API calls for context generation — batch where possible
- "Patterns Learned" section starts empty — agents can append to it over time
- Consider a separate "patterns.md" that persists between context regenerations
- Debounce context updates — don't regenerate on every tool call


## BD-037: Approval Flow Integration
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-025, BD-026
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
High-stakes actions (send email, delete event with notification) should require explicit approval from the user. The approval flow uses a stakes × reversibility matrix. This is communicated via tool descriptions and result metadata — the actual approval UX depends on the MCP client (Claude Desktop, etc.).

### Scope
Add approval metadata to tool results and descriptions:

Stakes classification in tool descriptions:
```
"This action requires explicit user approval (high stakes, hard to reverse)."
"This action is auto-approved (low stakes, easily reversible)."
```

Tool result metadata:
```json
{
    "success": true,
    "data": { ... },
    "approval": {
        "required": true,
        "level": "explicit",  // "auto" | "quick_confirm" | "explicit"
        "reason": "Sending email is high-stakes and hard to reverse"
    }
}
```

Approval matrix (from plan):
| Action | Stakes | Reversibility | Level |
|--------|--------|---------------|-------|
| List/read/search | Low | N/A | auto |
| Move message, mark read | Low | Easy | auto |
| Create draft | Low | Easy | auto |
| Send email | High | Hard | explicit |
| Delete message | Medium | Hard | quick_confirm |
| Create/update event | Medium | Easy | auto |
| Delete event with notify | High | Hard | explicit |
| Upload file | Low | Easy | auto |
| Delete file | Medium | Hard | quick_confirm |

### Success Criteria
- Tool descriptions include approval level guidance
- Tool results include approval metadata
- Approval matrix matches the defined stakespattern

### Test Plan
- Unit test: each write tool includes correct approval metadata
- Test: send email tool has "explicit" approval level
- Test: list operations have "auto" approval level

### Considerations
- We can't enforce approval in the MCP server — the MCP client (Claude Desktop, Cursor, etc.) decides how to present approvals
- Our job: provide clear metadata so clients CAN implement approval flows
- Tool descriptions should mention approval requirements so agents plan accordingly
- This is about communication, not enforcement (enforcement is read-only mode)


## BD-038: Completion Signals in Tool Results
- **Type:** feature
- **Priority:** P2 (important)
- **Depends on:** BD-025, BD-026
- **Blocks:** none
- **Estimated effort:** S (hours)

### Background
Every tool should return structured results with explicit continuation hints — hasMore, nextLink, suggested next actions. This helps agents know what to do next without guessing.

### Scope
Standardize tool result format across all MCP tools:

```swift
struct MCPToolResult: Encodable {
    let success: Bool
    let data: AnyCodable        // The actual result
    let hasMore: Bool           // More pages available
    let nextLink: String?       // For pagination continuation
    let totalCount: Int?        // Total items (if known)
    let suggestedActions: [String]?  // e.g., ["Use outlook_mail_read to see full message"]
}
```

Suggested actions examples:
- After `mail_list`: "Use outlook_mail_read with message_id to see full message body"
- After `mail_send`: "Email sent successfully. No further action needed."
- After `cal_list` with future events: "Use outlook_cal_get for event details"
- After `search` with results: "Use the appropriate get tool for full details"

### Success Criteria
- All tools return standardized result format
- Pagination tools include hasMore and nextLink
- Suggested actions help agents compose workflows

### Test Plan
- Unit test: all tools return valid MCPToolResult
- Test: list operations include hasMore/nextLink when applicable
- Test: suggested actions are relevant to the operation

### Considerations
- `AnyCodable` or just use `[String: Any]` encoded as JSON — depends on swift-sdk requirements
- Don't over-specify suggested actions — agents are smart enough to compose
- Keep it simple: success, data, hasMore, nextLink are the essentials; suggestedActions is bonus


---

# Wave 8 — Tests (Depends on All Above)

## BD-039: Core Unit Tests — Models
- **Type:** test
- **Priority:** P1 (critical)
- **Depends on:** BD-002
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
Comprehensive unit tests for all Codable models using real Graph API JSON fixtures.

### Scope
Create `Tests/OutlookCoreTests/ModelTests.swift`:

- Test Message decode from Graph API JSON fixture
- Test Event decode (including DateTimeTimeZone, Attendee, Recurrence)
- Test Contact decode
- Test DriveItem decode (file and folder variants)
- Test SearchResult decode (polymorphic resource)
- Test GraphPagedResponse decode (with and without nextLink)
- Test EmailAddress nested structure in recipients
- Test edge cases: nil optionals, empty arrays, HTML body
- Test encode → decode round-trip for each model

Include JSON fixtures in test bundle (or inline strings).

### Success Criteria
- 100% of model types have decode tests
- Edge cases covered
- All tests pass

### Test Plan
This IS the test plan. Fixtures should use real Graph API response structures.

### Considerations
- Get sample JSON from Graph API docs or Graph Explorer
- Test with minimal JSON (only required fields) and full JSON (all fields)
- Date parsing must handle Graph's ISO 8601 format correctly


## BD-040: Core Unit Tests — Auth
- **Type:** test
- **Priority:** P1 (critical)
- **Depends on:** BD-006, BD-007, BD-008
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
Unit tests for authentication: device code flow, token management, account management. Uses mocked URLSession and keychain.

### Scope
Create `Tests/OutlookCoreTests/AuthTests.swift`:

- Test DeviceCodeFlow: request parsing, poll responses (pending, declined, expired, slow_down, success)
- Test DeviceCodeFlow: refresh token request/response
- Test TokenManager: getAccessToken with valid cached token
- Test TokenManager: getAccessToken triggers refresh on expired token
- Test TokenManager: getAccessToken throws when no tokens
- Test AccountManager: single account auto-resolve
- Test AccountManager: multiple accounts require explicit selection
- Test AccountManager: default account persistence

Mock strategy: protocol-based URLSession mock or URLProtocol subclass.

### Success Criteria
- All auth paths tested
- Error cases covered
- No real network calls in tests

### Test Plan
This IS the test plan.

### Considerations
- KeychainStorage tests need mock or test-specific service name
- TokenManager tests need mock DeviceCodeFlow and KeychainStorage
- Consider a test helper that sets up the full auth stack with mocks


## BD-041: Core Unit Tests — GraphClient
- **Type:** test
- **Priority:** P1 (critical)
- **Depends on:** BD-009, BD-010, BD-011
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
Unit tests for GraphClient: request construction, retry logic, rate limiting, pagination, error handling.

### Scope
Create `Tests/OutlookCoreTests/GraphClientTests.swift`:

- Test: successful GET request decodes response
- Test: POST request with body encodes correctly
- Test: 429 response triggers retry with Retry-After delay
- Test: 401 triggers token refresh + retry
- Test: 5xx triggers exponential backoff
- Test: max retries exceeded throws error
- Test: 404 throws notFound (no retry)
- Test: malformed JSON throws decodingError
- Test: GraphQuery builder produces correct parameters
- Test: pagination follows nextLink
- Test: requestAll stops at maxPages
- Test: Authorization header includes bearer token

Use URLProtocol mock to intercept requests and return canned responses.

### Success Criteria
- All retry scenarios tested
- Pagination tested
- Request construction verified
- Error mapping verified

### Test Plan
This IS the test plan.

### Considerations
- URLProtocol mock: register custom protocol that returns predefined responses based on URL/method
- Test timing: retry delays should be minimized in tests (inject short delays)
- Verify correct headers are sent (Authorization, Content-Type, Prefer)


## BD-042: Core Unit Tests — Services
- **Type:** test
- **Priority:** P1 (critical)
- **Depends on:** BD-012, BD-013, BD-014, BD-015, BD-016
- **Blocks:** none
- **Estimated effort:** L (full day)

### Background
Unit tests for all service layers. Each service is tested with a mock GraphClient.

### Scope
Create test files:
- `Tests/OutlookCoreTests/MailServiceTests.swift`
- `Tests/OutlookCoreTests/CalendarServiceTests.swift`
- `Tests/OutlookCoreTests/ContactServiceTests.swift`
- `Tests/OutlookCoreTests/DriveServiceTests.swift`
- `Tests/OutlookCoreTests/SearchServiceTests.swift`

Per service, test:
- Correct Graph API paths called
- Query parameters constructed correctly
- Request bodies match expected format
- Responses parsed correctly
- Error propagation works

### Success Criteria
- All service methods have at least one happy-path test
- Error paths tested for critical operations
- No real network calls

### Test Plan
This IS the test plan.

### Considerations
- Mock GraphClient at protocol level — create `GraphClientProtocol` if not already
- Services should be testable with dependency injection
- Focus on path construction and parameter formatting — the heavy lifting is in GraphClient


## BD-043: CLI Command Parsing Tests
- **Type:** test
- **Priority:** P2 (important)
- **Depends on:** BD-018, BD-019, BD-020, BD-021, BD-022, BD-023
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
Test that all CLI commands parse arguments correctly using swift-argument-parser's built-in testing utilities.

### Scope
Create `Tests/OutlookCLITests/CommandParsingTests.swift`:

- Test each command parses its required and optional arguments
- Test: `mail list --unread --count 10 --format json`
- Test: `mail send user@example.com --subject "Test" --body "Hello"`
- Test: `cal create --subject "Meeting" --start 2024-01-15T10:00 --end 2024-01-15T11:00`
- Test: missing required args produce errors
- Test: global options (--account, --format, --verbose) propagate
- Test: `mcp serve --read-only --tools mail,calendar`

### Success Criteria
- All commands parse without error with valid args
- Missing required args caught
- Option types correct (String, Int, Bool, etc.)

### Test Plan
This IS the test plan. Use `ArgumentParser`'s `parse()` method in tests.

### Considerations
- swift-argument-parser provides `ParsableCommand.parse(_:)` for testing
- Don't test execution (that's integration) — just parsing


## BD-044: MCP Tool Tests
- **Type:** test
- **Priority:** P2 (important)
- **Depends on:** BD-026, BD-027, BD-028, BD-029, BD-030, BD-031
- **Blocks:** none
- **Estimated effort:** L (full day)

### Background
Test MCP tool handlers: input parsing, service delegation, result formatting, read-only mode, tool filtering.

### Scope
Create `Tests/OutlookCoreTests/MCPToolTests.swift` (or in a new OutlookMCPTests target):

- Test each tool handler parses JSON input correctly
- Test each tool calls the correct service method
- Test result format: success, data, hasMore, nextLink
- Test read-only mode: write tools return appropriate error
- Test tool filtering: filtered tools not registered
- Test raw graph tool: URL construction, read-only check

### Success Criteria
- All 35+ tools have at least one test
- Read-only and filtering tested
- Result format consistent

### Test Plan
This IS the test plan.

### Considerations
- May need a separate test target for OutlookMCP tests
- Mock all services — test only the MCP tool handler logic
- Tool input is JSON — test with realistic JSON strings


## BD-045: E2E Integration Test Suite
- **Type:** test
- **Priority:** P3 (nice-to-have)
- **Depends on:** all previous beads
- **Blocks:** none
- **Estimated effort:** XL (multi-day)

### Background
End-to-end tests against real Microsoft Graph API. Requires valid Azure AD credentials. Not for CI (requires secrets) but essential for manual verification.

### Scope
Create `Tests/OutlookE2ETests/` (separate test plan or conditionally compiled):

Test flows:
1. **Auth flow**: login → status → accounts → logout
2. **Mail roundtrip**: send email to self → list → read → reply → move → delete
3. **Calendar roundtrip**: create event → list → update → respond → delete
4. **Contact roundtrip**: create → list → search → update → delete
5. **Drive roundtrip**: upload file → list → download → verify content → delete
6. **Search**: unified search for known content
7. **MCP**: start server → call tools via MCP protocol

Each test should:
- Log every step with timestamps
- Clean up after itself (delete created resources)
- Skip if no auth tokens available

### Success Criteria
- All roundtrip flows pass against real Graph API
- Tests are idempotent and self-cleaning
- Clear logging for debugging failures

### Test Plan
This IS the test plan. Run manually: `swift test --filter OutlookE2ETests`

### Considerations
- Need a test Microsoft account (or use personal account carefully)
- Rate limits may affect test speed — add delays between API calls
- E2E tests are slow — separate from unit tests
- Consider using `XCTSkipIf` when auth tokens unavailable
- Clean up is critical — don't leave test emails/events/contacts/files behind


---

# Wave 9 — Polish

## BD-046: README with Azure Setup Guide
- **Type:** polish
- **Priority:** P1 (critical)
- **Depends on:** BD-024, BD-025
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
The README is the front door. Must include: what it is, quick start, Azure AD app registration (step-by-step with screenshots description), CLI usage examples, MCP setup for Claude Desktop, and configuration reference.

### Scope
Create/update `README.md`:

1. **Header** — name, one-line description, badges
2. **Features** — mail, calendar, contacts, drive, search, MCP
3. **Quick Start**
   - Install (brew or swift build)
   - Azure app registration (step-by-step):
     1. Go to portal.azure.com → Azure AD → App registrations
     2. New registration: name "OutlookCLI", account types "personal + work/school"
     3. No redirect URI needed
     4. Enable "Allow public client flows"
     5. Add API permissions: Mail.ReadWrite, Calendars.ReadWrite, Contacts.ReadWrite, Files.ReadWrite, People.Read, User.Read
     6. Copy Application (client) ID
   - `export OUTLOOK_CLIENT_ID=your-id`
   - `outlook auth login`
4. **CLI Usage** — examples for each command group
5. **MCP Setup** — Claude Desktop config JSON, `outlook mcp serve` options
6. **Configuration** — env vars reference table
7. **Agent-Native Design** — brief explanation of atomic tools philosophy
8. **Development** — build, test, contribute

### Success Criteria
- New user can go from zero to authenticated in < 10 minutes following README
- All commands documented with examples
- MCP setup is copy-paste ready

### Test Plan
- Review: follow README on a fresh machine
- Verify all example commands are valid

### Considerations
- Azure portal UI changes — be generic enough to survive minor UI updates
- Include troubleshooting section for common auth errors
- MCP config should show both Claude Desktop and generic MCP client setup


## BD-047: AGENTS.md
- **Type:** polish
- **Priority:** P2 (important)
- **Depends on:** BD-025
- **Blocks:** none
- **Estimated effort:** S (hours)

### Background
AGENTS.md provides guidance for AI agents working with this codebase. Points to agent-relevant information.

### Scope
Create `AGENTS.md`:

- Project structure overview (Peekaboo architecture)
- Key files and their purposes
- How to run: `swift build`, `swift test`, `outlook` CLI
- MCP server: `outlook mcp serve`
- Agent-native design principles (brief)
- Pointer to tool descriptions (via `outlook mcp tools`)
- Testing guidance
- Common development tasks

### Success Criteria
- An AI coding agent can understand the project structure from AGENTS.md
- Key commands documented

### Test Plan
- Review: does an agent have enough context to make changes?

### Considerations
- Keep concise — agents have context limits
- Focus on what's actionable, not philosophy


## BD-048: Error Messages & Help Text
- **Type:** polish
- **Priority:** P2 (important)
- **Depends on:** BD-018, BD-019, BD-020, BD-021, BD-022, BD-023
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
Polish all user-facing error messages and help text. Errors should be actionable ("Token expired. Run 'outlook auth login' to re-authenticate."). Help text should include examples.

### Scope
Review and improve:
- All `GraphError` descriptions — include suggested fix action
- All CLI command help text — add examples via ArgumentParser's `discussion` and `abstract`
- Auth error messages — clear guidance on what went wrong and how to fix
- Missing config errors — "OUTLOOK_CLIENT_ID not set. Register an app at https://portal.azure.com and set the environment variable."
- Permission errors — "Missing Mail.ReadWrite permission. Add it in Azure portal → API permissions."

### Success Criteria
- Every error message tells the user what to do next
- `--help` for each command includes at least one example
- No cryptic error codes without explanation

### Test Plan
- Manual review of all error paths
- Test: trigger each error type and verify message quality

### Considerations
- Include the relevant Azure portal URL in permission errors
- Common mistake: wrong tenant ID — detect and suggest "common"
- Include error codes for debugging when appropriate


## BD-049: Performance Optimization
- **Type:** polish
- **Priority:** P3 (nice-to-have)
- **Depends on:** BD-012, BD-013, BD-014, BD-015
- **Blocks:** none
- **Estimated effort:** M (half-day)

### Background
Optimize for speed: parallel requests where safe, response caching, efficient `$select` to minimize payload.

### Scope
Optimizations:
1. **Selective `$select`** — Every list operation should only request needed fields (not full body by default)
2. **Parallel requests** — Context generation can fetch folders + calendars + recent messages in parallel
3. **Folder caching** — Cache folder list for 60 seconds (folders rarely change)
4. **Connection reuse** — Ensure URLSession reuses connections (it does by default)
5. **Batch requests** — Graph supports `$batch` for multiple operations — consider for context generation (POST to `/$batch`)

### Success Criteria
- `outlook mail list` returns results in < 2 seconds
- Context generation makes parallel API calls
- Bandwidth reduced by using `$select`

### Test Plan
- Measure: time `outlook mail list` before and after optimization
- Verify: `$select` is included in all list requests
- Test: parallel context generation

### Considerations
- Don't over-optimize — keep code simple
- `$batch` adds complexity — only use if context generation is noticeably slow
- URLSession already handles connection pooling
- Profile before optimizing — measure first


## BD-050: Formatter Polish & Colorized Output
- **Type:** polish
- **Priority:** P3 (nice-to-have)
- **Depends on:** BD-017
- **Blocks:** none
- **Estimated effort:** S (hours)

### Background
Add ANSI color output for terminal: unread messages in bold, event times in color, file sizes formatted. Detect if stdout is a TTY (no colors when piped).

### Scope
Enhance formatters:
- Bold for unread messages
- Color-code importance (red for high, normal for normal)
- Green for accepted events, red for declined, yellow for tentative
- Human-friendly dates ("2h ago", "Yesterday 3:45 PM", "Jan 15")
- File sizes: "1.2 MB", "340 KB"
- Detect TTY: `isatty(STDOUT_FILENO)` — disable colors when piping
- `--no-color` flag to force disable

### Success Criteria
- Terminal output is visually clear and scannable
- Colors disabled when piped or --no-color
- Dates are human-friendly

### Test Plan
- Visual review of each command output
- Test: --no-color produces no ANSI codes
- Test: piped output has no ANSI codes

### Considerations
- Keep it minimal — don't over-colorize
- Some terminals don't support colors — always provide --no-color fallback
- Consider using a tiny ANSI helper (no external dep) rather than a full library


---

# Summary

| Wave | Beads | Description |
|------|-------|-------------|
| 1 — Foundation | BD-001 to BD-005 | Package scaffold, models, errors, keychain, config |
| 2 — Auth | BD-006 to BD-008 | Device code flow, token manager, multi-account |
| 3 — Graph Client | BD-009 to BD-011 | HTTP client, query builder, pagination |
| 4 — Services | BD-012 to BD-016 | Mail, calendar, contacts, drive, search |
| 5 — CLI | BD-017 to BD-024 | Formatters, commands, entry point |
| 6 — MCP Server | BD-025 to BD-035 | Server, tools, resources, prompts, read-only, filtering |
| 7 — Agent-Native | BD-036 to BD-038 | Context.md, approval flow, completion signals |
| 8 — Tests | BD-039 to BD-045 | Unit tests, CLI tests, MCP tests, E2E |
| 9 — Polish | BD-046 to BD-050 | README, AGENTS.md, errors, performance, colors |

**Total: 50 beads across 9 waves.**

*Generated: 2026-02-10*
