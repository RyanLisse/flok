import Foundation
import Core

// MARK: - Contact Tool Handlers

public struct ListContactsHandler: Sendable {
    let client: GraphClient

    public func handle(top: Int = 50, search: String? = nil) async throws -> ToolResult {
        var query: [String: String] = [
            "$top": String(top),
            "$select": "id,displayName,emailAddresses,businessPhones,mobilePhone,companyName,jobTitle",
        ]
        if let search { query["$search"] = "\"\(search)\"" }

        let data = try await client.get("/me/contacts", query: query)
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["get-contact", "create-contact"])
    }
}

public struct GetContactHandler: Sendable {
    let client: GraphClient

    public func handle(contactId: String) async throws -> ToolResult {
        let data = try await client.get("/me/contacts/\(contactId)")
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["update-contact", "send-mail"])
    }
}

public struct CreateContactHandler: Sendable {
    let client: GraphClient
    let readOnly: Bool

    public func handle(
        givenName: String,
        surname: String?,
        email: String?,
        phone: String?,
        company: String?,
        jobTitle: String?
    ) async throws -> ToolResult {
        guard !readOnly else { return .fail("Read-only mode — create-contact is disabled") }

        var contact: [String: Any] = ["givenName": givenName]
        if let surname { contact["surname"] = surname }
        if let email { contact["emailAddresses"] = [["address": email]] }
        if let phone { contact["businessPhones"] = [phone] }
        if let company { contact["companyName"] = company }
        if let jobTitle { contact["jobTitle"] = jobTitle }

        let jsonData = try JSONSerialization.data(withJSONObject: contact)
        let data = try await client.post("/me/contacts", body: jsonData)
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["list-contacts"])
    }
}
