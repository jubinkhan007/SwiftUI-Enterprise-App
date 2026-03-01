import SwiftUI
import Domain
import SharedModels
import DesignSystem
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

public struct TaskDetailView: View {
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var isPreviewingComment = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showErrorAlert = false
    
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
            await viewModel.fetchActivities()
            await viewModel.loadWorkflowIfNeeded()
            await viewModel.fetchAttachments()
            await viewModel.loadOrgMembersIfNeeded()
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
                    ProgressView()
                        .scaleEffect(0.9)
                }
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "paperclip")
                        .foregroundColor(AppColors.brandPrimary)
                }
                .disabled(viewModel.isUploadingAttachment)
            }

            if viewModel.isLoadingAttachments {
                ProgressView()
            } else if viewModel.attachments.isEmpty {
                Text("No attachments yet.")
                    .appFont(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.attachments) { a in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(a.filename)
                                    .appFont(AppTypography.caption1)
                                    .lineLimit(1)
                                Text("\(a.fileType.uppercased()) • \(ByteCountFormatter.string(fromByteCount: a.size, countStyle: .file))")
                                    .appFont(AppTypography.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(8)
                            .background(AppColors.surfacePrimary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppColors.borderDefault, lineWidth: 1)
                            )
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
                        await MainActor.run {
                            viewModel.error = NSError(
                                domain: "TaskDetailView",
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Couldn’t load the selected photo."]
                            )
                        }
                        return
                    }

                    #if canImport(UIKit)
                    if let image = UIImage(data: raw), let jpeg = image.jpegData(compressionQuality: 0.85) {
                        await viewModel.uploadJPEG(jpeg, filename: "photo.jpg")
                    } else {
                        await viewModel.uploadJPEG(raw, filename: "photo.jpg")
                    }
                    #else
                    await viewModel.uploadJPEG(raw, filename: "photo.jpg")
                    #endif
                } catch {
                    await MainActor.run { viewModel.error = error }
                }
                selectedPhotoItem = nil
            }
        }
    }
    
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
                    .task { await viewModel.loadOrgMembersIfNeeded() }
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
        let mention = "@[\(member.displayName)](user:\(member.userId.uuidString)) "
        text.replaceSubrange(freshToken.range, with: mention)
        viewModel.newCommentText = text
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
