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
    /// Actual amount paid per fixed expense (Σ linked transactions), keyed by id.
    /// A key's presence marks the expense as "paid".
    let paidFixedExpenseTotals: [UUID: Int64]
    let yearMonth: String
    let currencyCode: String
    let widestAmountBody: String

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
        fixedExpenses.filter { paidFixedExpenseTotals[$0.id] == nil }
            .sorted { $0.amount > $1.amount }
    }
    private var paid: [FixedExpense] {
        fixedExpenses.filter { paidFixedExpenseTotals[$0.id] != nil }
            .sorted { $0.amount > $1.amount }
    }

    /// What was actually paid for a fixed expense — the summed linked
    /// transactions, falling back to the plan if (unexpectedly) none are linked.
    private func paidTotal(for expense: FixedExpense) -> Int64 {
        paidFixedExpenseTotals[expense.id] ?? expense.amount
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
                        AmountColumnView(
                            minorUnits: headline,
                            currencyCode: currencyCode,
                            widestNumber: widestAmountBody
                        )
                        .font(.subheadline.weight(.semibold))
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
                                    accent: nil,
                                    isPaid: false
                                )
                            }
                            if !paid.isEmpty {
                                fixedSection(
                                    title: "Paid",
                                    icon: "checkmark.circle",
                                    items: paid,
                                    accent: Color.appSuccess,
                                    isPaid: true
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
                    AmountColumnView(
                        minorUnits: budget.spent,
                        currencyCode: currencyCode,
                        widestNumber: widestAmountBody
                    )
                    Text("/")
                    AmountColumnView(
                        minorUnits: eff,
                        currencyCode: currencyCode,
                        widestNumber: widestAmountBody
                    )
                }
                .font(.caption)
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

    /// A fixed-expense subsection (Unpaid / Paid). The Paid subtotal and rows use
    /// the **actual** amount paid (Σ linked transactions); Unpaid uses the plan.
    private func fixedSection(
        title: String,
        icon: String,
        items: [FixedExpense],
        accent: Color?,
        isPaid: Bool
    ) -> some View {
        let amount: (FixedExpense) -> Int64 = { isPaid ? paidTotal(for: $0) : $0.amount }
        let subtotal = items.reduce(Int64(0)) { $0 + amount($1) }
        let labelColor = accent ?? Color.appMutedForeground
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(labelColor)
                Spacer()
                AmountColumnView(
                    minorUnits: subtotal,
                    currencyCode: currencyCode,
                    widestNumber: widestAmountBody
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent ?? Color.appCardForeground)
            }

            ForEach(items) { item in
                if isPaid {
                    PaidFixedExpenseRow(
                        name: item.name,
                        planned: item.amount,
                        paid: paidTotal(for: item),
                        currencyCode: currencyCode,
                        widestAmountBody: widestAmountBody
                    )
                    .padding(.leading, 20)
                } else {
                    HStack {
                        Text(item.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        AmountColumnView(
                            minorUnits: item.amount,
                            currencyCode: currencyCode,
                            widestNumber: widestAmountBody
                        )
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(Color.appMutedForeground)
                    .padding(.leading, 20)
                }
            }
        }
    }
}

/// One row in the Paid fixed-expenses list. Shows the **actual** amount paid, and
/// when that diverges from the plan, a warning affordance that opens a compact
/// popover breaking down the planned amount and the (color-coded) difference.
private struct PaidFixedExpenseRow: View {
    let name: String
    let planned: Int64
    let paid: Int64
    let currencyCode: String
    let widestAmountBody: String

    @State private var showingDiff = false

    /// Signed gap between what was paid and what was planned. Positive means paid
    /// over plan (danger), negative means under (success).
    private var diff: Int64 { paid - planned }

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if diff != 0 {
                    Button { showingDiff = true } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.appWarning)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Paid amount differs from planned for \(name)")
                    .accessibilityHint("Shows the planned amount and the difference")
                    .popover(isPresented: $showingDiff,
                             attachmentAnchor: .rect(.bounds),
                             arrowEdge: .top) { diffPopover }
                }
            }

            Spacer()

            AmountColumnView(
                minorUnits: paid,
                currencyCode: currencyCode,
                widestNumber: widestAmountBody
            )
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color.appCardForeground)
    }

    private var diffPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 24) {
                Text("Planned")
                    .foregroundStyle(Color.appMutedForeground)
                Spacer()
                Text(planned.asCurrency(code: currencyCode))
                    .monospacedDigit()
            }
            HStack(spacing: 24) {
                Text("Difference")
                    .foregroundStyle(Color.appMutedForeground)
                Spacer()
                // Color carries direction (red = over plan, green = under), so no
                // +/− sign is needed.
                Text(abs(diff).asCurrency(code: currencyCode))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(diff > 0 ? Color.appDanger : Color.appSuccess)
            }
        }
        .font(.subheadline)
        .padding(12)
        // Keep it a compact popover on iPhone rather than a full-screen sheet
        // (iOS 16.4+; project targets newer).
        .presentationCompactAdaptation(.popover)
    }
}
