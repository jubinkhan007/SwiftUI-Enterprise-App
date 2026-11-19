import SwiftUI
import SharedModels
import DesignSystem
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct MessageBubbleView: View {
    let message: MessageDTO
    let isCurrentUser: Bool
    let currentUserId: UUID
    let participantNames: [UUID: String]
    let readers: [UUID]
    let onDelete: (() -> Void)?
    let onEdit: (() -> Void)?
    let onOpenThread: (() -> Void)?
    let onOpenActions: (() -> Void)?

    @ObservedObject private var store: MessageInteractionStore = MessageInteractionStore.shared
    @State private var reactionDetail: ReactionDetailItem?

    public init(
        message: MessageDTO,
        isCurrentUser: Bool,
        currentUserId: UUID = UUID(),
        participantNames: [UUID: String] = [:],
        readers: [UUID] = [],
        onDelete: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onOpenThread: (() -> Void)? = nil,
        onOpenActions: (() -> Void)? = nil
    ) {
        self.message = message
        self.isCurrentUser = isCurrentUser
        self.currentUserId = currentUserId
        self.participantNames = participantNames
        self.readers = readers
        self.onDelete = onDelete
        self.onEdit = onEdit
        self.onOpenThread = onOpenThread
        self.onOpenActions = onOpenActions
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 40)
            } else {
                avatarView
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: AppSpacing.xs) {
                if !isCurrentUser {
                    Text(message.senderName)
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }

                bubbleContent

                if !readers.isEmpty {
                    HStack(spacing: -6) {
                        ForEach(readers, id: \.self) { readerId in
                            let name = participantNames[readerId] ?? "User"
                            Circle()
                                .fill(AppColors.surfaceElevated)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Text(String(name.prefix(1)).uppercased())
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(AppColors.textPrimary)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.backgroundPrimary, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.top, 2)
                }

                messageFooter
            }

            if !isCurrentUser {
                Spacer(minLength: 40)
            }
        }
        .contextMenu {
            if let onOpenThread, message.deletedAt == nil {
                Button(action: onOpenThread) {
                    Label("Reply in Thread", systemImage: "arrowshape.turn.up.left")
                }
            }
            if let onOpenActions {
                Button(action: onOpenActions) {
                    Label("More Actions", systemImage: "ellipsis.circle")
                }
            }
            if let onEdit, message.deletedAt == nil {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete, message.deletedAt == nil {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(item: $reactionDetail) { detail in
            ReactionDetailView(
                emoji: detail.emoji,
                messageId: message.id,
                currentUserId: detail.currentUserId,
                interactionStore: store,
                participantNames: participantNames
            )
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: AppSpacing.sm) {
            // Pinned / Bookmarked badges
            let isPinned = store.pinnedMessages.contains(message.id)
            let isBookmarked = store.bookmarkedMessages.contains(message.id)
            if (isPinned || isBookmarked) && message.deletedAt == nil {
                HStack(spacing: AppSpacing.xs) {
                    if isPinned {
                        Label("Pinned", systemImage: "pin.fill")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.75) : AppColors.brandPrimary)
                    }
                    if isBookmarked {
                        Label("Saved", systemImage: "bookmark.fill")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.75) : AppColors.brandPrimary)
                    }
                }
                .labelStyle(.titleAndIcon)
            }

            if message.deletedAt != nil {
                Text("This message was deleted")
                    .appFont(AppTypography.body)
                    .italic()
                    .foregroundColor(AppColors.textSecondary)
            } else {
                richBodyView(for: message.body)

                if let url = firstURL(in: message.body) {
                    LinkPreviewCard(url: url)
                        .padding(.top, 4)
                }

                if let linkedTask = message.linkedTask {
                    TaskPreviewCard(task: linkedTask)
                }

                if message.replyCount > 0, let onOpenThread {
                    Button(action: onOpenThread) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "text.bubble")
                            Text(threadPreviewText)
                                .lineLimit(1)
                        }
                        .appFont(AppTypography.caption1)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.9) : AppColors.brandPrimary)
                    }
                    .buttonStyle(.plain)
                }

                let reactions = store.reactionSummary(for: message.id)
                if !reactions.isEmpty {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(reactions, id: \.emoji) { reaction in
                            Button {
                                reactionDetail = ReactionDetailItem(emoji: reaction.emoji, currentUserId: currentUserId)
                            } label: {
                                Text("\(reaction.emoji) \(reaction.count)")
                                    .appFont(AppTypography.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.backgroundPrimary.opacity(isCurrentUser ? 0.18 : 1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Remove my reaction", role: .destructive) {
                                    Task { await store.toggleReaction(reaction.emoji, for: message.id) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(message.deletedAt == nil
            ? (isCurrentUser ? AppColors.brandPrimary : AppColors.surfaceElevated)
            : AppColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var messageFooter: some View {
        HStack(spacing: 4) {
            if message.editedAt != nil && message.deletedAt == nil {
                Text("(edited)")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            if let date = message.createdAt {
                Text(date, style: .time)
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            if isCurrentUser && message.deletedAt == nil {
                HStack(spacing: -5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(readers.isEmpty ? AppColors.textSecondary : Color(.systemGreen))
            }
        }
    }

    private func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector?.firstMatch(in: text, options: [], range: range) else { return nil }
        return match.url
    }

    private var threadPreviewText: String {
        var base = "\(message.replyCount) repl\(message.replyCount == 1 ? "y" : "ies")"
        if let lastReplyAt = message.lastReplyAt {
            base += " • \(relativeTimeString(from: lastReplyAt))"
        }
        if let preview = message.threadPreviewText, !preview.isEmpty {
            base += ": \(preview)"
        }
        return base
    }

    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var avatarView: some View {
        Circle()
            .fill(AppColors.surfaceElevated)
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(message.senderName.prefix(1)).uppercased())
                    .appFont(AppTypography.caption1)
            )
    }

    // MARK: - Rich Code & Table Segment Parser

    private enum MessageBlockSegment: Identifiable {
        case text(id: Int, content: String)
        case codeBlock(id: Int, language: String, code: String)
        case table(id: Int, headers: [String], rows: [[String]])

        var id: Int {
            switch self {
            case .text(let id, _), .codeBlock(let id, _, _), .table(let id, _, _):
                return id
            }
        }
    }

    private func parseSegments(from raw: String) -> [MessageBlockSegment] {
        var segments: [MessageBlockSegment] = []
        var nextId = 0
        let parts = raw.components(separatedBy: "```")

        for (index, part) in parts.enumerated() {
            if index % 2 == 1 {
                // Inside fenced code block
                let lines = part.components(separatedBy: "\n")
                let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let hasLang = !firstLine.isEmpty && !firstLine.contains(" ") && lines.count > 1
                let lang = hasLang ? firstLine : "code"
                let codeBody = (hasLang ? Array(lines.dropFirst()) : lines)
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .newlines)
                segments.append(.codeBlock(id: nextId, language: lang, code: codeBody))
                nextId += 1
            } else {
                // Parse markdown tables vs plain text
                let lines = part.components(separatedBy: "\n")
                var textBuffer: [String] = []
                var tableBuffer: [String] = []

                func flushText() {
                    let joined = textBuffer.joined(separator: "\n").trimmingCharacters(in: .newlines)
                    if !joined.isEmpty {
                        segments.append(.text(id: nextId, content: joined))
                        nextId += 1
                    }
                    textBuffer.removeAll()
                }

                func flushTable() {
                    guard tableBuffer.count >= 2 else {
                        textBuffer.append(contentsOf: tableBuffer)
                        tableBuffer.removeAll()
                        return
                    }
                    let parsedRows = tableBuffer.map { line -> [String] in
                        line.trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                            .components(separatedBy: "|")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                    }
                    let headers = parsedRows.first ?? []
                    let dataRows = parsedRows.dropFirst().filter { row in
                        !row.allSatisfy { cell in
                            cell.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
                        }
                    }
                    segments.append(.table(id: nextId, headers: headers, rows: Array(dataRows)))
                    nextId += 1
                    tableBuffer.removeAll()
                }

                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count > 2 {
                        flushText()
                        tableBuffer.append(trimmed)
                    } else {
                        if !tableBuffer.isEmpty {
                            flushTable()
                        }
                        textBuffer.append(line)
                    }
                }
                if !tableBuffer.isEmpty { flushTable() }
                flushText()
            }
        }

        if segments.isEmpty {
            return [.text(id: 0, content: raw)]
        }
        return segments
    }

    @ViewBuilder
    private func richBodyView(for raw: String) -> some View {
        let segments = parseSegments(from: raw)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(segments) { seg in
                switch seg {
                case .text(_, let content):
                    Text(LocalizedStringKey(content))
                        .appFont(AppTypography.body)
                        .foregroundColor(isCurrentUser ? .white : AppColors.textPrimary)

                case .codeBlock(_, let language, let code):
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(language.uppercased())
                                .appFont(AppTypography.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.75))
                            Spacer()
                            Button {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = code
                                #elseif os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(code, forType: .string)
                                #endif
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .appFont(AppTypography.caption2)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(code)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                case .table(_, let headers, let rows):
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                                Text(header)
                                    .appFont(AppTypography.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(isCurrentUser ? .white : AppColors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(6)
                            }
                        }
                        .background(Color.black.opacity(0.18))

                        ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                            Divider()
                            HStack(spacing: 0) {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                    Text(cell)
                                        .appFont(AppTypography.caption2)
                                        .foregroundColor(isCurrentUser ? .white.opacity(0.92) : AppColors.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(6)
                                }
                            }
                            .background(rowIdx % 2 == 0 ? Color.clear : Color.black.opacity(0.07))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ReactionDetailItem: Identifiable {
    let id = UUID()
    let emoji: String
    let currentUserId: UUID
}
