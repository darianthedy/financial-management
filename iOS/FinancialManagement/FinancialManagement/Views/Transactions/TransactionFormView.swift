import SwiftUI

/// Create / edit a transaction. Presented as a sheet, or embedded in the
/// Transactions detail column on regular width (iPhone Duo plan D3.1): there
/// the view model comes from `TransactionEditorDrafts` so edits survive a fold,
/// `onClose` replaces `dismiss`, and `isDirty` reports unsaved changes so the
/// list can confirm before switching rows.
struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: TransactionFormViewModel
    @State private var showDiscardConfirm = false
    var onSaved: (() async -> Void)?
    private let onClose: (() -> Void)?
    private let isDirty: Binding<Bool>?

    init(
        editing transaction: Transaction? = nil,
        defaultAccountId: UUID? = nil,
        currency: String = "USD",
        decimalPlaces: Int = 2,
        prefillFixedExpenseId: UUID? = nil,
        prefillAmount: String? = nil,
        prefillDate: Date? = nil,
        onSaved: (() async -> Void)? = nil
    ) {
        _viewModel = State(initialValue: TransactionFormViewModel(
            editing: transaction,
            defaultAccountId: defaultAccountId,
            currency: currency,
            decimalPlaces: decimalPlaces,
            prefillFixedExpenseId: prefillFixedExpenseId,
            prefillAmount: prefillAmount,
            prefillDate: prefillDate
        ))
        self.onSaved = onSaved
        self.onClose = nil
        self.isDirty = nil
    }

    /// Edits through an existing (draft) view model, embedded in a split.
    init(
        model: TransactionFormViewModel,
        onSaved: (() async -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        isDirty: Binding<Bool>? = nil
    ) {
        _viewModel = State(initialValue: model)
        self.onSaved = onSaved
        self.onClose = onClose
        self.isDirty = isDirty
    }

    /// Dismisses the sheet, or hands back to the embedding split view.
    private func close() {
        if let onClose { onClose() } else { dismiss() }
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
                    if viewModel.hasChanges { showDiscardConfirm = true } else { close() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                // Editing a pending transaction: saving also confirms it, so the
                // label says so (§8.3).
                Button(viewModel.saveButtonTitle) {
                    Task {
                        await viewModel.save()
                        if viewModel.didSave {
                            await onSaved?()
                            close()
                        }
                    }
                }
                .disabled(!viewModel.isValid || viewModel.isSaving)
            }
        }
        .interactiveDismissDisabled(viewModel.hasChanges)
        // Embedded and pushed (a kept draft after a fold), Back would drop the
        // edits unasked; Cancel / Save are the way out, as in the sheet.
        .navigationBarBackButtonHidden(onClose != nil)
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) { close() }
            Button("Keep Editing", role: .cancel) {}
        }
        .onChange(of: viewModel.hasChanges, initial: true) { _, dirty in
            if let isDirty, isDirty.wrappedValue != dirty { isDirty.wrappedValue = dirty }
        }
        .task { await viewModel.loadTags() }
    }
}
