import Foundation
import Testing
@testable import FlokMCP

@Suite("ToolResult Tests")
struct ToolResultTests {
    @Test("ok result has success true")
    func okResult() {
        let result = ToolResult.ok("data", nextActions: ["next"])
        #expect(result.success == true)
        #expect(result.data == "data")
        #expect(result.nextActions == ["next"])
        #expect(result.error == nil)
    }

    @Test("fail result has success false")
    func failResult() {
        let result = ToolResult.fail("something broke")
        #expect(result.success == false)
        #expect(result.error == "something broke")
        #expect(result.data == nil)
    }

    // MARK: - JSON Encoding Tests

    @Test("ToolResult ok encodes to JSON correctly")
    func okResultEncoding() throws {
        let result = ToolResult.ok("test data", nextActions: ["action1", "action2"])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonData = try encoder.encode(result)
        let json = String(data: jsonData, encoding: .utf8)!

        #expect(json.contains("\"success\":true"))
        #expect(json.contains("\"data\":\"test data\""))
        #expect(json.contains("\"nextActions\""))
        #expect(json.contains("\"action1\""))
        #expect(json.contains("\"action2\""))
    }

    @Test("ToolResult fail encodes to JSON correctly")
    func failResultEncoding() throws {
        let result = ToolResult.fail("error message")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonData = try encoder.encode(result)
        let json = String(data: jsonData, encoding: .utf8)!

        #expect(json.contains("\"success\":false"))
        #expect(json.contains("\"error\":\"error message\""))
    }

    // MARK: - Edge Case Tests

    @Test("ok result with empty nextActions produces nil")
    func okResultEmptyNextActions() {
        let result = ToolResult.ok("data", nextActions: [])
        #expect(result.nextActions == nil)
        #expect(result.success == true)
        #expect(result.data == "data")
    }

    @Test("fail result always has nil nextActions")
    func failResultNilNextActions() {
        let result = ToolResult.fail("error")
        #expect(result.nextActions == nil)
        #expect(result.success == false)
        #expect(result.data == nil)
    }

    @Test("ok result round-trip through JSON")
    func okResultRoundTrip() throws {
        let original = ToolResult.ok("round trip data", nextActions: ["next1", "next2"])

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolResult.self, from: jsonData)

        #expect(decoded.success == original.success)
        #expect(decoded.data == original.data)
        #expect(decoded.nextActions == original.nextActions)
        #expect(decoded.error == original.error)
    }

    @Test("fail result round-trip through JSON")
    func failResultRoundTrip() throws {
        let original = ToolResult.fail("round trip error")

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolResult.self, from: jsonData)

        #expect(decoded.success == original.success)
        #expect(decoded.error == original.error)
        #expect(decoded.data == original.data)
        #expect(decoded.nextActions == original.nextActions)
    }
}
