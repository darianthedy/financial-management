import SwiftUI

/// Month-scoped dashboard: Budget Verdict, Accounts, Planned Expenses, and
/// Unplanned Expenses, all driven by `MonthNavigator` and refreshed on realtime
/// (iOS Tech Plan §8.1, System Design §4.6).
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            // Web's dashboard: `space-y-6` (24pt) between the month navigator and
            // the card grid, which itself uses `gap-4` (16pt) between cards.
            VStack(spacing: 24) {
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
                            currencyCode: appState.defaultCurrency,
                            widestAmountBody: widestDashboardAmountBody(
                                accounts: data.accounts
                            )
                        )

                        PlannedExpensesCard(
                            budgets: data.budgets,
                            fixedExpenses: data.fixedExpenses,
                            paidFixedExpenseIds: data.paidFixedExpenseIds,
                            yearMonth: viewModel.yearMonth,
                            currencyCode: appState.defaultCurrency,
                            widestAmountBody: widestDashboardAmountBody(
                                accounts: data.accounts
                            )
                        )

                        UnplannedExpensesCard(
                            groups: data.unplanned,
                            currencyCode: appState.defaultCurrency,
                            widestAmountBody: widestDashboardAmountBody(
                                accounts: data.accounts
                            )
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

    // MARK: - Amount alignment across dashboard cards

    private func widestDashboardAmountBody(accounts: [DashboardAccount]) -> String {
        var maxAbs: Int64 = accounts.map { abs($0.balance) }.max() ?? 0
        if let data = viewModel.data {
            maxAbs = max(maxAbs, data.budgets.map { abs($0.effectiveAmount) }.max() ?? 0)
            maxAbs = max(maxAbs, data.fixedExpenses.map { abs($0.amount) }.max() ?? 0)
            maxAbs = max(maxAbs, data.unplanned.map { abs($0.total) }.max() ?? 0)
        }
        return CurrencyUtils.numberBody(maxAbs, currency: appState.defaultCurrency)
    }
}
