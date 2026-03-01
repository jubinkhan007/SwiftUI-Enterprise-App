import Fluent
import NIOCore
import SharedModels
import Vapor

/// Secure attachment upload/list/download. No public URLs; downloads are streamed through auth.
struct AttachmentController: RouteCollection {
    private enum Constants {
        static let maxUploadBytes = 25 * 1024 * 1024
        static let storageFolder = "PrivateStorage"
    }

    func boot(routes: any RoutesBuilder) throws {
        // OrgTenantMiddleware is already applied by the parent route group (orgScopedAPI).
        // Do NOT add it again here — double middleware means double DB membership queries.
        let task = routes.grouped("tasks", ":taskID")
        task.get("attachments", use: listForTask)
        task.post("attachments", use: uploadToTask)

        routes.grouped("attachments", ":attachmentID").get("download", use: download)
    }

    // MARK: - GET /api/tasks/:taskID/attachments

    @Sendable
    func listForTask(req: Request) async throws -> APIResponse<[AttachmentDTO]> {
        let ctx = try req.orgContext
        let taskId = try requireTaskId(req)
        _ = try await requireTaskInOrg(taskId: taskId, orgId: ctx.orgId, db: req.db)

        let rows = try await AttachmentModel.query(on: req.db)
            .filter(\.$task.$id == taskId)
            .filter(\.$organization.$id == ctx.orgId)
            .sort(\.$createdAt, .descending)
            .all()

        let dtos = rows.compactMap { row -> AttachmentDTO? in
            guard let id = row.id else { return nil }
            return AttachmentDTO(
                id: id,
                taskId: row.$task.id,
                orgId: row.$organization.id,
                filename: row.filename,
                fileType: row.fileType,
                mimeType: row.mimeType,
                size: row.size,
                createdAt: row.createdAt
            )
        }
        return .success(dtos)
    }

    // MARK: - POST /api/tasks/:taskID/attachments

    private struct UploadPayload: Content {
        var file: File
    }

    @Sendable
    func uploadToTask(req: Request) async throws -> APIResponse<AttachmentDTO> {
        let ctx = try req.orgContext
        let taskId = try requireTaskId(req)
        let task = try await requireTaskInOrg(taskId: taskId, orgId: ctx.orgId, db: req.db)

        let payload = try req.content.decode(UploadPayload.self)
        let filename = sanitizeFilename(payload.file.filename)
        let size = Int64(payload.file.data.readableBytes)

        guard size > 0 else {
            throw Abort(.badRequest, reason: "Empty file.")
        }
        guard size <= Int64(Constants.maxUploadBytes) else {
            throw Abort(.payloadTooLarge, reason: "File too large. Max is 25MB.")
        }

        let (fileType, mimeType) = try inferTypeAndMime(from: filename)

        let uuid = UUID().uuidString
        let storageKey = "org/\(ctx.orgId.uuidString)/tasks/\(taskId.uuidString)/\(uuid)_\(filename)"
        let absolutePath = storagePath(for: storageKey, workingDirectory: req.application.directory.workingDirectory)

        try ensureDirectoryExists(forFilePath: absolutePath)
        var buffer = payload.file.data
        guard let data = buffer.readData(length: buffer.readableBytes) else {
            throw Abort(.badRequest, reason: "Invalid file payload.")
        }
        try data.write(to: URL(fileURLWithPath: absolutePath), options: [.atomic])

        let row = AttachmentModel(
            taskId: taskId,
            orgId: ctx.orgId,
            filename: filename,
            fileType: fileType,
            mimeType: mimeType,
            size: size,
            storageKey: storageKey
        )
        try await row.save(on: req.db)

        let id = try row.requireID()
        let dto = AttachmentDTO(
            id: id,
            taskId: taskId,
            orgId: ctx.orgId,
            filename: filename,
            fileType: fileType,
            mimeType: mimeType,
            size: size,
            createdAt: row.createdAt
        )

        // Broadcast to realtime channels (best-effort).
        RealtimeBroadcaster.broadcastAttachmentCreated(
            app: req.application,
            orgId: ctx.orgId,
            task: task,
            attachmentId: id
        )

        return .success(dto)
    }

    // MARK: - GET /api/attachments/:attachmentID/download

    @Sendable
    func download(req: Request) async throws -> Response {
        let ctx = try req.orgContext
        guard let attachmentId = req.parameters.get("attachmentID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid attachment ID.")
        }

        guard let row = try await AttachmentModel.find(attachmentId, on: req.db) else {
            throw Abort(.notFound, reason: "Attachment not found.")
        }
        guard row.$organization.id == ctx.orgId else {
            throw Abort(.forbidden, reason: "Access denied.")
        }

        // Ensure task still belongs to org (defense in depth).
        _ = try await requireTaskInOrg(taskId: row.$task.id, orgId: ctx.orgId, db: req.db)

        let absolutePath = storagePath(for: row.storageKey, workingDirectory: req.application.directory.workingDirectory)

        var response = req.fileio.streamFile(at: absolutePath)
        response.headers.replaceOrAdd(name: HTTPHeaders.Name("Content-Type"), value: row.mimeType)
        response.headers.replaceOrAdd(
            name: HTTPHeaders.Name("Content-Disposition"),
            value: "attachment; filename=\"\(row.filename)\""
        )
        return response
    }

    // MARK: - Helpers

    private func requireTaskId(_ req: Request) throws -> UUID {
        guard let taskId = req.parameters.get("taskID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Task ID.")
        }
        return taskId
    }

    private func requireTaskInOrg(taskId: UUID, orgId: UUID, db: Database) async throws -> TaskItemModel {
        guard let task = try await TaskItemModel.query(on: db)
            .filter(\.$id == taskId)
            .filter(\.$organization.$id == orgId)
            .first()
        else {
            throw Abort(.notFound, reason: "Task not found in this organization.")
        }
        return task
    }

    private func storagePath(for storageKey: String, workingDirectory: String) -> String {
        let base = workingDirectory.hasSuffix("/") ? workingDirectory : workingDirectory + "/"
        return base + Constants.storageFolder + "/" + storageKey
    }

    private func ensureDirectoryExists(forFilePath path: String) throws {
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
    }

    private func sanitizeFilename(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutSlashes = trimmed.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "\\", with: "_")
        return withoutSlashes.isEmpty ? "file" : withoutSlashes
    }

    private func inferTypeAndMime(from filename: String) throws -> (fileType: String, mimeType: String) {
        let ext = (filename.split(separator: ".").last ?? "").lowercased()
        switch ext {
        case "png":
            return ("image", "image/png")
        case "jpg", "jpeg":
            return ("image", "image/jpeg")
        case "pdf":
            return ("document", "application/pdf")
        case "txt":
            return ("document", "text/plain")
        case "csv":
            return ("document", "text/csv")
        case "json":
            return ("document", "application/json")
        case "zip":
            return ("archive", "application/zip")
        default:
            throw Abort(.unsupportedMediaType, reason: "Unsupported file type.")
        }
    }
}
