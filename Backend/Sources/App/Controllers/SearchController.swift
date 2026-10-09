import Fluent
import SharedModels
import Vapor

struct SearchController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let search = routes.grouped("search")
        search.get(use: getSearch)
        search.post(use: postSearch)
        search.post("reindex", use: postReindex)
    }

    // MARK: - Handlers

    @Sendable
    func getSearch(req: Request) async throws -> APIResponse<OmnibarSearchResponse> {
        let query = req.query[String.self, at: "q"] ?? ""
        let typesStr = req.query[String.self, at: "types"]
        let limit = req.query[Int.self, at: "limit"] ?? 20
        let modeStr = req.query[String.self, at: "mode"]
        let mode = modeStr.flatMap { SearchMode(rawValue: $0) } ?? .hybrid
        let threshold = req.query[Double.self, at: "threshold"]

        let types: [SearchEntityType]? = typesStr?.split(separator: ",").compactMap {
            SearchEntityType(rawValue: String($0).trimmingCharacters(in: .whitespaces))
        }

        return try await executeSearch(
            req: req,
            query: query,
            types: types,
            limit: limit,
            mode: mode,
            threshold: threshold
        )
    }

    @Sendable
    func postSearch(req: Request) async throws -> APIResponse<OmnibarSearchResponse> {
        let requestBody = try req.content.decode(OmnibarSearchRequest.self)
        return try await executeSearch(
            req: req,
            query: requestBody.query,
            types: requestBody.types,
            limit: requestBody.limit ?? 20,
            mode: requestBody.mode ?? .hybrid,
            threshold: requestBody.threshold
        )
    }

    @Sendable
    func postReindex(req: Request) async throws -> APIResponse<[String: Int]> {
        let orgId = try req.orgContext.orgId
        let count = try await indexOrganizationEntities(req: req, orgId: orgId, force: true)
        return APIResponse(data: ["indexedCount": count])
    }

    // MARK: - Search Execution

    private func executeSearch(
        req: Request,
        query: String,
        types: [SearchEntityType]?,
        limit: Int,
        mode: SearchMode = .hybrid,
        threshold: Double? = nil
    ) async throws -> APIResponse<OmnibarSearchResponse> {
        let orgId = try req.orgContext.orgId
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTypes = types?.isEmpty == false ? types! : SearchEntityType.allCases
        let effectiveThreshold = threshold ?? (mode == .semantic ? 0.22 : 0.25)

        // Empty query returns recent items
        if trimmedQuery.isEmpty {
            let recentResults = try await fetchRecentItems(req: req, orgId: orgId, types: searchTypes, limit: limit)
            return APIResponse(
                data: OmnibarSearchResponse(
                    results: recentResults,
                    totalCount: recentResults.count,
                    query: "",
                    mode: mode
                )
            )
        }

        // 1. Keyword-only mode bypasses vector embeddings
        if mode == .keyword {
            let keywordResults = try await executeKeywordSearch(
                req: req,
                orgId: orgId,
                query: trimmedQuery,
                types: searchTypes,
                limit: limit
            )
            return APIResponse(
                data: OmnibarSearchResponse(
                    results: keywordResults,
                    totalCount: keywordResults.count,
                    query: trimmedQuery,
                    mode: mode
                )
            )
        }

        // 2. Semantic & Hybrid Search
        // Ensure entity vector embeddings are indexed
        _ = try? await indexOrganizationEntities(req: req, orgId: orgId, force: false)

        let queryVector = EmbeddingService.shared.embed(trimmedQuery)

        // Load stored embeddings for this organization
        let embeddingQuery = VectorEmbeddingModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
        let embeddings = try await embeddingQuery.all()

        // Track semantic scores: [entityId: (similarity, contentPreview, entityType)]
        var semanticScores: [UUID: (similarity: Double, preview: String, type: SearchEntityType)] = [:]
        for emb in embeddings {
            guard let entityType = SearchEntityType(rawValue: emb.entityType),
                  searchTypes.contains(entityType),
                  let vec = EmbeddingService.shared.deserializeVector(emb.embeddingJson) else {
                continue
            }

            let sim = EmbeddingService.shared.cosineSimilarity(queryVector, vec)
            if sim >= effectiveThreshold {
                semanticScores[emb.entityId] = (sim, emb.contentPreview, entityType)
            }
        }

        // Execute keyword ILIKE search for exact lexical matches
        let keywordItems = try await executeKeywordSearch(
            req: req,
            orgId: orgId,
            query: trimmedQuery,
            types: searchTypes,
            limit: limit * 2
        )
        let keywordItemMap = Dictionary(uniqueKeysWithValues: keywordItems.compactMap { item -> (UUID, SearchResultItemDTO)? in
            guard let uid = UUID(uuidString: item.id) else { return nil }
            return (uid, item)
        })

        // Merge Candidates
        var combinedResults: [SearchResultItemDTO] = []
        var processedIds = Set<UUID>()

        // Process Semantic Matches
        for (entityId, matchData) in semanticScores {
            processedIds.insert(entityId)
            let isKeywordMatch = keywordItemMap[entityId] != nil
            let similarity = matchData.similarity

            let score: Double
            let matchType: String
            let badgeText: String

            if isKeywordMatch {
                score = min(1.0, 0.40 * 1.0 + 0.60 * similarity)
                matchType = "hybrid"
                badgeText = "✨ \(Int(score * 100))% Match"
            } else {
                score = similarity
                matchType = "semantic"
                badgeText = "✨ \(Int(similarity * 100))% Match"
            }

            if let item = keywordItemMap[entityId] {
                combinedResults.append(
                    SearchResultItemDTO(
                        id: item.id,
                        entityType: item.entityType,
                        title: item.title,
                        subtitle: item.subtitle,
                        deepLink: item.deepLink,
                        icon: item.icon,
                        badge: badgeText,
                        metadata: item.metadata,
                        similarityScore: score,
                        matchType: matchType,
                        highlightSnippet: matchData.preview,
                        updatedAt: item.updatedAt
                    )
                )
            } else {
                // Fetch entity by ID since it matched semantically without exact keyword
                if let entityItem = try await fetchEntityItem(
                    req: req,
                    orgId: orgId,
                    type: matchData.type,
                    id: entityId,
                    score: score,
                    matchType: matchType,
                    badge: badgeText,
                    preview: matchData.preview
                ) {
                    combinedResults.append(entityItem)
                }
            }
        }

        // Process pure keyword matches (if in Hybrid mode)
        if mode == .hybrid {
            for item in keywordItems {
                guard let uid = UUID(uuidString: item.id), !processedIds.contains(uid) else { continue }
                processedIds.insert(uid)
                combinedResults.append(
                    SearchResultItemDTO(
                        id: item.id,
                        entityType: item.entityType,
                        title: item.title,
                        subtitle: item.subtitle,
                        deepLink: item.deepLink,
                        icon: item.icon,
                        badge: "Exact Match",
                        metadata: item.metadata,
                        similarityScore: 0.50,
                        matchType: "exact",
                        highlightSnippet: nil,
                        updatedAt: item.updatedAt
                    )
                )
            }
        }

        // Sort descending by similarityScore
        combinedResults.sort { ($0.similarityScore ?? 0.0) > ($1.similarityScore ?? 0.0) }

        let clamped = Array(combinedResults.prefix(limit))
        return APIResponse(
            data: OmnibarSearchResponse(
                results: clamped,
                totalCount: clamped.count,
                query: trimmedQuery,
                mode: mode
            )
        )
    }

    // MARK: - Keyword ILIKE Search

    private func executeKeywordSearch(
        req: Request,
        orgId: UUID,
        query: String,
        types: [SearchEntityType],
        limit: Int
    ) async throws -> [SearchResultItemDTO] {
        var results: [SearchResultItemDTO] = []

        // 1. Tasks
        if types.contains(.task) {
            let taskQuery = TaskItemModel.query(on: req.db)
                .filter(\.$organization.$id == orgId)
                .filter(\.$archivedAt == nil)

            if !query.isEmpty {
                taskQuery.group(.or) { group in
                    group.filter(\.$title, .custom("ILIKE"), "%\(query)%")
                    group.filter(\.$description, .custom("ILIKE"), "%\(query)%")
                    group.filter(\.$issueKey, .custom("ILIKE"), "%\(query)%")
                }
            }

            let tasks = try await taskQuery.range(0..<limit).all()
            for task in tasks {
                let keyPrefix = task.issueKey.map { "\($0) • " } ?? ""
                let subtitle = "\(keyPrefix)\(task.status.rawValue.capitalized) • Priority: \(task.priority.rawValue.capitalized)"
                results.append(
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
                        similarityScore: 1.0,
                        matchType: "exact",
                        highlightSnippet: task.description,
                        updatedAt: task.updatedAt
                    )
                )
            }
        }

        // 2. Messages
        if types.contains(.message) && !query.isEmpty {
            let messages = try await MessageModel.query(on: req.db)
                .join(ConversationModel.self, on: \MessageModel.$conversation.$id == \ConversationModel.$id)
                .filter(ConversationModel.self, \.$organization.$id == orgId)
                .filter(\.$body, .custom("ILIKE"), "%\(query)%")
                .range(0..<limit)
                .all()

            for msg in messages {
                let snippet = msg.body.count > 60 ? String(msg.body.prefix(60)) + "..." : msg.body
                results.append(
                    SearchResultItemDTO(
                        id: msg.id?.uuidString ?? UUID().uuidString,
                        entityType: .message,
                        title: "Chat Message",
                        subtitle: snippet,
                        deepLink: "taskflow://channels/\(msg.$conversation.id.uuidString)",
                        icon: "bubble.left.and.bubble.right.fill",
                        badge: "Chat",
                        metadata: ["conversationId": msg.$conversation.id.uuidString],
                        similarityScore: 1.0,
                        matchType: "exact",
                        highlightSnippet: msg.body,
                        updatedAt: msg.createdAt
                    )
                )
            }
        }

        // 3. Meetings
        if types.contains(.meeting) {
            let meetingQuery = MeetingModel.query(on: req.db)
                .filter(\.$organization.$id == orgId)

            if !query.isEmpty {
                meetingQuery.filter(\.$title, .custom("ILIKE"), "%\(query)%")
            }

            let meetings = try await meetingQuery.range(0..<limit).all()
            for meeting in meetings {
                results.append(
                    SearchResultItemDTO(
                        id: meeting.id?.uuidString ?? UUID().uuidString,
                        entityType: .meeting,
                        title: meeting.title,
                        subtitle: "Status: \(meeting.status.capitalized)",
                        deepLink: "taskflow://meetings/\(meeting.id?.uuidString ?? "")",
                        icon: "video.fill",
                        badge: meeting.status.capitalized,
                        metadata: ["meetingId": meeting.id?.uuidString ?? ""],
                        similarityScore: 1.0,
                        matchType: "exact",
                        highlightSnippet: meeting.title,
                        updatedAt: meeting.scheduledStartAt
                    )
                )
            }
        }

        // 4. People / Members
        if types.contains(.member) {
            let memberQuery = OrganizationMemberModel.query(on: req.db)
                .filter(\.$organization.$id == orgId)
                .with(\.$user)

            let members = try await memberQuery.range(0..<limit).all()
            for m in members {
                let user = m.user
                if query.isEmpty ||
                   user.displayName.localizedCaseInsensitiveContains(query) ||
                   user.email.localizedCaseInsensitiveContains(query) {
                    results.append(
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
                            similarityScore: 1.0,
                            matchType: "exact",
                            highlightSnippet: "\(user.displayName) (\(user.email))",
                            updatedAt: m.joinedAt
                        )
                    )
                }
            }
        }

        return results
    }

    // MARK: - Fetch Recent Items

    private func fetchRecentItems(
        req: Request,
        orgId: UUID,
        types: [SearchEntityType],
        limit: Int
    ) async throws -> [SearchResultItemDTO] {
        return try await executeKeywordSearch(
            req: req,
            orgId: orgId,
            query: "",
            types: types,
            limit: limit
        )
    }

    // MARK: - Entity Lookup For Semantic Retrieval

    private func fetchEntityItem(
        req: Request,
        orgId: UUID,
        type: SearchEntityType,
        id: UUID,
        score: Double,
        matchType: String,
        badge: String,
        preview: String
    ) async throws -> SearchResultItemDTO? {
        switch type {
        case .task:
            guard let task = try await TaskItemModel.find(id, on: req.db),
                  task.$organization.id == orgId,
                  task.archivedAt == nil else {
                return nil
            }
            let keyPrefix = task.issueKey.map { "\($0) • " } ?? ""
            let subtitle = "\(keyPrefix)\(task.status.rawValue.capitalized) • Priority: \(task.priority.rawValue.capitalized)"
            return SearchResultItemDTO(
                id: task.id?.uuidString ?? id.uuidString,
                entityType: .task,
                title: task.title,
                subtitle: subtitle,
                deepLink: "taskflow://tasks/\(task.id?.uuidString ?? id.uuidString)",
                icon: "checkmark.square.fill",
                badge: badge,
                metadata: [
                    "status": task.status.rawValue,
                    "priority": task.priority.rawValue,
                    "taskKey": task.issueKey ?? ""
                ],
                similarityScore: score,
                matchType: matchType,
                highlightSnippet: preview,
                updatedAt: task.updatedAt
            )

        case .message:
            guard let msg = try await MessageModel.find(id, on: req.db) else { return nil }
            return SearchResultItemDTO(
                id: msg.id?.uuidString ?? id.uuidString,
                entityType: .message,
                title: "Chat Message",
                subtitle: preview,
                deepLink: "taskflow://channels/\(msg.$conversation.id.uuidString)",
                icon: "bubble.left.and.bubble.right.fill",
                badge: badge,
                metadata: ["conversationId": msg.$conversation.id.uuidString],
                similarityScore: score,
                matchType: matchType,
                highlightSnippet: preview,
                updatedAt: msg.createdAt
            )

        case .meeting:
            guard let meeting = try await MeetingModel.find(id, on: req.db),
                  meeting.$organization.id == orgId else {
                return nil
            }
            return SearchResultItemDTO(
                id: meeting.id?.uuidString ?? id.uuidString,
                entityType: .meeting,
                title: meeting.title,
                subtitle: "Status: \(meeting.status.capitalized)",
                deepLink: "taskflow://meetings/\(meeting.id?.uuidString ?? id.uuidString)",
                icon: "video.fill",
                badge: badge,
                metadata: ["meetingId": meeting.id?.uuidString ?? id.uuidString],
                similarityScore: score,
                matchType: matchType,
                highlightSnippet: preview,
                updatedAt: meeting.scheduledStartAt
            )

        case .member:
            guard let m = try await OrganizationMemberModel.find(id, on: req.db),
                  m.$organization.id == orgId else {
                return nil
            }
            try await m.$user.load(on: req.db)
            let user = m.user
            return SearchResultItemDTO(
                id: user.id?.uuidString ?? id.uuidString,
                entityType: .member,
                title: user.displayName,
                subtitle: "\(user.email) • \(m.role.rawValue.capitalized)",
                deepLink: "taskflow://channels/\(user.id?.uuidString ?? id.uuidString)",
                icon: "person.crop.circle.fill",
                badge: badge,
                metadata: [
                    "userId": user.id?.uuidString ?? id.uuidString,
                    "role": m.role.rawValue
                ],
                similarityScore: score,
                matchType: matchType,
                highlightSnippet: preview,
                updatedAt: m.joinedAt
            )

        case .doc:
            return nil
        }
    }

    // MARK: - Auto-Indexing & Vector Management

    private func indexOrganizationEntities(req: Request, orgId: UUID, force: Bool) async throws -> Int {
        var count = 0

        // Fetch existing indexed hashes
        let existingRecords = try await VectorEmbeddingModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .all()
        var existingHashMap = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.entityId, $0) })

        // 1. Index Tasks
        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .filter(\.$archivedAt == nil)
            .all()

        for task in tasks {
            guard let taskId = task.id else { continue }
            let text = "\(task.issueKey ?? "") \(task.title). \(task.description ?? "") Status: \(task.status.rawValue), Priority: \(task.priority.rawValue)"
            let hash = EmbeddingService.shared.contentHash(text)

            if force || existingHashMap[taskId]?.textHash != hash {
                let vec = EmbeddingService.shared.embed(text)
                let vecJson = EmbeddingService.shared.serializeVector(vec)
                let preview = task.description?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120) ?? ""

                if let existing = existingHashMap[taskId] {
                    existing.textHash = hash
                    existing.embeddingJson = vecJson
                    existing.contentPreview = String(preview)
                    try await existing.save(on: req.db)
                } else {
                    let newEmb = VectorEmbeddingModel(
                        organizationId: orgId,
                        entityType: SearchEntityType.task.rawValue,
                        entityId: taskId,
                        textHash: hash,
                        embeddingJson: vecJson,
                        contentPreview: String(preview)
                    )
                    try await newEmb.save(on: req.db)
                    existingHashMap[taskId] = newEmb
                }
                count += 1
            }
        }

        // 2. Index Messages
        let messages = try await MessageModel.query(on: req.db)
            .join(ConversationModel.self, on: \MessageModel.$conversation.$id == \ConversationModel.$id)
            .filter(ConversationModel.self, \.$organization.$id == orgId)
            .range(0..<500)
            .all()

        for msg in messages {
            guard let msgId = msg.id else { continue }
            let text = msg.body
            let hash = EmbeddingService.shared.contentHash(text)

            if force || existingHashMap[msgId]?.textHash != hash {
                let vec = EmbeddingService.shared.embed(text)
                let vecJson = EmbeddingService.shared.serializeVector(vec)
                let preview = text.prefix(120)

                if let existing = existingHashMap[msgId] {
                    existing.textHash = hash
                    existing.embeddingJson = vecJson
                    existing.contentPreview = String(preview)
                    try await existing.save(on: req.db)
                } else {
                    let newEmb = VectorEmbeddingModel(
                        organizationId: orgId,
                        entityType: SearchEntityType.message.rawValue,
                        entityId: msgId,
                        textHash: hash,
                        embeddingJson: vecJson,
                        contentPreview: String(preview)
                    )
                    try await newEmb.save(on: req.db)
                    existingHashMap[msgId] = newEmb
                }
                count += 1
            }
        }

        // 3. Index Meetings
        let meetings = try await MeetingModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .all()

        for meeting in meetings {
            guard let meetingId = meeting.id else { continue }
            let text = "Meeting: \(meeting.title), status \(meeting.status)"
            let hash = EmbeddingService.shared.contentHash(text)

            if force || existingHashMap[meetingId]?.textHash != hash {
                let vec = EmbeddingService.shared.embed(text)
                let vecJson = EmbeddingService.shared.serializeVector(vec)

                if let existing = existingHashMap[meetingId] {
                    existing.textHash = hash
                    existing.embeddingJson = vecJson
                    existing.contentPreview = meeting.title
                    try await existing.save(on: req.db)
                } else {
                    let newEmb = VectorEmbeddingModel(
                        organizationId: orgId,
                        entityType: SearchEntityType.meeting.rawValue,
                        entityId: meetingId,
                        textHash: hash,
                        embeddingJson: vecJson,
                        contentPreview: meeting.title
                    )
                    try await newEmb.save(on: req.db)
                    existingHashMap[meetingId] = newEmb
                }
                count += 1
            }
        }

        // 4. Index Members
        let members = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .with(\.$user)
            .all()

        for m in members {
            guard let memberId = m.id else { continue }
            let user = m.user
            let text = "Team member: \(user.displayName) (\(user.email)), Role: \(m.role.rawValue)"
            let hash = EmbeddingService.shared.contentHash(text)

            if force || existingHashMap[memberId]?.textHash != hash {
                let vec = EmbeddingService.shared.embed(text)
                let vecJson = EmbeddingService.shared.serializeVector(vec)
                let preview = "\(user.displayName) - \(m.role.rawValue.capitalized)"

                if let existing = existingHashMap[memberId] {
                    existing.textHash = hash
                    existing.embeddingJson = vecJson
                    existing.contentPreview = preview
                    try await existing.save(on: req.db)
                } else {
                    let newEmb = VectorEmbeddingModel(
                        organizationId: orgId,
                        entityType: SearchEntityType.member.rawValue,
                        entityId: memberId,
                        textHash: hash,
                        embeddingJson: vecJson,
                        contentPreview: preview
                    )
                    try await newEmb.save(on: req.db)
                    existingHashMap[memberId] = newEmb
                }
                count += 1
            }
        }

        return count
    }
}
