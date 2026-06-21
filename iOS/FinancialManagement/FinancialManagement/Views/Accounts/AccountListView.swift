import SwiftUI

struct AccountListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AccountListViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        List {
            // web shows a small muted "Total: <amount>" subtitle under the
            // "Accounts" heading, only when there are accounts.
            if !viewModel.accounts.isEmpty {
                Section {
                    HStack {
                        Text("Total")
                            .font(.subheadline)
                            .foregroundStyle(Color.appMutedForeground)
                        Spacer()
                        Text(viewModel.totalBalance.asCurrency(code: appState.defaultCurrency))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appForeground)
                    }
                }
            }

            // web renders a single flat list ordered by creation date — no
            // per-type grouping. `accounts` already arrives in created_at order.
            Section {
                ForEach(viewModel.accounts) { account in
                    NavigationLink(value: account.id) {
                        AccountCard(account: account, currentBalance: viewModel.balance(for: account.id))
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
                    title: "No accounts yet",
                    message: "Add your first account to start tracking your finances.",
                    systemImage: "creditcard"
                ) {
                    Button("Add account") { showingAddSheet = true }
                }
            }
        }
        .task {
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
    }
}
