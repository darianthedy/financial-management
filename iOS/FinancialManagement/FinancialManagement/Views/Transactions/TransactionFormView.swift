import SwiftUI

struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: TransactionFormViewModel
    var onSaved: (() async -> Void)?

    init(editing transaction: Transaction? = nil, defaultCurrency: String = "USD", onSaved: (() async -> Void)? = nil) {
        _viewModel = State(initialValue: TransactionFormViewModel(editing: transaction, defaultCurrency: defaultCurrency))
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

                CurrencyPicker(label: "Currency", selectedCode: $viewModel.currency)

                AccountPicker(
                    label: "Account",
                    selectedId: $viewModel.accountId
                )

                if viewModel.type == .transfer {
                    AccountPicker(
                        label: "To Account",
                        selectedId: $viewModel.toAccountId
                    )
                }

                CategoryPicker(
                    selectedId: $viewModel.categoryId,
                    transactionType: viewModel.type
                )

                if viewModel.type == .expense {
                    BudgetPicker(
                        selectedBudgetPeriodId: $viewModel.budgetPeriodId,
                        transactionDate: viewModel.transactionDate
                    )

                    FixedExpensePicker(
                        selectedExpenseId: $viewModel.fixedExpenseId,
                        transactionDate: viewModel.transactionDate
                    )
                }

                TextField("Description (optional)", text: $viewModel.description)

                DatePicker("Date", selection: $viewModel.transactionDate, displayedComponents: .date)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
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
    }
}
