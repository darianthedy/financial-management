import SwiftUI

/// Month-scoped dashboard: Budget Verdict, Accounts, Planned Expenses, and
/// Unplanned Expenses, all driven by `MonthNavigator` and refreshed on realtime
/// (iOS Tech Plan §8.1, System Design §4.6).
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
                    } else if let data = viewModel.data {
                        BudgetVerdictBanner(
                            budgets: data.budgets,
                            currencyCode: appState.defaultCurrency
                        )

                        AccountsCard(
                            accounts: data.accounts,
                            currencyCode: appState.defaultCurrency
                        )

                        PlannedExpensesCard(
                            budgets: data.budgets,
                            fixedExpenses: data.fixedExpenses,
                            paidFixedExpenseIds: data.paidFixedExpenseIds,
                            yearMonth: viewModel.yearMonth,
                            currencyCode: appState.defaultCurrency
                        )

                        UnplannedExpensesCard(
                            groups: data.unplanned,
                            currencyCode: appState.defaultCurrency
                        )
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
        .task {
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
        .onDisappear { Task { await viewModel.unsubscribe() } }
        .refreshable { await viewModel.load() }
    }
}
