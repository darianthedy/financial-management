import SwiftUI

struct TransactionListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: TransactionListViewModel
    @State private var showingForm = false
    @State private var editingTransaction: Transaction?

    init(scopedAccountId: UUID? = nil) {
        _viewModel = State(initialValue: TransactionListViewModel(scopedAccountId: scopedAccountId))
    }

    var body: some View {
        VStack(spacing: 0) {
            MonthNavigator(
                yearMonth: viewModel.yearMonth,
                onPrevious: { viewModel.navigateMonth(by: -1) },
                onNext: { viewModel.navigateMonth(by: 1) }
            )
            .padding()

            List {
                ForEach(viewModel.transactions) { txn in
                    TransactionRow(transaction: txn, account: viewModel.account(for: txn))
                        .contentShape(Rectangle())
                        .onTapGesture { editingTransaction = txn }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if txn.status == .pending {
                                Button {
                                    Task { await viewModel.setStatus(txn, to: .confirmed) }
                                } label: {
                                    Label("Confirm", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteTransaction(txn) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            if txn.status == .pending {
                                Button {
                                    Task { await viewModel.setStatus(txn, to: .dismissed) }
                                } label: {
                                    Label("Dismiss", systemImage: "xmark")
                                }
                                .tint(.orange)
                            }
                        }
                        .onAppear {
                            if txn.id == viewModel.transactions.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                }

                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if viewModel.transactions.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        title: "No Transactions",
                        message: "Add your first transaction for this month.",
                        systemImage: "list.bullet"
                    )
                }
            }
            .monthPageTransition(
                yearMonth: viewModel.yearMonth,
                direction: viewModel.navigationDirection
            )
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            NavigationStack {
                TransactionFormView(
                    defaultAccountId: appState.defaultAccountId,
                    currency: appState.defaultCurrency,
                    decimalPlaces: appState.decimalPlaces
                ) {
                    await viewModel.load()
                }
            }
        }
        .sheet(item: $editingTransaction) { txn in
            NavigationStack {
                TransactionFormView(
                    editing: txn,
                    currency: appState.defaultCurrency,
                    decimalPlaces: appState.decimalPlaces
                ) {
                    await viewModel.load()
                }
            }
        }
        .swipeToNavigateMonth(
            onPrevious: { viewModel.navigateMonth(by: -1) },
            onNext: { viewModel.navigateMonth(by: 1) }
        )
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
