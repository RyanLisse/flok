import Foundation
import Logging

/// HTTP client for Microsoft Graph API with retry, pagination, and rate limiting.
public actor GraphClient {
    private let tokenManager: TokenManager
    private let session: URLSession
    private let logger: Logger
    private let baseURL = "https://graph.microsoft.com/v1.0"
    private let maxRetries = 3
    private let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]

    public init(tokenManager: TokenManager, session: URLSession = .shared) {
        self.tokenManager = tokenManager
        self.session = session
        self.logger = Logger(label: "OutlookCLI.GraphClient")
    }

    /// Make a typed request to the Graph API.
    public func request<T: Decodable & Sendable>(
        _ method: HTTPMethod,
        path: String,
        query: [String: String]? = nil,
        body: (any Encodable & Sendable)? = nil,
        accountId: String? = nil
    ) async throws -> T {
        let data = try await rawRequest(method, path: path, query: query, body: body, accountId: accountId)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GraphError.decodingError(error)
        }
    }

    /// Make a request that returns a list via Graph API pagination.
    public func requestList<T: Decodable & Sendable>(
        path: String,
        query: [String: String]? = nil,
        accountId: String? = nil
    ) async throws -> [T] {
        let response: GraphResponse<T> = try await request(.get, path: path, query: query, accountId: accountId)
        return response.value
    }

    /// Make a request and follow all @odata.nextLink pages.
    public func requestAll<T: Decodable & Sendable>(
        path: String,
        query: [String: String]? = nil,
        accountId: String? = nil
    ) async throws -> [T] {
        var allItems: [T] = []
        var currentPath: String? = path
        var currentQuery = query

        while let reqPath = currentPath {
            let response: GraphResponse<T> = try await request(
                .get,
                path: reqPath,
                query: currentQuery,
                accountId: accountId
            )
            allItems.append(contentsOf: response.value)

            if let nextLink = response.nextLink,
               let url = URL(string: nextLink),
               let path = url.path.isEmpty ? nil : url.path {
                // nextLink is a full URL, extract path after /v1.0
                let pathStr = url.path
                if let range = pathStr.range(of: "/v1.0") {
                    currentPath = String(pathStr[range.upperBound...])
                } else {
                    currentPath = pathStr
                }
                // Parse query params from nextLink
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    currentQuery = Dictionary(
                        uniqueKeysWithValues: (components.queryItems ?? []).compactMap {
                            guard let value = $0.value else { return nil }
                            return ($0.name, value)
                        }
                    )
                } else {
                    currentQuery = nil
                }
                _ = path // suppress unused warning
            } else {
                currentPath = nil
            }
        }

        return allItems
    }

    /// Make a request with no response body (e.g., DELETE).
    public func requestVoid(
        _ method: HTTPMethod,
        path: String,
        query: [String: String]? = nil,
        body: (any Encodable & Sendable)? = nil,
        accountId: String? = nil
    ) async throws {
        _ = try await rawRequest(method, path: path, query: query, body: body, accountId: accountId)
    }

    // MARK: - Internal

    private func rawRequest(
        _ method: HTTPMethod,
        path: String,
        query: [String: String]?,
        body: (any Encodable & Sendable)?,
        accountId: String?
    ) async throws -> Data {
        let accessToken = try await tokenManager.getAccessToken(for: accountId)

        var urlString = baseURL + path
        if let query = query, !query.isEmpty {
            var components = URLComponents(string: urlString)!
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            urlString = components.url!.absoluteString
        }

        var urlRequest = URLRequest(url: URL(string: urlString)!)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            urlRequest.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return try await executeWithRetry(urlRequest, attempt: 0)
    }

    private func executeWithRetry(_ request: URLRequest, attempt: Int) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GraphError.networkError(URLError(.badServerResponse))
            }

            let statusCode = httpResponse.statusCode

            // Success
            if (200..<300).contains(statusCode) {
                return data
            }

            // 401 — token may have expired
            if statusCode == 401 {
                let msg = parseErrorMessage(data) ?? "Unauthorized"
                throw GraphError.unauthorized(msg)
            }

            // 403
            if statusCode == 403 {
                let msg = parseErrorMessage(data) ?? "Forbidden"
                throw GraphError.forbidden(msg)
            }

            // 404
            if statusCode == 404 {
                let msg = parseErrorMessage(data) ?? "Resource not found"
                throw GraphError.notFound(msg)
            }

            // 429 — rate limited
            if statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap(Int.init) ?? 10
                if attempt < maxRetries {
                    logger.warning("Rate limited, waiting \(retryAfter)s (attempt \(attempt + 1)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
                    return try await executeWithRetry(request, attempt: attempt + 1)
                }
                throw GraphError.rateLimited(retryAfter: retryAfter)
            }

            // 5xx — retryable
            if retryableStatusCodes.contains(statusCode) && attempt < maxRetries {
                let delay = pow(2.0, Double(attempt))
                logger.warning("Server error \(statusCode), retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await executeWithRetry(request, attempt: attempt + 1)
            }

            let msg = parseErrorMessage(data) ?? "HTTP \(statusCode)"
            throw GraphError.serverError(statusCode, msg)

        } catch let error as GraphError {
            throw error
        } catch {
            if attempt < maxRetries {
                let delay = pow(2.0, Double(attempt))
                logger.warning("Network error, retrying in \(delay)s: \(error.localizedDescription)")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await executeWithRetry(request, attempt: attempt + 1)
            }
            throw GraphError.networkError(error)
        }
    }

    private func parseErrorMessage(_ data: Data) -> String? {
        try? JSONDecoder().decode(GraphErrorResponse.self, from: data).error.message
    }
}

// MARK: - Type Erasure Helper

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        self.encodeClosure = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
