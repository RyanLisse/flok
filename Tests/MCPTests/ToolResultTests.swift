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

    // MARK: - JSON Structure Tests

    @Test("ToolResult.ok JSON has expected keys")
    func okResultJSONKeys() throws {
        let result = ToolResult.ok("test data", nextActions: ["action1", "action2"])
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)

        // Parse JSON to verify structure
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

        #expect(jsonObject.keys.contains("success"))
        #expect(jsonObject.keys.contains("data"))
        #expect(jsonObject.keys.contains("nextActions"))
        #expect(jsonObject["success"] as? Bool == true)
        #expect(jsonObject["data"] as? String == "test data")

        let actions = jsonObject["nextActions"] as? [String]
        #expect(actions == ["action1", "action2"])
    }

    @Test("ToolResult.fail JSON has expected keys")
    func failResultJSONKeys() throws {
        let result = ToolResult.fail("error message")
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)

        // Parse JSON to verify structure
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

        #expect(jsonObject.keys.contains("success"))
        #expect(jsonObject.keys.contains("error"))
        #expect(jsonObject["success"] as? Bool == false)
        #expect(jsonObject["error"] as? String == "error message")

        // Ensure data and nextActions are either nil or not present
        let data = jsonObject["data"]
        let nextActions = jsonObject["nextActions"]
        #expect(data == nil || (data is NSNull))
        #expect(nextActions == nil || (nextActions is NSNull))
    }

    // MARK: - Special Characters Tests

    @Test("ToolResult handles unicode characters in data")
    func unicodeInData() throws {
        let unicodeData = "Hello 世界 🌍 café naïve résumé"
        let result = ToolResult.ok(unicodeData)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolResult.self, from: jsonData)

        #expect(decoded.data == unicodeData)
    }

    @Test("ToolResult handles newlines in data")
    func newlinesInData() throws {
        let multilineData = """
        Line 1
        Line 2
        Line 3
        """
        let result = ToolResult.ok(multilineData)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolResult.self, from: jsonData)

        #expect(decoded.data == multilineData)
        #expect(decoded.data?.contains("\n") == true)
    }

    @Test("ToolResult handles special JSON characters in data")
    func specialJSONCharactersInData() throws {
        let specialData = #"Special chars: " \ / backslash quote"#
        let result = ToolResult.ok(specialData)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolResult.self, from: jsonData)

        #expect(decoded.data == specialData)
    }

    @Test("ToolResult handles unicode in error message")
    func unicodeInError() throws {
        let unicodeError = "エラー: File not found 📁"
        let result = ToolResult.fail(unicodeError)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolResult.self, from: jsonData)

        #expect(decoded.error == unicodeError)
    }

    // MARK: - Long Data Tests

    @Test("ToolResult handles long data string without truncation")
    func longDataString() throws {
        // Generate a long string (10KB+)
        let longData = String(repeating: "This is a test message with some content. ", count: 250)
        #expect(longData.count > 10_000)

        let result = ToolResult.ok(longData, nextActions: ["process", "review"])

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolResult.self, from: jsonData)

        #expect(decoded.data == longData)
        #expect(decoded.data?.count == longData.count)
        #expect(decoded.nextActions == ["process", "review"])
    }

    @Test("ToolResult handles very long nextActions array")
    func longNextActionsArray() throws {
        let manyActions = (1...100).map { "action_\($0)" }
        let result = ToolResult.ok("data", nextActions: manyActions)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolResult.self, from: jsonData)

        #expect(decoded.nextActions?.count == 100)
        #expect(decoded.nextActions?[0] == "action_1")
        #expect(decoded.nextActions?[99] == "action_100")
    }

    @Test("ToolResult handles JSON-like data string")
    func jsonLikeDataString() throws {
        let jsonLikeData = #"{"nested": "value", "array": [1, 2, 3], "bool": true}"#
        let result = ToolResult.ok(jsonLikeData)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolResult.self, from: jsonData)

        #expect(decoded.data == jsonLikeData)
    }

    @Test("ToolResult handles empty string data")
    func emptyStringData() throws {
        let result = ToolResult.ok("")

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolResult.self, from: jsonData)

        #expect(decoded.success == true)
        #expect(decoded.data == "")
        #expect(decoded.error == nil)
    }
}
