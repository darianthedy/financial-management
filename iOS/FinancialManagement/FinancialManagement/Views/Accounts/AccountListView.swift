import SwiftUI

struct AccountListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AccountListViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Net Worth")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.totalBalance.asCurrency(code: appState.defaultCurrency))
                        .font(.title2.bold())
                }
            }

            ForEach(AccountType.allCases, id: \.self) { type in
                if let accounts = viewModel.groupedByType[type], !accounts.isEmpty {
                    Section(type.displayName) {
                        ForEach(accounts) { account in
                            NavigationLink(value: account.id) {
                                AccountCard(account: account, currentBalance: viewModel.balance(for: account.id))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Accounts")
        .navigationDestination(for: UUID.self) { accountId in
            AccountDetailView(accountId: accountId)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AccountFormSheet {
                await viewModel.load()
            }
        }
        .overlay {
            if viewModel.accounts.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No Accounts",
                    message: "Add your first account to start tracking.",
                    systemImage: "creditcard"
                )
            }
        }
        .task {
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
    }
}
