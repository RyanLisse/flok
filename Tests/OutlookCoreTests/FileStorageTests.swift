import XCTest
@testable import OutlookCore

final class FileStorageTests: XCTestCase {
    var storage: FileTokenStorage!
    var testDir: URL!

    override func setUp() async throws {
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("outlookcli-test-\(UUID().uuidString)")
        storage = FileTokenStorage(directory: testDir)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testDir)
    }

    func testSaveAndLoadAccessToken() async throws {
        try await storage.saveAccessToken("test-token-123", for: "user@example.com")
        let loaded = try await storage.loadAccessToken(for: "user@example.com")
        XCTAssertEqual(loaded, "test-token-123")
    }

    func testSaveAndLoadRefreshToken() async throws {
        try await storage.saveRefreshToken("refresh-abc", for: "user@example.com")
        let loaded = try await storage.loadRefreshToken(for: "user@example.com")
        XCTAssertEqual(loaded, "refresh-abc")
    }

    func testLoadMissingToken() async throws {
        let loaded = try await storage.loadAccessToken(for: "nonexistent@example.com")
        XCTAssertNil(loaded)
    }

    func testSaveAndLoadAccountInfo() async throws {
        let info = AccountInfo(
            id: "user@example.com",
            displayName: "Test User",
            email: "user@example.com",
            tenantId: "tenant-123"
        )
        try await storage.saveAccountInfo(info)

        let loaded = try await storage.loadAccountInfo(for: "user@example.com")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, "user@example.com")
        XCTAssertEqual(loaded?.displayName, "Test User")
        XCTAssertEqual(loaded?.tenantId, "tenant-123")
    }

    func testListAccounts() async throws {
        let info1 = AccountInfo(id: "user1@example.com", displayName: "User 1", email: "user1@example.com", tenantId: "t1")
        let info2 = AccountInfo(id: "user2@example.com", displayName: "User 2", email: "user2@example.com", tenantId: "t2")

        try await storage.saveAccountInfo(info1)
        try await storage.saveAccountInfo(info2)

        let accounts = try await storage.listAccounts()
        XCTAssertEqual(accounts.count, 2)

        let ids = Set(accounts.map(\.id))
        XCTAssertTrue(ids.contains("user1@example.com"))
        XCTAssertTrue(ids.contains("user2@example.com"))
    }

    func testDeleteAccount() async throws {
        try await storage.saveAccessToken("token", for: "user@example.com")
        try await storage.saveRefreshToken("refresh", for: "user@example.com")
        let info = AccountInfo(id: "user@example.com", displayName: "User", email: "user@example.com", tenantId: "t")
        try await storage.saveAccountInfo(info)

        try await storage.deleteAccount("user@example.com")

        let token = try await storage.loadAccessToken(for: "user@example.com")
        let refresh = try await storage.loadRefreshToken(for: "user@example.com")
        let account = try await storage.loadAccountInfo(for: "user@example.com")

        XCTAssertNil(token)
        XCTAssertNil(refresh)
        XCTAssertNil(account)
    }

    func testDefaultAccount() async throws {
        try await storage.setDefaultAccount("user@example.com")
        let loaded = try await storage.loadDefaultAccount()
        XCTAssertEqual(loaded, "user@example.com")
    }
}
