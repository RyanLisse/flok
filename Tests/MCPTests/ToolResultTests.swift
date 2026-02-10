import Testing
@testable import MCP

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
}
