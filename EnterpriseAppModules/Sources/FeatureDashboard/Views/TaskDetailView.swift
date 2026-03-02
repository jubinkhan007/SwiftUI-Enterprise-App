import SwiftUI
import Domain
import SharedModels
import DesignSystem
import PhotosUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
import QuickLook
#endif
#if os(macOS)
import AppKit
#endif

public struct TaskDetailView: View {
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var isPreviewingComment = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showErrorAlert = false
    @State private var showFilePicker = false
    @State private var previewItem: AttachmentPreviewItem? = nil
    
    public init(viewModel: TaskDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.hasConflict {
                    conflictBanner
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        taskHeader
                        Divider()
                        taskDescription
                        Divider()
                        attachmentsSection
                        Divider()
                        activitySection
                    }
                    .padding()
                }
                
                commentInputArea
            }
            
            if viewModel.isSaving {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .padding()
                        .background(AppColors.surfacePrimary)
                        .cornerRadius(8)
                }
            }
        }
        .navigationTitle("Task Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task { await viewModel.saveChanges() }
                }) {
                    Text("Save")
                        .appFont(AppTypography.headline)
                        .foregroundColor(viewModel.isSaving ? AppColors.textTertiary : AppColors.brandPrimary)
                }
                .disabled(viewModel.isSaving)
            }
        }
        .task {
            // Run independent fetches in parallel so one slow/failing call
            // does not delay the others (e.g. attachment timeout blocking orgMembers load).
            async let _activities: Void = viewModel.fetchActivities()
            async let _workflow: Void = viewModel.loadWorkflowIfNeeded()
            async let _attachments: Void = viewModel.fetchAttachments()
            async let _members: Void = viewModel.loadOrgMembersIfNeeded()
            _ = await (_activities, _workflow, _attachments, _members)
            // startRealtime uses workflowProjectId set by loadWorkflowIfNeeded, so run after.
            await viewModel.startRealtime()
        }
        .onDisappear {
            viewModel.stopRealtime()
        }
        .onChange(of: viewModel.error != nil) { _, hasError in
            showErrorAlert = hasError
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "Something went wrong.")
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf, .plainText, .commaSeparatedText, .json, .zip],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await viewModel.uploadFile(url: url) }
        }
        .background(previewPresenter)
    }

    // Presents the downloaded file — QuickLook sheet on iOS, default app on macOS.
    @ViewBuilder private var previewPresenter: some View {
        #if canImport(UIKit)
        Color.clear.sheet(item: $previewItem) { item in
            QuickLookSheet(url: item.url).ignoresSafeArea()
        }
        #else
        Color.clear.onChange(of: previewItem) { _, item in
            if let url = item?.url {
                NSWorkspace.shared.open(url)
                previewItem = nil
            }
        }
        #endif
    }
    
    // MARK: - Components
    
    private var conflictBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Conflict detected! Another user modified this task. Please refresh.")
                .appFont(AppTypography.subheadline)
            Spacer()
        }
        .padding()
        .background(AppColors.statusError.opacity(0.2))
        .foregroundColor(AppColors.statusError)
    }
    
    private var taskHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            AppTextField("Title", text: $viewModel.editTitle)
            
            HStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading) {
                    Text("Status")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                    if !viewModel.workflowStatuses.isEmpty {
                        Picker("Status", selection: $viewModel.editStatusId) {
                            ForEach(viewModel.workflowStatuses) { status in
                                Text(status.name).tag(Optional(status.id))
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Picker("Status", selection: $viewModel.editStatus) {
                            ForEach(TaskStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Priority")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                    Picker("Priority", selection: $viewModel.editPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
    
    private var taskDescription: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Description")
                .appFont(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)
            
            TextEdit(text: $viewModel.editDescription)
                .frame(minHeight: 100)
                .padding()
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.borderDefault, lineWidth: 1)
                )
        }
    }
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Activity")
                .appFont(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            if viewModel.isLoadingActivities {
                ProgressView()
            } else if viewModel.activities.isEmpty {
                Text("No activity yet.")
                    .appFont(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(viewModel.activities) { activity in
                    ActivityRow(activity: activity)
                }
            }
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Attachments\(viewModel.attachments.isEmpty ? "" : " (\(viewModel.attachments.count))")")
                    .appFont(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()

                if viewModel.isUploadingAttachment {
                    ProgressView().scaleEffect(0.9)
                }

                // File picker (PDFs, Docs, etc.)
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(AppColors.brandPrimary)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isUploadingAttachment)

                // Photo picker (images)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .foregroundColor(AppColors.brandPrimary)
                }
                .disabled(viewModel.isUploadingAttachment)
            }

            if viewModel.isLoadingAttachments {
                ProgressView()
            } else if let error = viewModel.attachmentsLoadError, viewModel.attachments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Couldn’t load attachments.")
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                    Text(error.localizedDescription)
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(2)

                    Button("Retry") {
                        Task { await viewModel.fetchAttachments() }
                    }
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.brandPrimary)
                }
            } else if viewModel.attachments.isEmpty {
                Text("No attachments yet.")
                    .appFont(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.attachments) { a in
                            AttachmentCard(
                                attachment: a,
                                isDownloading: viewModel.downloadingAttachmentId == a.id
                            ) {
                                Task {
                                    if let url = await viewModel.downloadAttachment(a) {
                                        #if canImport(UIKit)
                                        previewItem = AttachmentPreviewItem(url: url)
                                        #else
                                        NSWorkspace.shared.open(url)
                                        #endif
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                do {
                    guard let raw = try await newValue.loadTransferable(type: Data.self) else {
                        DispatchQueue.main.async {
                            viewModel.error = NSError(
                                domain: "TaskDetailView",
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Couldn’t load the selected photo."]
                            )
                        }
                        return
                    }
                    #if canImport(UIKit)
                    let maxBytes = 24 * 1024 * 1024
                    if let jpeg = compressForUpload(raw, maxBytes: maxBytes) {
                        if jpeg.count > maxBytes {
                            DispatchQueue.main.async {
                                viewModel.error = NSError(
                                    domain: "TaskDetailView",
                                    code: 2,
                                    userInfo: [NSLocalizedDescriptionKey: "Image is too large to upload (max 25MB)."]
                                )
                            }
                        } else {
                            await viewModel.uploadJPEG(jpeg, filename: "photo.jpg")
                        }
                    } else {
                        DispatchQueue.main.async {
                            viewModel.error = NSError(
                                domain: "TaskDetailView",
                                code: 3,
                                userInfo: [NSLocalizedDescriptionKey: "Couldn’t process the selected photo."]
                            )
                        }
                    }
                    #else
                    await viewModel.uploadJPEG(raw, filename: "photo.jpg")
                    #endif
                } catch {
                    DispatchQueue.main.async { viewModel.error = error }
                }
                selectedPhotoItem = nil
            }
        }
    }

    #if canImport(UIKit)
    private func compressForUpload(_ data: Data, maxBytes: Int) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let w = image.size.width
            let h = image.size.height
            let longest = max(w, h)
            guard longest > maxDimension else { return image }
            let scale = maxDimension / longest
            let newSize = CGSize(width: max(1, w * scale), height: max(1, h * scale))
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        var current = resize(image, maxDimension: 2560)
        var quality: CGFloat = 0.85
        var best = current.jpegData(compressionQuality: quality)

        // Reduce quality first.
        while let d = best, d.count > maxBytes, quality > 0.35 {
            quality -= 0.1
            best = current.jpegData(compressionQuality: quality)
        }

        // If still too large, progressively downscale.
        while let d = best, d.count > maxBytes {
            let newSize = CGSize(width: current.size.width * 0.8, height: current.size.height * 0.8)
            if newSize.width < 600 || newSize.height < 600 { break }

            let renderer = UIGraphicsImageRenderer(size: newSize)
            current = renderer.image { _ in
                current.draw(in: CGRect(origin: .zero, size: newSize))
            }

            quality = min(quality, 0.75)
            best = current.jpegData(compressionQuality: quality)
            while let d2 = best, d2.count > maxBytes, quality > 0.35 {
                quality -= 0.1
                best = current.jpegData(compressionQuality: quality)
            }
        }

        return best
    }
    #endif
    
    private var commentInputArea: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Button(isPreviewingComment ? "Edit" : "Preview") {
                    isPreviewingComment.toggle()
                }
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.brandPrimary)
                Spacer()
            }

            if isPreviewingComment {
                let rendered = (try? AttributedString(markdown: viewModel.newCommentText)) ?? AttributedString(viewModel.newCommentText)
                ScrollView {
                    Text(rendered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
                .padding()
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.borderDefault, lineWidth: 1)
                )
            } else {
                AppTextField("Add a comment... (Markdown supported)", text: $viewModel.newCommentText)
            }

            if !isPreviewingComment, let token = currentMentionToken(in: viewModel.newCommentText) {
                mentionSuggestions(token: token)
            }

            HStack {
                Spacer()
                Button(action: {
                    Task { await viewModel.submitComment() }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(viewModel.newCommentText.isEmpty ? AppColors.textTertiary : AppColors.brandPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .disabled(viewModel.newCommentText.isEmpty || viewModel.isSubmittingComment)
            }
        }
        .padding()
        .background(AppColors.surfacePrimary)
        .shadow(color: Color.black.opacity(0.1), radius: 3, y: -2)
    }

    // MARK: - Mention Suggestions

    private struct MentionToken {
        let range: Range<String.Index>
        let query: String
    }

    private func currentMentionToken(in text: String) -> MentionToken? {
        guard let at = text.lastIndex(of: "@") else { return nil }

        if at > text.startIndex {
            let prev = text.index(before: at)
            let p = text[prev]
            // Avoid triggering inside words/emails like "foo@bar".
            if p.isLetter || p.isNumber || p == "_" {
                return nil
            }
        }

        let afterAt = text.index(after: at)
        var end = afterAt
        while end < text.endIndex {
            let ch = text[end]
            if ch.isWhitespace || ch == "\n" {
                break
            }
            end = text.index(after: end)
        }

        let query = String(text[afterAt..<end])
        return MentionToken(range: at..<end, query: query)
    }

    @ViewBuilder
    private func mentionSuggestions(token: MentionToken) -> some View {
        let q = token.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidates = viewModel.orgMembers
            .filter { q.isEmpty || $0.displayName.lowercased().contains(q) || $0.email.lowercased().contains(q) }
            .prefix(6)

        if viewModel.isLoadingOrgMembers {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading people…")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
            .padding(10)
            .background(AppColors.surfaceElevated)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.borderDefault, lineWidth: 1)
            )
        } else if !candidates.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(candidates), id: \.id) { member in
                    Button {
                        insertMention(member: member, token: token)
                    } label: {
                        HStack {
                            Text(member.displayName)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(member.email)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                        .appFont(AppTypography.caption1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(AppColors.surfaceElevated)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.borderDefault, lineWidth: 1)
            )
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.orgMembers.isEmpty ? "No people available to mention." : "No matches.")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textSecondary)

                if let err = viewModel.orgMembersLoadError {
                    Text(err.localizedDescription)
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(2)
                }

                Button("Reload") {
                    Task { await viewModel.reloadOrgMembers() }
                }
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.brandPrimary)
            }
            .padding(10)
            .background(AppColors.surfaceElevated)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.borderDefault, lineWidth: 1)
            )
        }
    }

    private func insertMention(member: OrganizationMemberDTO, token: MentionToken) {
        guard let freshToken = currentMentionToken(in: viewModel.newCommentText) else { return }
        var text = viewModel.newCommentText
        // Plain-text display: "@Full Name " — UUID is tracked separately.
        text.replaceSubrange(freshToken.range, with: "@\(member.displayName) ")
        viewModel.newCommentText = text
        viewModel.addPendingMention(userId: member.userId)
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let activity: TaskActivityDTO
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: activity.type == .comment ? "bubble.left.fill" : "arrow.triangle.2.circlepath")
                .foregroundColor(AppColors.brandPrimary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("User \(activity.userId.uuidString.prefix(4))") // Mocking user string
                    .appFont(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                if let content = activity.content, activity.type == .comment {
                    let rendered = (try? AttributedString(markdown: content)) ?? AttributedString(content)
                    Text(rendered)
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    Text(activity.type.rawValue.capitalized)
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .italic()
                }
                
                Text(activity.createdAt, style: .time)
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, AppSpacing.sm)
    }
}

