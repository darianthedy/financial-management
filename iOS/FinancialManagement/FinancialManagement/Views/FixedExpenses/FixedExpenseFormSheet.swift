import SwiftUI
import Supabase

struct FixedExpenseFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var name = ""
    @State private var amount = ""
    @State private var currency = ""
    @State private var dueDay = 1
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let repository = FixedExpenseRepository()
    let yearMonth: String
    var editing: FixedExpense?
    var onSaved: (() async -> Void)?

    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Name", text: $name)
                    CurrencyField(label: "Amount", value: $amount)
                    CurrencyPicker(label: "Currency", selectedCode: $currency)
                }

                Section("Schedule") {
                    Stepper("Due Day: \(dueDay)", value: $dueDay, in: 1...31)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Fixed Expense" : "New Fixed Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || amount.isEmpty || isSaving)
                }
            }
            .onAppear {
                if let editing {
                    name = editing.name
                    amount = String(CurrencyUtils.toDisplayAmount(editing.amount, currency: editing.currency))
                    currency = editing.currency
                    dueDay = editing.dueDay
                } else if currency.isEmpty {
                    currency = appState.defaultCurrency
                }
            }
        }
    }

    private func save() async {
        guard let parsedAmount = Double(amount) else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            if let editing {
                try await repository.update(id: editing.id, fields: [
                    "name": AnyJSON.string(name),
                    "amount": AnyJSON.integer(Int(CurrencyUtils.toMinorUnits(parsedAmount, currency: currency))),
                    "currency": AnyJSON.string(currency),
                    "due_day": AnyJSON.integer(dueDay)
                ])
            } else {
                _ = try await repository.create(
                    name: name,
                    yearMonth: yearMonth,
                    amount: CurrencyUtils.toMinorUnits(parsedAmount, currency: currency),
                    currency: currency,
                    dueDay: dueDay
                )
            }

            await onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
