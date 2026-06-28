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
    @State private var showDiscardConfirm = false

    /// The values the sheet opened with, so an edit can be detected.
    private let initialName: String
    private let initialAmount: String

    private let repository = FixedExpenseRepository()

    init(expense: FixedExpense, decimalPlaces: Int, onSaved: (() async -> Void)? = nil) {
        self.expense = expense
        self.decimalPlaces = decimalPlaces
        self.onSaved = onSaved
        let display = CurrencyUtils.toDisplayAmount(expense.amount, decimalPlaces: decimalPlaces)
        let amountText = String(format: "%.\(decimalPlaces)f", display)
        self.initialName = expense.name
        self.initialAmount = amountText
        _name = State(initialValue: expense.name)
        _amount = State(initialValue: amountText)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var isValid: Bool {
        !trimmedName.isEmpty && (Double(amount) ?? 0) > 0
    }

    /// True once the user edits away from the opened values.
    private var hasChanges: Bool {
        name != initialName || amount != initialAmount
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
                    Button("Cancel") {
                        if hasChanges { showDiscardConfirm = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!isValid || isSaving)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog(
                "Discard changes?",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
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
