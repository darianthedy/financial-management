import SwiftUI

/// Planned Expenses widget (iOS Tech Plan §8.1): budgets with **pace-aware**
/// bars (fill colored by the projected month-end at the current spend pace, plus
/// a tick at the linear-pace position) and the month's fixed expenses split into
/// Unpaid / Paid with subtotals.
///
/// Mirrors web's `planned-expenses.tsx`: headline `Total planned`
/// (Σ budget `effective − reserved` + Σ fixed-expense `amount`), then an
/// uppercase-captioned Budgets section (bars colored `primary`/`danger`) and a
/// Fixed Expenses section. Budgets are ordered by urgency (most-over first).
struct PlannedExpensesCard: View {
    let budgets: [BudgetProgress]
    let fixedExpenses: [FixedExpense]
    let paidFixedExpenseIds: Set<UUID>
    let yearMonth: String
    let currencyCode: String

    /// Effective budget after virtual-installment reservations (P1), matching
    /// web's `effective_amount - reserved`.
    private func effective(_ budget: BudgetProgress) -> Int64 {
        budget.effectiveAmount - budget.reserved
    }

    private var headline: Int64 {
        budgets.reduce(Int64(0)) { $0 + effective($1) }
            + fixedExpenses.reduce(Int64(0)) { $0 + $1.amount }
    }

    /// Budgets ordered by urgency, most-over first (web's `pctUsed` sort).
    private var sortedBudgets: [BudgetProgress] {
        budgets.sorted { pctUsed($0) > pctUsed($1) }
    }

    private func pctUsed(_ budget: BudgetProgress) -> Double {
        let eff = effective(budget)
        if eff > 0 { return Double(budget.spent) / Double(eff) }
        return budget.spent > 0 ? .infinity : 0
    }

    private var unpaid: [FixedExpense] {
        fixedExpenses.filter { !paidFixedExpenseIds.contains($0.id) }
            .sorted { $0.amount > $1.amount }
    }
    private var paid: [FixedExpense] {
        fixedExpenses.filter { paidFixedExpenseIds.contains($0.id) }
            .sorted { $0.amount > $1.amount }
    }

    private var isEmpty: Bool { budgets.isEmpty && fixedExpenses.isEmpty }

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

    // Only show the pace tick mid-month; at 0 (future) or 1 (past) it's noise.
    private var showPaceMarker: Bool { elapsedFraction > 0 && elapsedFraction < 1 }

    var body: some View {
        DashboardCard(title: "Planned Expenses") {
            if isEmpty {
                DashboardCardEmptyState(
                    title: "Nothing planned this month",
                    message: "Add a budget or a fixed expense to plan your spending."
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Total planned")
                            .font(.subheadline)
                            .foregroundStyle(Color.appMutedForeground)
                        Spacer()
                        Text(headline.asCurrency(code: currencyCode))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.appCardForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    if !budgets.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionCaption("Budgets")
                            ForEach(sortedBudgets) { budgetRow($0) }
                        }
                    }

                    if !fixedExpenses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionCaption("Fixed Expenses")
                            if !unpaid.isEmpty {
                                fixedSection(
                                    title: "Unpaid",
                                    icon: "clock",
                                    items: unpaid,
                                    accent: nil
                                )
                            }
                            if !paid.isEmpty {
                                fixedSection(
                                    title: "Paid",
                                    icon: "checkmark.circle",
                                    items: paid,
                                    accent: Color.appSuccess
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section caption (web: text-xs uppercase tracking-wide muted)

    private func sectionCaption(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.medium))
            .kerning(0.5)
            .foregroundStyle(Color.appMutedForeground)
    }

    // MARK: - Budgets (pace-aware bars)

    private func budgetRow(_ budget: BudgetProgress) -> some View {
        let eff = effective(budget)
        let overspent = budget.remaining < 0
        let canProject = elapsedFraction > 0 && eff > 0
        let projectedOver = canProject
            ? Double(budget.spent) / elapsedFraction > Double(eff)
            : overspent

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(budget.budgetName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 2) {
                    Text(budget.spent.asCurrency(code: currencyCode))
                    Text("/")
                    Text(eff.asCurrency(code: currencyCode))
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(overspent ? Color.appDanger : Color.appMutedForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }

            paceBar(
                fill: fraction(spent: budget.spent, of: eff),
                color: projectedOver ? Color.appDanger : Color.appPrimary
            )
        }
    }

    private func fraction(spent: Int64, of effective: Int64) -> Double {
        guard effective > 0 else { return spent > 0 ? 1 : 0 }
        return min(max(Double(spent) / Double(effective), 0), 1)
    }

    private func paceBar(fill: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appMuted)

                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * fill)

                // Linear-pace tick: where spend "should" be at this point.
                if showPaceMarker {
                    Rectangle()
                        .fill(Color.appCardForeground)
                        .frame(width: 2)
                        .offset(x: geo.size.width * min(max(elapsedFraction, 0), 1))
                }
            }
        }
        .frame(height: 6)
    }

    // MARK: - Fixed expenses (Unpaid / Paid with subtotals)

    private func fixedSection(
        title: String,
        icon: String,
        items: [FixedExpense],
        accent: Color?
    ) -> some View {
        let subtotal = items.reduce(Int64(0)) { $0 + $1.amount }
        let labelColor = accent ?? Color.appMutedForeground
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(labelColor)
                Spacer()
                Text(subtotal.asCurrency(code: currencyCode))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(accent ?? Color.appCardForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            ForEach(items) { item in
                HStack {
                    Text(item.name)
                        .font(.subheadline.weight(accent == nil ? .regular : .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(item.amount.asCurrency(code: currencyCode))
                        .font(.subheadline)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(accent == nil ? Color.appMutedForeground : Color.appCardForeground)
                .padding(.leading, 20)
            }
        }
    }
}
