import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MonthNavigator(
                    yearMonth: viewModel.yearMonth,
                    onPrevious: { viewModel.navigateMonth(by: -1) },
                    onNext: { viewModel.navigateMonth(by: 1) }
                )

                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let summary = viewModel.summary {
                        CashflowCard(
                            income: summary.totalIncome,
                            expense: summary.totalExpense,
                            net: summary.netCashflow,
                            currencyCode: appState.defaultCurrency
                        )

                        if !viewModel.budgetPeriods.isEmpty {
                            BudgetProgressCard(periods: viewModel.budgetPeriods)
                        }

                        if !summary.spendingByCategory.isEmpty {
                            SpendingByCategoryChart(
                                data: summary.spendingByCategory,
                                currencyCode: appState.defaultCurrency
                            )
                        }

                        if !summary.recentTransactions.isEmpty {
                            RecentTransactionsCard(
                                transactions: summary.recentTransactions
                            )
                        }
                    }
                }
                .monthPageTransition(
                    yearMonth: viewModel.yearMonth,
                    direction: viewModel.navigationDirection
                )
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .swipeToNavigateMonth(
            onPrevious: { viewModel.navigateMonth(by: -1) },
            onNext: { viewModel.navigateMonth(by: 1) }
        )
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
