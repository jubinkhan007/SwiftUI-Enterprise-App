import Foundation

// MARK: - Generic API Response Wrapper

/// A generic wrapper for all API responses, providing a consistent structure.
public struct APIResponse<T: Codable & Sendable>: Codable, Sendable {
    public let success: Bool
    public let data: T?
    public let error: APIError?
    public let pagination: PaginationMeta?

    public init(
        success: Bool = true,
        data: T? = nil,
        error: APIError? = nil,
        pagination: PaginationMeta? = nil
    ) {
        self.success = success
        self.data = data
        self.error = error
        self.pagination = pagination
    }

    /// Convenience factory for a successful response.
    public static func success(_ data: T, pagination: PaginationMeta? = nil) -> APIResponse {
        APIResponse(success: true, data: data, pagination: pagination)
    }

    /// Convenience factory for a failed response.
    public static func failure(_ error: APIError) -> APIResponse {
        APIResponse(success: false, error: error)
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

    public init(page: Int, perPage: Int, total: Int) {
        self.page = page
        self.perPage = perPage
        self.total = total
        self.totalPages = total > 0 ? Int(ceil(Double(total) / Double(perPage))) : 0
    }
}
