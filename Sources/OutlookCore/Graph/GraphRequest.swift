import Foundation

/// HTTP methods for Graph API requests.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

/// Builder for OData query parameters used by Microsoft Graph API.
public struct GraphQuery: Sendable {
    private var params: [String: String] = [:]

    public init() {}

    public func select(_ fields: String...) -> GraphQuery {
        var copy = self
        copy.params["$select"] = fields.joined(separator: ",")
        return copy
    }

    public func filter(_ expression: String) -> GraphQuery {
        var copy = self
        copy.params["$filter"] = expression
        return copy
    }

    public func orderBy(_ expression: String) -> GraphQuery {
        var copy = self
        copy.params["$orderby"] = expression
        return copy
    }

    public func top(_ count: Int) -> GraphQuery {
        var copy = self
        copy.params["$top"] = String(count)
        return copy
    }

    public func skip(_ count: Int) -> GraphQuery {
        var copy = self
        copy.params["$skip"] = String(count)
        return copy
    }

    public func search(_ query: String) -> GraphQuery {
        var copy = self
        copy.params["$search"] = "\"\(query)\""
        return copy
    }

    public func expand(_ fields: String...) -> GraphQuery {
        var copy = self
        copy.params["$expand"] = fields.joined(separator: ",")
        return copy
    }

    public func custom(_ key: String, _ value: String) -> GraphQuery {
        var copy = self
        copy.params[key] = value
        return copy
    }

    public func build() -> [String: String] {
        params
    }
}
