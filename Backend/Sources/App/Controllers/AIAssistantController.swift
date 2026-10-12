import Fluent
import SharedModels
import Vapor

struct AIAssistantController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let ai = routes.grouped("ai")
        ai.post("copilot", use: handleCopilot)
        ai.post("breakdown", use: handleBreakdown)
        ai.get("standup", use: handleStandup)
        ai.post("ask", use: handleAskKnowledgeBase)
    }

    // MARK: - Handlers

    @Sendable
    func handleCopilot(req: Request) async throws -> APIResponse<AIAssistantResponse> {
        let requestBody = try req.content.decode(AIAssistantRequest.self)
        switch requestBody.action {
        case .breakdownTask:
            return try await executeTaskBreakdown(req: req, request: requestBody)
        case .generateStandupSummary:
            return try await executeStandupSummary(req: req, request: requestBody)
        case .suggestNextActions:
            return try await executeNextActions(req: req, request: requestBody)
        case .summarizeThread:
            return try await executeThreadSummary(req: req, request: requestBody)
        case .askKnowledgeBase:
            return try await executeAskKnowledgeBase(req: req, request: requestBody)
        }
    }

    @Sendable
    func handleBreakdown(req: Request) async throws -> APIResponse<AIAssistantResponse> {
        let requestBody = try req.content.decode(AIAssistantRequest.self)
        return try await executeTaskBreakdown(req: req, request: requestBody)
    }

    @Sendable
    func handleStandup(req: Request) async throws -> APIResponse<AIAssistantResponse> {
        let requestBody = AIAssistantRequest(action: .generateStandupSummary)
        return try await executeStandupSummary(req: req, request: requestBody)
    }

    @Sendable
    func handleAskKnowledgeBase(req: Request) async throws -> APIResponse<AIAssistantResponse> {
        let requestBody = try req.content.decode(AIAssistantRequest.self)
        return try await executeAskKnowledgeBase(req: req, request: requestBody)
    }

    // MARK: - AI Action Implementations

    private func executeTaskBreakdown(
        req: Request,
        request: AIAssistantRequest
    ) async throws -> APIResponse<AIAssistantResponse> {
        var baseTitle = request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var baseDesc = ""

        if let contextIdStr = request.contextId, let taskId = UUID(uuidString: contextIdStr) {
            if let task = try await TaskItemModel.find(taskId, on: req.db) {
                if baseTitle.isEmpty { baseTitle = task.title }
                baseDesc = task.description ?? ""
            }
        }

        if baseTitle.isEmpty {
            baseTitle = request.entityPayload?["title"] ?? "Project Feature"
        }

        let subtasks = [
            SuggestedTaskDTO(
                title: "1. Technical Specification & Scope for: \(baseTitle)",
                description: "Outline architectural requirements, data contracts, and integration surfaces.",
                priority: "high",
                estimateHours: 1.5
            ),
            SuggestedTaskDTO(
                title: "2. Core Implementation of: \(baseTitle)",
                description: "Implement business logic, domain models, and API endpoints.",
                priority: "high",
                estimateHours: 4.0
            ),
            SuggestedTaskDTO(
                title: "3. UI/UX Interface & Component Wiring for: \(baseTitle)",
                description: "Build user-facing views, state binding, and responsiveness.",
                priority: "medium",
                estimateHours: 3.5
            ),
            SuggestedTaskDTO(
                title: "4. Automated Testing & Edge Cases for: \(baseTitle)",
                description: "Add comprehensive unit tests, mock error scenarios, and regression tests.",
                priority: "medium",
                estimateHours: 2.0
            ),
            SuggestedTaskDTO(
                title: "5. Documentation & Deployment Verification for: \(baseTitle)",
                description: "Update API documentation, changelog, and verify in staging.",
                priority: "low",
                estimateHours: 1.0
            )
        ]

        let summary = "Decomposed '\(baseTitle)' into 5 structured subtasks totaling 12 estimated hours."
        let actionItems = subtasks.map { $0.title }

        return APIResponse(
            data: AIAssistantResponse(
                action: .breakdownTask,
                summary: summary,
                suggestedTasks: subtasks,
                actionItems: actionItems
            )
        )
    }

    private func executeStandupSummary(
        req: Request,
        request: AIAssistantRequest
    ) async throws -> APIResponse<AIAssistantResponse> {
        let orgId = try req.orgContext.orgId
        let userId = try req.orgContext.userId

        // Fetch user's tasks
        let userTasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .filter(\.$assignee.$id == userId)
            .filter(\.$archivedAt == nil)
            .all()

        let completed = userTasks.filter { $0.status == .done }
        let inProgress = userTasks.filter { $0.status == .inProgress || $0.status == .inReview }
        let pending = userTasks.filter { $0.status == .todo }
        let highPriority = userTasks.filter { $0.priority == .critical || $0.priority == .high }

        // Fetch meetings
        let meetings = try await MeetingModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .range(0..<5)
            .all()

        var lines: [String] = []
        lines.append("### 📋 Daily Standup Summary")
        lines.append("")

        lines.append("#### ✅ What I Worked On Recently:")
        if completed.isEmpty {
            lines.append("- Focused on ongoing implementation and planning.")
        } else {
            for task in completed.prefix(4) {
                let keyStr = task.issueKey.map { "[\($0)] " } ?? ""
                lines.append("- Completed \(keyStr)\(task.title)")
            }
        }
        lines.append("")

        lines.append("#### 🚀 What I'm Working On Today:")
        if inProgress.isEmpty && pending.isEmpty {
            lines.append("- Triaging backlog items and picking up next sprint priority.")
        } else {
            for task in inProgress.prefix(3) {
                let keyStr = task.issueKey.map { "[\($0)] " } ?? ""
                lines.append("- Actively developing \(keyStr)\(task.title)")
            }
            for task in pending.prefix(2) {
                let keyStr = task.issueKey.map { "[\($0)] " } ?? ""
                lines.append("- Starting \(keyStr)\(task.title)")
            }
        }
        lines.append("")

        lines.append("#### ⚠️ Blockers & Risks:")
        let blockers = highPriority.filter { $0.status != .done }
        if blockers.isEmpty {
            lines.append("- No critical blockers. Proceeding as planned.")
        } else {
            for task in blockers.prefix(2) {
                lines.append("- High priority attention needed on: \(task.title)")
            }
        }
        lines.append("")

        if !meetings.isEmpty {
            lines.append("#### 📅 Scheduled Today:")
            for m in meetings.prefix(3) {
                lines.append("- \(m.title)")
            }
        }

        let fullMarkdown = lines.joined(separator: "\n")
        let actionItems = inProgress.map { $0.title }

        return APIResponse(
            data: AIAssistantResponse(
                action: .generateStandupSummary,
                summary: fullMarkdown,
                suggestedTasks: nil,
                actionItems: actionItems
            )
        )
    }

    private func executeNextActions(
        req: Request,
        request: AIAssistantRequest
    ) async throws -> APIResponse<AIAssistantResponse> {
        let orgId = try req.orgContext.orgId

        let urgentTasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .filter(\.$priority == .critical)
            .filter(\.$status != .done)
            .filter(\.$archivedAt == nil)
            .range(0..<5)
            .all()

        let suggestions = urgentTasks.map { task in
            SuggestedTaskDTO(
                title: "Resolve Urgent Issue: \(task.title)",
                description: "Priority resolution for blocking item.",
                priority: "urgent",
                estimateHours: 2.0
            )
        }

        return APIResponse(
            data: AIAssistantResponse(
                action: .suggestNextActions,
                summary: "Identified \(suggestions.count) urgent priority tasks that need immediate attention.",
                suggestedTasks: suggestions,
                actionItems: suggestions.map { $0.title }
            )
        )
    }

    private func executeThreadSummary(
        req: Request,
        request: AIAssistantRequest
    ) async throws -> APIResponse<AIAssistantResponse> {
        let summary = "Thread highlights: Key technical decisions aligned, architecture confirmed, and milestones scheduled for rollout."
        return APIResponse(
            data: AIAssistantResponse(
                action: .summarizeThread,
                summary: summary,
                suggestedTasks: nil,
                actionItems: ["Proceed with planned release checklist", "Review automated test reports"]
            )
        )
    }

    private func executeAskKnowledgeBase(
        req: Request,
        request: AIAssistantRequest
    ) async throws -> APIResponse<AIAssistantResponse> {
        let orgId = try req.orgContext.orgId
        let query = request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !query.isEmpty else {
            return APIResponse(
                data: AIAssistantResponse(
                    action: .askKnowledgeBase,
                    summary: "Please provide a question or topic so I can search your workspace knowledge base (tasks, messages, and meetings).",
                    suggestedTasks: nil,
                    actionItems: ["Ask about recent tasks", "Ask about meeting discussions", "Ask about blocker issues"],
                    citations: [],
                    suggestedFollowUps: [
                        "What tasks are currently in progress?",
                        "Summarize recent architecture discussions",
                        "Are there any open blockers on the sprint board?"
                    ]
                )
            )
        }

        // Auto-index unindexed items
        _ = try? await SearchController.indexOrganizationEntities(req: req, orgId: orgId, force: false)

        let queryVector = EmbeddingService.shared.embed(query)
        let searchTypes = request.entityTypes ?? [.task, .message, .meeting]
        let maxSources = min(max(request.maxSources ?? 4, 1), 8)

        // Query stored vector embeddings for this organization
        let allEmbeddings = try await VectorEmbeddingModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .all()

        struct ScoredCandidate {
            let embedding: VectorEmbeddingModel
            let entityType: SearchEntityType
            let similarity: Double
        }

        var scoredCandidates: [ScoredCandidate] = []
        for emb in allEmbeddings {
            guard let entityType = SearchEntityType(rawValue: emb.entityType),
                  searchTypes.contains(entityType),
                  let vec = EmbeddingService.shared.deserializeVector(emb.embeddingJson) else {
                continue
            }
            let sim = EmbeddingService.shared.cosineSimilarity(queryVector, vec)
            // Relevant semantic score threshold
            if sim >= 0.20 {
                scoredCandidates.append(ScoredCandidate(embedding: emb, entityType: entityType, similarity: sim))
            }
        }

        scoredCandidates.sort { $0.similarity > $1.similarity }
        let topCandidates = Array(scoredCandidates.prefix(maxSources))

        if topCandidates.isEmpty {
            return APIResponse(
                data: AIAssistantResponse(
                    action: .askKnowledgeBase,
                    summary: "I couldn't find any documents, tasks, or discussions matching \"\(query)\" in your workspace knowledge base. Try refining your question with different keywords or check if the relevant items are indexed.",
                    suggestedTasks: nil,
                    actionItems: ["Search tasks using keyword search", "Check sprint backlog", "Verify workspace indexing"],
                    citations: [],
                    suggestedFollowUps: [
                        "Search all active tasks",
                        "Show recent team chat messages",
                        "Review upcoming meetings"
                    ]
                )
            )
        }

        var citations: [RAGCitationDTO] = []
        var sourcePoints: [String] = []

        for (idx, candidate) in topCandidates.enumerated() {
            let num = idx + 1
            let emb = candidate.embedding
            let entityId = emb.entityId

            var title = ""
            var snippet = emb.contentPreview
            var deepLink = ""

            switch candidate.entityType {
            case .task:
                if let task = try await TaskItemModel.find(entityId, on: req.db) {
                    title = task.title
                    let desc = task.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !desc.isEmpty {
                        snippet = desc.prefix(200).description
                    }
                    deepLink = "taskflow://tasks/\(task.id?.uuidString ?? entityId.uuidString)"
                } else {
                    title = "Task #\(entityId.uuidString.prefix(6))"
                    deepLink = "taskflow://tasks/\(entityId.uuidString)"
                }
            case .message:
                if let msg = try await MessageModel.find(entityId, on: req.db) {
                    title = "Chat Discussion"
                    snippet = msg.body.prefix(200).description
                    deepLink = "taskflow://channels/\(msg.$conversation.id.uuidString)"
                } else {
                    title = "Message"
                    deepLink = "taskflow://channels/\(entityId.uuidString)"
                }
            case .meeting:
                if let meeting = try await MeetingModel.find(entityId, on: req.db) {
                    title = meeting.title
                    let notes = meeting.description ?? meeting.agenda ?? emb.contentPreview
                    snippet = notes.prefix(200).description
                    deepLink = "taskflow://meetings/\(meeting.id?.uuidString ?? entityId.uuidString)"
                } else {
                    title = "Meeting"
                    deepLink = "taskflow://meetings/\(entityId.uuidString)"
                }
            case .member:
                if let member = try await OrganizationMemberModel.find(entityId, on: req.db) {
                    try? await member.$user.load(on: req.db)
                    title = member.user.displayName
                    snippet = "\(member.user.email) • Role: \(member.role.rawValue)"
                    deepLink = "taskflow://channels/\(member.user.id?.uuidString ?? entityId.uuidString)"
                } else {
                    title = "Team Member"
                    deepLink = "taskflow://team/\(entityId.uuidString)"
                }
            case .doc:
                title = "Documentation Document"
                deepLink = "taskflow://docs/\(entityId.uuidString)"
            }

            if title.isEmpty {
                title = "\(candidate.entityType.rawValue.capitalized) Item"
            }

            let citation = RAGCitationDTO(
                id: entityId.uuidString,
                entityType: candidate.entityType,
                title: title,
                snippet: snippet,
                deepLink: deepLink,
                similarityScore: Double(round(100 * candidate.similarity) / 100),
                citationNumber: num
            )
            citations.append(citation)
            sourcePoints.append("[\(num)] **\(title)**: \(snippet)")
        }

        let joinedSources = sourcePoints.joined(separator: "\n\n")
        let citationsList = citations.map { "[\($0.citationNumber)]" }.joined(separator: ", ")

        let summary = """
        Based on your workspace knowledge base, here is what I found regarding **"\(query)"**:

        \(joinedSources)

        **Summary & Key Takeaway:**
        The retrieved sources \(citationsList) provide direct context addressing your question. You can click any cited reference to open the corresponding item in TaskFlow.
        """

        var followUps: [String] = []
        if let first = citations.first {
            followUps.append("Open \(first.title) in detail")
        }
        if citations.contains(where: { $0.entityType == .task }) {
            followUps.append("What are the next action items for these tasks?")
        }
        followUps.append("Summarize blockers related to this topic")

        let actionItems = citations.prefix(3).map { "Review [\($0.citationNumber)] \($0.title)" }

        return APIResponse(
            data: AIAssistantResponse(
                action: .askKnowledgeBase,
                summary: summary,
                suggestedTasks: nil,
                actionItems: actionItems,
                citations: citations,
                suggestedFollowUps: followUps
            )
        )
    }
}
