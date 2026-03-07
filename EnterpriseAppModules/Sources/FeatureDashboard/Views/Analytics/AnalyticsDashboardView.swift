import SwiftUI
import Charts
import SharedModels
import Domain
import DesignSystem
#if os(macOS)
import AppKit
#endif

public struct AnalyticsDashboardView: View {
    @StateObject private var viewModel: AnalyticsDashboardViewModel
    @State private var shareItem: ShareItem? = nil
    @State private var showingCreateSprint = false
    
    public init(projectId: UUID, repository: AnalyticsRepositoryProtocol) {
        self._viewModel = StateObject(wrappedValue: AnalyticsDashboardViewModel(projectId: projectId, repository: repository))
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                
                if viewModel.isLoading && viewModel.leadTime == nil {
                    AnalyticsSkeletonView()
                        .padding(.top, 10)
                } else if let error = viewModel.error {
                    ErrorStateView(error: error) {
                        Task { await viewModel.fetchAllAnalytics(forceRefresh: true) }
                    }
                } else {
                    kpiCardsView
                    burndownChartView
                    weeklyThroughputChartView
                    sprintVelocityChartView
                }
            }
            .padding()
        }
        .background(Color.platformSystemGroupedBackground)
        .navigationTitle("Analytics")
        .task {
            await viewModel.fetchAllAnalytics()
        }
        .loadingOverlay(
            viewModel.isExporting || viewModel.isCreatingSprint,
            message: viewModel.isExporting ? "Preparing export…" : "Creating sprint…"
        )
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .sheet(isPresented: $showingCreateSprint) {
            CreateSprintSheet { name, start, end, status in
                Task { await viewModel.createSprint(name: name, startDate: start, endDate: end, status: status) }
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project Analytics")
                        .font(.title2.bold())
                    if let last = viewModel.lastUpdated {
                        Text("Last updated \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Menu {
                    Button("Refresh") {
                        Task { await viewModel.fetchAllAnalytics(forceRefresh: true) }
                    }
                    Button("Create Sprint") {
                        showingCreateSprint = true
                    }
                    Divider()
                    Button("Export Burndown CSV") {
                        Task {
                            do {
                                let url = try await viewModel.exportBurndownCSV()
                                shareItem = ShareItem(url: url)
                            } catch {
                                viewModel.error = error
                            }
                        }
                    }
                    Button("Export PDF Report") {
                        Task {
                            do {
                                let url = try await viewModel.exportPDFReport()
                                shareItem = ShareItem(url: url)
                            } catch {
                                viewModel.error = error
                            }
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                }
            }

            HStack {
                DatePicker("Start", selection: $viewModel.startDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: viewModel.startDate) { _ in
                        Task { await viewModel.fetchAllAnalytics() }
                    }

                Text("-").foregroundStyle(.secondary)

                DatePicker("End", selection: $viewModel.endDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: viewModel.endDate) { _ in
                        Task { await viewModel.fetchAllAnalytics() }
                    }

                Spacer()
            }
        }
    }
    
    private var kpiCardsView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
            if let lead = viewModel.leadTime {
                KPICard(title: "Lead Time", value: String(format: "%.1f days", lead.value / 86400), subtitle: "Avg: \(lead.sampleSize) tasks")
            }
            if let cycle = viewModel.cycleTime {
                KPICard(title: "Cycle Time", value: String(format: "%.1f days", cycle.value / 86400), subtitle: "Avg: \(cycle.sampleSize) tasks")
            }
            if let vel = viewModel.velocity {
                KPICard(title: "Velocity", value: String(format: "%.0f pts", vel.value), subtitle: "Total Points")
            }
            if let thr = viewModel.throughput {
                KPICard(title: "Throughput", value: "\(thr.value) tasks", subtitle: "Total Tasks")
            }
        }
    }
    
    private var burndownChartView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Burndown (Remaining Points)")
                .font(.headline)
            
            Chart {
                ForEach(viewModel.burndownStats) { stat in
                    LineMark(
                        x: .value("Date", stat.date, unit: .day),
                        y: .value("Points", stat.remainingPoints)
                    )
                    .foregroundStyle(Color.accentColor)
                    
                    AreaMark(
                        x: .value("Date", stat.date, unit: .day),
                        y: .value("Points", stat.remainingPoints)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.1))
                }
            }
            .frame(height: 300)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .padding()
        .background(Color.platformSecondarySystemGroupedBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var weeklyThroughputChartView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Throughput (Completed Tasks)")
                .font(.headline)

            if viewModel.weeklyThroughput.isEmpty {
                Text("No weekly throughput data for this range.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(viewModel.weeklyThroughput) { point in
                        BarMark(
                            x: .value("Week", point.weekStart, unit: .weekOfYear),
                            y: .value("Tasks", point.completedTasks)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                    }
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.platformSecondarySystemGroupedBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var sprintVelocityChartView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sprint Velocity (Completed Points)")
                .font(.headline)

            if viewModel.sprintVelocity.isEmpty {
                Text("No sprints found (or none overlap this date range).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(viewModel.sprintVelocity) { point in
                        BarMark(
                            x: .value("Sprint", point.startDate, unit: .day),
                            y: .value("Points", point.completedPoints)
                        )
                        .foregroundStyle(Color.green.gradient)
                    }
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 14)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.platformSecondarySystemGroupedBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct KPICard: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.platformSecondarySystemGroupedBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Skeleton

private struct AnalyticsSkeletonView: View {
    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    ShimmerView()
                        .frame(height: 92)
                }
            }

            ShimmerView()
                .frame(height: 320)

            ShimmerView()
                .frame(height: 240)

            ShimmerView()
                .frame(height: 240)
        }
    }
}

// MARK: - Share Sheet

private struct ShareItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

private extension Color {
    static var platformSystemGroupedBackground: Color {
#if os(iOS)
        Color(.systemGroupedBackground)
#elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color.white
#endif
    }

    static var platformSecondarySystemGroupedBackground: Color {
#if os(iOS)
        Color(.secondarySystemGroupedBackground)
#elseif os(macOS)
        Color(nsColor: .underPageBackgroundColor)
#else
        Color.white
#endif
    }
}
