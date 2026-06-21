import SwiftUI

/// One-line verdict on the month's budgets, read from `v_budget_progress`:
/// counts budgets with `remaining < 0` and sums the overage. Green when every
/// budget is on track, red otherwise. Hidden entirely when there are no budgets
/// (iOS Tech Plan §8.1, System Design §4.6).
///
/// Mirrors web's `verdict-banner.tsx`: a card with a 4pt left accent border
/// (success / danger), an outline status icon, a colored `text-base` headline
/// and a muted `text-sm` detail line.
struct BudgetVerdictBanner: View {
    let budgets: [BudgetProgress]
    let currencyCode: String

    private var overBudgets: [BudgetProgress] { budgets.filter { $0.remaining < 0 } }
    private var totalOverage: Int64 { overBudgets.reduce(Int64(0)) { $0 + (-$1.remaining) } }

    var body: some View {
        if !budgets.isEmpty {
            let onTrack = overBudgets.isEmpty
            let accent = onTrack ? Color.appSuccess : Color.appDanger
            HStack(spacing: 12) {
                Image(systemName: onTrack ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(headline(onTrack: onTrack))
                        .font(.headline)
                        .foregroundStyle(accent)
                    Text(detail(onTrack: onTrack))
                        .font(.subheadline)
                        .foregroundStyle(Color.appMutedForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()
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
                    .fill(accent)
                    .frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
    }

    private func headline(onTrack: Bool) -> String {
        if onTrack { return "On track" }
        let plural = overBudgets.count == 1 ? "" : "s"
        return "Overspending in \(overBudgets.count) budget\(plural) (−\(totalOverage.asCurrency(code: currencyCode)))"
    }

    private func detail(onTrack: Bool) -> String {
        if onTrack {
            let plural = budgets.count == 1 ? "" : "s"
            return "All \(budgets.count) budget\(plural) within target."
        }
        return "\(totalOverage.asCurrency(code: currencyCode)) over budget across the month."
    }
}
