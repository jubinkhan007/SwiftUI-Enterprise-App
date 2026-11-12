import SwiftUI
import SharedModels
import DesignSystem
import Domain

struct LogTimeSheet: View {
    let taskId: UUID
    let taskRepository: TaskRepositoryProtocol
    let onLogSuccess: @MainActor @Sendable () -> Void

    @Environment(\.dismiss) private var dismiss
    
    @State private var hoursLogged: Double = 1.0
    @State private var loggedAt: Date = Date()
    @State private var description: String = ""
    @State private var isBillable: Bool = true
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    // Live Stopwatch State
    @State private var isTimerRunning: Bool = false
    @State private var elapsedSeconds: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let quickPresets: [(label: String, hours: Double)] = [
        ("15m", 0.25),
        ("30m", 0.50),
        ("1h", 1.0),
        ("2h", 2.0),
        ("4h", 4.0),
        ("8h", 8.0)
    ]

    private var formattedStopwatch: String {
        let hrs = elapsedSeconds / 3600
        let mins = (elapsedSeconds % 3600) / 60
        let secs = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Live Task Stopwatch").foregroundColor(AppColors.textSecondary)) {
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: isTimerRunning ? "stopwatch.fill" : "stopwatch")
                                .foregroundColor(isTimerRunning ? AppColors.statusSuccess : AppColors.brandPrimary)
                            Text(formattedStopwatch)
                                .font(.system(.title3, design: .monospaced).weight(.bold))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Button {
                                isTimerRunning.toggle()
                            } label: {
                                Label(isTimerRunning ? "Pause" : "Start", systemImage: isTimerRunning ? "pause.fill" : "play.fill")
                                    .appFont(AppTypography.caption1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isTimerRunning ? AppColors.statusWarning.opacity(0.18) : AppColors.statusSuccess.opacity(0.18))
                                    .foregroundColor(isTimerRunning ? AppColors.statusWarning : AppColors.statusSuccess)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            if elapsedSeconds > 0 {
                                Button {
                                    isTimerRunning = false
                                    let rawHours = Double(elapsedSeconds) / 3600.0
                                    let roundedQuarter = max(0.25, (rawHours * 4.0).rounded(.up) / 4.0)
                                    hoursLogged = min(24.0, roundedQuarter)
                                    if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        description = "Timed work session (\(formattedStopwatch))"
                                    }
                                } label: {
                                    Text("Apply")
                                        .appFont(AppTypography.caption1)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppColors.brandPrimary.opacity(0.15))
                                        .foregroundColor(AppColors.brandPrimary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listRowBackground(AppColors.surfacePrimary)

                Section(header: Text("Hours worked").foregroundColor(AppColors.textSecondary)) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(AppColors.brandPrimary)
                        
                        Slider(value: $hoursLogged, in: 0.25...24.0, step: 0.25) {
                            Text("Hours")
                        }
                        
                        Spacer()
                        
                        Text(String(format: "%.2f hrs", hoursLogged))
                            .bold()
                            .appFont(AppTypography.body)
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 80, alignment: .trailing)
                    }
                    
                    Stepper("Adjust hours", value: $hoursLogged, in: 0.25...24.0, step: 0.25)
                        .appFont(AppTypography.caption1)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickPresets, id: \.label) { preset in
                                Button {
                                    hoursLogged = preset.hours
                                } label: {
                                    Text(preset.label)
                                        .appFont(AppTypography.caption2)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            abs(hoursLogged - preset.hours) < 0.01
                                                ? AppColors.brandPrimary
                                                : AppColors.backgroundSecondary
                                        )
                                        .foregroundColor(
                                            abs(hoursLogged - preset.hours) < 0.01
                                                ? .white
                                                : AppColors.textPrimary
                                        )
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listRowBackground(AppColors.surfacePrimary)

                Section(header: Text("Date & Billing").foregroundColor(AppColors.textSecondary)) {
                    DatePicker(
                        "Date logged",
                        selection: $loggedAt,
                        displayedComponents: [.date]
                    )
                    .appFont(AppTypography.body)

                    Toggle(isOn: $isBillable) {
                        HStack(spacing: 6) {
                            Image(systemName: isBillable ? "dollarsign.circle.fill" : "dollarsign.circle")
                                .foregroundColor(isBillable ? AppColors.statusSuccess : AppColors.textSecondary)
                            Text("Billable Hours")
                                .appFont(AppTypography.body)
                        }
                    }
                    .tint(AppColors.statusSuccess)
                }
                .listRowBackground(AppColors.surfacePrimary)

                Section(header: Text("Description").foregroundColor(AppColors.textSecondary)) {
                    TextField("What did you work on? (optional)", text: $description)
                        .appFont(AppTypography.body)
                }
                .listRowBackground(AppColors.surfacePrimary)

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(AppColors.statusError)
                            .appFont(AppTypography.caption1)
                    }
                    .listRowBackground(AppColors.surfacePrimary)
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Log Time")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.brandPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveLog()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .bold()
                        }
                    }
                    .disabled(isSaving)
                    .foregroundColor(AppColors.brandPrimary)
                }
            }
            .onReceive(timer) { _ in
                if isTimerRunning {
                    elapsedSeconds += 1
                }
            }
        }
    }

    private func saveLog() {
        isSaving = true
        errorMessage = nil
        
        let payload = LogTimeRequest(
            hoursLogged: hoursLogged,
            loggedAt: loggedAt,
            description: description.isEmpty ? nil : description,
            isBillable: isBillable
        )
        
        Task {
            do {
                _ = try await taskRepository.logTime(taskId: taskId, payload: payload)
                await MainActor.run {
                    isSaving = false
                    onLogSuccess()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
