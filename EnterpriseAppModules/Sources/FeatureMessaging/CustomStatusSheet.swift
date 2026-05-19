import SwiftUI
import SharedModels
import DesignSystem

public struct CustomStatusSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var presenceStore: PresenceStore = PresenceStore.shared

    @State private var emoji: String = ""
    @State private var text: String = ""
    @State private var expiry: ExpiryChoice = .never
    @State private var customExpiry: Date = Date().addingTimeInterval(60 * 60)
    @State private var isSaving = false
    @State private var error: String?

    private let quickPresets: [(emoji: String, text: String)] = [
        ("📅", "In a meeting"),
        ("🍔", "Out to lunch"),
        ("🏠", "Working from home"),
        ("🌴", "On vacation"),
        ("🤒", "Out sick"),
        ("🎧", "Focus time")
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Set status") {
                    HStack {
                        TextField("Emoji", text: $emoji)
                            .frame(maxWidth: 60)
                            .multilineTextAlignment(.center)
                        TextField("What's your status?", text: $text)
                    }
                }

                Section("Presets") {
                    ForEach(quickPresets, id: \.text) { preset in
                        Button {
                            emoji = preset.emoji
                            text = preset.text
                        } label: {
                            HStack {
                                Text(preset.emoji)
                                Text(preset.text)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                            }
                        }
                    }
                }

                Section("Clear after") {
                    Picker("Expires", selection: $expiry) {
                        ForEach(ExpiryChoice.allCases, id: \.self) { choice in
                            Text(choice.label).tag(choice)
                        }
                    }
                    if expiry == .custom {
                        DatePicker("Expires at", selection: $customExpiry, in: Date()...)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .appFont(AppTypography.caption1)
                            .foregroundColor(.red)
                    }
                }

                if let current = presenceStore.myPresence,
                   current.customStatusEmoji != nil || current.customStatusText != nil {
                    Section {
                        Button("Clear current status", role: .destructive) {
                            Task { await clear() }
                        }
                    }
                }
            }
            .navigationTitle("Set Status")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(emoji.trimmingCharacters(in: .whitespaces).isEmpty
                                  && text.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .onAppear { hydrateFromCurrent() }
        }
    }

    private func hydrateFromCurrent() {
        guard let current = presenceStore.myPresence else { return }
        emoji = current.customStatusEmoji ?? ""
        text = current.customStatusText ?? ""
        if let exp = current.customStatusExpiresAt {
            expiry = .custom
            customExpiry = exp
        } else {
            expiry = .never
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let expiresAt: Date? = {
            switch expiry {
            case .never: return nil
            case .thirtyMinutes: return Date().addingTimeInterval(30 * 60)
            case .oneHour: return Date().addingTimeInterval(60 * 60)
            case .fourHours: return Date().addingTimeInterval(4 * 60 * 60)
            case .today:
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = 23
                components.minute = 59
                return Calendar.current.date(from: components)
            case .custom: return customExpiry
            }
        }()

        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespaces)
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        let result = await presenceStore.setCustomStatus(
            emoji: trimmedEmoji.isEmpty ? nil : trimmedEmoji,
            text: trimmedText.isEmpty ? nil : trimmedText,
            expiresAt: expiresAt
        )
        if result != nil {
            dismiss()
        } else if let err = presenceStore.lastError {
            error = err.localizedDescription
        }
    }

    private func clear() async {
        isSaving = true
        defer { isSaving = false }
        _ = await presenceStore.clearCustomStatus()
        dismiss()
    }

    private enum ExpiryChoice: Hashable, CaseIterable {
        case never
        case thirtyMinutes
        case oneHour
        case fourHours
        case today
        case custom

        var label: String {
            switch self {
            case .never: return "Don't clear"
            case .thirtyMinutes: return "30 minutes"
            case .oneHour: return "1 hour"
            case .fourHours: return "4 hours"
            case .today: return "Today"
            case .custom: return "Custom"
            }
        }
    }
}
