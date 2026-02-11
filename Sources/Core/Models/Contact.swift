import Foundation

public struct Contact: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String?
    public let givenName: String?
    public let surname: String?
    public let emailAddresses: [EmailAddressDetail]?
    public let businessPhones: [String]?
    public let mobilePhone: String?
    public let homePhones: [String]?
    public let companyName: String?
    public let jobTitle: String?
    public let department: String?
    public let businessAddress: PhysicalAddress?
    public let homeAddress: PhysicalAddress?
    public let personalNotes: String?
    public let birthday: String?
}

/// Minimal payload for creating a contact.
public struct DraftContact: Codable, Sendable {
    public let givenName: String
    public let surname: String?
    public let email: String?
    public let businessPhones: [String]?
    public let companyName: String?
    public let jobTitle: String?

    public init(
        givenName: String,
        surname: String? = nil,
        email: String? = nil,
        businessPhones: [String]? = nil,
        companyName: String? = nil,
        jobTitle: String? = nil
    ) {
        self.givenName = givenName
        self.surname = surname
        self.email = email
        self.businessPhones = businessPhones
        self.companyName = companyName
        self.jobTitle = jobTitle
    }
}
