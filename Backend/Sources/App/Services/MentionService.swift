import Fluent
import Foundation

enum MentionService {
    /// Extracts mentioned user IDs from `@[Full Name](user:UUID)` patterns.
    static func extractUserIds(from body: String) -> [UUID] {
        let pattern = #"@\[[^\]]+\]\(user:([0-9A-Fa-f-]{36})\)"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        let matches = re.matches(in: body, options: [], range: range)
        var ids: [UUID] = []
        ids.reserveCapacity(matches.count)

        for m in matches {
            guard m.numberOfRanges >= 2 else { continue }
            guard let r = Range(m.range(at: 1), in: body) else { continue }
            if let uuid = UUID(uuidString: String(body[r])) {
                ids.append(uuid)
            }
        }

        // Deduplicate while preserving order
        var seen = Set<UUID>()
        var out: [UUID] = []
        out.reserveCapacity(ids.count)
        for id in ids where !seen.contains(id) {
            seen.insert(id)
            out.append(id)
        }
        return out
    }

    /// Returns only those mentioned IDs that are members of the given org.
    static func filterToOrgMembers(userIds: [UUID], orgId: UUID, db: Database) async throws -> [UUID] {
        guard !userIds.isEmpty else { return [] }
        let rows = try await OrganizationMemberModel.query(on: db)
            .filter(\.$organization.$id == orgId)
            .filter(\.$user.$id ~~ userIds)
            .all()
        let allowed = Set(rows.map { $0.$user.id })
        return userIds.filter { allowed.contains($0) }
    }
}

