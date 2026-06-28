import SwiftUI

/// Create / edit a recurring schedule, mirroring web's `ScheduledForm`. Field
/// order matches web: type → account → amount → next due date → repeats →
/// description → budget → category → fixed expense → tags → active. Only income
/// and expense are offered (scheduled transfers aren't supported) and the amount
/// is always positive, so `CurrencyField` shows no sign toggle.
struct ScheduledFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: ScheduledTransactionFormViewModel
    @State private var showDiscardConfirm = false
    var onSaved: (() async -> Void)?

    init(
        editing schedule: ScheduledTransaction? = nil,
        defaultAccountId: UUID? = nil,
        decimalPlaces: Int = 2,
        onSaved: (() async -> Void)? = nil
    ) {
        _viewModel = State(initialValue: ScheduledTransactionFormViewModel(
            editing: schedule,
            defaultAccountId: defaultAccountId,
            decimalPlaces: decimalPlaces
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section {
                // Scheduled transactions support income / expense only — web omits
                // transfer because the generator can't copy a destination account.
                Picker("Type", selection: $viewModel.type) {
                    Text("Income").tag(TransactionType.income)
                    Text("Expense").tag(TransactionType.expense)
                }
                .pickerStyle(.segmented)

                AccountPicker(label: "Account", selectedId: $viewModel.accountId)

                CurrencyField(
                    label: "Amount",
                    value: $viewModel.amount,
                    decimals: appState.decimalPlaces
                )

                DatePicker(
                    "Next due date",
                    selection: $viewModel.nextDueDate,
                    displayedComponents: .date
                )

                // Recurrence is monthly-only for now (the only value in the
                // `recurrence_type` enum / generator), so it's a fixed read-only
                // row, matching web's disabled "Monthly" select.
                LabeledContent("Repeats", value: "Monthly")

                TextField("Description (optional)", text: $viewModel.description)

                // Budget & fixed expense link by lineage name (resolved per due
                // month at generation); web lists budget before category.
                BudgetNamePicker(
                    selectedName: $viewModel.budgetName,
                    dueDate: viewModel.nextDueDate
                )

                CategoryPicker(selectedId: $viewModel.categoryId)

                if viewModel.type == .expense {
                    FixedExpenseNamePicker(
                        selectedName: $viewModel.fixedExpenseName,
                        dueDate: viewModel.nextDueDate
                    )
                }

                TagPicker(selectedTags: $viewModel.selectedTags)
            }

            Section {
                Toggle("Active", isOn: $viewModel.isActive)
            } footer: {
                Text("When active, this generates a pending transaction each month for you to confirm.")
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(Color.appDanger)
                }
            }
        }
        .navigationTitle(viewModel.editing == nil ? "New Scheduled" : "Edit Scheduled")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if viewModel.hasChanges { showDiscardConfirm = true } else { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await viewModel.save()
                        if viewModel.didSave {
                            await onSaved?()
                            dismiss()
                        }
                    }
                }
                .disabled(!viewModel.isValid || viewModel.isSaving)
            }
        }
        .interactiveDismissDisabled(viewModel.hasChanges)
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .task { await viewModel.loadTags() }
    }
}
