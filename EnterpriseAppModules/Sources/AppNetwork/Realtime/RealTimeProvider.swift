import Foundation

@MainActor
public final class RealTimeProvider: ObservableObject {
    public struct ServerEvent: Decodable, Sendable, Equatable {
        public let eventId: String
        public let orgId: UUID
        public let type: String
        public let entityId: UUID
        public let updatedAt: Date
        public let payload: [String: String]?
    }

    public var onEvent: ((ServerEvent) -> Void)? = nil

    private let configuration: APIConfiguration
    private let session: URLSession
    private var task: URLSessionWebSocketTask? = nil
    private var orgId: UUID? = nil

    private var reconnectAttempt: Int = 0
    private var shouldReconnect: Bool = true

    private var seenEventIds = Set<String>()
    private var seenEventQueue: [String] = []

    public init(configuration: APIConfiguration = .localVapor, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func connect(orgId: UUID) async {
        self.orgId = orgId
        shouldReconnect = true
        reconnectAttempt = 0
        await openSocket()
    }

    public func disconnect() {
        shouldReconnect = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    public func subscribe(channels: [String]) async {
        guard let task else { return }
        let msg = ["action": "subscribe", "channels": channels] as [String: Any]
        guard let data = try? JSONSerialization.data(withJSONObject: msg, options: []),
              let text = String(data: data, encoding: .utf8)
        else { return }

        do {
            try await task.send(.string(text))
        } catch {
            // Will reconnect on receive loop failure.
        }
    }

    private func openSocket() async {
        guard let orgId else { return }
        guard let token = TokenStore.shared.token else { return }

        var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = (configuration.baseURL.scheme == "https") ? "wss" : "ws"
        components?.path = "/ws"
        components?.queryItems = [URLQueryItem(name: "org_id", value: orgId.uuidString)]

        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let wsTask = session.webSocketTask(with: request)
        task = wsTask
        wsTask.resume()

        Task { await receiveLoop() }
    }

    private func receiveLoop() async {
        guard let orgId else { return }
        guard let wsTask = task else { return }

        do {
            while true {
                let message = try await wsTask.receive()
                switch message {
                case .string(let text):
                    handle(text: text, orgId: orgId)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handle(text: text, orgId: orgId)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            // Reconnect with backoff.
            await scheduleReconnect()
        }
    }

    private func handle(text: String, orgId: UUID) {
        guard let data = text.data(using: .utf8) else { return }
        guard let event = try? JSONDecoder.iso8601.decode(ServerEvent.self, from: data) else { return }
        guard event.orgId == orgId else { return }
        guard dedupe(eventId: event.eventId) else { return }
        onEvent?(event)
    }

    private func dedupe(eventId: String) -> Bool {
        if seenEventIds.contains(eventId) { return false }
        seenEventIds.insert(eventId)
        seenEventQueue.append(eventId)

        if seenEventQueue.count > 500 {
            let overflow = seenEventQueue.count - 500
            for _ in 0..<overflow {
                let removed = seenEventQueue.removeFirst()
                seenEventIds.remove(removed)
            }
        }
        return true
    }

    private func scheduleReconnect() async {
        guard shouldReconnect else { return }
        reconnectAttempt += 1

        let maxDelay: Double = 30
        let delay = min(maxDelay, pow(2.0, Double(min(reconnectAttempt, 5))))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await openSocket()
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

