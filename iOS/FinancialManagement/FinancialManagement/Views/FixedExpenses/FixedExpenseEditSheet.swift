import SwiftUI
import Supabase

/// Edit an existing fixed expense's name/amount. Scoped to the selected month
/// only — other months' rows for the same name are unaffected (§5.6, §8.5).
struct FixedExpenseEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let expense: FixedExpense
    let decimalPlaces: Int
    var onSaved: (() async -> Void)?

    @State private var name: String
    @State private var amount: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let repository = FixedExpenseRepository()

    init(expense: FixedExpense, decimalPlaces: Int, onSaved: (() async -> Void)? = nil) {
        self.expense = expense
        self.decimalPlaces = decimalPlaces
        self.onSaved = onSaved
        _name = State(initialValue: expense.name)
        let display = CurrencyUtils.toDisplayAmount(expense.amount, decimalPlaces: decimalPlaces)
        _amount = State(initialValue: String(format: "%.\(decimalPlaces)f", display))
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var isValid: Bool {
        !trimmedName.isEmpty && (Double(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Name", text: $name)
                    CurrencyField(label: "Amount", value: $amount, decimals: decimalPlaces)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(Color.appDanger)
                    }
                }
            }
            .navigationTitle("Edit Fixed Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!isValid || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let value = Double(amount) else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await repository.update(id: expense.id, fields: [
                "name": .string(trimmedName),
                "amount": .integer(Int(CurrencyUtils.toMinorUnits(value, decimalPlaces: decimalPlaces)))
            ])
            await onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
