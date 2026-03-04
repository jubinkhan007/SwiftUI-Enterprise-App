import Foundation
import SwiftUI
import SharedModels
import AppNetwork

@MainActor
public final class ReleaseManagementViewModel: ObservableObject {
    @Published public private(set) var releases: [ReleaseDTO] = []
    @Published public private(set) var progressByReleaseId: [UUID: ReleaseProgressDTO] = [:]
    @Published public private(set) var isLoading = false
    @Published public var error: Error?

    private let projectId: UUID
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration

    public init(
        projectId: UUID,
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .localVapor
    ) {
        self.projectId = projectId
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            let listEndpoint = ReleaseEndpoint.list(projectId: projectId, configuration: apiConfiguration)
            let listResponse = try await apiClient.request(listEndpoint, responseType: APIResponse<[ReleaseDTO]>.self)
            let releases = listResponse.data ?? []

            self.releases = releases.sorted { lhs, rhs in
                // Unreleased first, then by releaseDate
                if lhs.status != rhs.status { return lhs.status == .unreleased }
                return (lhs.releaseDate ?? .distantFuture) < (rhs.releaseDate ?? .distantFuture)
            }

            await loadProgress(for: self.releases)
        } catch {
            self.error = error
        }
    }

    private func loadProgress(for releases: [ReleaseDTO]) async {
        var next: [UUID: ReleaseProgressDTO] = progressByReleaseId

        await withTaskGroup(of: (UUID, ReleaseProgressDTO?).self) { group in
            for r in releases {
                group.addTask { [apiClient, apiConfiguration] in
                    do {
                        let endpoint = ReleaseEndpoint.progress(releaseId: r.id, configuration: apiConfiguration)
                        let response = try await apiClient.request(endpoint, responseType: APIResponse<ReleaseProgressDTO>.self)
                        return (r.id, response.data)
                    } catch {
                        return (r.id, nil)
                    }
                }
            }

            for await (id, progress) in group {
                if let progress {
                    next[id] = progress
                }
            }
        }

        progressByReleaseId = next
    }
}

