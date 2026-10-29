import SwiftUI

/// Accounts (S4). Compact pushes `AccountDetailView` as before; on regular
/// width (`SplitRootContainer`) the detail tiles beside the list, which
/// highlights the selected row (design §S4, implementation plan D2.1).
struct AccountListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.canTileSplitRoot) private var canTile
    @State private var viewModel = AccountListViewModel()
    @State private var showingAddSheet = false
    /// The tiled split's selection. On compact the rows push by value instead.
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
        .modifier(PushAccountByValue(enabled: !canTile))
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
    }
}

extension AccountListView {
    /// Compact: a `NavigationLink(value:)` push, as before D2.1. Tiled: a
    /// button that selects the account for the detail column.
    @ViewBuilder
    fileprivate func accountRow(_ account: Account) -> some View {
        let card = AccountCard(account: account, currentBalance: viewModel.balance(for: account.id))
        if canTile {
            Button { selectedAccountId = account.id } label: {
                card.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: account.id) { card }
        }
    }
}

/// Compact width: rows are `NavigationLink(value:)`s that push the detail, as
/// before D2.1. Left out when tiled, where rows select instead of push.
private struct PushAccountByValue: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.navigationDestination(for: UUID.self) { accountId in
                AccountDetailView(accountId: accountId)
            }
        } else {
            content
        }
    }
}
