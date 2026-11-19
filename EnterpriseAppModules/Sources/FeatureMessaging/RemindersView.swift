import SwiftUI
import DesignSystem
import SharedModels

public struct RemindersView: View {
    @StateObject private var store: ReminderStore = .shared
    @State private var statusFilter: ReminderFilter = .upcoming
    @State private var showCreate = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Status", selection: $statusFilter) {
                ForEach(ReminderFilter.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, AppSpacing.sm)

            list
        }
        .navigationTitle("Reminders")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await store.load() }
        .refreshable { await store.load() }
        .sheet(isPresented: $showCreate) {
            CreateReminderSheet()
        }
        .background(AppColors.backgroundPrimary)
    }

    private var list: some View {
        Group {
            if filtered.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filtered) { reminder in
                        ReminderRow(reminder: reminder)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "bell")
                .appFont(AppTypography.title1)
                .foregroundColor(AppColors.textSecondary)
            Text("No reminders").appFont(AppTypography.subheadline).foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filtered: [ReminderDTO] {
        switch statusFilter {
        case .upcoming: return store.items.filter { $0.status == .pending }
        case .fired: return store.items.filter { $0.status == .fired }
        case .dismissed: return store.items.filter { $0.status == .dismissed }
        }
    }
}

private struct ReminderRow: View {
    let reminder: ReminderDTO
    @StateObject private var store: ReminderStore = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "bell.fill").foregroundColor(AppColors.brandPrimary)
                Text(formatted(reminder.remindAt))
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                if reminder.status == .fired {
                    Text("FIRED").appFont(AppTypography.overline).foregroundColor(.orange)
                }
            }
            Text(reminder.body).appFont(AppTypography.body)

            HStack(spacing: AppSpacing.sm) {
                if reminder.status != .dismissed {
                    Button("+15m") { Task { _ = await store.snooze(reminder.id, minutes: 15) } }
                        .appFont(AppTypography.caption1)
                    Button("+1h") { Task { _ = await store.snooze(reminder.id, minutes: 60) } }
                        .appFont(AppTypography.caption1)
                    Button("+3h") { Task { _ = await store.snooze(reminder.id, minutes: 180) } }
                        .appFont(AppTypography.caption1)
                    Button("Tomorrow") { Task { _ = await store.snooze(reminder.id, minutes: 1440) } }
                        .appFont(AppTypography.caption1)
                    Button("Done") { Task { _ = await store.dismiss(reminder.id) } }
                        .appFont(AppTypography.caption1)
                        .foregroundColor(.green)
                }
                Spacer()
                Button(role: .destructive) {
                    Task { await store.delete(reminder.id) }
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }
}

public enum ReminderFilter: String, CaseIterable, Identifiable, Hashable {
    case upcoming, fired, dismissed
    public var id: String { rawValue }
    var label: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .fired: return "Fired"
        case .dismissed: return "Dismissed"
        }
    }
}

// MARK: - Create

public struct CreateReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: ReminderStore = .shared

    @State private var text: String = ""
    @State private var remindAt: Date = Date().addingTimeInterval(60 * 60)
    @State private var isSubmitting = false
    @State private var error: String?

    private let quickPresets: [(label: String, offset: TimeInterval)] = [
        ("In 20m", 1200),
        ("In 1h", 3600),
        ("In 3h", 10800),
        ("Tomorrow 9am", 50400)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("What do you want to be reminded about?") {
                    TextField("Description", text: $text, axis: .vertical).lineLimit(2...4)
                }
                Section("When") {
                    DatePicker("Remind me at", selection: $remindAt, in: Date()...)
                    presetButtonsRow
                }
                if let error {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle("New reminder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting { ProgressView() }
                    else {
                        Button("Create") {
                            submitReminder()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private var presetButtonsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPresets, id: \.label) { preset in
                    Button(preset.label) {
                        remindAt = Date().addingTimeInterval(preset.offset)
                    }
                    .appFont(AppTypography.caption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(8)
                }
            }
        }
    }

    private func submitReminder() {
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { error = "Description is required."; return }
            if let _ = await store.create(body: trimmed, remindAt: remindAt) {
                dismiss()
            } else {
                error = "Could not create reminder."
            }
        }
    }
}
