import Foundation
import Domain
import AppNetwork
import SharedModels

public final class LiveSearchService: SearchRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration

    public init(apiClient: APIClientProtocol, configuration: APIConfiguration = .current) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    public func search(query: String, types: [SearchEntityType]?, limit: Int?, mode: SearchMode?) async throws -> OmnibarSearchResponse {
        let ep = SearchEndpoint.search(query: query, types: types, limit: limit, mode: mode, threshold: nil, configuration: apiConfiguration)
        let response = try await apiClient.request(ep, responseType: APIResponse<OmnibarSearchResponse>.self)
        guard let data = response.data else {
            throw NetworkError.decodingFailed("Missing response data for search.")
        }
        return data
    }
}
