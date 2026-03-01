import Foundation
import NIOConcurrencyHelpers
import Vapor

/// In-memory WebSocket hub keyed by logical channels (org/project/list).
/// This is intentionally simple and process-local.
final class RealtimeHub {
    struct Connection {
        let id: UUID
        let userId: UUID
        let orgId: UUID
        let socket: WebSocket
        var channels: Set<String>
    }

    private let lock = NIOLock()
    private var connections: [UUID: Connection] = [:]
    private var channelMembers: [String: Set<UUID>] = [:]

    func addConnection(userId: UUID, orgId: UUID, socket: WebSocket, initialChannels: [String]) -> UUID {
        let id = UUID()
        lock.withLock {
            let set = Set(initialChannels)
            connections[id] = Connection(id: id, userId: userId, orgId: orgId, socket: socket, channels: set)
            for c in set {
                channelMembers[c, default: []].insert(id)
            }
        }
        return id
    }

    func removeConnection(id: UUID) {
        lock.withLock {
            guard let conn = connections.removeValue(forKey: id) else { return }
            for c in conn.channels {
                channelMembers[c]?.remove(id)
                if channelMembers[c]?.isEmpty == true {
                    channelMembers.removeValue(forKey: c)
                }
            }
        }
    }

    func subscribe(id: UUID, channels: [String]) {
        lock.withLock {
            guard var conn = connections[id] else { return }
            for c in channels where !conn.channels.contains(c) {
                conn.channels.insert(c)
                channelMembers[c, default: []].insert(id)
            }
            connections[id] = conn
        }
    }

    func unsubscribe(id: UUID, channels: [String]) {
        lock.withLock {
            guard var conn = connections[id] else { return }
            for c in channels where conn.channels.contains(c) {
                conn.channels.remove(c)
                channelMembers[c]?.remove(id)
                if channelMembers[c]?.isEmpty == true {
                    channelMembers.removeValue(forKey: c)
                }
            }
            connections[id] = conn
        }
    }

    func broadcast(channel: String, text: String) {
        let sockets: [WebSocket] = lock.withLock {
            guard let members = channelMembers[channel], !members.isEmpty else { return [] }
            return members.compactMap { connections[$0]?.socket }
        }

        for ws in sockets {
            ws.eventLoop.execute {
                ws.send(text)
            }
        }
    }
}

private struct RealtimeHubKey: StorageKey {
    typealias Value = RealtimeHub
}

extension Application {
    var realtimeHub: RealtimeHub {
        if let existing = storage[RealtimeHubKey.self] {
            return existing
        }
        let hub = RealtimeHub()
        storage[RealtimeHubKey.self] = hub
        return hub
    }
}

