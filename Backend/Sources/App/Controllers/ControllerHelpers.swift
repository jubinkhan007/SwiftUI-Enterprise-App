import RoutingKit
import Vapor

extension Request {
    func requireParameter<T>(_ name: String, as type: T.Type) throws -> T where T: LosslessStringConvertible {
        guard let value = parameters.get(name, as: T.self) else {
            throw Abort(.badRequest, reason: "Missing or invalid \(name).")
        }
        return value
    }
}

extension Parameters {
    func require<T>(_ name: String, as type: T.Type) throws -> T where T: LosslessStringConvertible {
        guard let value = get(name, as: T.self) else {
            throw Abort(.badRequest, reason: "Missing or invalid \(name).")
        }
        return value
    }
}
