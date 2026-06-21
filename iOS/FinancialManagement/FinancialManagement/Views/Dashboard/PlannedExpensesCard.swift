import SwiftUI

/// Planned Expenses widget (iOS Tech Plan §8.1): budgets with **pace-aware**
/// bars (fill colored by the projected month-end at the current spend pace, plus
/// a tick at the linear-pace position) and the month's fixed expenses split into
/// Unpaid / Paid with subtotals. Headline = Σ budget `effective_amount` +
/// Σ fixed-expense `amount`, shown as a vertical-stacked money row (§9.2).
struct PlannedExpensesCard: View {
    let budgets: [BudgetProgress]
    let fixedExpenses: [FixedExpense]
    let paidFixedExpenseIds: Set<UUID>
    let yearMonth: String
    let currencyCode: String

    private var headline: Int64 {
        budgets.reduce(Int64(0)) { $0 + $1.effectiveAmount }
            + fixedExpenses.reduce(Int64(0)) { $0 + $1.amount }
    }

    private var unpaid: [FixedExpense] { fixedExpenses.filter { !paidFixedExpenseIds.contains($0.id) } }
    private var paid: [FixedExpense] { fixedExpenses.filter { paidFixedExpenseIds.contains($0.id) } }

    /// Fraction of the selected month already elapsed: 0 for a future month,
    /// 1 for a past month, partial for the current month. Drives the pace tick
    /// and the projected-spend coloring.
    private var elapsedFraction: Double {
        guard let range = DateUtils.monthDateRange(yearMonth),
              let interval = Calendar.current.dateInterval(of: .month, for: range.start)
        else { return 1 }
        let now = Date()
        if now <= interval.start { return 0 }
        if now >= interval.end { return 1 }
        return now.timeIntervalSince(interval.start) / interval.duration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Planned Expenses")
                .font(.headline)

            moneyRow(label: "Total planned", icon: "calendar", amount: headline)

            if budgets.isEmpty && fixedExpenses.isEmpty {
                Text("Nothing planned this month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !budgets.isEmpty {
                Divider()
                ForEach(budgets) { budget in
                    budgetRow(budget)
                }
            }

            if !fixedExpenses.isEmpty {
                Divider()
                fixedSection(title: "Unpaid", items: unpaid)
                fixedSection(title: "Paid", items: paid)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Headline (§9.2 vertical-stacked money row)

    private func moneyRow(label: String, icon: String, amount: Int64) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
            Spacer()
            Text(amount.asCurrency(code: currencyCode))
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Budgets (pace-aware bars)

    private func budgetRow(_ budget: BudgetProgress) -> some View {
        let fill = fraction(spent: budget.spent, of: budget.effectiveAmount)
        let color = paceColor(for: budget)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(budget.budgetName)
                    .font(.subheadline)
                Spacer()
                Text("\(budget.spent.asCurrency(code: currencyCode)) / \(budget.effectiveAmount.asCurrency(code: currencyCode))")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            paceBar(fill: fill, tick: elapsedFraction, color: color)
        }
    }

    private func fraction(spent: Int64, of effective: Int64) -> Double {
        guard effective > 0 else { return spent > 0 ? 1 : 0 }
        return min(max(Double(spent) / Double(effective), 0), 1)
    }

    /// Red once actually overspent; orange when the current pace projects an
    /// overspend by month-end; green when on track.
    private func paceColor(for budget: BudgetProgress) -> Color {
        if budget.remaining < 0 { return .red }
        guard elapsedFraction > 0 else { return .green }
        let projected = Double(budget.spent) / elapsedFraction
        return projected > Double(budget.effectiveAmount) ? .orange : .green
    }

    private func paceBar(fill: Double, tick: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))

                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * fill)

                // Linear-pace tick: where spend "should" be at this point.
                Rectangle()
                    .fill(Color.primary.opacity(0.4))
                    .frame(width: 2)
                    .offset(x: geo.size.width * min(max(tick, 0), 1))
            }
        }
        .frame(height: 8)
    }

    // MARK: - Fixed expenses (Unpaid / Paid with subtotals)

    @ViewBuilder
    private func fixedSection(title: String, items: [FixedExpense]) -> some View {
        if !items.isEmpty {
            let subtotal = items.reduce(Int64(0)) { $0 + $1.amount }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(subtotal.asCurrency(code: currencyCode))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                ForEach(items) { item in
                    HStack {
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        Text(item.amount.asCurrency(code: currencyCode))
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }
}
