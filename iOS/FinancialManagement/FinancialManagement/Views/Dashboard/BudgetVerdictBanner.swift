import SwiftUI

/// One-line verdict on the month's budgets, read from `v_budget_progress`:
/// counts budgets with `remaining < 0` and sums the overage. Green when every
/// budget is on track, red otherwise. Hidden entirely when there are no budgets
/// (iOS Tech Plan §8.1, System Design §4.6).
struct BudgetVerdictBanner: View {
    let budgets: [BudgetProgress]
    let currencyCode: String

    private var overBudgets: [BudgetProgress] { budgets.filter { $0.remaining < 0 } }
    private var totalOverage: Int64 { overBudgets.reduce(Int64(0)) { $0 + (-$1.remaining) } }

    var body: some View {
        if !budgets.isEmpty {
            let onTrack = overBudgets.isEmpty
            HStack(spacing: 12) {
                Image(systemName: onTrack ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(onTrack ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(onTrack ? "On track" : "Over budget")
                        .font(.headline)
                    Text(onTrack
                         ? "All \(budgets.count) budget\(budgets.count == 1 ? "" : "s") within limit"
                         : "\(overBudgets.count) over by \(totalOverage.asCurrency(code: currencyCode))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()
            }
            .padding()
            .background((onTrack ? Color.green : Color.red).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
