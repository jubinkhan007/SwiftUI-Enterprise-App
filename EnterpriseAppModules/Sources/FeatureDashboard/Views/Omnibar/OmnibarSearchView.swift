import SwiftUI
import Combine
import SharedModels
import Domain
import DesignSystem

@MainActor
public final class OmnibarViewModel: ObservableObject {
    @Published public var query: String = ""
    @Published public var selectedFilter: SearchEntityType? = nil
    @Published public var isCopilotActive: Bool = false
    @Published public var results: [SearchResultItemDTO] = []
    @Published public var isSearching: Bool = false
    @Published public var errorMessage: String? = nil

    // AI Copilot state
    @Published public var copilotPrompt: String = ""
    @Published public var isCopilotLoading: Bool = false
    @Published public var copilotResponse: AIAssistantResponse? = nil
    @Published public var isCreatingTasks: Bool = false
    @Published public var tasksCreatedSuccess: Bool = false

    private let searchRepository: SearchRepositoryProtocol
    private let aiRepository: AIAssistantRepositoryProtocol
    private let taskRepository: TaskRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    public init(
        searchRepository: SearchRepositoryProtocol,
        aiRepository: AIAssistantRepositoryProtocol,
        taskRepository: TaskRepositoryProtocol
    ) {
        self.searchRepository = searchRepository
        self.aiRepository = aiRepository
        self.taskRepository = taskRepository

        $query
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newQuery in
                guard let self else { return }
                Task { await self.performSearch(query: newQuery) }
            }
            .store(in: &cancellables)
    }

    public func performSearch(query: String) async {
        guard !isCopilotActive else { return }
        isSearching = true
        errorMessage = nil

        let types = selectedFilter.map { [$0] }
        do {
            let resp = try await searchRepository.search(query: query, types: types, limit: 30)
            self.results = resp.results
        } catch {
            self.errorMessage = "Search failed: \(error.localizedDescription)"
        }
        self.isSearching = false
    }

    public func selectFilter(_ filter: SearchEntityType?) {
        self.selectedFilter = filter
        self.isCopilotActive = false
        Task { await performSearch(query: query) }
    }

    public func switchToCopilot() {
        self.isCopilotActive = true
        self.selectedFilter = nil
    }

    public func runTaskBreakdown() async {
        let trimmed = copilotPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isCopilotLoading = true
        tasksCreatedSuccess = false
        errorMessage = nil

        do {
            let resp = try await aiRepository.breakdownTask(
                title: trimmed,
                description: nil,
                contextId: nil
            )
            self.copilotResponse = resp
        } catch {
            self.errorMessage = "Task breakdown failed: \(error.localizedDescription)"
        }
        self.isCopilotLoading = false
    }

    public func runDailyStandup() async {
        isCopilotLoading = true
        tasksCreatedSuccess = false
        errorMessage = nil

        do {
            let resp = try await aiRepository.generateStandup()
            self.copilotResponse = resp
        } catch {
            self.errorMessage = "Standup generation failed: \(error.localizedDescription)"
        }
        self.isCopilotLoading = false
    }

    public func createSuggestedTasks(listId: UUID? = nil) async {
        guard let tasks = copilotResponse?.suggestedTasks, !tasks.isEmpty else { return }
        isCreatingTasks = true
        defer { isCreatingTasks = false }

        for item in tasks {
            let prioStr = item.priority?.lowercased() ?? "medium"
            let priority: TaskPriority = {
                switch prioStr {
                case "critical", "urgent": return .critical
                case "high": return .high
                case "low": return .low
                default: return .medium
                }
            }()
            let req = CreateTaskRequest(
                title: item.title,
                description: item.description,
                status: .todo,
                priority: priority,
                taskType: .task,
                listId: listId
            )
            _ = try? await taskRepository.createTask(payload: req)
        }
        self.tasksCreatedSuccess = true
    }
}

