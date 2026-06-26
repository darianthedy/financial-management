import SwiftUI

/// Add or edit a single budget row for one month: name, monthly amount, and an
/// optional note. There is **no carry-over toggle** — carry-over is always on
/// and computed live in `v_budget_progress` (§8.4). Writes go to the `budgets`
/// table via `BudgetListViewModel`.
struct BudgetFormSheet: View {
    enum Mode {
        case add(yearMonth: String)
        case edit(BudgetProgress)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let mode: Mode
    let viewModel: BudgetListViewModel

    @State private var name = ""
    @State private var amount = ""
    @State private var note = ""
    @State private var isSaving = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var isValid: Bool {
        !trimmedName.isEmpty && (Double(amount) ?? 0) > 0
    }

    /// The month this budget belongs to, used in the title (web shows
    /// "New budget · June 2026").
    private var yearMonth: String {
        switch mode {
        case .add(let yearMonth): return yearMonth
        case .edit(let progress): return progress.yearMonth
        }
    }

    private var title: String {
        let prefix = { if case .edit = mode { return "Edit budget" }; return "New budget" }()
        return "\(prefix) · \(DateUtils.formatYearMonth(yearMonth))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    CurrencyField(label: "Monthly amount", value: $amount, decimals: appState.decimalPlaces)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(title)
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
            .onAppear(perform: loadInitialValues)
        }
    }

    private func loadInitialValues() {
        guard case .edit(let progress) = mode, name.isEmpty else { return }
        name = progress.budgetName
        let display = CurrencyUtils.toDisplayAmount(progress.periodicAmount, decimalPlaces: appState.decimalPlaces)
        amount = String(format: "%.\(appState.decimalPlaces)f", display)
        note = progress.description ?? ""
    }

    private func save() async {
        guard let value = Double(amount) else { return }
        isSaving = true
        defer { isSaving = false }

        let minorUnits = CurrencyUtils.toMinorUnits(value, decimalPlaces: appState.decimalPlaces)
        let noteValue = note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note

        switch mode {
        case .add:
            await viewModel.addBudget(name: trimmedName, periodicAmount: minorUnits, note: noteValue)
        case .edit(let progress):
            await viewModel.updateBudget(
                id: progress.budgetId, name: trimmedName, periodicAmount: minorUnits, note: noteValue
            )
        }
        dismiss()
    }
}
