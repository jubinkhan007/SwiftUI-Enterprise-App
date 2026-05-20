import SwiftUI
import SharedModels
import DesignSystem
import Domain
import AppNetwork

public struct MeetingDetailView: View {
    @StateObject private var session: MeetingSessionStore
    @StateObject private var calendarSync: CalendarSyncStore = .shared

    @State private var showLobby = false
    @State private var showSummary = false
    @State private var showAddParticipants = false
    @State private var showCancelConfirm = false
    @State private var cancelReason: String = ""

    public let currentUserId: UUID
    public let availableMembers: [MeetingPickableMember]

    public init(
        meetingId: UUID,
        currentUserId: UUID,
        repository: MeetingRepositoryProtocol,
        realtimeProvider: RealTimeProvider? = nil,
        availableMembers: [MeetingPickableMember]
    ) {
        self.currentUserId = currentUserId
        self.availableMembers = availableMembers
        _session = StateObject(wrappedValue: MeetingSessionStore(
            meetingId: meetingId,
            currentUserId: currentUserId,
            repository: repository,
            realtimeProvider: realtimeProvider
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                if let m = session.meeting {
                    headerCard(m)
                    actionRow(m)
                    participantsCard(m)
                    notesCard(m)
                    if m.status == .ended {
                        summaryCard(m)
                    }
                } else {
                    ProgressView().padding(.top, AppSpacing.xxl)
                }
            }
            .padding()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(session.meeting?.title ?? "Meeting")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { detailToolbar }
        .task {
            await session.refresh()
            await session.loadNotes()
            await calendarSync.requestAccessIfNeeded()
        }
        .sheet(isPresented: $showLobby) {
            if let m = session.meeting {
                MeetingLobbyView(session: session, meeting: m)
            }
        }
        .sheet(isPresented: $showSummary) {
            if let m = session.meeting {
                NavigationStack {
                    MeetingSummaryView(session: session, meeting: m)
                }
            }
        }
        .sheet(isPresented: $showAddParticipants) {
            AddParticipantsSheet(
                availableMembers: availableMembers,
                excludedIds: Set(session.meeting?.participants.compactMap { $0.userId } ?? [])
            ) { ids, emails in
                Task { await session.addParticipants(memberIds: ids, guestEmails: emails) }
            }
        }
        .alert("Cancel meeting?", isPresented: $showCancelConfirm) {
            TextField("Reason (optional)", text: $cancelReason)
            Button("Cancel meeting", role: .destructive) {
                Task {
                    _ = await MeetingsStore.shared.cancel(session.meetingId, reason: cancelReason.isEmpty ? nil : cancelReason)
                    await session.refresh()
                }
            }
            Button("Keep meeting", role: .cancel) {}
        } message: {
            Text("Participants who RSVPed will be notified.")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Add to Calendar") {
                    Task {
                        if let m = session.meeting { await calendarSync.upsert(m) }
                    }
                }
                if let urlString = session.meeting?.shareUrl, let url = URL(string: urlString) {
                    Link(destination: url) { Label("Open invite link", systemImage: "link") }
                    ShareLink(item: url) { Label("Share link", systemImage: "square.and.arrow.up") }
                }
                if let icsString = session.meeting?.icsUrl, let url = URL(string: icsString) {
                    Link(destination: url) { Label("Download .ics", systemImage: "square.and.arrow.down") }
                }
                if let m = session.meeting, isHostOrCoHost(m) {
                    Divider()
                    Button("Invite more people…") { showAddParticipants = true }
                    if m.status == .scheduled || m.status == .inProgress {
                        Button("Cancel meeting", role: .destructive) { showCancelConfirm = true }
                    }
                    if m.status == .ended {
                        Button("View summary") { showSummary = true }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Cards

    private func headerCard(_ m: MeetingDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                statusBadge(m.status)
                Spacer()
                Text(m.timezone).appFont(AppTypography.caption2).foregroundColor(AppColors.textSecondary)
            }
            Text(m.title).appFont(AppTypography.title2).foregroundColor(AppColors.textPrimary)
            Text(timeLine(m)).appFont(AppTypography.subheadline).foregroundColor(AppColors.textSecondary)
            if let agenda = m.agenda, !agenda.isEmpty {
                Text(agenda).appFont(AppTypography.body).foregroundColor(AppColors.textPrimary)
            }
            if let desc = m.description, !desc.isEmpty {
                Text(desc).appFont(AppTypography.subheadline).foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .background(AppColors.surfaceElevated)
        .cornerRadius(12)
    }

    private func actionRow(_ m: MeetingDTO) -> some View {
        HStack(spacing: AppSpacing.md) {
            if m.status == .scheduled, let mine = m.myParticipant {
                rsvpButtons(current: mine.inviteStatus)
            }
            if canJoin(m) {
                Button {
                    showLobby = true
                } label: {
                    Label(m.status == .inProgress ? "Join now" : "Lobby", systemImage: "video.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.brandPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            if m.status == .scheduled && isHostOrCoHost(m) {
                Button {
                    Task { await session.start() }
                } label: {
                    Label("Start", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            if m.status == .inProgress && isHostOrCoHost(m) {
                Button {
                    Task { await session.end() }
                } label: {
                    Label("End", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
    }

    private func rsvpButtons(current: MeetingInviteStatus) -> some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach([MeetingInviteStatus.accepted, .tentative, .declined], id: \.self) { status in
                Button {
                    Task { _ = await MeetingsStore.shared.rsvp(session.meetingId, status: status) ; await session.refresh() }
                } label: {
                    Text(rsvpLabel(status))
                        .appFont(AppTypography.caption1)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(current == status ? AppColors.brandPrimary.opacity(0.15) : AppColors.surfacePrimary)
                        .foregroundColor(current == status ? AppColors.brandPrimary : AppColors.textPrimary)
                        .cornerRadius(6)
                }
            }
        }
    }

    private func participantsCard(_ m: MeetingDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Participants (\(m.participants.count))").appFont(AppTypography.headline)
                Spacer()
                if isHostOrCoHost(m) && m.waitingCount > 0 {
                    Text("\(m.waitingCount) waiting")
                        .appFont(AppTypography.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                }
            }
            ForEach(m.participants) { p in
                participantRow(m: m, p: p)
            }
            if isHostOrCoHost(m) {
                Button {
                    showAddParticipants = true
                } label: {
                    Label("Invite more people", systemImage: "person.badge.plus")
                        .appFont(AppTypography.subheadline)
                        .foregroundColor(AppColors.brandPrimary)
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding()
        .background(AppColors.surfaceElevated)
        .cornerRadius(12)
    }

    private func participantRow(m: MeetingDTO, p: MeetingParticipantDTO) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(p.displayName).appFont(AppTypography.body)
                    if p.role == .host { Text("HOST").appFont(AppTypography.overline).foregroundColor(.purple) }
                    else if p.role == .coHost { Text("CO-HOST").appFont(AppTypography.overline).foregroundColor(.purple) }
                    else if p.role == .presenter { Text("PRESENTER").appFont(AppTypography.overline).foregroundColor(.blue) }
                }
                HStack(spacing: 6) {
                    Text(rsvpLabel(p.inviteStatus))
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    if p.joinState == .waiting {
                        Text("· waiting").appFont(AppTypography.caption2).foregroundColor(.orange)
                    } else if p.joinState == .inMeeting {
                        Text("· in meeting").appFont(AppTypography.caption2).foregroundColor(.green)
                    }
                }
            }
            Spacer()
            if isHostOrCoHost(m) && p.joinState == .waiting {
                Button("Admit") { Task { await session.admit(participantId: p.id) } }
                    .appFont(AppTypography.caption1)
                Button("Deny") { Task { await session.deny(participantId: p.id) } }
                    .appFont(AppTypography.caption1)
                    .foregroundColor(.red)
            }
        }
    }

    private func notesCard(_ m: MeetingDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Notes").appFont(AppTypography.headline)
            MeetingNotesEditor(session: session)
        }
        .padding()
        .background(AppColors.surfaceElevated)
        .cornerRadius(12)
    }

    private func summaryCard(_ m: MeetingDTO) -> some View {
        Button {
            Task { await session.loadSummary(); showSummary = true }
        } label: {
            HStack {
                Image(systemName: "doc.text")
                Text(session.summary == nil ? "Generate summary" : "View summary")
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(AppColors.textSecondary)
            }
            .padding()
            .background(AppColors.surfaceElevated)
            .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ s: MeetingStatus) -> some View {
        let (label, color): (String, Color) = {
            switch s {
            case .scheduled: return ("Scheduled", .blue)
            case .inProgress: return ("In progress", .green)
            case .ended: return ("Ended", AppColors.textSecondary)
            case .cancelled: return ("Cancelled", .red)
            }
        }()
        return Text(label)
            .appFont(AppTypography.caption2)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private func timeLine(_ m: MeetingDTO) -> String {
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .short
        let t = DateFormatter(); t.timeStyle = .short
        return "\(f.string(from: m.scheduledStartAt)) – \(t.string(from: m.scheduledEndAt))"
    }

    private func rsvpLabel(_ status: MeetingInviteStatus) -> String {
        switch status {
        case .accepted: return "Going"
        case .declined: return "Declined"
        case .tentative: return "Maybe"
        case .pending: return "Pending"
        }
    }

    private func isHostOrCoHost(_ m: MeetingDTO) -> Bool {
        guard let mine = m.myParticipant else { return false }
        return mine.role == .host || mine.role == .coHost
    }

    private func canJoin(_ m: MeetingDTO) -> Bool {
        switch m.status {
        case .scheduled:
            return m.scheduledStartAt.timeIntervalSinceNow < 15 * 60
        case .inProgress: return true
        case .ended, .cancelled: return false
        }
    }
}

// MARK: - Add participants sheet

private struct AddParticipantsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let availableMembers: [MeetingPickableMember]
    let excludedIds: Set<UUID>
    let onSubmit: ([UUID], [String]?) -> Void

    @State private var selected: Set<UUID> = []
    @State private var guestRaw: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Org members") {
                    ForEach(availableMembers.filter { !excludedIds.contains($0.id) }) { m in
                        Button {
                            if selected.contains(m.id) { selected.remove(m.id) } else { selected.insert(m.id) }
                        } label: {
                            HStack {
                                Text(m.displayName).foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if selected.contains(m.id) {
                                    Image(systemName: "checkmark").foregroundColor(AppColors.brandPrimary)
                                }
                            }
                        }
                    }
                }
                Section("Guests (comma-separated emails)") {
                    TextField("name@example.com", text: $guestRaw)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
            }
            .navigationTitle("Invite People")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Invite") {
                        let guests = guestRaw.split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        onSubmit(Array(selected), guests.isEmpty ? nil : guests)
                        dismiss()
                    }
                    .disabled(selected.isEmpty && guestRaw.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Notes editor

private struct MeetingNotesEditor: View {
    @ObservedObject var session: MeetingSessionStore
    @State private var draft: String = ""
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $draft)
                .frame(minHeight: 100, maxHeight: 240)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppColors.borderDefault, lineWidth: 1)
                )
            HStack {
                if let err = saveError {
                    Text(err).appFont(AppTypography.caption2).foregroundColor(.red)
                }
                Spacer()
                Button {
                    Task {
                        isSaving = true
                        defer { isSaving = false }
                        await session.saveNotes(body: draft)
                        if let updated = session.notes { draft = updated.body }
                    }
                } label: {
                    if isSaving { ProgressView() } else { Text("Save").appFont(AppTypography.buttonLabelSmall) }
                }
                .disabled(isSaving || draft == (session.notes?.body ?? ""))
            }
        }
        .onAppear {
            draft = session.notes?.body ?? ""
        }
        .onChange(of: session.notes?.version ?? 0) { _, _ in
            draft = session.notes?.body ?? draft
        }
    }
}

