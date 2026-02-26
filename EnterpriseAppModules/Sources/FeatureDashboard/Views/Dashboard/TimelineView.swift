import SwiftUI
import SharedModels
import DesignSystem

struct TimelineView: View {
    @ObservedObject var viewModel: DashboardViewModel

    private let calendar = Calendar.current
    private let dayWidth: CGFloat = 80
    private let rowHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            TimelineHeader(startDate: viewModel.startDate, endDate: viewModel.endDate, dayWidth: dayWidth)

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    // Task Labels
                    VStack(spacing: 0) {
                        ForEach(viewModel.tasks) { task in
                            Text(task.title)
                                .appFont(AppTypography.caption1)
                                .frame(height: rowHeight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 8)
                                .background(AppColors.surfacePrimary)
                                .border(AppColors.borderDefault.opacity(0.3), width: 0.5)
                        }
                    }
                    .frame(width: 150)
                    .zIndex(1)

                    // Timeline Grid + Bars + Dependency Lines
                    ScrollView(.horizontal, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            TimelineGrid(
                                startDate: viewModel.startDate,
                                endDate: viewModel.endDate,
                                dayWidth: dayWidth,
                                rowHeight: rowHeight,
                                rows: viewModel.tasks.count
                            )

                            VStack(spacing: 0) {
                                ForEach(viewModel.tasks) { task in
                                    TimelineTaskBar(
                                        task: task,
                                        timelineStart: viewModel.startDate,
                                        dayWidth: dayWidth
                                    )
                                    .frame(height: rowHeight)
                                }
                            }

                            // Dependency lines drawn on top of bars, non-interactive
                            if let relations = viewModel.timelineResponse?.relations, !relations.isEmpty {
                                TimelineDependencyLines(
                                    tasks: viewModel.tasks,
                                    relations: relations,
                                    timelineStart: viewModel.startDate,
                                    dayWidth: dayWidth,
                                    rowHeight: rowHeight
                                )
                                .allowsHitTesting(false)
                            }
                        }
                    }
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .onAppear {
            updateRange()
        }
    }

    private func updateRange() {
        // Default to a 14-day window around now if not set
        if viewModel.startDate == viewModel.endDate {
             viewModel.startDate = Date().addingTimeInterval(-86400 * 7).startOfDay()
             viewModel.endDate = Date().addingTimeInterval(86400 * 7).endOfDay()
        }
        Task {
            await viewModel.fetchTimeline()
        }
    }
}

// MARK: - Header

struct TimelineHeader: View {
    let startDate: Date
    let endDate: Date
    let dayWidth: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                Spacer().frame(width: 150) // Matching task list width

                ForEach(generateDays(), id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(date.monthName.prefix(3))
                            .appFont(.system(size: 8))
                            .foregroundColor(AppColors.textSecondary)
                        Text("\(Calendar.current.component(.day, from: date))")
                            .appFont(AppTypography.caption1)
                            .fontWeight(.semibold)
                    }
                    .frame(width: dayWidth)
                    .padding(.vertical, 8)
                    .background(AppColors.backgroundSecondary)
                    .border(AppColors.borderDefault.opacity(0.2), width: 0.5)
                }
            }
        }
    }

    private func generateDays() -> [Date] {
        var days: [Date] = []
        var current = startDate
        while current <= endDate {
            days.append(current)
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }
}

// MARK: - Grid

struct TimelineGrid: View {
    let startDate: Date
    let endDate: Date
    let dayWidth: CGFloat
    let rowHeight: CGFloat
    let rows: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalDays(), id: \.self) { _ in
                Rectangle()
                    .fill(Color.gray.opacity(0.05))
                    .frame(width: dayWidth)
                    .overlay(
                        Rectangle()
                            .stroke(AppColors.borderDefault.opacity(0.1), lineWidth: 0.5)
                            .padding(.vertical, 0)
                    )
            }
        }
        .frame(height: CGFloat(rows) * rowHeight)
    }

    private func totalDays() -> Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0 + 1
    }
}

// MARK: - Task Bar

struct TimelineTaskBar: View {
    let task: TaskItemDTO
    let timelineStart: Date
    let dayWidth: CGFloat

