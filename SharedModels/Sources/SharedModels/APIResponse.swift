import Foundation

// MARK: - Generic API Response Wrapper

/// A generic wrapper for all API responses, providing a consistent structure.
public struct APIResponse<T: Codable & Sendable>: Codable, Sendable {
    public let success: Bool
    public let data: T?
    public let error: APIError?
    public let pagination: PaginationMeta?
    /// Opaque cursor value for delta-sync style APIs (e.g. hierarchy updates).
    /// This is separate from `pagination.cursor`, which is used for list pagination.
    public let cursor: String?

    public init(
        success: Bool = true,
        data: T? = nil,
        error: APIError? = nil,
        pagination: PaginationMeta? = nil,
        cursor: String? = nil
    ) {
        self.success = success
        self.data = data
        self.error = error
        self.pagination = pagination
        self.cursor = cursor
    }

    /// Convenience factory for a successful response.
    public static func success(_ data: T, pagination: PaginationMeta? = nil, cursor: String? = nil) -> APIResponse {
        APIResponse(success: true, data: data, pagination: pagination, cursor: cursor)
    }

    /// Convenience factory for a failed response.
    public static func failure(_ error: APIError) -> APIResponse {
        APIResponse(success: false, error: error)
    }
}

public extension APIResponse where T == EmptyResponse {
    /// Convenience factory for endpoints that return no payload.
    static func empty() -> APIResponse<EmptyResponse> {
        .success(EmptyResponse())
    }
}

// MARK: - API Error

/// A structured error object returned by the API.
public struct APIError: Codable, Sendable, Equatable {
    public let code: String
    public let message: String
    public let details: String?

    public init(code: String, message: String, details: String? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

// MARK: - Pagination

/// Metadata for paginated list responses.
public struct PaginationMeta: Codable, Sendable, Equatable {
    public let page: Int
    public let perPage: Int
    public let total: Int
    public let totalPages: Int
    /// Opaque keyset cursor for fetching the next page. Nil when no more pages exist.
    public let cursor: String?

    public init(page: Int, perPage: Int, total: Int, cursor: String? = nil) {
        self.page = page
        self.perPage = perPage
        self.total = total
        self.totalPages = total > 0 ? Int(ceil(Double(total) / Double(perPage))) : 0
        self.cursor = cursor
    }
}
