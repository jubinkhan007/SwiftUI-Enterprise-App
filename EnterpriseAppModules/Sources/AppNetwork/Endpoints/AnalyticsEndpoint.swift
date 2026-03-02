import Foundation
import SharedModels

public enum AnalyticsEndpoint {
    case getLeadTime(projectId: UUID, startDate: Date?, endDate: Date?, configuration: APIConfiguration)
    case getCycleTime(projectId: UUID, startDate: Date?, endDate: Date?, configuration: APIConfiguration)
    case getVelocity(projectId: UUID, startDate: Date?, endDate: Date?, configuration: APIConfiguration)
    case getThroughput(projectId: UUID, startDate: Date?, endDate: Date?, configuration: APIConfiguration)
    case getBurndown(projectId: UUID, startDate: Date?, endDate: Date?, configuration: APIConfiguration)
}

extension AnalyticsEndpoint: APIEndpoint {
    public var baseURL: URL {
        configuration.baseURL
    }

    private var configuration: APIConfiguration {
        switch self {
        case .getLeadTime(_, _, _, let c),
             .getCycleTime(_, _, _, let c),
             .getVelocity(_, _, _, let c),
             .getThroughput(_, _, _, let c),
             .getBurndown(_, _, _, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .getLeadTime(let projectId, _, _, _): return "/api/projects/\(projectId.uuidString)/analytics/lead-time"
        case .getCycleTime(let projectId, _, _, _): return "/api/projects/\(projectId.uuidString)/analytics/cycle-time"
        case .getVelocity(let projectId, _, _, _): return "/api/projects/\(projectId.uuidString)/analytics/velocity"
        case .getThroughput(let projectId, _, _, _): return "/api/projects/\(projectId.uuidString)/analytics/throughput"
        case .getBurndown(let projectId, _, _, _): return "/api/projects/\(projectId.uuidString)/analytics/burndown"
        }
    }
    
    public var method: HTTPMethod {
        return .get
    }
    
    public var headers: [String : String]? {
        return nil
    }
    
    public var body: Data? {
        return nil
    }
    
    public var queryItems: [URLQueryItem]? {
        let formatter = ISO8601DateFormatter()
        
        var items: [URLQueryItem] = []
        let dates: (Date?, Date?)
        switch self {
        case .getLeadTime(_, let s, let e, _),
             .getCycleTime(_, let s, let e, _),
             .getVelocity(_, let s, let e, _),
             .getThroughput(_, let s, let e, _),
             .getBurndown(_, let s, let e, _):
            dates = (s, e)
        }
        
        if let s = dates.0 { items.append(URLQueryItem(name: "start_date", value: formatter.string(from: s))) }
        if let e = dates.1 { items.append(URLQueryItem(name: "end_date", value: formatter.string(from: e))) }
        
        return items.isEmpty ? nil : items
    }
    
    public var requiresAuth: Bool {
        return true
    }
}
