import Fluent
import Vapor
import SharedModels

/// Fluent database model for Project Daily Stats.
final class ProjectDailyStatsModel: Model, Content, @unchecked Sendable {
    static let schema = "project_daily_stats"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: ProjectModel

    @Field(key: "date")
    var date: Date

    @Field(key: "remaining_points")
    var remainingPoints: Double

    @Field(key: "completed_points")
    var completedPoints: Double

    @Field(key: "completed_tasks")
    var completedTasks: Int

    @Field(key: "created_tasks")
    var createdTasks: Int

    init() {}

    init(id: UUID? = nil, projectId: UUID, date: Date, remainingPoints: Double = 0.0, completedPoints: Double = 0.0, completedTasks: Int = 0, createdTasks: Int = 0) {
        self.id = id
        self.$project.id = projectId
        self.date = date
        self.remainingPoints = remainingPoints
        self.completedPoints = completedPoints
        self.completedTasks = completedTasks
        self.createdTasks = createdTasks
    }

    func toDTO() -> ProjectDailyStatsDTO {
        ProjectDailyStatsDTO(
            id: id ?? UUID(),
            projectId: $project.id,
            date: date,
            remainingPoints: remainingPoints,
            completedPoints: completedPoints,
            completedTasks: completedTasks,
            createdTasks: createdTasks
        )
    }
}
