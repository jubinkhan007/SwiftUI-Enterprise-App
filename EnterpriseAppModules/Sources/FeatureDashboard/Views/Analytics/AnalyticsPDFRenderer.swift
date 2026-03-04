import Foundation
import SharedModels

#if canImport(UIKit)
import UIKit

enum AnalyticsPDFRenderer {
    static func render(report: AnalyticsReportPayloadDTO) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()

            let margin: CGFloat = 44
            var y: CGFloat = margin

            func draw(_ text: String, font: UIFont, color: UIColor = .label) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let attributed = NSAttributedString(string: text, attributes: attrs)
                let maxRect = CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: pageRect.height - margin - y)
                let size = attributed.boundingRect(with: maxRect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
                attributed.draw(in: CGRect(x: margin, y: y, width: maxRect.width, height: ceil(size.height)))
                y += ceil(size.height) + 8
            }

            func fmtDate(_ d: Date) -> String {
                d.formatted(date: .abbreviated, time: .omitted)
            }

            draw("Analytics Report", font: .systemFont(ofSize: 22, weight: .bold))
            draw(report.projectName, font: .systemFont(ofSize: 15, weight: .semibold), color: .secondaryLabel)
            draw("Range: \(fmtDate(report.from)) – \(fmtDate(report.to))", font: .systemFont(ofSize: 12, weight: .regular), color: .secondaryLabel)
            draw("Generated: \(report.generatedAt.formatted(date: .abbreviated, time: .shortened))", font: .systemFont(ofSize: 12, weight: .regular), color: .secondaryLabel)

            y += 6

            draw("Key Metrics", font: .systemFont(ofSize: 16, weight: .bold))

            func metricLine(_ title: String, value: String) {
                draw("\(title): \(value)", font: .systemFont(ofSize: 12, weight: .regular))
            }

            if let lead = report.leadTime {
                metricLine("Lead Time (avg)", value: String(format: "%.1f days (n=%d)", lead.value / 86400.0, lead.sampleSize))
            }
            if let cycle = report.cycleTime {
                metricLine("Cycle Time (avg)", value: String(format: "%.1f days (n=%d)", cycle.value / 86400.0, cycle.sampleSize))
            }
            if let v = report.velocity {
                metricLine("Velocity", value: String(format: "%.0f pts", v.value))
            }
            if let t = report.throughput {
                metricLine("Throughput", value: "\(t.value) tasks")
            }

            y += 10

            draw("Weekly Throughput", font: .systemFont(ofSize: 16, weight: .bold))
            if report.weeklyThroughput.isEmpty {
                draw("No data.", font: .systemFont(ofSize: 12, weight: .regular), color: .secondaryLabel)
            } else {
                for p in report.weeklyThroughput.prefix(12) {
                    draw("\(fmtDate(p.weekStart)): \(p.completedTasks) tasks", font: .systemFont(ofSize: 12, weight: .regular))
                }
            }

            y += 10

            draw("Sprint Velocity", font: .systemFont(ofSize: 16, weight: .bold))
            if report.sprintVelocity.isEmpty {
                draw("No sprints found.", font: .systemFont(ofSize: 12, weight: .regular), color: .secondaryLabel)
            } else {
                for s in report.sprintVelocity.prefix(10) {
                    draw("\(s.name): \(String(format: "%.0f", s.completedPoints)) pts (\(s.completedTasks) tasks)", font: .systemFont(ofSize: 12, weight: .regular))
                }
            }

            // If we overflow the page, start a new one for burndown.
            if y > pageRect.height - margin - 140 {
                ctx.beginPage()
                y = margin
            }

            y += 10
            draw("Burndown (Remaining Points)", font: .systemFont(ofSize: 16, weight: .bold))
            if report.burndown.isEmpty {
                draw("No data.", font: .systemFont(ofSize: 12, weight: .regular), color: .secondaryLabel)
            } else {
                for row in report.burndown.suffix(14) {
                    draw("\(fmtDate(row.date)): \(String(format: "%.1f", row.remainingPoints)) pts remaining", font: .systemFont(ofSize: 12, weight: .regular))
                }
            }
        }
    }
}
#else
enum AnalyticsPDFRenderer {
    static func render(report: AnalyticsReportPayloadDTO) -> Data { Data() }
}
#endif

