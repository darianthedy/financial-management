import SwiftUI

/// Month-scoped dashboard: Budget Verdict, Accounts, Planned Expenses, and
/// Unplanned Expenses, all driven by `MonthNavigator` and refreshed on realtime
/// (iOS Tech Plan §8.1, System Design §4.6).
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel = DashboardViewModel()
    /// The scroll view's width, to tell whether the columns can meet the fold.
    @State private var scrollWidth: CGFloat = 0

    /// The screen's margin, which the fold position must be corrected by.
    private let margin: CGFloat = 16

    var body: some View {
        ScrollView {
            FoldAwareDashboardContent(margin: margin, scrollWidth: scrollWidth) { foldX, navigatorWidth in
                content(foldX: foldX, navigatorWidth: navigatorWidth)
            }
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { scrollWidth = $0 }
        // Here, not at the root: beside the sidebar this view starts at its own
        // origin. The scroll view doesn't move as its content scrolls.
        .readsFoldContext()
        .layoutProbe("dashboard.scroll")
        .navigationTitle("Dashboard")
        .task {
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
        .refreshable { await viewModel.load() }
    }

    private func content(foldX: CGFloat?, navigatorWidth: CGFloat?) -> some View {
        // Web's dashboard: `space-y-6` (24pt) between the month navigator and
        // the card grid, which itself uses `gap-4` (16pt) between cards.
        VStack(spacing: 24) {
            MonthNavigator(
                yearMonth: viewModel.yearMonth,
                onPrevious: { viewModel.navigateMonth(by: -1) },
                onNext: { viewModel.navigateMonth(by: 1) }
            )
            .layoutProbe("dashboard.monthNavigator", interactive: true)
            // Spans both columns, unless the fold would run through it.
            .frame(maxWidth: navigatorWidth ?? .infinity)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let data = viewModel.data {
                    // Regular width (D4.1): two balanced columns; compact
                    // keeps the single stack below, exactly as before.
                    if horizontalSizeClass == .regular {
                        DashboardColumns(spacing: 16, foldX: foldX) { cards(data) }
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
        .padding(margin)
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

/// Turns `\.foldContext`, read at the scroll view, into what the Dashboard's
/// content lays out by: the fold in the columns' coordinates, and in book
/// posture the Month Navigator's width, so it stays in the leading region.
private struct FoldAwareDashboardContent<Content: View>: View {
    let margin: CGFloat
    let scrollWidth: CGFloat
    @ViewBuilder let content: (_ foldX: CGFloat?, _ navigatorWidth: CGFloat?) -> Content

    @Environment(\.foldContext) private var fold
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        content(foldX, navigatorWidth)
    }

    private var foldX: CGFloat? {
        guard horizontalSizeClass == .regular, case .book(let x) = fold else { return nil }
        return x - margin
    }

    private var navigatorWidth: CGFloat? {
        let columns = DashboardColumns()
        return DashboardColumns.foldedWidths(
            width: scrollWidth - margin * 2, foldX: foldX,
            gutter: columns.foldGutter, minimumColumnWidth: columns.minimumColumnWidth
        )?.left
    }
}
