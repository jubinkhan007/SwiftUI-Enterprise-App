import Foundation

/// Response payload for the Timeline view.
/// Contains all tasks in the range and their inter-dependencies.
public struct TimelineResponseDTO: Codable, Sendable {
    public let tasks: [TaskItemDTO]
    public let relations: [TaskRelationDTO]
    
    public init(tasks: [TaskItemDTO], relations: [TaskRelationDTO]) {
        self.tasks = tasks
        self.relations = relations
    }
}