public struct OmnibarSearchView: View {
    @StateObject private var viewModel: OmnibarViewModel
    @Binding private var isPresented: Bool
    @FocusState private var isInputFocused: Bool
    @State private var copilotMode: CopilotMode = .breakdown

    private enum CopilotMode: String, CaseIterable {
        case breakdown = "Task Breakdown"
        case standup = "Daily Standup"
    }

    public init(
        isPresented: Binding<Bool>,
        searchRepository: SearchRepositoryProtocol,
        aiRepository: AIAssistantRepositoryProtocol,
        taskRepository: TaskRepositoryProtocol
    ) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: OmnibarViewModel(
            searchRepository: searchRepository,
            aiRepository: aiRepository,
            taskRepository: taskRepository
        ))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeaderBar
                filterChipsRow

                Divider()

                if viewModel.isCopilotActive {
                    copilotView
                } else {
                    searchResultsList
                }
            }
            .background(AppColors.backgroundSecondary)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
            .task {
                isInputFocused = true
                await viewModel.performSearch(query: "")
            }
        }
    }

    // MARK: - Header Bar

    private var searchHeaderBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textSecondary)
                .font(.system(size: 18, weight: .medium))

            TextField("Search tasks, messages, meetings, or switch to AI...", text: $viewModel.query)
                .focused($isInputFocused)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.performSearch(query: viewModel.query) }
                }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surfacePrimary)
    }

    // MARK: - Filter Chips

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                filterChip(title: "All", isSelected: !viewModel.isCopilotActive && viewModel.selectedFilter == nil) {
                    viewModel.selectFilter(nil)
                }

                ForEach(SearchEntityType.allCases, id: \.self) { entityType in
                    filterChip(
                        title: entityTypeTitle(entityType),
                        isSelected: !viewModel.isCopilotActive && viewModel.selectedFilter == entityType
                    ) {
                        viewModel.selectFilter(entityType)
                    }
                }

                Button {
                    viewModel.switchToCopilot()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("AI Copilot")
                    }
                    .font(AppTypography.caption1)
                    .fontWeight(.semibold)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 6)
                    .background(viewModel.isCopilotActive ? AppColors.brandPrimary : AppColors.surfacePrimary)
                    .foregroundColor(viewModel.isCopilotActive ? .white : AppColors.brandPrimary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppColors.brandPrimary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
        }
        .background(AppColors.surfacePrimary)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.caption1)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 6)
                .background(isSelected ? AppColors.brandPrimary : AppColors.backgroundSecondary)
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .clipShape(Capsule())
        }
    }

    private func entityTypeTitle(_ type: SearchEntityType) -> String {
        switch type {
        case .task: return "Tasks"
        case .message: return "Messages"
        case .meeting: return "Meetings"
        case .member: return "People"
        case .doc: return "Docs"
        }
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.statusError)
                }
            }

            if viewModel.results.isEmpty && !viewModel.isSearching {
                Section {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(AppColors.textSecondary)
                        Text("No matching results")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Try searching for tasks, channel messages, or teammates.")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(viewModel.results) { item in
                        Button {
                            DeeplinkRouter.handle(item.deepLink)
                            isPresented = false
                        } label: {
                            HStack(spacing: AppSpacing.sm) {
                                entityIcon(for: item.entityType)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(AppTypography.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineLimit(1)

                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(AppTypography.caption1)
                                            .foregroundColor(AppColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if let badge = item.badge {
                                    Text(badge)
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(badgeBackground(badge))
                                        .foregroundColor(badgeForeground(badge))
                                        .cornerRadius(4)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func entityIcon(for type: SearchEntityType) -> some View {
        let (icon, color): (String, Color) = {
            switch type {
            case .task: return ("checkmark.square.fill", AppColors.brandPrimary)
            case .message: return ("bubble.left.and.bubble.right.fill", Color.blue)
            case .meeting: return ("video.fill", Color.purple)
            case .member: return ("person.crop.circle.fill", Color.orange)
            case .doc: return ("doc.text.fill", Color.teal)
            }
        }()

        return Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundColor(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private func badgeBackground(_ badge: String) -> Color {
        let b = badge.lowercased()
        if b.contains("urgent") || b.contains("critical") { return AppColors.statusError.opacity(0.15) }
        if b.contains("high") { return Color.orange.opacity(0.15) }
        if b.contains("done") { return AppColors.statusSuccess.opacity(0.15) }
        return AppColors.backgroundSecondary
    }

    private func badgeForeground(_ badge: String) -> Color {
        let b = badge.lowercased()
        if b.contains("urgent") || b.contains("critical") { return AppColors.statusError }
        if b.contains("high") { return Color.orange }
        if b.contains("done") { return AppColors.statusSuccess }
        return AppColors.textSecondary
    }

    // MARK: - AI Copilot View

    private var copilotView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Picker("Copilot Mode", selection: $copilotMode) {
                    ForEach(CopilotMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if copilotMode == .breakdown {
                    taskBreakdownSection
                } else {
                    dailyStandupSection
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.statusError)
                }

                if let response = viewModel.copilotResponse {
                    copilotResultsSection(response)
                }
            }
            .padding(AppSpacing.md)
        }
    }

    private var taskBreakdownSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("AI Task Decomposition")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            Text("Enter a complex feature or requirement. The Copilot will break it down into estimated subtasks.")
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)

            TextField("e.g. Implement OAuth2 login with Apple and Google", text: $viewModel.copilotPrompt)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.body)

            Button {
                Task { await viewModel.runTaskBreakdown() }
            } label: {
                HStack {
                    if viewModel.isCopilotLoading {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("Decompose Task")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColors.brandPrimary)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(viewModel.isCopilotLoading || viewModel.copilotPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
        .cornerRadius(10)
    }

    private var dailyStandupSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Daily Standup Generator")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            Text("Automatically synthesizes completed work, in-progress tasks, and blockers into a clean standup summary.")
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)

            Button {
                Task { await viewModel.runDailyStandup() }
            } label: {
                HStack {
                    if viewModel.isCopilotLoading {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "calendar.badge.clock")
                    }
                    Text("Generate Today's Standup")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColors.brandPrimary)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(viewModel.isCopilotLoading)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
        .cornerRadius(10)
    }

    private func copilotResultsSection(_ response: AIAssistantResponse) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Label("AI Suggestions", systemImage: "sparkles")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.brandPrimary)

                Spacer()

                if !response.summary.isEmpty {
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = response.summary
                        #endif
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.brandPrimary)
                    }
                }
            }

            if !response.summary.isEmpty {
                Text(response.summary)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(8)
            }

            if let tasks = response.suggestedTasks, !tasks.isEmpty {
                Text("Suggested Subtasks (\(tasks.count))")
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                ForEach(tasks, id: \.title) { subtask in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(subtask.title)
                                .font(AppTypography.body)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            let hours = subtask.estimateHours ?? 2.0
                            let prio = subtask.priority ?? "medium"

                            Text("\(String(format: "%.1f", hours))h")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .foregroundColor(.blue)
                                .cornerRadius(4)

                            Text(prio.capitalized)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeBackground(prio))
                                .foregroundColor(badgeForeground(prio))
                                .cornerRadius(4)
                        }

                        if let desc = subtask.description {
                            Text(desc)
                                .font(AppTypography.caption1)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(8)
                }

                if viewModel.tasksCreatedSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.statusSuccess)
                        Text("Subtasks created successfully in backlog!")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.statusSuccess)
                    }
                } else {
                    Button {
                        Task { await viewModel.createSuggestedTasks() }
                    } label: {
                        HStack {
                            if viewModel.isCreatingTasks {
                                ProgressView().controlSize(.small).tint(.white)
                            }
                            Text("Add All to Project Backlog")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppColors.brandPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.isCreatingTasks)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
        .cornerRadius(10)
    }
}
