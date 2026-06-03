import SwiftUI

struct TransactionListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = TransactionListViewModel()
    @State private var showingForm = false

    var body: some View {
        VStack(spacing: 0) {
            MonthNavigator(
                yearMonth: viewModel.yearMonth,
                onPrevious: { viewModel.navigateMonth(by: -1) },
                onNext: { viewModel.navigateMonth(by: 1) }
            )
            .padding()

            FilterBar(
                selectedType: $viewModel.filterType,
                onChanged: { viewModel.invalidateCacheAndReload() }
            )

            List {
                ForEach(viewModel.transactions) { txn in
                    TransactionRow(transaction: txn)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let txn = viewModel.transactions[index]
                        Task { await viewModel.deleteTransaction(txn) }
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
                TransactionFormView(defaultCurrency: appState.defaultCurrency) {
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
