import Foundation

/// HTTP client for Microsoft Graph API with retry and pagination support.
public actor GraphClient {
    private let session: URLSession
    private let tokenProvider: any TokenProvider
    private let baseURL: URL
    private let apiVersion: String

    public init(
        tokenProvider: any TokenProvider,
        apiVersion: String = "v1.0",
        session: URLSession = .shared
    ) {
        self.tokenProvider = tokenProvider
        self.apiVersion = apiVersion
        self.session = session
        self.baseURL = URL(string: "https://graph.microsoft.com/\(apiVersion)")!
    }

    // MARK: - Public API

    public func get(_ path: String, query: [String: String] = [:]) async throws -> Data {
        try await request(.get, path: path, query: query)
    }

    public func post(_ path: String, body: Data? = nil) async throws -> Data {
        try await request(.post, path: path, body: body)
    }

    public func patch(_ path: String, body: Data) async throws -> Data {
        try await request(.patch, path: path, body: body)
    }

    public func delete(_ path: String) async throws {
        _ = try await request(.delete, path: path)
    }

    /// Raw Graph API call — escape hatch for any endpoint.
    public func raw(
        method: HTTPMethod,
        path: String,
        query: [String: String] = [:],
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> Data {
        try await request(method, path: path, query: query, body: body, extraHeaders: headers)
    }

    /// Paginated fetch — follows @odata.nextLink automatically.
    public func getPaginated<T: Decodable>(
        _ path: String,
        query: [String: String] = [:],
        maxPages: Int = 10
    ) async throws -> [T] {
        var allItems: [T] = []
        var nextURL: URL? = buildURL(path: path, query: query)
        var pages = 0

        while let url = nextURL, pages < maxPages {
            let data = try await executeRequest(buildURLRequest(url: url, method: .get))
            let page = try JSONDecoder.graph.decode(GraphPage<T>.self, from: data)
            allItems.append(contentsOf: page.value)
            nextURL = page.nextLink.flatMap(URL.init(string:))
            pages += 1
        }

        return allItems
    }

    // MARK: - Internal

    public enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case put = "PUT"
        case delete = "DELETE"
    }

    private func request(
        _ method: HTTPMethod,
        path: String,
        query: [String: String] = [:],
        body: Data? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        let url = buildURL(path: path, query: query)
        var req = try await buildURLRequest(url: url, method: method)
        req.httpBody = body
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (key, value) in extraHeaders {
            req.setValue(value, forHTTPHeaderField: key)
        }
        return try await executeRequest(req)
    }

    private func buildURL(path: String, query: [String: String] = [:]) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url!
    }

    private func buildURLRequest(url: URL, method: HTTPMethod) async throws -> URLRequest {
        let token = try await tokenProvider.accessToken()
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func executeRequest(_ request: URLRequest, retryCount: Int = 0) async throws -> Data {
        let maxRetries = 3
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GraphError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 429:
            let retryAfter = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "5") ?? 5
            guard retryCount < maxRetries else { throw GraphError.rateLimited }
            try await Task.sleep(nanoseconds: UInt64(min(retryAfter, 60)) * 1_000_000_000)
            return try await executeRequest(request, retryCount: retryCount + 1)
        case 500...599:
            guard retryCount < maxRetries else { throw GraphError.serverError(http.statusCode) }
            let wait = UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000
            try await Task.sleep(nanoseconds: wait)
            return try await executeRequest(request, retryCount: retryCount + 1)
        case 401:
            throw GraphError.unauthorized
        case 403:
            throw GraphError.forbidden
        case 404:
            throw GraphError.notFound
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GraphError.httpError(http.statusCode, body)
        }
    }
}

// MARK: - Supporting Types

public struct GraphPage<T: Decodable>: Decodable {
    public let value: [T]
    public let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

public enum GraphError: Error, LocalizedError {
    case invalidResponse
    case rateLimited
    case serverError(Int)
    case unauthorized
    case forbidden
    case notFound
    case httpError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from Graph API"
        case .rateLimited: "Rate limited by Graph API (too many retries)"
        case .serverError(let code): "Server error (\(code))"
        case .unauthorized: "Unauthorized — token may be expired. Run `flok auth login`."
        case .forbidden: "Forbidden — missing required permissions"
        case .notFound: "Resource not found"
        case .httpError(let code, let body): "HTTP \(code): \(body)"
        }
    }
}

extension JSONDecoder {
    static let graph: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let graph: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
