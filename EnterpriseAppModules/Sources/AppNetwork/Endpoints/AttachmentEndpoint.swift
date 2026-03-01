import Foundation
import SharedModels

public enum AttachmentEndpoint {
    case list(taskId: UUID, configuration: APIConfiguration)
    case upload(taskId: UUID, filename: String, fileData: Data, mimeType: String, boundary: String, configuration: APIConfiguration)
    case download(attachmentId: UUID, configuration: APIConfiguration)
}

extension AttachmentEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .list(_, let c), .upload(_, _, _, _, _, let c), .download(_, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .list(let taskId, _), .upload(let taskId, _, _, _, _, _):
            return "/api/tasks/\(taskId.uuidString)/attachments"
        case .download(let attachmentId, _):
            return "/api/attachments/\(attachmentId.uuidString)/download"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .list, .download:
            return .get
        case .upload:
            return .post
        }
    }

    public var headers: [String: String]? {
        var h: [String: String] = [:]
        if let token = TokenStore.shared.token { h["Authorization"] = "Bearer \(token)" }
        if let orgId = OrganizationContext.shared.orgId { h["X-Org-Id"] = orgId.uuidString }

        switch self {
        case .upload(_, _, _, _, let boundary, _):
            h["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
            h["Accept"] = "application/json"
        case .download:
            h["Accept"] = "*/*"
        default:
            h["Content-Type"] = "application/json"
            h["Accept"] = "application/json"
        }
        return h
    }

    public var body: Data? {
        switch self {
        case .upload(_, let filename, let fileData, let mimeType, let boundary, _):
            return Self.multipartBody(
                fieldName: "file",
                filename: filename,
                mimeType: mimeType,
                fileData: fileData,
                boundary: boundary
            )
        default:
            return nil
        }
    }

    private static func multipartBody(
        fieldName: String,
        filename: String,
        mimeType: String,
        fileData: Data,
        boundary: String
    ) -> Data {
        var data = Data()
        func append(_ s: String) {
            data.append(s.data(using: .utf8)!)
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        append("\r\n--\(boundary)--\r\n")
        return data
    }
}

