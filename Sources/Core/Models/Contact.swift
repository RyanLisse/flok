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
