import SwiftUI
import DesignSystem
import SharedModels

/// Triggered from the message action sheet — "Remind me about this".
/// Presets cover common reschedule windows; custom reveals a DatePicker.
public struct MessageReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let message: MessageDTO
    let onCreated: (ReminderDTO) -> Void

    @State private var selection: Preset = .in1h
    @State private var customDate: Date = Date().addingTimeInterval(60 * 60)
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var error: String?

    public init(message: MessageDTO, onCreated: @escaping (ReminderDTO) -> Void) {
        self.message = message
        self.onCreated = onCreated
    }

    public enum Preset: String, CaseIterable, Identifiable, Hashable {
        case in15, in1h, in3h, tomorrowMorning, mondayMorning, custom
        public var id: String { rawValue }
        var label: String {
            switch self {
            case .in15: return "In 15 minutes"
            case .in1h: return "In 1 hour"
            case .in3h: return "In 3 hours"
            case .tomorrowMorning: return "Tomorrow morning"
            case .mondayMorning: return "Monday morning"
            case .custom: return "Custom…"
            }
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Remind me at") {
                    Picker("When", selection: $selection) {
                        ForEach(Preset.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    if selection == .custom {
                        DatePicker("Date & time", selection: $customDate, in: Date()...)
                    }
                }
                Section("Note (optional)") {
                    TextField("Add a note", text: $note, axis: .vertical).lineLimit(1...3)
                }
                Section("Message") {
                    Text("\(message.senderName): \(message.body)")
                        .appFont(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(3)
                }
                if let error {
                    Section { Text(error).foregroundColor(.red).appFont(AppTypography.caption1) }
                }
            }
            .navigationTitle("Remind me")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting { ProgressView() }
                    else {
                        Button("Set reminder") {
                            Task { await submit() }
                        }
                    }
                }
            }
        }
    }

    private var remindAt: Date {
        switch selection {
        case .in15: return Date().addingTimeInterval(15 * 60)
        case .in1h: return Date().addingTimeInterval(60 * 60)
        case .in3h: return Date().addingTimeInterval(3 * 60 * 60)
        case .tomorrowMorning: return next(hour: 9, daysAhead: 1)
        case .mondayMorning: return nextMondayMorning()
        case .custom: return customDate
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if let dto = await ReminderStore.shared.createForMessage(messageId: message.id, remindAt: remindAt, body: trimmed) {
            onCreated(dto)
            dismiss()
        } else {
            error = "Could not create reminder."
        }
    }

    private func next(hour: Int, daysAhead: Int) -> Date {
        let cal = Calendar.current
        var target = cal.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date()
        target = cal.date(bySettingHour: hour, minute: 0, second: 0, of: target) ?? target
        return target
    }

    private func nextMondayMorning() -> Date {
        let cal = Calendar.current
        var date = Date()
        for _ in 0..<14 {
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
            if cal.component(.weekday, from: date) == 2 {
                return cal.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
            }
        }
        return date
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
