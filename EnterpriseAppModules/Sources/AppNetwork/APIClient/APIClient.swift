import Foundation
import SharedModels

public enum NetworkError: Error, LocalizedError, Sendable, Equatable {
    case invalidURL
    case decodingFailed(String)
    case serverError(statusCode: Int, message: String?)
    case conflict(data: Data, message: String?, headers: [String: String])
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
        case .conflict(_, let message, _):
            return message ?? "Conflict. The server has newer data."
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
    var queryParameters: [String: String]? { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var body: Data? { get }
}

public extension APIEndpoint {
    var queryParameters: [String: String]? { nil }
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

        private func requestTimeout(for endpoint: APIEndpoint) -> TimeInterval {
            // Multipart uploads (attachments) can legitimately take longer on slow simulators/devices.
            if let contentType = endpoint.headers?["Content-Type"],
               contentType.lowercased().contains("multipart/form-data") {
                return 120
            }
            if endpoint.path.contains("/attachments") {
                return 60
            }
            return 30
        }

        public func request<T: Decodable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T {
            guard let base = URL(string: endpoint.path, relativeTo: endpoint.baseURL) else {
                throw NetworkError.invalidURL
            }
            guard var components = URLComponents(url: base, resolvingAgainstBaseURL: true) else {
                throw NetworkError.invalidURL
            }
            if let params = endpoint.queryParameters, !params.isEmpty {
                var items = components.queryItems ?? []
                items.append(contentsOf: params.map { URLQueryItem(name: $0.key, value: $0.value) })
                components.queryItems = items
            }
            guard let url = components.url else {
                throw NetworkError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = endpoint.method.rawValue
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = requestTimeout(for: endpoint)

        // Header precedence: endpoint overrides defaults.
        var headers = endpoint.headers ?? [:]
        if headers["Accept"] == nil {
            headers["Accept"] = "application/json"
        }
        if headers["Content-Type"] == nil, endpoint.body != nil {
            headers["Content-Type"] = "application/json; charset=utf-8"
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
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
            case 409:
                throw NetworkError.conflict(
                    data: data,
                    message: decodeVaporErrorMessage(from: data),
                    headers: Self.stringHeaders(from: httpResponse)
                )
            default:
                throw NetworkError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: decodeVaporErrorMessage(from: data)
                )
            }
        } catch let error as NetworkError {
            throw error
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw NetworkError.underlying("The request timed out. Is the backend running at \(endpoint.baseURL.absoluteString)?")
        } catch let urlError as URLError where urlError.code.rawValue == -1022 {
            // NSURLErrorAppTransportSecurityRequiresSecureConnection
            throw NetworkError.underlying("Blocked by App Transport Security (ATS): this build requires HTTPS. Use an `https://` base URL or add an ATS exception for this host in `Info.plist`.")
        } catch let urlError as URLError
            where urlError.code == .cannotConnectToHost
                || urlError.code == .cannotFindHost
                || urlError.code == .dnsLookupFailed
        {
            throw NetworkError.underlying("Could not connect to the server at \(endpoint.baseURL.absoluteString). Make sure the backend is running and listening on that host/port.")
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw NetworkError.offline
        } catch {
            throw NetworkError.underlying(String(describing: error))
        }
    }

    /// Issues a request and returns the raw response bytes (used for downloads / non-JSON responses).
        public func requestData(_ endpoint: APIEndpoint) async throws -> Data {
            guard let base = URL(string: endpoint.path, relativeTo: endpoint.baseURL) else {
                throw NetworkError.invalidURL
            }
            guard var components = URLComponents(url: base, resolvingAgainstBaseURL: true) else {
                throw NetworkError.invalidURL
            }
            if let params = endpoint.queryParameters, !params.isEmpty {
                var items = components.queryItems ?? []
                items.append(contentsOf: params.map { URLQueryItem(name: $0.key, value: $0.value) })
                components.queryItems = items
            }
            guard let url = components.url else {
                throw NetworkError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = endpoint.method.rawValue
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = max(60, requestTimeout(for: endpoint))

        var headers = endpoint.headers ?? [:]
        if headers["Accept"] == nil {
            headers["Accept"] = "*/*"
        }
        if headers["Content-Type"] == nil, endpoint.body != nil {
            headers["Content-Type"] = "application/octet-stream"
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = endpoint.body

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.serverError(statusCode: 0, message: "Invalid server response.")
            }

            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                throw NetworkError.unauthorized(message: decodeVaporErrorMessage(from: data))
            case 403:
                OrganizationContext.shared.clear()
                throw NetworkError.forbidden(message: decodeVaporErrorMessage(from: data))
            case 409:
                throw NetworkError.conflict(
                    data: data,
                    message: decodeVaporErrorMessage(from: data),
                    headers: Self.stringHeaders(from: httpResponse)
                )
            default:
                throw NetworkError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: decodeVaporErrorMessage(from: data)
                )
            }
        } catch let error as NetworkError {
            throw error
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw NetworkError.underlying("The request timed out. Is the backend running at \(endpoint.baseURL.absoluteString)?")
        } catch let urlError as URLError
            where urlError.code == .cannotConnectToHost
                || urlError.code == .cannotFindHost
                || urlError.code == .dnsLookupFailed
        {
            throw NetworkError.underlying("Could not connect to the server at \(endpoint.baseURL.absoluteString). Make sure the backend is running and listening on that host/port.")
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

    private static func stringHeaders(from response: HTTPURLResponse) -> [String: String] {
        var out: [String: String] = [:]
        for (k, v) in response.allHeaderFields {
            if let key = k as? String {
                out[key] = String(describing: v)
            }
        }
        return out
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
