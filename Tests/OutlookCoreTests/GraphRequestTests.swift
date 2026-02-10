import XCTest
@testable import OutlookCore

final class GraphRequestTests: XCTestCase {
    func testGraphQueryBuild() {
        let query = GraphQuery()
            .select("id", "subject", "from")
            .filter("isRead eq false")
            .orderBy("receivedDateTime desc")
            .top(25)
            .skip(10)
            .build()

        XCTAssertEqual(query["$select"], "id,subject,from")
        XCTAssertEqual(query["$filter"], "isRead eq false")
        XCTAssertEqual(query["$orderby"], "receivedDateTime desc")
        XCTAssertEqual(query["$top"], "25")
        XCTAssertEqual(query["$skip"], "10")
    }

    func testGraphQuerySearch() {
        let query = GraphQuery()
            .search("important meeting")
            .top(10)
            .build()

        XCTAssertEqual(query["$search"], "\"important meeting\"")
        XCTAssertEqual(query["$top"], "10")
    }

    func testGraphQueryExpand() {
        let query = GraphQuery()
            .expand("attachments", "extensions")
            .build()

        XCTAssertEqual(query["$expand"], "attachments,extensions")
    }

    func testGraphQueryCustom() {
        let query = GraphQuery()
            .custom("startDateTime", "2024-01-01T00:00:00Z")
            .custom("endDateTime", "2024-12-31T23:59:59Z")
            .build()

        XCTAssertEqual(query["startDateTime"], "2024-01-01T00:00:00Z")
        XCTAssertEqual(query["endDateTime"], "2024-12-31T23:59:59Z")
    }

    func testGraphQueryImmutability() {
        let base = GraphQuery().top(10)
        let withFilter = base.filter("isRead eq true")
        let withOrder = base.orderBy("date desc")

        let filterParams = withFilter.build()
        let orderParams = withOrder.build()

        XCTAssertEqual(filterParams["$top"], "10")
        XCTAssertEqual(filterParams["$filter"], "isRead eq true")
        XCTAssertNil(filterParams["$orderby"])

        XCTAssertEqual(orderParams["$top"], "10")
        XCTAssertEqual(orderParams["$orderby"], "date desc")
        XCTAssertNil(orderParams["$filter"])
    }
}
