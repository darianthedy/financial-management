import SwiftUI

/// Month-scoped dashboard: Budget Verdict, Accounts, Planned Expenses, and
/// Unplanned Expenses, all driven by `MonthNavigator` and refreshed on realtime
/// (iOS Tech Plan §8.1, System Design §4.6).
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
                .layoutProbe("dashboard.monthNavigator", interactive: true)

                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let data = viewModel.data {
                        // Regular width (D4.1): two balanced columns; compact
                        // keeps the single stack below, exactly as before.
                        if horizontalSizeClass == .regular {
                            DashboardColumns(spacing: 16) { cards(data) }
                        } else {
                            cards(data)
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
        .layoutProbe("dashboard.scroll")
        .navigationTitle("Dashboard")
        .task {
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
        .onDisappear { Task { await viewModel.unsubscribe() } }
        .refreshable { await viewModel.load() }
    }

    /// The six cards in iPhone order. Left column: Verdict, Cashflow, Trend;
    /// right (`.dashboardColumn(1)`): Accounts, Planned, Unplanned.
    @ViewBuilder
    private func cards(_ data: DashboardData) -> some View {
        BudgetVerdictBanner(
            budgets: data.budgets,
            fixedExpenses: data.fixedExpenses,
            paidFixedExpenseTotals: data.paidFixedExpenseTotals,
            currencyCode: appState.defaultCurrency
        )
        .layoutProbe("dashboard.verdict")

        CashflowCard(
            cashflow: data.cashflow,
            currencyCode: appState.defaultCurrency
        )
        .layoutProbe("dashboard.cashflow")

        CashflowTrendCard(
            trend: data.trend,
            selectedYearMonth: viewModel.yearMonth,
            currencyCode: appState.defaultCurrency
        )
        .layoutProbe("dashboard.trend")

        AccountsCard(
            accounts: data.accounts,
            currencyCode: appState.defaultCurrency,
            widestAmountBody: widestDashboardAmountBody(
                accounts: data.accounts
            )
        )
        .layoutProbe("dashboard.accounts")
        // Outermost, so `DashboardColumns` reads it.
        .dashboardColumn(1)

        PlannedExpensesCard(
            budgets: data.budgets,
            fixedExpenses: data.fixedExpenses,
            paidFixedExpenseTotals: data.paidFixedExpenseTotals,
            yearMonth: viewModel.yearMonth,
            currencyCode: appState.defaultCurrency,
            widestAmountBody: widestDashboardAmountBody(
                accounts: data.accounts
            )
        )
        .layoutProbe("dashboard.planned")
        // Outermost, so `DashboardColumns` reads it.
        .dashboardColumn(1)

        UnplannedExpensesCard(
            groups: data.unplanned,
            currencyCode: appState.defaultCurrency,
            widestAmountBody: widestDashboardAmountBody(
                accounts: data.accounts
            )
        )
        .layoutProbe("dashboard.unplanned")
        // Outermost, so `DashboardColumns` reads it.
        .dashboardColumn(1)
    }

    // MARK: - Amount alignment across dashboard cards

    private func widestDashboardAmountBody(accounts: [DashboardAccount]) -> String {
        var maxAbs: Int64 = accounts.map { abs($0.balance) }.max() ?? 0
        if let data = viewModel.data {
            maxAbs = max(maxAbs, data.budgets.map { abs($0.effectiveAmount) }.max() ?? 0)
            maxAbs = max(maxAbs, data.fixedExpenses.map { abs($0.amount) }.max() ?? 0)
            // Paid fixed expenses display the actual amount paid, which can exceed
            // the plan — size the shared column to those too so nothing clips.
            maxAbs = max(maxAbs, data.paidFixedExpenseTotals.values.map { abs($0) }.max() ?? 0)
            maxAbs = max(maxAbs, data.unplanned.map { abs($0.total) }.max() ?? 0)
        }
        return CurrencyUtils.numberBody(maxAbs, currency: appState.defaultCurrency)
    }
}
