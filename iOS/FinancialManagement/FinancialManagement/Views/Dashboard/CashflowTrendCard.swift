import Charts
import SwiftUI

/// Dashboard Spending Trend card: income vs expenses across the trailing six
/// months, so the selected month reads in context ("is this month unusual?").
/// The card answers that question up front — a headline states the month's spend
/// and its swing off the average of the preceding months, and a dashed rule draws
/// that same average across the bars so the claim is checkable by eye. The focused
/// month's columns are at full strength while the rest are dimmed.
/// The expense column is stacked into the two kinds of spend the app already
/// tracks — planned (budgeted or fixed) at the base, unplanned riding on top —
/// so the shape of a month's spending reads at a glance without losing the
/// income-vs-total comparison or the average rule (both quoted off the total).
/// The chart is read-only: tapping a column opens a popover with its income /
/// planned / unplanned / net detail (dismissed by tapping outside) but never
/// navigates — month changes belong to the navigator
/// above, where they're deliberate. Confirmed transactions only, transfers excluded
/// (see `v_monthly_cashflow`); a window with no activity shows an empty state
/// (iOS Tech Plan §8.1, System Design §4.6).
///
/// Mirrors web's `spending-trend.tsx` + `use-cashflow-trend.ts`. The first use of
/// Swift Charts in the app. Series identity is carried by the always-present
/// legend and by each bar's fixed position within its month group, never by color
/// alone (HIG: don't encode meaning in color only).
struct CashflowTrendCard: View {
    let trend: [CashflowTrendPoint]
    /// The month the dashboard is focused on — emphasized in the chart.
    let selectedYearMonth: String
    let currencyCode: String

    /// The month whose detail popover is open (`year_month`), or `nil` when none.
    /// Set on tap and cleared when the popover is dismissed by tapping outside.
    @State private var activeYearMonth: String?

    /// Anchor rect (in the chart's coordinate space) for the detail popover, set
    /// to the tapped column so the popover points at the bar the user touched.
    @State private var popoverAnchor: CGRect = .zero

    // Identity colors follow the app's semantic language (matching the Cashflow
    // card): income = success. Expense is split into two stacked kinds — planned
    // (expected, tied to a budget or fixed expense) reads as warning/amber, while
    // unplanned (the spend to watch) keeps the full danger/red. Carried into the
    // chart as a manual foreground-style scale so the legend and bars stay in
    // lock-step. Identity = legend + fixed stack order, never color alone.
    private let incomeLabel = "Income"
    private let plannedLabel = "Planned"
    private let unplannedLabel = "Unplanned"
    /// Position value shared by both expense segments so they stack into a single
    /// column that sits beside the income column (rather than grouping apart).
    private let expenseGroup = "Expenses"

    /// Resolve the active currency's scale so touch-detail amounts don't fall
    /// back to `format`'s two-decimal default.
    private var fractionDigits: Int { CurrencyUtils.fractionDigits(for: currencyCode) }

    private var isEmpty: Bool {
        trend.allSatisfy { $0.income == 0 && $0.expense == 0 }
    }

