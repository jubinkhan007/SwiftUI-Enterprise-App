import Foundation
import SwiftUI
import SharedModels
import AppNetwork

@MainActor
public final class ReleaseManagementViewModel: ObservableObject {
    @Published public private(set) var releases: [ReleaseDTO] = []
    @Published public private(set) var progressByReleaseId: [UUID: ReleaseProgressDTO] = [:]
    @Published public var statusFilter: ReleaseStatus? = nil
    @Published public private(set) var isLoading = false
    @Published public var error: Error?

    public var filteredReleases: [ReleaseDTO] {
        guard let statusFilter else { return releases }
        return releases.filter { $0.status == statusFilter }
    }

    private let projectId: UUID
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration

    public init(
        projectId: UUID,
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .current
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

    public func createRelease(name: String, description: String?, releaseDate: Date?) async throws {
        let payload = CreateReleaseRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            releaseDate: releaseDate
        )
        let endpoint = ReleaseEndpoint.create(projectId: projectId, payload: payload, configuration: apiConfiguration)
        _ = try await apiClient.request(endpoint, responseType: APIResponse<ReleaseDTO>.self)
        await refresh()
    }

    public func updateRelease(releaseId: UUID, payload: UpdateReleaseRequest) async throws {
        let endpoint = ReleaseEndpoint.update(releaseId: releaseId, payload: payload, configuration: apiConfiguration)
        _ = try await apiClient.request(endpoint, responseType: APIResponse<ReleaseDTO>.self)
        await refresh()
    }

    public func finalizeRelease(releaseId: UUID, lock: Bool = true) async throws {
        let endpoint = ReleaseEndpoint.finalize(releaseId: releaseId, lock: lock, configuration: apiConfiguration)
        _ = try await apiClient.request(endpoint, responseType: APIResponse<ReleaseDTO>.self)
        await refresh()
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

