import Foundation
import SwiftUI
import SharedModels
import AppNetwork

@MainActor
public final class EpicDetailDashboardViewModel: ObservableObject {
    @Published public private(set) var epic: TaskItemDTO
    @Published public private(set) var childIssues: [TaskItemDTO] = []
    @Published public private(set) var isLoading = false
    @Published public var error: Error?

    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration

    public init(
        epic: TaskItemDTO,
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .localVapor
    ) {
        self.epic = epic
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            async let epicTask: TaskItemDTO? = try fetchEpic()
            async let children: [TaskItemDTO] = try fetchChildren()
            let (updatedEpic, childList) = try await (epicTask, children)
            if let updatedEpic {
                self.epic = updatedEpic
            }
            self.childIssues = childList
        } catch {
            self.error = error
        }
    }

    private func fetchEpic() async throws -> TaskItemDTO? {
        let endpoint = TaskEndpoint.getTask(id: epic.id, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
        return response.data
    }

    private func fetchChildren() async throws -> [TaskItemDTO] {
        let endpoint = TaskEndpoint.getSubtasks(taskId: epic.id, page: 1, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[TaskItemDTO]>.self)
        return response.data ?? []
    }
}