    var body: some View {
        DashboardCard(title: "Spending Trend", accessory: { legend }) {
            if isEmpty {
                DashboardCardEmptyState(
                    title: "No activity yet",
                    message: "Income and expenses will chart here as you add transactions."
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    summary
                    chart
                        .frame(height: 180)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Baseline (the months preceding the selected one)

    /// The window is the six months *ending* at the selected month, so everything
    /// before it is the recent history the selected month is judged against.
    /// Comparing against a baseline that includes the selected month would let a
    /// spike drag its own yardstick up and mute the very signal we're surfacing.
    private var priorMonths: [CashflowTrendPoint] {
        trend.filter { $0.yearMonth < selectedYearMonth }
    }

    /// Mean expense across the prior months, or `nil` when there's no usable
    /// baseline (no prior months, or none of them had any spending) — in which
    /// case there is nothing honest to compare against and we show no delta.
    private var baselineExpense: Int64? {
        let months = priorMonths
        guard !months.isEmpty else { return nil }
        let total = months.reduce(Int64(0)) { $0 + $1.expense }
        guard total > 0 else { return nil }
        return total / Int64(months.count)
    }

    private var selectedExpense: Int64? {
        trend.first { $0.yearMonth == selectedYearMonth }?.expense
    }

    /// Selected month's expenses as a percentage swing off the baseline.
    private var expenseDeltaPercent: Int? {
        guard let baseline = baselineExpense, let current = selectedExpense else { return nil }
        let delta = Double(current - baseline) / Double(baseline) * 100
        return Int(delta.rounded())
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(trend) { point in
                bar(for: point, series: incomeLabel, group: incomeLabel, amount: point.income)
                // Planned first, then unplanned, so the stack reads planned at the
                // base with the spend-to-watch riding on top.
                bar(for: point, series: plannedLabel, group: expenseGroup, amount: point.plannedExpense)
                bar(for: point, series: unplannedLabel, group: expenseGroup, amount: point.unplannedExpense)
            }
            // The yardstick the headline delta is quoted against, drawn so the
            // claim is visible in the bars rather than taken on faith. Styled
            // directly (not via `foregroundStyle(by:)`) so it stays out of the
            // series color scale and reads as chrome, not a fourth series.
            if let baseline = baselineExpense {
                RuleMark(
                    y: .value(
                        "Average expenses",
                        CurrencyUtils.toDisplayAmount(baseline, currency: currencyCode)
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.appMutedForeground)
                .annotation(position: .top, alignment: .trailing, spacing: 2) {
                    Text("Avg expenses")
                        .font(.caption2)
                        .foregroundStyle(Color.appMutedForeground)
                }
            }
        }
        // Manual scale pins each series to its semantic color and drives series
        // identity; the built-in legend is hidden in favor of the title-row one.
        .chartForegroundStyleScale([
            incomeLabel: Color.appSuccess,
            plannedLabel: Color.appWarning,
            unplannedLabel: Color.appDanger,
        ])
        .chartLegend(.hidden)
        .chartYAxis(.hidden)
        // Keep the columns in chronological order regardless of the axis label
        // collation.
        .chartXScale(domain: trend.map { DateUtils.formatYearMonthShort($0.yearMonth) })
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(Color.appMutedForeground)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    // Tap-to-open: tapping a column pins its detail popover, which
                    // then stays put and only dismisses when the user taps outside
                    // it (system-managed, matching the budget card's info popover).
                    // Nothing here changes the dashboard's month — a graze of the
                    // chart used to teleport the whole screen.
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if let ym = month(at: value.location, proxy: proxy, geo: geo) {
                                    popoverAnchor = CGRect(origin: value.location, size: CGSize(width: 1, height: 1))
                                    activeYearMonth = ym
                                }
                            }
                    )
            }
        }
        .popover(
            isPresented: Binding(
                get: { activeYearMonth != nil },
                set: { if !$0 { activeYearMonth = nil } }
            ),
            attachmentAnchor: .rect(.rect(popoverAnchor)),
            arrowEdge: .top
        ) { touchDetail }
    }

    /// One month/series column. The focused month is emphasized while the rest
    /// recede, keeping the chart anchored to the month navigator above it.
    private func bar(for point: CashflowTrendPoint, series: String, group: String, amount: Int64) -> some ChartContent {
        BarMark(
            x: .value("Month", DateUtils.formatYearMonthShort(point.yearMonth)),
            y: .value("Amount", CurrencyUtils.toDisplayAmount(amount, currency: currencyCode))
        )
        // Color carries series identity (Income / Planned / Unplanned); position
        // groups the two expense series into one shared column so they stack,
        // while income sits in its own column beside them.
        .foregroundStyle(by: .value("Type", series))
        .position(by: .value("Group", group))
        .opacity(point.yearMonth == selectedYearMonth ? 1 : 0.4)
        .cornerRadius(3)
    }

    /// Maps a touch location to the `year_month` of the column under it.
    private func month(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> String? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let relativeX = location.x - geo[plotFrame].origin.x
        guard let label = proxy.value(atX: relativeX, as: String.self) else { return nil }
        return trend.first { DateUtils.formatYearMonthShort($0.yearMonth) == label }?.yearMonth
    }

    // MARK: - Headline (what the chart is trying to say, in words)

