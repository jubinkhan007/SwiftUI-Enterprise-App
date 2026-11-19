import SwiftUI
import DesignSystem
import SharedModels

public struct ScheduledMessagesView: View {
    @StateObject private var store: ScheduledMessageStore = .shared
    @State private var statusFilter: String = "scheduled"

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Status", selection: $statusFilter) {
                Text("Scheduled").tag("scheduled")
                Text("Sent").tag("sent")
                Text("Cancelled").tag("cancelled")
                Text("Failed").tag("failed")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, AppSpacing.sm)

            list
        }
        .navigationTitle("Scheduled Messages")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await store.load(status: statusFilter) }
        .onChange(of: statusFilter) { _, new in
            Task { await store.load(status: new) }
        }
        .refreshable { await store.load(status: statusFilter) }
        .background(AppColors.backgroundPrimary)
    }

    private var list: some View {
        Group {
            if store.items.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "clock.arrow.circlepath")
                        .appFont(AppTypography.title1)
                        .foregroundColor(AppColors.textSecondary)
                    Text("Nothing here.").appFont(AppTypography.subheadline).foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.items) { ScheduledRow(item: $0) }
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct ScheduledRow: View {
    let item: ScheduledMessageDTO
    @StateObject private var store: ScheduledMessageStore = .shared
    @State private var showEditSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "paperplane")
                    .foregroundColor(AppColors.brandPrimary)
                Text(formatted(item.scheduledFor))
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(item.status.rawValue.uppercased())
                    .appFont(AppTypography.overline)
                    .foregroundColor(statusColor(item.status))
            }
            Text(item.body)
                .appFont(AppTypography.body)
                .lineLimit(3)
            if let err = item.error, item.status == .failed {
                Text(err).appFont(AppTypography.caption2).foregroundColor(.red)
            }
            if item.status == .scheduled {
                HStack(spacing: AppSpacing.md) {
                    Button("Send now") { Task { _ = await store.sendNow(item.id) } }
                        .appFont(AppTypography.caption1)
                    Button("Edit / Reschedule") {
                        showEditSheet = true
                    }
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.brandPrimary)
                    Button("Cancel", role: .destructive) {
                        Task { _ = await store.cancel(item.id) }
                    }
                    .appFont(AppTypography.caption1)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .sheet(isPresented: $showEditSheet) {
            EditScheduledMessageSheet(item: item)
        }
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }

    private func statusColor(_ status: ScheduledMessageStatus) -> Color {
        switch status {
        case .scheduled: return AppColors.brandPrimary
        case .sending: return .orange
        case .sent: return .green
        case .cancelled: return AppColors.textSecondary
        case .failed: return .red
        }
    }
}

private struct EditScheduledMessageSheet: View {
    let item: ScheduledMessageDTO
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: ScheduledMessageStore = .shared

    @State private var editedBody: String
    @State private var editedDate: Date
    @State private var isSaving: Bool = false

    private let quickPresets: [(label: String, offset: TimeInterval)] = [
        ("In 30m", 1800),
        ("In 2h", 7200),
        ("Tomorrow 9am", 50400),
        ("Next Mon 9am", 259200)
    ]

    init(item: ScheduledMessageDTO) {
        self.item = item
        self._editedBody = State(initialValue: item.body)
        self._editedDate = State(initialValue: max(item.scheduledFor, Date().addingTimeInterval(300)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Message Content") {
                    TextField("Message", text: $editedBody, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Delivery Time") {
                    DatePicker("Send at", selection: $editedDate, in: Date()...)
                    presetButtonsRow
                }
            }
            .navigationTitle("Edit Scheduled Message")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving || editedBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var presetButtonsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPresets, id: \.label) { preset in
                    Button(preset.label) {
                        editedDate = Date().addingTimeInterval(preset.offset)
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

    private func saveChanges() {
        isSaving = true
        let trimmed = editedBody.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            _ = await store.update(
                id: item.id,
                body: trimmed,
                scheduledFor: editedDate
            )
            isSaving = false
            dismiss()
        }
    }
}
