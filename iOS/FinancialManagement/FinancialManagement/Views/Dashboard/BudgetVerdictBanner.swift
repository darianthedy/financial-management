import SwiftUI

/// The at-a-glance answer to "am I on track this month?", read from
/// `v_budget_progress` plus the month's fixed expenses. Renders one compact
/// status line per domain — budgets, and (when they diverge) paid fixed
/// expenses — each with its own icon, a colored label, and a short muted detail,
/// so the two read as parallel statuses rather than one buried under the other.
/// The card's left border takes the most severe tone present. Hidden entirely
/// when there is nothing to report (iOS Tech Plan §8.1, System Design §4.6).
///
/// Mirrors web's `verdict-banner.tsx`.
struct BudgetVerdictBanner: View {
    let budgets: [BudgetProgress]
    let fixedExpenses: [FixedExpense]
    /// Actual amount paid per fixed expense (Σ linked transactions), keyed by id.
    let paidFixedExpenseTotals: [UUID: Int64]
    let currencyCode: String

    private enum Tone {
        case success, danger, warning

        var color: Color {
            switch self {
            case .success: return .appSuccess
            case .danger: return .appDanger
            case .warning: return .appWarning
            }
        }

        /// Only the on-track (success) state reads as reassurance; everything
        /// else is a caution and shares the triangle.
        var icon: String {
            self == .success ? "checkmark.circle" : "exclamationmark.triangle"
        }
    }

    /// One at-a-glance status line: an icon (from tone), a colored label, and a
    /// muted detail.
    private struct StatusRow: Identifiable {
        let id = UUID()
        let tone: Tone
        let label: String
        let detail: String
    }

    // MARK: - Derivations

    private var overBudgets: [BudgetProgress] { budgets.filter { $0.remaining < 0 } }
    private var totalOverage: Int64 { overBudgets.reduce(Int64(0)) { $0 + (-$1.remaining) } }

    /// Paid fixed expenses whose actual amount differs from the plan.
    private var paidOffPlan: [(expense: FixedExpense, diff: Int64)] {
        fixedExpenses.compactMap { expense in
            guard let paid = paidFixedExpenseTotals[expense.id], paid != expense.amount
            else { return nil }
            return (expense, paid - expense.amount)
        }
    }
    private var netDiff: Int64 { paidOffPlan.reduce(Int64(0)) { $0 + $1.diff } }

    private var rows: [StatusRow] {
        var rows: [StatusRow] = []

        if !budgets.isEmpty {
            if overBudgets.isEmpty {
                let plural = budgets.count == 1 ? "" : "s"
                rows.append(StatusRow(
                    tone: .success,
                    label: "Budgets on track",
                    detail: "all \(budgets.count) budget\(plural) within target"
                ))
            } else {
                let plural = overBudgets.count == 1 ? "" : "s"
                rows.append(StatusRow(
                    tone: .danger,
                    label: "Overspending in \(overBudgets.count) budget\(plural)",
                    detail: "−\(totalOverage.asCurrency(code: currencyCode)) over"
                ))
            }
        }

        if !paidOffPlan.isEmpty {
            let plural = paidOffPlan.count == 1 ? "" : "s"
            let detail: String
            if netDiff == 0 {
                detail = "amounts differ"
            } else {
                let sign = netDiff > 0 ? "+" : "−"
                detail = "net \(sign)\(abs(netDiff).asCurrency(code: currencyCode))"
            }
            rows.append(StatusRow(
                tone: .warning,
                label: "\(paidOffPlan.count) fixed expense\(plural) off plan",
                detail: detail
            ))
        }

        return rows
    }

    /// The card border reflects the most severe row: danger > warning > success.
    private func borderTone(_ rows: [StatusRow]) -> Tone {
        if rows.contains(where: { $0.tone == .danger }) { return .danger }
        if rows.contains(where: { $0.tone == .warning }) { return .warning }
        return .success
    }

    // MARK: - Body

    var body: some View {
        let rows = rows
        if !rows.isEmpty {
            let border = borderTone(rows)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        Image(systemName: row.tone.icon)
                            .font(.body)
                            .foregroundStyle(row.tone.color)

                        (Text(row.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(row.tone.color)
                         + Text(" · \(row.detail)")
                            .font(.subheadline)
                            .foregroundColor(Color.appMutedForeground))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            )
            // Web's `border-l-4`: a 4pt accent stripe over the leading edge.
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(border.color)
                    .frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
    }
}