    /// The selected month's spend and how it sits against recent history, so the
    /// card answers "is this month unusual?" without anyone having to touch it or
    /// eyeball six columns. Direction is carried by an arrow glyph as well as
    /// color, since "over budget" must not be a red-only signal.
    @ViewBuilder
    private var summary: some View {
        if let current = selectedExpense {
            VStack(alignment: .leading, spacing: 4) {
                Text("Expenses in \(DateUtils.formatYearMonthShort(selectedYearMonth))")
                    .font(.caption)
                    .foregroundStyle(Color.appMutedForeground)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(CurrencyUtils.format(current, currency: currencyCode, decimalPlaces: fractionDigits))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.appCardForeground)
                        .contentTransition(.numericText())
                    deltaChip
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// Spending *more* than usual is the bad direction, so an increase is danger
    /// and a decrease is success — the inverse of a portfolio chart, and the one
    /// place in the app where "up" is not good news.
    @ViewBuilder
    private var deltaChip: some View {
        if let delta = expenseDeltaPercent {
            let rising = delta > 0
            let flat = delta == 0
            let color: Color = flat ? .appMutedForeground : (rising ? .appDanger : .appSuccess)
            let symbol = flat ? "equal" : (rising ? "arrow.up.right" : "arrow.down.right")
            let phrase = flat ? "in line with" : (rising ? "above" : "below")

            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                if !flat {
                    Text("\(abs(delta))%")
                        .font(.caption.weight(.semibold))
                }
                Text("vs \(priorMonths.count)-mo avg")
                    .font(.caption)
            }
            .foregroundStyle(color)
            .accessibilityLabel(
                flat
                    ? "In line with the prior \(priorMonths.count) month average"
                    : "\(abs(delta)) percent \(phrase) the prior \(priorMonths.count) month average"
            )
        }
    }

    // MARK: - Legend (always present)

    /// The three-series legend, so the stacked expense column never leans on
    /// color alone. Identity = legend + fixed stack order (planned base, unplanned
    /// on top).
    private var legend: some View {
        HStack(spacing: 12) {
            swatch(label: incomeLabel, color: .appSuccess)
            swatch(label: plannedLabel, color: .appWarning)
            swatch(label: unplannedLabel, color: .appDanger)
        }
    }

    private func swatch(label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.appMutedForeground)
        }
    }

    // MARK: - Touch detail (income / expense / net for the touched month)

    @ViewBuilder
    private var touchDetail: some View {
        if let ym = activeYearMonth,
           let point = trend.first(where: { $0.yearMonth == ym }) {
            let positiveNet = point.net >= 0
            // A Grid rather than HStack+Spacer rows: the label and amount columns
            // each size to their widest cell, so a long label ("Unplanned") can't
            // be squeezed into truncation by a long amount the way a Spacer-driven
            // row allows. Keeps the amounts aligned in a single trailing column.
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                GridRow {
                    Text(DateUtils.formatYearMonth(point.yearMonth))
                        .font(.headline)
                        .foregroundStyle(Color.appCardForeground)
                        .gridCellColumns(2)
                }
                detailRow(label: incomeLabel, color: .appSuccess, amount: point.income)
                detailRow(label: plannedLabel, color: .appWarning, amount: point.plannedExpense)
                detailRow(label: unplannedLabel, color: .appDanger, amount: point.unplannedExpense)
                // A non-GridRow child automatically spans every column.
                Divider()
                GridRow {
                    Text("Net")
                        .font(.subheadline)
                        .foregroundStyle(Color.appMutedForeground)
                        .fixedSize()
                    Text("\(positiveNet ? "+" : "-")\(CurrencyUtils.format(abs(point.net), currency: currencyCode, decimalPlaces: fractionDigits))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(positiveNet ? Color.appSuccess : Color.appDanger)
                        .gridColumnAlignment(.trailing)
                        .fixedSize()
                }
            }
            .padding()
            // Floor so short months still read as a card; the Grid grows past this
            // on its own when the content (or a large Dynamic Type size) needs it.
            .frame(minWidth: 240, alignment: .leading)
            // Keep it a popover in compact size classes (iPhone) rather than
            // degrading to a full-screen sheet. Requires iOS 16.4+; the app
            // targets iOS 26.1+.
            .presentationCompactAdaptation(.popover)
        }
    }

    /// One `series — amount` row of the detail grid. Both cells are `.fixedSize`
    /// so they always render at full intrinsic width: the label is never clipped
    /// to "Unplann…", and the grid column simply widens instead.
    private func detailRow(label: String, color: Color, amount: Int64) -> some View {
        GridRow {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.appMutedForeground)
            }
            .fixedSize()
            Text(CurrencyUtils.format(amount, currency: currencyCode, decimalPlaces: fractionDigits))
                .font(.subheadline)
                .foregroundStyle(Color.appCardForeground)
                .gridColumnAlignment(.trailing)
                .fixedSize()
        }
    }
}
