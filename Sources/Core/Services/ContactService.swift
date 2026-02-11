import Foundation

/// Contact operations via Microsoft Graph.
public actor ContactService {
    private let client: GraphClient

    public init(client: GraphClient) {
        self.client = client
    }

    // MARK: - Read

    public func listContacts(search: String? = nil, top: Int = 50) async throws -> [Contact] {
        var query: [String: String] = [
            "$top": String(top),
            "$select": "id,displayName,givenName,surname,emailAddresses,businessPhones,mobilePhone,companyName,jobTitle",
        ]
        if let search { query["$search"] = "\"\(search)\"" }
        let data = try await client.get("/me/contacts", query: query)
        let page = try JSONDecoder.graph.decode(GraphPage<Contact>.self, from: data)
        return page.value
    }

    public func getContact(id: String) async throws -> Contact {
        let data = try await client.get("/me/contacts/\(id)")
        return try JSONDecoder.graph.decode(Contact.self, from: data)
    }

    // MARK: - Write

    public func createContact(_ draft: DraftContact) async throws -> Contact {
        var body: [String: Any] = ["givenName": draft.givenName]
        if let s = draft.surname { body["surname"] = s }
        if let e = draft.email { body["emailAddresses"] = [["address": e]] }
        if let p = draft.businessPhones { body["businessPhones"] = p }
        if let c = draft.companyName { body["companyName"] = c }
        if let j = draft.jobTitle { body["jobTitle"] = j }
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let data = try await client.post("/me/contacts", body: jsonData)
        return try JSONDecoder.graph.decode(Contact.self, from: data)
    }

    public func updateContact(id: String, givenName: String? = nil, surname: String? = nil, companyName: String? = nil, jobTitle: String? = nil) async throws -> Contact {
        var body: [String: Any] = [:]
        if let g = givenName { body["givenName"] = g }
        if let s = surname { body["surname"] = s }
        if let c = companyName { body["companyName"] = c }
        if let j = jobTitle { body["jobTitle"] = j }
        guard !body.isEmpty else { return try await getContact(id: id) }
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let data = try await client.patch("/me/contacts/\(id)", body: jsonData)
        return try JSONDecoder.graph.decode(Contact.self, from: data)
    }

    public func deleteContact(id: String) async throws {
        try await client.delete("/me/contacts/\(id)")
    }
}
