import SwiftUI
import SharedModels
import DesignSystem
import Domain

@MainActor
final class GlobalSearchViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case messages = "Messages"
        case channels = "Channels"
        case files = "Files"
        case people = "People"

        var id: String { rawValue }
    }

    struct MessageResult: Identifiable {
        let id: UUID
        let conversationName: String
        let message: MessageDTO
    }

    @Published var query = ""
    @Published var selectedTab: Tab = .messages
    @Published var filterFrom: String = ""
    @Published var filterIn: String = ""
    @Published var filterAfterDate: Date? = nil
    @Published private(set) var conversations: [ConversationListItemDTO] = []
    @Published private(set) var messageResults: [MessageResult] = []
    @Published private(set) var people: [ConversationMemberDTO] = []
    @Published private(set) var isLoading = false

    var hasActiveFilters: Bool {
        !filterFrom.isEmpty || !filterIn.isEmpty || filterAfterDate != nil
    }

    private let messagingRepository: MessagingRepositoryProtocol

    init(messagingRepository: MessagingRepositoryProtocol) {
        self.messagingRepository = messagingRepository
    }

    func clearFilters() {
        filterFrom = ""
        filterIn = ""
        filterAfterDate = nil
    }

    func search() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasActiveFilters else {
            conversations = []
            messageResults = []
            people = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Merge visual filter bar values into the raw query for parsing
        var augmented = query
        if !filterFrom.isEmpty { augmented += " from:\(filterFrom)" }
        if !filterIn.isEmpty   { augmented += " in:\(filterIn)" }
        if let date = filterAfterDate {
            augmented += " after:\(ISO8601DateFormatter().string(from: date))"
        }
        let parsed = SearchQuery(raw: augmented)
        do {
            let conversationResponse = try await messagingRepository.getConversations(searchQuery: parsed.channel)
            let fetchedConversations = conversationResponse.data ?? []
            conversations = fetchedConversations.filter { conversation in
                parsed.matchesConversation(conversation)
            }

            var gatheredMessages: [MessageResult] = []
            var gatheredPeople: [ConversationMemberDTO] = []
            for conversation in conversations.prefix(8) {
                let messages = try await messagingRepository.getMessages(conversationId: conversation.id, cursor: nil, limit: 50)
                for message in messages.data ?? [] where parsed.matchesMessage(message, in: conversation) {
                    gatheredMessages.append(MessageResult(id: message.id, conversationName: conversation.name ?? "Unknown", message: message))
                }

                let detail = try await messagingRepository.getConversation(id: conversation.id)
                gatheredPeople.append(contentsOf: detail.data?.members ?? [])
            }
            messageResults = gatheredMessages
            people = Array(Dictionary(grouping: gatheredPeople, by: \.userId).compactMap { $0.value.first })
        } catch {
            conversations = []
            messageResults = []
            people = []
        }
    }

    private struct SearchQuery {
        let raw: String
        let sender: String?
        let channel: String?
        let afterDate: Date?
        let freeText: String

        init(raw: String) {
            self.raw = raw
            self.sender = SearchQuery.value(for: "from:", in: raw)
            self.channel = SearchQuery.value(for: "in:", in: raw)
            if let afterString = SearchQuery.value(for: "after:", in: raw) {
                let formatter = ISO8601DateFormatter()
                self.afterDate = formatter.date(from: afterString)
            } else {
                self.afterDate = nil
            }
            self.freeText = raw
                .components(separatedBy: " ")
                .filter { !$0.hasPrefix("from:") && !$0.hasPrefix("in:") && !$0.hasPrefix("after:") }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        static func value(for prefix: String, in raw: String) -> String? {
            raw.components(separatedBy: " ").first(where: { $0.hasPrefix(prefix) })?.replacingOccurrences(of: prefix, with: "")
        }

        func matchesConversation(_ conversation: ConversationListItemDTO) -> Bool {
            if let channel, !channel.isEmpty {
                return conversation.name?.localizedCaseInsensitiveContains(channel.replacingOccurrences(of: "#", with: "")) == true
            }
            if freeText.isEmpty { return true }
            return conversation.name?.localizedCaseInsensitiveContains(freeText) == true
                || conversation.lastMessage?.body.localizedCaseInsensitiveContains(freeText) == true
        }

        func matchesMessage(_ message: MessageDTO, in conversation: ConversationListItemDTO) -> Bool {
            if let sender, !sender.isEmpty, !message.senderName.localizedCaseInsensitiveContains(sender) {
                return false
            }
            if let afterDate, let createdAt = message.createdAt, createdAt < afterDate {
                return false
            }
            if let channel, !channel.isEmpty, !(conversation.name?.localizedCaseInsensitiveContains(channel.replacingOccurrences(of: "#", with: "")) == true) {
                return false
            }
            if freeText.isEmpty { return true }
            return message.body.localizedCaseInsensitiveContains(freeText)
        }
    }
}

public struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GlobalSearchViewModel

    public init(messagingRepository: MessagingRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: GlobalSearchViewModel(messagingRepository: messagingRepository))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.backgroundPrimary)

                Divider()

                Picker("Results", selection: $viewModel.selectedTab) {
                    ForEach(GlobalSearchViewModel.Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, AppSpacing.sm)

                resultsView
            }
            .searchable(text: $viewModel.query, prompt: "Search messages, channels, people")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .navigationTitle("Global Search")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if viewModel.hasActiveFilters {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Clear Filters") {
                            viewModel.clearFilters()
                            Task { await viewModel.search() }
                        }
                        .foregroundColor(AppColors.statusError)
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "person")
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 16)
                TextField("From (sender name)", text: $viewModel.filterFrom)
                    .appFont(AppTypography.caption1)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await viewModel.search() } }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 7)
            .background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "number")
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 16)
                TextField("In (channel name)", text: $viewModel.filterIn)
                    .appFont(AppTypography.caption1)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await viewModel.search() } }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 7)
            .background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "calendar")
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 16)
                if let date = viewModel.filterAfterDate {
                    HStack {
                        Text("After: \(date.formatted(date: .abbreviated, time: .omitted))")
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Button {
                            viewModel.filterAfterDate = nil
                            Task { await viewModel.search() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    DatePicker(
                        "After date",
                        selection: Binding(
                            get: { viewModel.filterAfterDate ?? Date() },
                            set: { viewModel.filterAfterDate = $0; Task { await viewModel.search() } }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .appFont(AppTypography.caption1)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 7)
            .background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        switch viewModel.selectedTab {
        case .messages:
            List(viewModel.messageResults) { result in
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.conversationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.message.body)
                }
            }
        case .channels:
            List(viewModel.conversations) { conversation in
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.name ?? "Unknown")
                    Text(conversation.type.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        case .files:
            ContentUnavailableView("No file search yet", systemImage: "doc.text.magnifyingglass")
        case .people:
            List(viewModel.people) { member in
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.displayName)
                    Text(member.role.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
