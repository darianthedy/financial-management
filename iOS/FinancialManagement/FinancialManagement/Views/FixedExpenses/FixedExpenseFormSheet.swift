import SwiftUI
import Supabase

/// Add a new fixed expense for the selected month (§8.5). Name + amount only —
/// there is no per-row currency and no day-of-month. Editing an existing row
/// goes through `FixedExpenseEditSheet`.
struct FixedExpenseFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let yearMonth: String
    var onSaved: (() async -> Void)?

    @State private var name = ""
    @State private var amount = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDiscardConfirm = false

    private let repository = FixedExpenseRepository()

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var isValid: Bool {
        !trimmedName.isEmpty && (Double(amount) ?? 0) > 0
    }

    /// Any meaningful input entered, so a swipe-down / Cancel should confirm.
    private var hasChanges: Bool {
        !name.isEmpty || !amount.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Name", text: $name)
                    CurrencyField(label: "Amount", value: $amount, decimals: appState.decimalPlaces)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(Color.appDanger)
                    }
                }
            }
            .navigationTitle("New Fixed Expense")
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
            // Guard the swipe-down dismissal too, then confirm via Cancel.
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog(
                "Discard new fixed expense?",
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
            _ = try await repository.create(
                name: trimmedName,
                yearMonth: yearMonth,
                amount: CurrencyUtils.toMinorUnits(value, decimalPlaces: appState.decimalPlaces)
            )
            await onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
