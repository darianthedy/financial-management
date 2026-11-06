import SwiftUI

/// Accounts (S4). A row selects its account: tiled (`SplitRootContainer` on
/// the inner display in landscape) the detail shows beside the list, which
/// highlights the row; elsewhere `.splitDetail` pushes it. Selecting in both
/// cases is what lets a rotation or a fold keep the account on screen.
struct AccountListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.canTileSplitRoot) private var canTile
    @State private var viewModel = AccountListViewModel()
    @State private var showingAddSheet = false
    /// The open account: the detail column's, or the pushed one.
    @State private var selectedAccountId: UUID?

    init(selectedAccountId: UUID? = nil) {
        _selectedAccountId = State(initialValue: selectedAccountId)
    }

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
                    accountRow(account)
                        .splitRowSelected(selectedAccountId == account.id)
                        .layoutProbe("accounts.row.\(account.name)", interactive: true)
                }
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .foldSafeSheet(isPresented: $showingAddSheet) {
            AccountFormSheet {
                await viewModel.load()
            }
        }
        .overlay {
            if viewModel.failedToLoad {
                LoadFailedView(title: "Couldn't Load Accounts", message: viewModel.errorMessage) {
                    await viewModel.load()
                }
            } else if viewModel.accounts.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No accounts yet",
                    message: "Add your first account to start tracking your finances.",
                    systemImage: "creditcard"
                ) {
                    Button("Add account") { showingAddSheet = true }
                }
            }
        }
        .splitDetail(
            selection: $selectedAccountId,
            in: viewModel.accounts.map(\.id),
            id: \.uuidString,
            storageKey: "accounts",
            placeholder: SplitPlaceholder(
                title: "Select an Account",
                systemImage: "wallet.bifold",
                description: "Its details and balance appear here."
            )
        ) { accountId in
            AccountDetailView(accountId: accountId)
        }
        .task {
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
        .refreshable { await viewModel.load() }
    }
}

extension AccountListView {
    /// Selects the account. Pushed (not tiled) it carries a disclosure
    /// chevron, as the `NavigationLink` it replaces did.
    fileprivate func accountRow(_ account: Account) -> some View {
        Button { selectedAccountId = account.id } label: {
            HStack(spacing: 8) {
                AccountCard(account: account, currentBalance: viewModel.balance(for: account.id))
                if !canTile {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
