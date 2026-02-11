import Foundation
import Core

// MARK: - Raw Graph API Escape Hatch

/// Handler: graph-api — Call any Microsoft Graph API endpoint directly.
/// This is the emergent capability escape hatch: agents can call ANY Graph endpoint
/// even if there's no dedicated tool for it.
public struct GraphAPIHandler: Sendable {
    let client: GraphClient
    let readOnly: Bool

    public func handle(
        method: String,
        path: String,
        query: [String: String] = [:],
        body: String? = nil,
        headers: [String: String] = [:]
    ) async throws -> ToolResult {
        let httpMethod: GraphClient.HTTPMethod
        switch method.uppercased() {
        case "GET": httpMethod = .get
        case "POST":
            guard !readOnly else { return .fail("Read-only mode — POST is disabled") }
            httpMethod = .post
        case "PATCH":
            guard !readOnly else { return .fail("Read-only mode — PATCH is disabled") }
            httpMethod = .patch
        case "PUT":
            guard !readOnly else { return .fail("Read-only mode — PUT is disabled") }
            httpMethod = .put
        case "DELETE":
            guard !readOnly else { return .fail("Read-only mode — DELETE is disabled") }
            httpMethod = .delete
        default:
            return .fail("Unsupported HTTP method: \(method)")
        }

        let bodyData = body?.data(using: .utf8)
        let isRead = (method.uppercased() == "GET")
        let data = try await client.raw(
            method: httpMethod,
            path: path,
            query: query,
            body: bodyData,
            headers: headers
        )
        let approvalLevel: String? = isRead ? "auto" : "explicit"
        return .ok(String(data: data, encoding: .utf8) ?? "", nextActions: [], approvalLevel: approvalLevel)
    }
}
