import Fluent
import SharedModels

enum IssueKeyService {
    static func computePrefix(from projectName: String) -> String {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "PROJ" }

        // Keep A-Z / 0-9 only, collapse others.
        let upper = trimmed.uppercased()
        let allowed = upper.filter { $0.isLetter || $0.isNumber }
        let prefix = String(allowed.prefix(5))
        return prefix.isEmpty ? "PROJ" : prefix
    }

    /// Returns the next project-scoped issue key (e.g. "APP-42") and advances the counter atomically.
    static func nextIssueKey(project: ProjectModel, db: any Database) async throws -> String {
        let projectId = try project.requireID()

        let desiredPrefix = project.issueKeyPrefix ?? computePrefix(from: project.name)
        if project.issueKeyPrefix != desiredPrefix {
            project.issueKeyPrefix = desiredPrefix
            try await project.save(on: db)
        }

        if let counter = try await IssueKeyCounterModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .first()
        {
            let n = max(counter.nextNumber, 1)
            counter.nextNumber = n + 1
            try await counter.save(on: db)
            return "\(desiredPrefix)-\(n)"
        } else {
            let counter = IssueKeyCounterModel(projectId: projectId, nextNumber: 2)
            try await counter.save(on: db)
            return "\(desiredPrefix)-1"
        }
    }
}

