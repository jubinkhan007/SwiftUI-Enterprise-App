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
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            Form {
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
                }
                .listRowBackground(AppColors.surfacePrimary)

                Section(header: Text("Date").foregroundColor(AppColors.textSecondary)) {
                    DatePicker(
                        "Date logged",
                        selection: $loggedAt,
                        displayedComponents: [.date]
                    )
                    .appFont(AppTypography.body)
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
        }
    }

    private func saveLog() {
        isSaving = true
        errorMessage = nil
        
        let payload = LogTimeRequest(
            hoursLogged: hoursLogged,
            loggedAt: loggedAt,
            description: description.isEmpty ? nil : description
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
