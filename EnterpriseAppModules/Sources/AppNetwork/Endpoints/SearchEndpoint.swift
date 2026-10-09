import Foundation
import SharedModels

public enum SearchEndpoint {
    case search(query: String, types: [SearchEntityType]?, limit: Int?, configuration: APIConfiguration)
    case postSearch(payload: OmnibarSearchRequest, configuration: APIConfiguration)
}

extension SearchEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .search(_, _, _, let c), .postSearch(_, let c):
            return c
        }
    }

    public var path: String {
        return "/api/search"
    }

    public var method: HTTPMethod {
        switch self {
        case .search:
            return .get
        case .postSearch:
            return .post
        }
    }

    public var queryParameters: [String: String]? {
        switch self {
        case .search(let query, let types, let limit, _):
            var q: [String: String] = ["q": query]
            if let types, !types.isEmpty {
                q["types"] = types.map { $0.rawValue }.joined(separator: ",")
            }
            if let limit {
                q["limit"] = "\(limit)"
            }
            return q
        case .postSearch:
            return nil
        }
    }

    public var headers: [String: String]? {
        var h: [String: String] = [:]
        if let token = TokenStore.shared.token { h["Authorization"] = "Bearer \(token)" }
        if let orgId = OrganizationContext.shared.orgId { h["X-Org-Id"] = orgId.uuidString }
        h["Accept"] = "application/json"

        switch self {
        case .postSearch:
            h["Content-Type"] = "application/json; charset=utf-8"
        default:
            break
        }

        return h
    }

    public var body: Data? {
        switch self {
        case .postSearch(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        default:
            return nil
        }
    }
}
