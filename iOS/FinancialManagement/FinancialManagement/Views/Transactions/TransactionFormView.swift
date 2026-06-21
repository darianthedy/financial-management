import SwiftUI

struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: TransactionFormViewModel
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
            Section("Type") {
                Picker("Transaction Type", selection: $viewModel.type) {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Details") {
                CurrencyField(label: "Amount", value: $viewModel.amount)

                AccountPicker(
                    label: "Account",
                    selectedId: $viewModel.accountId
                )

                if viewModel.type == .transfer {
                    AccountPicker(
                        label: "To Account",
                        selectedId: $viewModel.transferAccountId
                    )
                }

                // Category & budget apply to income/expense; transfers carry none.
                if viewModel.type != .transfer {
                    CategoryPicker(selectedId: $viewModel.categoryId)

                    BudgetPicker(
                        selectedBudgetId: $viewModel.budgetId,
                        transactionDate: viewModel.transactionDate
                    )
                }

                // Fixed-expense link marks the expense paid; expense only.
                if viewModel.type == .expense {
                    FixedExpensePicker(
                        selectedExpenseId: $viewModel.fixedExpenseId,
                        transactionDate: viewModel.transactionDate
                    )
                }

                TextField("Description (optional)", text: $viewModel.description)

                DatePicker("Date", selection: $viewModel.transactionDate, displayedComponents: .date)
            }

            TagPicker(selectedTags: $viewModel.selectedTags)

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
                Button("Cancel") { dismiss() }
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
        .task { await viewModel.loadTags() }
    }
}
