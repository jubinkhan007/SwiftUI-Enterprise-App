import Foundation
import SwiftUI
import Domain
import SharedModels
import Combine

@MainActor
public final class SidebarViewModel: ObservableObject {
    @Published public private(set) var areas: [HierarchyTreeDTO.SpaceNode] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public var error: Error?
    
    // Selection state
    @Published public var selectedArea: SidebarItem?
    
    private let hierarchyRepository: HierarchyRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    public enum SidebarItem: Hashable {
        case allTasks
        case inbox
        case space(UUID)
        case project(UUID)
        case list(UUID)
        
        public var id: String {
            switch self {
            case .allTasks: return "all"
            case .inbox: return "inbox"
            case .space(let id): return "space-\(id.uuidString)"
            case .project(let id): return "project-\(id.uuidString)"
            case .list(let id): return "list-\(id.uuidString)"
            }
        }
    }
    
    public init(hierarchyRepository: HierarchyRepositoryProtocol) {
        self.hierarchyRepository = hierarchyRepository
    }
    
    public func fetchHierarchy() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let tree = try await hierarchyRepository.getHierarchy()
            self.areas = tree.spaces
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}
