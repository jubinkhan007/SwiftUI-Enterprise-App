import Foundation
import SharedModels

public protocol SearchRepositoryProtocol: Sendable {
    func search(query: String, types: [SearchEntityType]?, limit: Int?) async throws -> OmnibarSearchResponse
}
