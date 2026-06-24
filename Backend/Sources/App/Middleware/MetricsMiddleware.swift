import Foundation
import Vapor

/// Thread-safe actor that tracks rolling performance statistics of the Vapor web server.
public actor PlatformMetricsService {
    public static let shared = PlatformMetricsService()

    private var totalRequests: Int = 0
    private var errorRequests: Int = 0
    private var latencies: [Double] = []
    private var requestTimestamps: [Date] = []

    private init() {}

    /// Records a completed HTTP request's duration and status.
    public func recordRequest(duration: Double, isError: Bool) {
        totalRequests += 1
        if isError {
            errorRequests += 1
        }
        latencies.append(duration)
        if latencies.count > 100 {
            latencies.removeFirst()
        }

        let now = Date()
        requestTimestamps.append(now)
        pruneOldTimestamps(now: now)
    }

    private func pruneOldTimestamps(now: Date) {
        let cutoff = now.addingTimeInterval(-60)
        requestTimestamps.removeAll { $0 < cutoff }
    }

    /// Extracted metrics statistics.
    public struct Stats: Content {
        public let requestsPerSecond: Double
        public let averageLatencyMs: Double
        public let errorRate: Double
        public let totalRequests: Int
    }

    /// Retrieve the aggregated server performance stats.
    public func getStats() -> Stats {
        let now = Date()
        pruneOldTimestamps(now: now)

        let rps = Double(requestTimestamps.count) / 60.0
        let avgLatency = latencies.isEmpty ? 0.0 : (latencies.reduce(0.0, +) / Double(latencies.count))
        let errorRate = totalRequests == 0 ? 0.0 : Double(errorRequests) / Double(totalRequests)

        return Stats(
            requestsPerSecond: (rps * 100).rounded() / 100,
            // Convert duration from seconds to milliseconds
            averageLatencyMs: (avgLatency * 1000 * 100).rounded() / 100,
            errorRate: (errorRate * 100).rounded() / 100,
            totalRequests: totalRequests
        )
    }
}

/// Middleware that intercepts HTTP requests to track throughput, latency, and error rate metrics.
struct MetricsMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Skip tracking options requests or specific routes to keep metric signal clean if needed,
        // but tracking all requests is the standard approach.
        let startTime = Date()
        do {
            let response = try await next.respond(to: request)
            let duration = Date().timeIntervalSince(startTime)
            let isError = response.status.code >= 400
            await PlatformMetricsService.shared.recordRequest(duration: duration, isError: isError)
            return response
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            await PlatformMetricsService.shared.recordRequest(duration: duration, isError: true)
            throw error
        }
    }
}
