import Foundation

public enum DeeplinkDestination: Equatable, Sendable {
    case task(id: UUID)
    case channel(id: UUID)
    case meeting(id: UUID)
    case call(id: UUID)
    case billing
    case inbox
    case productivity
}

public enum DeeplinkParser {
    public static func parse(url: URL) -> DeeplinkDestination? {
        let scheme = url.scheme?.lowercased()
        guard scheme == "taskflow" || scheme == "https" || scheme == "http" else {
            return nil
        }

        let pathComponents: [String]
        if scheme == "taskflow" {
            var comps: [String] = []
            if let host = url.host, !host.isEmpty {
                comps.append(host.lowercased())
            }
            let remaining = url.path.split(separator: "/").map { String($0) }
            comps.append(contentsOf: remaining)
            pathComponents = comps
        } else {
            pathComponents = url.path.split(separator: "/").map { String($0) }
        }

        guard let first = pathComponents.first?.lowercased() else {
            return nil
        }

        switch first {
        case "tasks", "task":
            if pathComponents.count > 1, let id = UUID(uuidString: pathComponents[1]) {
                return .task(id: id)
            }
            return nil

        case "channels", "channel", "messages", "message":
            if pathComponents.count > 1, let id = UUID(uuidString: pathComponents[1]) {
                return .channel(id: id)
            }
            return nil

        case "meetings", "meeting":
            if pathComponents.count > 1, let id = UUID(uuidString: pathComponents[1]) {
                return .meeting(id: id)
            }
            return nil

        case "calls", "call":
            if pathComponents.count > 1, let id = UUID(uuidString: pathComponents[1]) {
                return .call(id: id)
            }
            return nil

        case "billing", "subscriptions", "subscription":
            return .billing

        case "inbox", "notifications", "notification":
            return .inbox

        case "productivity", "reminders", "reminder":
            return .productivity

        default:
            return nil
        }
    }

    public static func parse(urlString: String) -> DeeplinkDestination? {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return parse(url: url)
    }
}
