/// Fluent builder for OData query parameters used by Microsoft Graph API.
///
/// Provides a type-safe, chainable interface for constructing Microsoft Graph API
/// query parameters following OData conventions.
///
/// Example:
/// ```swift
/// let query = GraphQuery()
///     .select("id", "subject", "from")
///     .filter("receivedDateTime ge 2024-01-01")
///     .orderBy("receivedDateTime", descending: true)
///     .top(25)
///     .build()
/// ```
public struct GraphQuery: Sendable {
    private var params: [String: String] = [:]

    /// Creates a new empty GraphQuery builder.
    public init() {}

    /// Selects specific fields to return in the response.
    ///
    /// Multiple calls append to the existing selection list.
    ///
    /// - Parameter fields: Field names to select
    /// - Returns: A new GraphQuery with the selection added
    public func select(_ fields: String...) -> GraphQuery {
        var new = self
        let existingFields = new.params["$select"]?.split(separator: ",").map(String.init) ?? []
        let allFields = existingFields + fields
        new.params["$select"] = allFields.joined(separator: ",")
        return new
    }

    /// Filters results based on an OData filter expression.
    ///
    /// - Parameter expression: OData filter expression (e.g., "receivedDateTime ge 2024-01-01")
    /// - Returns: A new GraphQuery with the filter set
    public func filter(_ expression: String) -> GraphQuery {
        var new = self
        new.params["$filter"] = expression
        return new
    }

    /// Orders results by the specified field.
    ///
    /// Multiple calls create comma-separated ordering.
    ///
    /// - Parameters:
    ///   - field: Field name to order by
    ///   - descending: If true, orders descending; default is ascending
    /// - Returns: A new GraphQuery with the ordering added
    public func orderBy(_ field: String, descending: Bool = false) -> GraphQuery {
        var new = self
        let orderClause = descending ? "\(field) desc" : field

        if let existing = new.params["$orderby"] {
            new.params["$orderby"] = "\(existing),\(orderClause)"
        } else {
            new.params["$orderby"] = orderClause
        }
        return new
    }

    /// Limits the number of results returned.
    ///
    /// - Parameter count: Maximum number of items to return
    /// - Returns: A new GraphQuery with the limit set
    public func top(_ count: Int) -> GraphQuery {
        var new = self
        new.params["$top"] = String(count)
        return new
    }

    /// Skips the specified number of results.
    ///
    /// - Parameter count: Number of items to skip
    /// - Returns: A new GraphQuery with the skip offset set
    public func skip(_ count: Int) -> GraphQuery {
        var new = self
        new.params["$skip"] = String(count)
        return new
    }

    /// Performs a search query (wraps value in escaped quotes for Graph API).
    ///
    /// - Parameter query: Search text (will be automatically quoted)
    /// - Returns: A new GraphQuery with the search set
    public func search(_ query: String) -> GraphQuery {
        var new = self
        new.params["$search"] = "\"\(query)\""
        return new
    }

    /// Expands related entities inline.
    ///
    /// - Parameter field: Navigation property to expand
    /// - Returns: A new GraphQuery with the expansion added
    public func expand(_ field: String) -> GraphQuery {
        var new = self
        new.params["$expand"] = field
        return new
    }

    /// Includes a count of matching results.
    ///
    /// - Parameter include: If true, requests count; default is true
    /// - Returns: A new GraphQuery with count parameter set
    public func count(_ include: Bool = true) -> GraphQuery {
        var new = self
        new.params["$count"] = include ? "true" : "false"
        return new
    }

    /// Builds the final query parameter dictionary.
    ///
    /// - Returns: Dictionary of OData query parameters
    public func build() -> [String: String] {
        return params
    }
}
