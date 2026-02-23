import Foundation
import SharedModels

public struct AuthSession: Codable, Equatable, Sendable {
    public let token: String
    public let user: UserDTO

    public init(token: String, user: UserDTO) {
        self.token = token
        self.user = user
    }
}

