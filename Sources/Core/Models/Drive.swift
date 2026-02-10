import Foundation

public struct DriveItem: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let size: Int?
    public let webUrl: String?
    public let createdDateTime: Date?
    public let lastModifiedDateTime: Date?
    public let folder: FolderFacet?
    public let file: FileFacet?
    public let parentReference: ItemReference?
}

public struct FolderFacet: Codable, Sendable {
    public let childCount: Int?
}

public struct FileFacet: Codable, Sendable {
    public let mimeType: String?
}

public struct ItemReference: Codable, Sendable {
    public let driveId: String?
    public let id: String?
    public let path: String?
}
