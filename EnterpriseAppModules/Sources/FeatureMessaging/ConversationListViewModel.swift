import Foundation
import Combine
import Domain
import SharedModels
import AppNetwork

@MainActor
public final class ConversationListViewModel: ObservableObject {
    @Published public private(set) var conversations: [ConversationListItemDTO] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public var error: Error?
    @Published public var searchQuery: String = ""
    
    private let messagingRepository: MessagingRepositoryProtocol
    private let realtimeProvider: RealTimeProvider
    private var orgId: UUID?
    private var cancellables = Set<AnyCancellable>()
    private var realtimeListenerID: UUID?
    
    public init(messagingRepository: MessagingRepositoryProtocol, realtimeProvider: RealTimeProvider) {
        self.messagingRepository = messagingRepository
        self.realtimeProvider = realtimeProvider
        
        $searchQuery
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchConversations()
                }
            }
            .store(in: &cancellables)

        realtimeListenerID = realtimeProvider.addEventListener { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleRealtimeEvent(event)
            }
        }
    }

    deinit {
        if let realtimeListenerID {
            Task { @MainActor [realtimeProvider] in
                realtimeProvider.removeEventListener(realtimeListenerID)
            }
        }
    }
    
    public var filteredConversations: [ConversationListItemDTO] {
        return conversations
    }
    
    public func setOrgId(_ orgId: UUID) {
        self.orgId = orgId
        Task { await realtimeProvider.connect(orgId: orgId) }
    }
    
    public func fetchConversations() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await messagingRepository.getConversations(searchQuery: query.isEmpty ? nil : query)
            self.conversations = response.data ?? []
            
            let channels = self.conversations.map { "conversation:\($0.id.uuidString)" }
            if !channels.isEmpty {
                await realtimeProvider.subscribe(channels: channels)
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func handleRealtimeEvent(_ event: RealTimeProvider.ServerEvent) {
        if event.type == "message.new" {
            Task {
                await fetchConversations()
            }
        }
    }
}