// TextEdit wrapper for multiline TextField
struct TextEdit: View {
    @Binding var text: String

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            TextField("Task description...", text: $text, axis: .vertical)
                .lineLimit(5...)
        } else {
            TextEditor(text: $text)
        }
    }
}

// MARK: - Attachment Preview Item

/// Identifiable wrapper so `sheet(item:)` can present a downloaded file URL.
struct AttachmentPreviewItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - Attachment Card

struct AttachmentCard: View {
    let attachment: AttachmentDTO
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: fileIcon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                Spacer()
                Button(action: onDownload) {
                    if isDownloading {
                        ProgressView().scaleEffect(0.75).frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.title3)
                            .foregroundColor(AppColors.brandPrimary)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isDownloading)
            }

            Text(attachment.filename)
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(attachment.fileType.uppercased()) • \(formattedSize)")
                .appFont(AppTypography.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(10)
        .frame(width: 130, alignment: .leading)
        .background(AppColors.surfacePrimary)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.borderDefault, lineWidth: 1))
    }

    private var fileIcon: String {
        switch attachment.fileType.lowercased() {
        case "image":    return "photo.fill"
        case "document": return attachment.mimeType.contains("pdf") ? "doc.richtext.fill" : "doc.text.fill"
        case "archive":  return "archivebox.fill"
        default:         return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch attachment.fileType.lowercased() {
        case "image":    return .green
        case "document": return attachment.mimeType.contains("pdf") ? .red : .blue
        case "archive":  return .orange
        default:         return .gray
        }
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: attachment.size, countStyle: .file)
    }
}

// MARK: - QuickLook Sheet (iOS only)

#if canImport(UIKit)
private struct QuickLookSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}
#endif
