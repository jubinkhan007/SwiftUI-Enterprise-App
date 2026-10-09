import Foundation
import SharedModels

public protocol SearchRepositoryProtocol: Sendable {
    func search(query: String, types: [SearchEntityType]?, limit: Int?, mode: SearchMode?) async throws -> OmnibarSearchResponse
}

public extension SearchRepositoryProtocol {
    func search(query: String, types: [SearchEntityType]?, limit: Int?) async throws -> OmnibarSearchResponse {
        try await search(query: query, types: types, limit: limit, mode: .hybrid)
    }
}