    var body: some View {
        let (offset, width) = calculatePosition()

        return ZStack(alignment: .leading) {
            if width > 0 {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: width, height: 24)
                    .offset(x: offset)
                    .overlay(
                        Text(task.title)
                            .appFont(.system(size: 10))
                            .foregroundColor(.blue)
                            .padding(.leading, offset + 4)
                            .lineLimit(1),
                        alignment: .leading
                    )
            } else if task.dueDate != nil {
                // Milestone marker
                Image(systemName: "rhombus.fill")
                    .foregroundColor(.orange)
                    .offset(x: offset - 8)
            }
        }
    }

    private func calculatePosition() -> (CGFloat, CGFloat) {
        let calendar = Calendar.current
        let start = task.startDate ?? task.dueDate ?? Date()
        let end = task.dueDate ?? task.startDate ?? Date()

        let startDiff = calendar.dateComponents([.day], from: timelineStart.startOfDay(), to: start.startOfDay()).day ?? 0
        let duration = calendar.dateComponents([.day], from: start.startOfDay(), to: end.startOfDay()).day ?? 0

        let offset = CGFloat(max(0, startDiff)) * dayWidth
        let width = CGFloat(max(0, duration + 1)) * dayWidth

        // If no start date, it's a milestone (0 width)
        if task.startDate == nil {
            return (offset + dayWidth / 2, 0)
        }

        return (offset + 10, width - 20) // Adding some padding inside the day cell
    }
}

// MARK: - Dependency Lines

/// Draws bezier curves between tasks connected by "blocks" relations.
/// Uses SwiftUI Canvas for efficient rendering without layout overhead.
struct TimelineDependencyLines: View {
    let tasks: [TaskItemDTO]
    let relations: [TaskRelationDTO]
    let timelineStart: Date
    let dayWidth: CGFloat
    let rowHeight: CGFloat

    var body: some View {
        Canvas { context, _ in
            let calendar = Calendar.current

            // Build row-index lookup for O(1) access
            let rowMap: [UUID: Int] = Dictionary(
                uniqueKeysWithValues: tasks.enumerated().map { ($1.id, $0) }
            )

            for relation in relations where relation.relationType == .blocks {
                guard
                    let srcIdx = rowMap[relation.taskId],
                    let tgtIdx = rowMap[relation.relatedTaskId],
                    srcIdx != tgtIdx
                else { continue }

                let srcTask = tasks[srcIdx]
                let tgtTask = tasks[tgtIdx]

                // Pick the best representative dates for each endpoint
                guard
                    let srcEndDate = srcTask.dueDate ?? srcTask.startDate,
                    let tgtStartDate = tgtTask.startDate ?? tgtTask.dueDate
                else { continue }

                let srcEndDiff = calendar.dateComponents(
                    [.day], from: timelineStart.startOfDay(), to: srcEndDate.startOfDay()
                ).day ?? 0
                let tgtStartDiff = calendar.dateComponents(
                    [.day], from: timelineStart.startOfDay(), to: tgtStartDate.startOfDay()
                ).day ?? 0

                // Right edge of source bar  (mirrors calculatePosition: offset + width - 20)
                let srcX = CGFloat(max(0, srcEndDiff) + 1) * dayWidth - 10
                // Left edge of target bar   (mirrors calculatePosition: offset + 10)
                let tgtX = CGFloat(max(0, tgtStartDiff)) * dayWidth + 10

                // Vertical centre of each row
                let srcY = CGFloat(srcIdx) * rowHeight + rowHeight / 2
                let tgtY = CGFloat(tgtIdx) * rowHeight + rowHeight / 2

                // S-curve bezier between source right-edge and target left-edge
                let ctrlX = (srcX + tgtX) / 2
                var curvePath = Path()
                curvePath.move(to: CGPoint(x: srcX, y: srcY))
                curvePath.addCurve(
                    to: CGPoint(x: tgtX, y: tgtY),
                    control1: CGPoint(x: ctrlX, y: srcY),
                    control2: CGPoint(x: ctrlX, y: tgtY)
                )
                context.stroke(curvePath, with: .color(.orange.opacity(0.7)), lineWidth: 1.5)

                // Arrowhead pointing right at the target end
                let arrowSize: CGFloat = 5
                var arrow = Path()
                arrow.move(to: CGPoint(x: tgtX - arrowSize, y: tgtY - arrowSize))
                arrow.addLine(to: CGPoint(x: tgtX, y: tgtY))
                arrow.addLine(to: CGPoint(x: tgtX - arrowSize, y: tgtY + arrowSize))
                context.stroke(arrow, with: .color(.orange.opacity(0.7)), lineWidth: 1.5)
            }
        }
    }
}
