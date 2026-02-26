import SwiftUI
import SharedModels
import DesignSystem

enum CalendarMode: String, CaseIterable {
    case month = "Month"
    case week = "Week"
}

struct CalendarView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var selectedDate = Date()
    @State private var calendarMode: CalendarMode = .month
    @State private var selectedDayTasks: [TaskItemDTO]? = nil

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 0) {
            calendarToolbar

            daysOfWeekHeader

            calendarGrid
        }
        .background(AppColors.backgroundPrimary)
        .onAppear { updateRange() }
        .onChange(of: selectedDate) { updateRange() }
        .onChange(of: calendarMode) { updateRange() }
        .sheet(item: selectedDayBinding) { day in
            DayTaskListSheet(date: day.date, tasks: day.tasks)
        }
    }

    // MARK: - Toolbar

    private var calendarToolbar: some View {
        HStack {
            Button(action: { moveByOne(direction: -1) }) {
                Image(systemName: "chevron.left").padding()
            }

            Spacer()

            Text(headerTitle)
                .appFont(AppTypography.headline)

            Spacer()

            Button(action: { moveByOne(direction: 1) }) {
                Image(systemName: "chevron.right").padding()
            }

            Picker("Mode", selection: $calendarMode) {
                ForEach(CalendarMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .padding(.trailing, AppSpacing.md)
        }
        .padding(.horizontal)
        .background(AppColors.surfacePrimary)
    }

    private var headerTitle: String {
        switch calendarMode {
        case .month:
            return "\(selectedDate.monthName) \(String(selectedDate.year))"
        case .week:
            let days = daysInCurrentPeriod
            guard let first = days.first, let last = days.last else { return "" }
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
        }
    }

    // MARK: - Days of Week Header

    private var daysOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .background(AppColors.backgroundSecondary)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = daysInCurrentPeriod
        let leadingBlanks: Int = {
            guard calendarMode == .month, let first = days.first else { return 0 }
            return calendar.component(.weekday, from: first) - 1
        }()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 0) {
                // Leading blank cells for month alignment
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: calendarMode == .month ? 100 : 150)
                }

                ForEach(days, id: \.self) { date in
                    let tasksForDay = viewModel.tasks.filter { taskOverlapsDay($0, day: date) }
                    CalendarDayCell(
                        date: date,
                        isCurrentMonth: calendarMode == .week
                            || calendar.isDate(date, equalTo: selectedDate, toGranularity: .month),
                        tasks: tasksForDay
                    ) {
                        // Tap: show day sheet
                        selectedDayTasks = tasksForDay
                    }
                    .frame(height: calendarMode == .month ? 100 : 150)
                    .border(AppColors.borderDefault.opacity(0.3), width: 0.5)
                }
            }
        }
    }

    // MARK: - Helpers

    private var daysInCurrentPeriod: [Date] {
        switch calendarMode {
        case .month: return generateDaysInMonth(for: selectedDate)
        case .week:  return generateDaysInWeek(for: selectedDate)
        }
    }

    private func generateDaysInMonth(for date: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: interval.start)) else { return [] }
        let count = calendar.range(of: .day, in: .month, for: firstDay)!.count
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: firstDay) }
    }

    private func generateDaysInWeek(for date: Date) -> [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekInterval.start) }
    }

    private func taskOverlapsDay(_ task: TaskItemDTO, day: Date) -> Bool {
        let dayStart = day.startOfDay()
        let dayEnd   = day.endOfDay()
        if let start = task.startDate, let due = task.dueDate {
            return start <= dayEnd && due >= dayStart
        } else if let due = task.dueDate {
            return due.isSameDay(as: day)
        } else if let start = task.startDate {
            return start.isSameDay(as: day)
        }
        return false
    }

    private func moveByOne(direction: Int) {
        switch calendarMode {
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: direction, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: direction, to: selectedDate) ?? selectedDate
        }
    }

    private func updateRange() {
        switch calendarMode {
        case .month:
            viewModel.startDate = selectedDate.startOfMonth()
            viewModel.endDate   = selectedDate.endOfMonth()
        case .week:
            let days = generateDaysInWeek(for: selectedDate)
            viewModel.startDate = days.first?.startOfDay() ?? selectedDate.startOfMonth()
            viewModel.endDate   = days.last?.endOfDay()   ?? selectedDate.endOfMonth()
        }
        Task { await viewModel.fetchCalendarTasks() }
    }

    // Binding adapter to present the DayTaskListSheet as a sheet(item:)
    private var selectedDayBinding: Binding<SelectedDay?> {
        Binding(
            get: { selectedDayTasks.map { SelectedDay(date: selectedDate, tasks: $0) } },
            set: { if $0 == nil { selectedDayTasks = nil } }
        )
    }
}

// MARK: - Helpers

private struct SelectedDay: Identifiable {
    let id = UUID()
    let date: Date
    let tasks: [TaskItemDTO]
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let tasks: [TaskItemDTO]
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .appFont(AppTypography.caption1)
                .foregroundColor(isCurrentMonth ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.5))
                .padding(4)

            ForEach(tasks.prefix(3)) { task in
                Text(task.title)
                    .appFont(.system(size: 8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(2)
                    .lineLimit(1)
            }

            if tasks.count > 3 {
                Text("+\(tasks.count - 3) more")
                    .appFont(.system(size: 8))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isToday ? Color.accentColor.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Day Task List Sheet

private struct DayTaskListSheet: View {
    let date: Date
    let tasks: [TaskItemDTO]

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    EmptyStateView(title: "No Tasks", message: "No tasks scheduled for this day.")
                } else {
                    List(tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TaskTypeBadge(taskType: task.taskType)
                                Text(task.title)
                                    .appFont(AppTypography.body)
                            }
                            HStack {
                                StatusBadge(status: task.status)
                                PriorityBadge(priority: task.priority)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(date.formatted(date: .long, time: .omitted))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.medium, .large])
    }
}
