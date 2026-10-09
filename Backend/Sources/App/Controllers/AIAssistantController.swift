import Fluent
import SharedModels
import Vapor

struct AIAssistantController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let ai = routes.grouped("ai")
        ai.post("copilot", use: handleCopilot)
        ai.post("breakdown", use: handleBreakdown)
        ai.get("standup", use: handleStandup)
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
}
