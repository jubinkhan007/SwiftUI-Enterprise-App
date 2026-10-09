import Fluent
import SharedModels
import Vapor

struct SearchController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let search = routes.grouped("search")
        search.get(use: getSearch)
        search.post(use: postSearch)
    }

    // MARK: - Handlers

    @Sendable
    func getSearch(req: Request) async throws -> APIResponse<OmnibarSearchResponse> {
        let query = req.query[String.self, at: "q"] ?? ""
        let typesStr = req.query[String.self, at: "types"]
        let limit = req.query[Int.self, at: "limit"] ?? 20

        let types: [SearchEntityType]? = typesStr?.split(separator: ",").compactMap {
            SearchEntityType(rawValue: String($0).trimmingCharacters(in: .whitespaces))
        }

        return try await executeSearch(req: req, query: query, types: types, limit: limit)
    }

    @Sendable
    func postSearch(req: Request) async throws -> APIResponse<OmnibarSearchResponse> {
        let requestBody = try req.content.decode(OmnibarSearchRequest.self)
        return try await executeSearch(
            req: req,
            query: requestBody.query,
            types: requestBody.types,
            limit: requestBody.limit ?? 20
        )
    }

    // MARK: - Search Execution

    private func executeSearch(
        req: Request,
        query: String,
        types: [SearchEntityType]?,
        limit: Int
    ) async throws -> APIResponse<OmnibarSearchResponse> {
        let orgId = try req.orgContext.orgId
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTypes = types?.isEmpty == false ? types! : SearchEntityType.allCases

        var allResults: [SearchResultItemDTO] = []

        // 1. Tasks
        if searchTypes.contains(.task) {
            let taskQuery = TaskItemModel.query(on: req.db)
                .filter(\.$organization.$id == orgId)
                .filter(\.$archivedAt == nil)

            if !trimmedQuery.isEmpty {
                taskQuery.group(.or) { group in
                    group.filter(\.$title, .custom("ILIKE"), "%\(trimmedQuery)%")
                    group.filter(\.$description, .custom("ILIKE"), "%\(trimmedQuery)%")
                    group.filter(\.$issueKey, .custom("ILIKE"), "%\(trimmedQuery)%")
                }
            }

            let tasks = try await taskQuery.range(0..<limit).all()
            for task in tasks {
                let keyPrefix = task.issueKey.map { "\($0) • " } ?? ""
                let subtitle = "\(keyPrefix)\(task.status.rawValue.capitalized) • Priority: \(task.priority.rawValue.capitalized)"
                allResults.append(
                    SearchResultItemDTO(
                        id: task.id?.uuidString ?? UUID().uuidString,
                        entityType: .task,
                        title: task.title,
                        subtitle: subtitle,
                        deepLink: "taskflow://tasks/\(task.id?.uuidString ?? "")",
                        icon: "checkmark.square.fill",
                        badge: task.priority.rawValue.capitalized,
                        metadata: [
                            "status": task.status.rawValue,
                            "priority": task.priority.rawValue,
                            "taskKey": task.issueKey ?? ""
                        ],
                        updatedAt: task.updatedAt
                    )
                )
            }
        }

        // 2. Messages
        if searchTypes.contains(.message) && !trimmedQuery.isEmpty {
            let messages = try await MessageModel.query(on: req.db)
                .join(ConversationModel.self, on: \MessageModel.$conversation.$id == \ConversationModel.$id)
                .filter(ConversationModel.self, \.$organization.$id == orgId)
                .filter(\.$body, .custom("ILIKE"), "%\(trimmedQuery)%")
                .range(0..<limit)
                .all()

            for msg in messages {
                let snippet = msg.body.count > 60 ? String(msg.body.prefix(60)) + "..." : msg.body
                allResults.append(
                    SearchResultItemDTO(
                        id: msg.id?.uuidString ?? UUID().uuidString,
                        entityType: .message,
                        title: "Chat Message",
                        subtitle: snippet,
                        deepLink: "taskflow://channels/\(msg.$conversation.id.uuidString)",
                        icon: "bubble.left.and.bubble.right.fill",
                        badge: "Chat",
                        metadata: ["conversationId": msg.$conversation.id.uuidString],
                        updatedAt: msg.createdAt
                    )
                )
            }
        }

        // 3. Meetings
        if searchTypes.contains(.meeting) {
            let meetingQuery = MeetingModel.query(on: req.db)
                .filter(\.$organization.$id == orgId)

            if !trimmedQuery.isEmpty {
                meetingQuery.filter(\.$title, .custom("ILIKE"), "%\(trimmedQuery)%")
            }

            let meetings = try await meetingQuery.range(0..<limit).all()
            for meeting in meetings {
                allResults.append(
                    SearchResultItemDTO(
                        id: meeting.id?.uuidString ?? UUID().uuidString,
                        entityType: .meeting,
                        title: meeting.title,
                        subtitle: "Status: \(meeting.status.capitalized)",
                        deepLink: "taskflow://meetings/\(meeting.id?.uuidString ?? "")",
                        icon: "video.fill",
                        badge: meeting.status.capitalized,
                        metadata: ["meetingId": meeting.id?.uuidString ?? ""],
                        updatedAt: meeting.scheduledStartAt
                    )
                )
            }
        }

        // 4. People / Members
        if searchTypes.contains(.member) {
            let memberQuery = OrganizationMemberModel.query(on: req.db)
                .filter(\.$organization.$id == orgId)
                .with(\.$user)

            let members = try await memberQuery.range(0..<limit).all()
            for m in members {
                let user = m.user
                if trimmedQuery.isEmpty ||
                   user.displayName.localizedCaseInsensitiveContains(trimmedQuery) ||
                   user.email.localizedCaseInsensitiveContains(trimmedQuery) {
                    allResults.append(
                        SearchResultItemDTO(
                            id: user.id?.uuidString ?? UUID().uuidString,
                            entityType: .member,
                            title: user.displayName,
                            subtitle: "\(user.email) • \(m.role.rawValue.capitalized)",
                            deepLink: "taskflow://channels/\(user.id?.uuidString ?? "")",
                            icon: "person.crop.circle.fill",
                            badge: m.role.rawValue.capitalized,
                            metadata: [
                                "userId": user.id?.uuidString ?? "",
                                "role": m.role.rawValue
                            ],
                            updatedAt: m.joinedAt
                        )
                    )
                }
            }
        }

        let clampedResults = Array(allResults.prefix(limit))
        return APIResponse(
            data: OmnibarSearchResponse(
                results: clampedResults,
                totalCount: clampedResults.count,
                query: trimmedQuery
            )
        )
    }
}
