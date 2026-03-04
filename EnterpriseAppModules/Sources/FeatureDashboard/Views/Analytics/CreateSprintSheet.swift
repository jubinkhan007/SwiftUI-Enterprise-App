import SwiftUI
import SharedModels

struct CreateSprintSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var status: SprintStatus = .planned

    let onCreate: (_ name: String, _ start: Date, _ end: Date, _ status: SprintStatus) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Sprint") {
                    TextField("Name", text: $name)
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                    Picker("Status", selection: $status) {
                        ForEach(SprintStatus.allCases, id: \.self) { s in
                            Text(s.rawValue.capitalized).tag(s)
                        }
                    }
                }
            }
            .navigationTitle("Create Sprint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), startDate, endDate, status)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .onAppear {
            // Default end date to 2 weeks out.
            if let twoWeeks = Calendar.current.date(byAdding: .day, value: 13, to: startDate) {
                endDate = max(endDate, twoWeeks)
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && startDate <= endDate
    }
}

