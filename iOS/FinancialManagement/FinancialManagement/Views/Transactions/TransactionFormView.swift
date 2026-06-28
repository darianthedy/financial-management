import SwiftUI

struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: TransactionFormViewModel
    @State private var showDiscardConfirm = false
    var onSaved: (() async -> Void)?

    init(
        editing transaction: Transaction? = nil,
        defaultAccountId: UUID? = nil,
        currency: String = "USD",
        decimalPlaces: Int = 2,
        onSaved: (() async -> Void)? = nil
    ) {
        _viewModel = State(initialValue: TransactionFormViewModel(
            editing: transaction,
            defaultAccountId: defaultAccountId,
            currency: currency,
            decimalPlaces: decimalPlaces
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            // Type, details, and tags are combined into a single section.
            // Field order mirrors the web form
            // (web/src/components/transactions/transaction-form.tsx): type →
            // account(s) → amount → date → description → budget → category →
            // fixed expense → tags.
            Section {
                Picker("Transaction Type", selection: $viewModel.type) {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                AccountPicker(
                    label: viewModel.type == .transfer ? "From" : "Account",
                    selectedId: $viewModel.accountId
                )

                if viewModel.type == .transfer {
                    AccountPicker(
                        label: "To",
                        selectedId: $viewModel.transferAccountId
                    )
                }

                // Income/expense can be negative (e.g. a refund as a negative
                // expense); transfers stay positive — mirrors web.
                CurrencyField(
                    label: "Amount",
                    value: $viewModel.amount,
                    decimals: appState.decimalPlaces,
                    allowNegative: viewModel.type != .transfer
                )

                DatePicker("Date", selection: $viewModel.transactionDate, displayedComponents: .date)

                TextField("Description (optional)", text: $viewModel.description)

                // Budget & category apply to income/expense; transfers carry none.
                // Web lists budget before category.
                if viewModel.type != .transfer {
                    BudgetPicker(
                        selectedBudgetId: $viewModel.budgetId,
                        transactionDate: viewModel.transactionDate
                    )

                    CategoryPicker(selectedId: $viewModel.categoryId)
                }

                // Fixed-expense link marks the expense paid; expense only.
                if viewModel.type == .expense {
                    FixedExpensePicker(
                        selectedExpenseId: $viewModel.fixedExpenseId,
                        transactionDate: viewModel.transactionDate
                    )
                }

                TagPicker(selectedTags: $viewModel.selectedTags)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(Color.appDanger)
                }
            }
        }
        .navigationTitle(viewModel.editingTransaction == nil ? "New Transaction" : "Edit Transaction")
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
