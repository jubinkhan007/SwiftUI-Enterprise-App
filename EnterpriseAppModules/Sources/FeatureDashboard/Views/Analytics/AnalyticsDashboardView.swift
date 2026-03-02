import SwiftUI
import Charts
import SharedModels
import Domain
import DesignSystem

public struct AnalyticsDashboardView: View {
    @StateObject private var viewModel: AnalyticsDashboardViewModel
    
    public init(projectId: UUID, repository: AnalyticsRepositoryProtocol) {
        self._viewModel = StateObject(wrappedValue: AnalyticsDashboardViewModel(projectId: projectId, repository: repository))
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                
                if viewModel.isLoading && viewModel.leadTime == nil {
                    ProgressView("Loading Analytics...")
                        .padding(.top, 40)
                } else if let error = viewModel.error {
                    ErrorStateView(error: error) {
                        Task { await viewModel.fetchAllAnalytics() }
                    }
                } else {
                    kpiCardsView
                    burndownChartView
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
        .task {
            await viewModel.fetchAllAnalytics()
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Project Analytics")
                .font(.title2.bold())
            
            Spacer()
            
            DatePicker("Start", selection: $viewModel.startDate, displayedComponents: .date)
                .labelsHidden()
                .onChange(of: viewModel.startDate) { _ in
                    Task { await viewModel.fetchAllAnalytics() }
                }
            
            Text("-")
            
            DatePicker("End", selection: $viewModel.endDate, displayedComponents: .date)
                .labelsHidden()
                .onChange(of: viewModel.endDate) { _ in
                    Task { await viewModel.fetchAllAnalytics() }
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
        .background(Color(.secondarySystemGroupedBackground))
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
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
