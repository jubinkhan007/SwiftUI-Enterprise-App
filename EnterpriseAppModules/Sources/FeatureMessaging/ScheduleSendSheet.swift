import SwiftUI
import DesignSystem
import SharedModels

/// Sheet for scheduling a message send. Presets cover the common cases;
/// "Custom" reveals a DatePicker for exact times.
public struct ScheduleSendSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let messageBody: String
    public let conversationId: UUID
    public let parentId: UUID?
    public let onScheduled: (ScheduledMessageDTO) -> Void

    @State private var selection: Preset = .later9am
    @State private var customDate: Date = Date().addingTimeInterval(60 * 60)
    @State private var isSubmitting = false
    @State private var error: String?

    public init(
        messageBody: String,
        conversationId: UUID,
        parentId: UUID? = nil,
        onScheduled: @escaping (ScheduledMessageDTO) -> Void
    ) {
        self.messageBody = messageBody
        self.conversationId = conversationId
        self.parentId = parentId
        self.onScheduled = onScheduled
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Send at") {
                    Picker("When", selection: $selection) {
                        ForEach(Preset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .pickerStyle(.inline)
                    if selection == .custom {
                        DatePicker("Date & time", selection: $customDate, in: Date()...)
                    }
                }

                Section("Preview") {
                    Text(messageBody.isEmpty ? "(empty message)" : messageBody)
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Will send at \(formatted(scheduledFor))")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }

                if let error {
                    Section {
                        Text(error).foregroundColor(.red).appFont(AppTypography.caption1)
                    }
                }
            }
            .navigationTitle("Schedule send")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting { ProgressView() }
                    else {
                        Button("Schedule") {
                            Task { await submit() }
                        }
                        .disabled(messageBody.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private var scheduledFor: Date {
        switch selection {
        case .in15: return Date().addingTimeInterval(15 * 60)
        case .in1h: return Date().addingTimeInterval(60 * 60)
        case .later9am: return next(hour: 9)
        case .tomorrow9am: return next(hour: 9, daysAhead: 1)
        case .mondayMorning: return nextMondayMorning()
        case .custom: return customDate
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        guard scheduledFor > Date() else {
            error = "Scheduled time must be in the future."
            return
        }
        let result = await ScheduledMessageStore.shared.schedule(
            conversationId: conversationId, body: messageBody, parentId: parentId, scheduledFor: scheduledFor
        )
        if let dto = result {
            onScheduled(dto)
            dismiss()
        } else {
            error = "Could not schedule message."
        }
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .short
        return f.string(from: d)
    }

    private func next(hour: Int, daysAhead: Int = 0) -> Date {
        let cal = Calendar.current
        var target = cal.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date()
        target = cal.date(bySettingHour: hour, minute: 0, second: 0, of: target) ?? target
        if target <= Date() { target = cal.date(byAdding: .day, value: 1, to: target) ?? target }
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

    public enum Preset: String, CaseIterable, Identifiable, Hashable {
        case in15, in1h, later9am, tomorrow9am, mondayMorning, custom
        public var id: String { rawValue }
        var label: String {
            switch self {
            case .in15: return "In 15 minutes"
            case .in1h: return "In 1 hour"
            case .later9am: return "Today at 9 AM"
            case .tomorrow9am: return "Tomorrow at 9 AM"
            case .mondayMorning: return "Monday morning"
            case .custom: return "Custom…"
            }
        }
    }
}
