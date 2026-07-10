import Charts
import SwiftUI

/// Dashboard Spending Trend card: income vs expenses across the trailing six
/// months, so the selected month reads in context ("is this month unusual?").
/// The focused month's columns are at full strength while the rest are dimmed,
/// and tapping any month navigates the whole dashboard there. Net is surfaced
/// while a column is touched. Confirmed transactions only, transfers excluded
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
    /// Jump the whole dashboard to a month when its column is tapped.
    let onSelectMonth: (String) -> Void

    /// The month currently under the finger (`year_month`), for the touch detail.
    @State private var activeYearMonth: String?

    // Identity colors follow the app's semantic language (matching the Cashflow
    // card): income = success, expense = danger. Carried into the chart as a
    // manual foreground-style scale so the legend and bars stay in lock-step.
    private let incomeLabel = "Income"
    private let expenseLabel = "Expenses"

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
                chart
                    .frame(height: 180)
                    .overlay(alignment: .top) { touchDetail }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(trend) { point in
            bar(for: point, label: incomeLabel, amount: point.income)
            bar(for: point, label: expenseLabel, amount: point.expense)
        }
        // Manual scale pins each series to its semantic color and drives series
        // identity; the built-in legend is hidden in favor of the title-row one.
        .chartForegroundStyleScale([
            incomeLabel: Color.appSuccess,
            expenseLabel: Color.appDanger,
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
                    // A zero-distance drag doubles as a tap that also tracks the
                    // touched column so the detail can follow the finger.
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                activeYearMonth = month(at: value.location, proxy: proxy, geo: geo)
                            }
                            .onEnded { value in
                                if let ym = month(at: value.location, proxy: proxy, geo: geo) {
                                    onSelectMonth(ym)
                                }
                                activeYearMonth = nil
                            }
                    )
            }
        }
    }

    /// One month/series column. The focused month is emphasized while the rest
    /// recede, keeping the chart anchored to the month navigator above it.
    private func bar(for point: CashflowTrendPoint, label: String, amount: Int64) -> some ChartContent {
        BarMark(
            x: .value("Month", DateUtils.formatYearMonthShort(point.yearMonth)),
            y: .value("Amount", CurrencyUtils.toDisplayAmount(amount, currency: currencyCode))
        )
        .foregroundStyle(by: .value("Type", label))
        .position(by: .value("Type", label))
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

    // MARK: - Legend (always present)

    /// The two-series legend, mirroring web's title-row swatches. Identity =
    /// legend + fixed in-group order, so the chart never leans on color alone.
    private var legend: some View {
        HStack(spacing: 12) {
            swatch(label: incomeLabel, color: .appSuccess)
            swatch(label: expenseLabel, color: .appDanger)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(DateUtils.formatYearMonth(point.yearMonth))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.appCardForeground)
                detailRow(label: incomeLabel, color: .appSuccess, amount: point.income)
                detailRow(label: expenseLabel, color: .appDanger, amount: point.expense)
                Divider()
                HStack(spacing: 16) {
                    Text("Net")
                        .font(.caption)
                        .foregroundStyle(Color.appMutedForeground)
                    Spacer()
                    Text("\(positiveNet ? "+" : "-")\(CurrencyUtils.format(abs(point.net), currency: currencyCode, decimalPlaces: fractionDigits))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(positiveNet ? Color.appSuccess : Color.appDanger)
                }
            }
            .padding(10)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .fixedSize()
            .allowsHitTesting(false)
        }
    }

    private func detailRow(label: String, color: Color, amount: Int64) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.appMutedForeground)
            }
            Spacer()
            Text(CurrencyUtils.format(amount, currency: currencyCode, decimalPlaces: fractionDigits))
                .font(.caption)
                .foregroundStyle(Color.appCardForeground)
        }
    }
}
