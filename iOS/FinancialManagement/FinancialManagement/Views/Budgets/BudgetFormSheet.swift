import SwiftUI

struct BudgetFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var name = ""
    @State private var enableCarryOver = false
    @State private var periodicAmount = ""
    @State private var currency = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let repository = BudgetRepository()
    var onSaved: (() async -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget Details") {
                    TextField("Budget Name", text: $name)

                    CurrencyField(label: "Monthly Amount", value: $periodicAmount)

                    CurrencyPicker(label: "Currency", selectedCode: $currency)

                    Toggle("Enable Carry-Over", isOn: $enableCarryOver)
                }

                if enableCarryOver {
                    Section {
                        Text("Unspent budget will roll over to the next month automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .onAppear {
                if currency.isEmpty {
                    currency = appState.defaultCurrency
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let budget = try await repository.create(name: name, enableCarryOver: enableCarryOver)

            if let amount = Double(periodicAmount) {
                let yearMonth = DateUtils.currentYearMonth()
                _ = try await repository.upsertPeriod(
                    budgetId: budget.id,
                    yearMonth: yearMonth,
                    periodicAmount: CurrencyUtils.toMinorUnits(amount, currency: currency),
                    currency: currency
                )
            }

            await onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
