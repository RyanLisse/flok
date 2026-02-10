import Foundation

/// Errors from Microsoft Graph API interactions.
public enum GraphError: Error, LocalizedError {
    case unauthorized(String)
    case forbidden(String)
    case notFound(String)
    case rateLimited(retryAfter: Int)
    case serverError(Int, String)
    case networkError(Error)
    case decodingError(Error)
    case invalidRequest(String)
    case readOnlyMode

    public var errorDescription: String? {
        switch self {
        case .unauthorized(let msg):
            return "Unauthorized: \(msg). Try 'outlook auth login' to re-authenticate."
        case .forbidden(let msg):
            return "Forbidden: \(msg). Check your app permissions in Azure portal."
        case .notFound(let msg):
            return "Not found: \(msg)"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(retryAfter) seconds."
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .invalidRequest(let msg):
            return "Invalid request: \(msg)"
        case .readOnlyMode:
            return "Operation blocked: read-only mode is enabled."
        }
    }
}

/// Graph API error response body.
struct GraphErrorResponse: Codable {
    let error: GraphErrorDetail
}

struct GraphErrorDetail: Codable {
    let code: String
    let message: String
}
