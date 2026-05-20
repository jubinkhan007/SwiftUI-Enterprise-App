import SwiftUI
import SharedModels
import DesignSystem
import Domain
import AppNetwork

/// Top-level meetings screen: segmented Upcoming/Today/Past with a "+ schedule" toolbar.
public struct MeetingsHomeView: View {
    public enum Scope: String, CaseIterable, Identifiable {
        case upcoming, today, past
        public var id: String { rawValue }
        var label: String {
            switch self {
            case .upcoming: return "Upcoming"
            case .today: return "Today"
            case .past: return "Past"
            }
        }
    }

    @StateObject private var store: MeetingsStore = .shared
    @State private var scope: Scope = .upcoming
    @State private var showSchedule = false
    @State private var selectedMeetingId: UUID?

    public let currentUserId: UUID
    public let repository: MeetingRepositoryProtocol
    public let realtimeProvider: RealTimeProvider?
    public let availableMembers: [MeetingPickableMember]

    public init(
        currentUserId: UUID,
        repository: MeetingRepositoryProtocol,
        realtimeProvider: RealTimeProvider? = nil,
        availableMembers: [MeetingPickableMember]
    ) {
        self.currentUserId = currentUserId
        self.repository = repository
        self.realtimeProvider = realtimeProvider
        self.availableMembers = availableMembers
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Scope", selection: $scope) {
                ForEach(Scope.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, AppSpacing.sm)

            list
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Meetings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSchedule = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .appFont(AppTypography.title3)
                }
            }
        }
        .task { await load() }
        .onChange(of: scope) { _, _ in
            Task { await load() }
        }
        .refreshable { await load() }
        .sheet(isPresented: $showSchedule) {
            ScheduleMeetingSheet(
                repository: repository,
                availableMembers: availableMembers
            ) { created in
                selectedMeetingId = created.id
            }
            .presentationDetents([.large])
        }
        .navigationDestination(item: $selectedMeetingId) { id in
            MeetingDetailView(
                meetingId: id,
                currentUserId: currentUserId,
                repository: repository,
                realtimeProvider: realtimeProvider,
                availableMembers: availableMembers
            )
        }
    }

    private var list: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(items) { meeting in
                        Button {
                            selectedMeetingId = meeting.id
                        } label: {
                            MeetingsRowView(meeting: meeting, currentUserId: currentUserId)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "calendar.badge.clock")
                .appFont(AppTypography.title1)
                .foregroundColor(AppColors.textSecondary)
            Text(emptyText)
                .appFont(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
            Button("Schedule a meeting") { showSchedule = true }
                .appFont(AppTypography.buttonLabelSmall)
                .padding(.top, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundPrimary)
    }

    private var emptyText: String {
        switch scope {
        case .upcoming: return "No upcoming meetings."
        case .today: return "Nothing on the schedule today."
        case .past: return "No past meetings yet."
        }
    }

    private var items: [MeetingListItemDTO] {
        switch scope {
        case .upcoming: return store.upcoming
        case .today: return store.today
        case .past: return store.past
        }
    }

    private func load() async {
        switch scope {
        case .upcoming: await store.loadUpcoming()
        case .today: await store.loadToday()
        case .past: await store.loadPast()
        }
    }
}

// MARK: - Row

private struct MeetingsRowView: View {
    let meeting: MeetingListItemDTO
    let currentUserId: UUID

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(spacing: 2) {
                Text(monthShort)
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Text(dayNum)
                    .appFont(AppTypography.title3)
                    .foregroundColor(AppColors.brandPrimary)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .appFont(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .appFont(AppTypography.caption2)
                    Text(timeRange)
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                    Text("·").foregroundColor(AppColors.textSecondary)
                    Image(systemName: "person.2.fill")
                        .appFont(AppTypography.caption2)
                    Text("\(meeting.participantCount)")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }

                statusPill
            }

            Spacer()
            if meeting.waitingCount > 0 && (meeting.myRole == .host || meeting.myRole == .coHost) {
                Text("\(meeting.waitingCount) waiting")
                    .appFont(AppTypography.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var dayNum: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: meeting.scheduledStartAt)
    }
    private var monthShort: String {
        let f = DateFormatter(); f.dateFormat = "MMM"
        return f.string(from: meeting.scheduledStartAt).uppercased()
    }
    private var timeRange: String {
        let f = DateFormatter(); f.timeStyle = .short
        return "\(f.string(from: meeting.scheduledStartAt)) – \(f.string(from: meeting.scheduledEndAt))"
    }

    @ViewBuilder
    private var statusPill: some View {
        switch meeting.status {
        case .inProgress:
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("In progress").appFont(AppTypography.caption2).foregroundColor(.green)
            }
        case .cancelled:
            Text("Cancelled").appFont(AppTypography.caption2).foregroundColor(.red)
        case .ended:
            Text("Ended").appFont(AppTypography.caption2).foregroundColor(AppColors.textSecondary)
        case .scheduled:
            if meeting.myInviteStatus == .pending {
                Text("Awaiting your RSVP").appFont(AppTypography.caption2).foregroundColor(.orange)
            } else if meeting.myInviteStatus == .declined {
                Text("You declined").appFont(AppTypography.caption2).foregroundColor(AppColors.textSecondary)
            } else if meeting.myInviteStatus == .tentative {
                Text("Tentative").appFont(AppTypography.caption2).foregroundColor(AppColors.textSecondary)
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Pickable member descriptor

public struct MeetingPickableMember: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String
    public let email: String?

    public init(id: UUID, displayName: String, email: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
    }
}
