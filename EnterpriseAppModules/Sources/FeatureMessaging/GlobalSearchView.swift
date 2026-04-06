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
    @Published private(set) var conversations: [ConversationListItemDTO] = []
    @Published private(set) var messageResults: [MessageResult] = []
    @Published private(set) var people: [ConversationMemberDTO] = []
    @Published private(set) var isLoading = false

    private let messagingRepository: MessagingRepositoryProtocol

    init(messagingRepository: MessagingRepositoryProtocol) {
        self.messagingRepository = messagingRepository
    }

    func search() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            conversations = []
            messageResults = []
            people = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        let parsed = SearchQuery(raw: query)
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
            VStack(spacing: AppSpacing.md) {
                Picker("Results", selection: $viewModel.selectedTab) {
                    ForEach(GlobalSearchViewModel.Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                resultsView
            }
            .padding()
            .searchable(text: $viewModel.query, prompt: "Search messages, channels, people")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .navigationTitle("Global Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
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
