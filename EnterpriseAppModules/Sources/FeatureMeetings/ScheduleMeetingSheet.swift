import SwiftUI
import SharedModels
import DesignSystem
import Domain

public struct ScheduleMeetingSheet: View {
    @Environment(\.dismiss) private var dismiss

    let repository: MeetingRepositoryProtocol
    let availableMembers: [MeetingPickableMember]
    let onCreated: (MeetingDTO) -> Void

    @State private var title: String = ""
    @State private var agenda: String = ""
    @State private var description: String = ""
    @State private var start: Date = nextHalfHour()
    @State private var duration: TimeInterval = 30 * 60
    @State private var timezone: String = TimeZone.current.identifier
    @State private var requiresWaitingRoom = true
    @State private var allowGuests = false
    @State private var selectedMemberIds: Set<UUID> = []
    @State private var guestEmailsRaw: String = ""

    @State private var recurrenceFreq: RecurrenceChoice = .none
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceCount: Int = 10
    @State private var recurrenceEnd: Date = Date().addingTimeInterval(60 * 86_400)

    @State private var isSubmitting = false
    @State private var error: String?

    public init(
        repository: MeetingRepositoryProtocol,
        availableMembers: [MeetingPickableMember],
        onCreated: @escaping (MeetingDTO) -> Void
    ) {
        self.repository = repository
        self.availableMembers = availableMembers
        self.onCreated = onCreated
    }

    public var body: some View {
        NavigationStack {
            Form {
                detailsSection
                whenSection
                participantsSection
                recurrenceSection
                settingsSection
                errorSection
            }
            .navigationTitle("New Meeting")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
        }
    }

    // MARK: - Sections

    @ViewBuilder private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $title)
            TextField("Agenda (optional)", text: $agenda, axis: .vertical).lineLimit(3...6)
            TextField("Description (optional)", text: $description, axis: .vertical).lineLimit(2...4)
        }
    }

    @ViewBuilder private var whenSection: some View {
        Section("When") {
            DatePicker("Starts", selection: $start, displayedComponents: [.date, .hourAndMinute])
            Picker("Duration", selection: $duration) {
                ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                    Text("\(mins) min").tag(TimeInterval(mins * 60))
                }
            }
            HStack {
                Text("Time zone")
                Spacer()
                Text(timezone)
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    @ViewBuilder private var participantsSection: some View {
        Section("Invite people") {
            if availableMembers.isEmpty {
                Text("No org members available.")
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(availableMembers) { m in
                    Button {
                        if selectedMemberIds.contains(m.id) {
                            selectedMemberIds.remove(m.id)
                        } else {
                            selectedMemberIds.insert(m.id)
                        }
                    } label: {
                        HStack {
                            Text(m.displayName).foregroundColor(AppColors.textPrimary)
                            Spacer()
                            if selectedMemberIds.contains(m.id) {
                                Image(systemName: "checkmark").foregroundColor(AppColors.brandPrimary)
                            }
                        }
                    }
                }
            }

            if allowGuests {
                TextField("Guest emails (comma-separated)", text: $guestEmailsRaw, axis: .vertical)
                    .lineLimit(1...3)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }
        }
    }

    @ViewBuilder private var recurrenceSection: some View {
        Section("Recurrence") {
            Picker("Repeat", selection: $recurrenceFreq) {
                ForEach(RecurrenceChoice.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            if recurrenceFreq != .none {
                Stepper("Every \(recurrenceInterval) \(recurrenceFreq.unitLabel)", value: $recurrenceInterval, in: 1...10)
                Stepper("End after \(recurrenceCount) occurrences", value: $recurrenceCount, in: 1...100)
            }
        }
    }

    @ViewBuilder private var settingsSection: some View {
        Section("Settings") {
            Toggle("Require waiting room", isOn: $requiresWaitingRoom)
            Toggle("Allow guests via link", isOn: $allowGuests)
        }
    }

    @ViewBuilder private var errorSection: some View {
        if let error {
            Section {
                Text(error).foregroundColor(.red).appFont(AppTypography.caption1)
            }
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            if isSubmitting {
                ProgressView()
            } else {
                Button("Create") {
                    Task { await submit() }
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            error = "Title is required."
            return
        }

        let end = start.addingTimeInterval(duration)
        let recurrence = recurrenceFreq.toDTO(interval: recurrenceInterval, count: recurrenceCount)
        let guestList: [String]? = allowGuests
            ? guestEmailsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            : nil

        let request = CreateMeetingRequest(
            title: trimmedTitle,
            description: description.nilIfEmpty,
            agenda: agenda.nilIfEmpty,
            scheduledStartAt: start,
            scheduledEndAt: end,
            timezone: timezone,
            conversationId: nil,
            memberIds: Array(selectedMemberIds),
            guestEmails: guestList,
            requiresWaitingRoom: requiresWaitingRoom,
            allowGuests: allowGuests,
            recurrence: recurrence
        )

        do {
            let response = try await repository.createMeeting(request)
            if let dto = response.data {
                MeetingsStore.shared.ingest(dto)
                onCreated(dto)
                dismiss()
            } else {
                error = "Could not create meeting."
            }
        } catch let e {
            error = e.localizedDescription
        }
    }
}

// MARK: - Helpers

private func nextHalfHour(from now: Date = Date()) -> Date {
    let cal = Calendar.current
    let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
    var rounded = comps
    if let mins = comps.minute {
        rounded.minute = mins < 30 ? 30 : 0
        if mins >= 30 { rounded.hour = (comps.hour ?? 0) + 1 }
    }
    return cal.date(from: rounded) ?? now.addingTimeInterval(15 * 60)
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

public enum RecurrenceChoice: String, CaseIterable, Hashable {
    case none, daily, weekly, monthly

    var label: String {
        switch self {
        case .none: return "Does not repeat"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
    var unitLabel: String {
        switch self {
        case .daily: return "day(s)"
        case .weekly: return "week(s)"
        case .monthly: return "month(s)"
        case .none: return ""
        }
    }
    func toDTO(interval: Int, count: Int) -> MeetingRecurrenceDTO? {
        switch self {
        case .none: return nil
        case .daily: return MeetingRecurrenceDTO(freq: .daily, interval: interval, count: count)
        case .weekly: return MeetingRecurrenceDTO(freq: .weekly, interval: interval, count: count)
        case .monthly: return MeetingRecurrenceDTO(freq: .monthly, interval: interval, count: count)
        }
    }
}
