import Vapor
import Fluent
import SharedModels

/// Service for exporting project analytics data.
public struct ExportService {
    
    /// Generates a CSV string for a project's burndown stats.
    public static func generateBurndownCSV(projectId: UUID, db: Database) async throws -> String {
        let stats = try await ProjectDailyStatsModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .sort(\.$date, .ascending)
            .all()
            
        var csv = "Date,Remaining Points,Completed Points,Completed Tasks,Created Tasks\n"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for stat in stats {
            let dateStr = formatter.string(from: stat.date)
            let remaining = stat.remainingPoints
            let completed = stat.completedPoints
            let tasks = stat.completedTasks
            let created = stat.createdTasks
            
            csv += "\(dateStr),\(remaining),\(completed),\(tasks),\(created)\n"
        }
        
        return csv
    }
}
