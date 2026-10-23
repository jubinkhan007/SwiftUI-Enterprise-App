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

        let existingCounter = try await IssueKeyCounterModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .first()

        let baseNumber: Int
        let counter: IssueKeyCounterModel
        if let existing = existingCounter {
            counter = existing
            baseNumber = max(counter.nextNumber, 1)
        } else {
            // Find highest existing issue key number for this project if tasks already exist
            let tasks = try await TaskItemModel.query(on: db)
                .filter(\.$project.$id == projectId)
                .all()
            var maxExisting = 0
            for t in tasks {
                if let key = t.issueKey, let numStr = key.split(separator: "-").last, let num = Int(numStr) {
                    if num > maxExisting {
                        maxExisting = num
                    }
                }
            }
            baseNumber = maxExisting + 1
            counter = IssueKeyCounterModel(projectId: projectId, nextNumber: baseNumber)
        }

        var candidate = baseNumber
        // Ensure no collision if seed or manual insertion bypassed counter
        while true {
            let key = "\(desiredPrefix)-\(candidate)"
            let exists = try await TaskItemModel.query(on: db)
                .filter(\.$project.$id == projectId)
                .filter(\.$issueKey == key)
                .first() != nil
            if !exists {
                counter.nextNumber = candidate + 1
                try await counter.save(on: db)
                return key
            }
            candidate += 1
        }
    }
}

