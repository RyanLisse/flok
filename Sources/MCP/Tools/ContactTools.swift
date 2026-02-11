import Foundation
import Core

// MARK: - Contact Tool Handlers

public struct ListContactsHandler: Sendable {
    let contactService: ContactService

    public func handle(top: Int = 50, search: String? = nil) async throws -> ToolResult {
        let contacts = try await contactService.listContacts(search: search, top: top)
        let data = try JSONEncoder.graph.encode(contacts)
        return .ok(String(data: data, encoding: .utf8) ?? "[]", nextActions: ["get-contact", "create-contact"], approvalLevel: "auto")
    }
}

public struct GetContactHandler: Sendable {
    let contactService: ContactService

    public func handle(contactId: String) async throws -> ToolResult {
        let contact = try await contactService.getContact(id: contactId)
        let data = try JSONEncoder.graph.encode(contact)
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["update-contact", "send-mail"], approvalLevel: "auto")
    }
}

public struct CreateContactHandler: Sendable {
    let contactService: ContactService
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
        let draft = DraftContact(givenName: givenName, surname: surname, email: email, businessPhones: phone.map { [$0] }, companyName: company, jobTitle: jobTitle)
        let contact = try await contactService.createContact(draft)
        let data = try JSONEncoder.graph.encode(contact)
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: ["list-contacts"], approvalLevel: "explicit")
    }
}
