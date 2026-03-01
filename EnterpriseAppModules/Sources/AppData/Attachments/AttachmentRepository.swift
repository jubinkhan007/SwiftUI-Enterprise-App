import Foundation
import SharedModels
import AppNetwork
import Domain

public final class AttachmentRepository: AttachmentRepositoryProtocol {
    private let apiClient: APIClient
    private let apiConfiguration: APIConfiguration

    public init(apiClient: APIClient, configuration: APIConfiguration = .localVapor) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    public func list(taskId: UUID) async throws -> [AttachmentDTO] {
        let endpoint = AttachmentEndpoint.list(taskId: taskId, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[AttachmentDTO]>.self)
        return response.data ?? []
    }

    public func upload(taskId: UUID, filename: String, data: Data, mimeType: String) async throws -> AttachmentDTO {
        let boundary = "boundary-\(UUID().uuidString)"
        let endpoint = AttachmentEndpoint.upload(
            taskId: taskId,
            filename: filename,
            fileData: data,
            mimeType: mimeType,
            boundary: boundary,
            configuration: apiConfiguration
        )
        let response = try await apiClient.request(endpoint, responseType: APIResponse<AttachmentDTO>.self)
        guard let dto = response.data else { throw NetworkError.underlying("Failed to upload attachment") }
        return dto
    }

    public func download(attachmentId: UUID) async throws -> Data {
        let endpoint = AttachmentEndpoint.download(attachmentId: attachmentId, configuration: apiConfiguration)
        return try await apiClient.requestData(endpoint)
    }
}

