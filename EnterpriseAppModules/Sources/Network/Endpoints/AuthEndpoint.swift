import Foundation
import SharedModels

public enum AuthEndpoint: APIEndpoint {
    case login(LoginRequest, configuration: APIConfiguration)
    case register(RegisterRequest, configuration: APIConfiguration)

    public var baseURL: URL {
        switch self {
        case .login(_, let configuration), .register(_, let configuration):
            return configuration.baseURL
        }
    }

    public var path: String {
        switch self {
        case .login:
            return "/api/auth/login"
        case .register:
            return "/api/auth/register"
        }
    }

    public var method: HTTPMethod { .post }

    public var headers: [String: String]? { nil }

    public var body: Data? {
        do {
            switch self {
            case .login(let request, _):
                return try JSONCoding.encoder.encode(request)
            case .register(let request, _):
                return try JSONCoding.encoder.encode(request)
            }
        } catch {
            return nil
        }
    }
}

