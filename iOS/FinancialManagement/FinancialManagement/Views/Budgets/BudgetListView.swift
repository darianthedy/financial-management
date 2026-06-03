import SwiftUI

struct BudgetListView: View {
    @State private var viewModel = BudgetListViewModel()
    @State private var showingForm = false

    var body: some View {
        VStack(spacing: 0) {
            MonthNavigator(
                yearMonth: viewModel.yearMonth,
                onPrevious: { viewModel.navigateMonth(by: -1) },
                onNext: { viewModel.navigateMonth(by: 1) }
            )
            .padding()

            List {
                ForEach(viewModel.budgets) { budget in
                    BudgetCard(
                        budget: budget,
                        period: viewModel.periods[budget.id]
                    )
                }
            }
            .listStyle(.plain)
            .overlay {
                if viewModel.budgets.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        title: "No Budgets",
                        message: "Create a budget to track your spending limits.",
                        systemImage: "target"
                    )
                }
            }
            .monthPageTransition(
                yearMonth: viewModel.yearMonth,
                direction: viewModel.navigationDirection
            )
        }
        .navigationTitle("Budgets")
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
            BudgetFormSheet {
                await viewModel.load()
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
