import Testing
@testable import Core

@Suite("GraphClient Tests")
struct GraphClientTests {
    @Test("GraphError descriptions are meaningful")
    func errorDescriptions() {
        let errors: [GraphError] = [
            .unauthorized,
            .forbidden,
            .notFound,
            .rateLimited,
            .serverError(500),
            .httpError(400, "Bad Request"),
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("GraphPage decodes correctly")
    func pageDecoding() throws {
        let json = """
        {"value": [{"id": "1"}, {"id": "2"}], "@odata.nextLink": "https://graph.microsoft.com/next"}
        """
        let data = json.data(using: .utf8)!
        let page = try JSONDecoder().decode(GraphPage<TestItem>.self, from: data)
        #expect(page.value.count == 2)
        #expect(page.nextLink != nil)
    }
}

struct TestItem: Decodable {
    let id: String
}
