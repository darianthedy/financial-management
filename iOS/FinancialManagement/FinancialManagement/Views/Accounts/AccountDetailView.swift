import SwiftUI

struct AccountDetailView: View {
    @State private var viewModel: AccountDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(accountId: UUID) {
        _viewModel = State(initialValue: AccountDetailViewModel(accountId: accountId))
    }

    var body: some View {
        List {
            if let account = viewModel.account {
                Section("Account Info") {
                    LabeledContent("Name", value: account.name)
                    LabeledContent("Type", value: account.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    LabeledContent("Currency", value: account.currency)
                    LabeledContent("Starting Balance", value: account.startingBalance.asCurrency(code: account.currency))
                    LabeledContent("Current Balance") {
                        Text(viewModel.currentBalance.asCurrency(code: account.currency))
                            .bold()
                    }
                }

                Section("Transactions") {
                    if viewModel.transactions.isEmpty {
                        Text("No transactions yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.transactions) { txn in
                            TransactionRow(transaction: txn)
                        }
                    }
                }

                Section {
                    Button("Archive Account", role: .destructive) {
                        Task {
                            await viewModel.archiveAccount()
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.account?.name ?? "Account")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
