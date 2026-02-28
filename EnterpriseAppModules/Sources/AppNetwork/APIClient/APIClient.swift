import Foundation
import SharedModels

public enum NetworkError: Error, LocalizedError, Sendable, Equatable {
    case invalidURL
    case decodingFailed(String)
    case serverError(statusCode: Int, message: String?)
    case underlying(String)
    case unauthorized(message: String?)
    case forbidden(message: String?)
    case offline

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL."
        case .decodingFailed(let message):
            return "Unexpected response format. \(message)"
        case .serverError(_, let message):
            return message ?? "Server error."
        case .underlying(let message):
            return message
        case .unauthorized(let message):
            return message ?? "You are not authorized."
        case .forbidden(let message):
            return message ?? "Access denied. You may have been removed from this workspace."
        case .offline:
            return "You appear to be offline."
        }
    }
}

public protocol APIEndpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var body: Data? { get }
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

public protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T
}

public struct APIClient: APIClientProtocol {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func request<T: Decodable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T {
        guard let url = URL(string: endpoint.path, relativeTo: endpoint.baseURL) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        endpoint.headers?.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        request.httpBody = endpoint.body

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.serverError(statusCode: 0, message: "Invalid server response.")
            }

            switch httpResponse.statusCode {
            case 200...299:
                if data.isEmpty {
                    if T.self == EmptyResponse.self {
                        return EmptyResponse() as! T
                    }
                    if T.self == APIResponse<EmptyResponse>.self {
                        return APIResponse(success: true, data: EmptyResponse()) as! T
                    }
                }
                do {
                    return try JSONCoding.decoder.decode(T.self, from: data)
                } catch {
                    throw NetworkError.decodingFailed(String(describing: error))
                }
            case 401:
#if DEBUG
                let hasAuthHeader = request.value(forHTTPHeaderField: "Authorization") != nil
                let hasOrgHeader = request.value(forHTTPHeaderField: "X-Org-Id") != nil
                print("API 401 \(request.httpMethod ?? "") \(url.absoluteString) hasAuth=\(hasAuthHeader) hasOrg=\(hasOrgHeader)")
#endif
                // Do NOT clear the token or trigger global logout here — let the caller decide.
                // Callers that own the auth lifecycle (e.g. DashboardViewModel, OrganizationGateViewModel)
                // should post .apiUnauthorized themselves when they see NetworkError.unauthorized.
                throw NetworkError.unauthorized(message: decodeVaporErrorMessage(from: data))
            case 403:
                // Immediately clear org context — user lost access
                OrganizationContext.shared.clear()
                throw NetworkError.forbidden(message: decodeVaporErrorMessage(from: data))
            default:
                throw NetworkError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: decodeVaporErrorMessage(from: data)
                )
            }
        } catch let error as NetworkError {
            throw error
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw NetworkError.offline
        } catch {
            throw NetworkError.underlying(String(describing: error))
        }
    }

    private func decodeVaporErrorMessage(from data: Data) -> String? {
        // Vapor's default Abort response looks like: { "error": true, "reason": "..." }
        guard let abort = try? JSONCoding.decoder.decode(VaporAbortResponse.self, from: data) else {
            return nil
        }
        return abort.reason
    }
}

private struct VaporAbortResponse: Decodable {
    let error: Bool
    let reason: String
}

public enum JSONCoding {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
