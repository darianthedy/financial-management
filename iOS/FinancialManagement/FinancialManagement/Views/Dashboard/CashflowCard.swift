import SwiftUI

/// Dashboard Cashflow card: money in vs money out for the selected month —
/// income, expenses, and the net that answers "did I come out ahead?". A
/// proportion bar shows how much of the month's income the expenses consumed,
/// and a savings-rate chip (net ÷ income) summarizes it as one figure. Confirmed
/// transactions only, transfers excluded (see `v_monthly_cashflow`); a month with
/// no activity shows an empty state (iOS Tech Plan §8.1, System Design §4.6).
///
/// Mirrors web's `cashflow-card.tsx`. Per HIG the net conveys its sign with an
/// explicit "+"/"-", never color alone.
struct CashflowCard: View {
    let cashflow: MonthCashflow
    let currencyCode: String

    private var income: Int64 { cashflow.income }
    private var expense: Int64 { cashflow.expense }
    private var net: Int64 { cashflow.net }

    private var isEmpty: Bool { income == 0 && expense == 0 }
    private var positiveNet: Bool { net >= 0 }

    /// Share one number-slot width across income, expenses, and net so their
    /// symbols and digits line up into a tidy column, as elsewhere on the
    /// dashboard. Mirrors web's `widestCurrencyNumber`.
    private var widestAmountBody: String {
        let widest = max(abs(income), abs(expense), abs(net))
        return CurrencyUtils.numberBody(widest, currency: currencyCode)
    }

    /// Fraction of income the expenses ate up, clamped to a drawable 0…1. With no
    /// income but real spend, the bar reads full (money out with none in).
    private var spentFraction: Double {
        if income > 0 { return min(1, Double(expense) / Double(income)) }
        return expense > 0 ? 1 : 0
    }

    /// Savings rate only makes sense against real income.
    private var savingsRate: Int? {
        guard income > 0 else { return nil }
        return Int((Double(net) / Double(income) * 100).rounded())
    }

    var body: some View {
        DashboardCard(title: "Cashflow", accessory: { savingsChip }) {
            if isEmpty {
                DashboardCardEmptyState(
                    title: "No activity this month",
                    message: "Income and expenses for this month will show up here."
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 8) {
                        flowRow(
                            icon: "arrow.down.left",
                            iconColor: .appSuccess,
                            label: "Income",
                            amount: income,
                            amountColor: .appSuccess
                        )
                        flowRow(
                            icon: "arrow.up.right",
                            iconColor: .appDanger,
                            label: "Expenses",
                            amount: expense,
                            amountColor: .appDanger
                        )
                    }

                    proportionBar

                    Divider()

                    HStack(alignment: .firstTextBaseline) {
                        Text("Net")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appCardForeground)
                        Spacer()
                        AmountColumnView(
                            minorUnits: net,
                            // Net must read as positive/negative without relying on
                            // color alone (HIG: don't encode meaning in color only).
                            sign: net < 0 ? "-" : "+",
                            currencyCode: currencyCode,
                            widestNumber: widestAmountBody
                        )
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(positiveNet ? Color.appSuccess : Color.appDanger)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Rows

    private func flowRow(
        icon: String,
        iconColor: Color,
        label: String,
        amount: Int64,
        amountColor: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.appMutedForeground)
            Spacer()
            AmountColumnView(
                minorUnits: amount,
                currencyCode: currencyCode,
                widestNumber: widestAmountBody
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(amountColor)
        }
    }

    /// How much of this month's income the expenses consumed — a 6pt rounded
    /// muted track with a primary fill that turns danger when expenses meet or
    /// exceed income. Mirrors web's proportion bar.
    private var proportionBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appMuted)
                Capsule()
                    .fill(spentFraction >= 1 ? Color.appDanger : Color.appPrimary)
                    .frame(width: max(0, geo.size.width * spentFraction))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    // MARK: - Savings-rate chip

    /// Title-row chip summarizing net as a share of income, tinted green/red by
    /// sign. Only shown when there is real income to rate against.
    @ViewBuilder
    private var savingsChip: some View {
        if let rate = savingsRate {
            let tint = positiveNet ? Color.appSuccess : Color.appDanger
            Text("\(rate)% saved")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(tint.opacity(0.12), in: Capsule())
        }
    }
}
