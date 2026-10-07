import Foundation
import Combine

@MainActor
public final class DeeplinkRouter: ObservableObject {
    public static let shared = DeeplinkRouter()

    @Published public var currentDestination: DeeplinkDestination? = nil

    public init() {}

    @discardableResult
    public static func handle(_ url: URL) -> Bool {
        return shared.route(url: url)
    }

    @discardableResult
    public static func handle(_ urlString: String) -> Bool {
        return shared.route(urlString: urlString)
    }

    public func route(url: URL) -> Bool {
        guard let destination = DeeplinkParser.parse(url: url) else {
            return false
        }
        self.currentDestination = destination
        return true
    }

    public func route(urlString: String) -> Bool {
        guard let destination = DeeplinkParser.parse(urlString: urlString) else {
            return false
        }
        self.currentDestination = destination
        return true
    }

    public func route(destination: DeeplinkDestination) {
        self.currentDestination = destination
    }

    public func clear() {
        self.currentDestination = nil
    }
}
