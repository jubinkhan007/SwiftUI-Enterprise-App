import Foundation
import SharedModels

public protocol AttachmentRepositoryProtocol: Sendable {
    func list(taskId: UUID) async throws -> [AttachmentDTO]
    func upload(taskId: UUID, filename: String, data: Data, mimeType: String) async throws -> AttachmentDTO
    func download(attachmentId: UUID) async throws -> Data
}

