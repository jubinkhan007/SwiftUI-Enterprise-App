import Foundation

public enum AuthError: Error, LocalizedError, Sendable, Equatable {
    case invalidCredentials
    case emailAlreadyInUse
    case invalidInput(String)
    case server(String)
    case offline
    case unknown

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password."
        case .emailAlreadyInUse:
            return "A user with this email already exists."
        case .invalidInput(let message):
            return message
        case .server(let message):
            return message
        case .offline:
            return "You appear to be offline. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

