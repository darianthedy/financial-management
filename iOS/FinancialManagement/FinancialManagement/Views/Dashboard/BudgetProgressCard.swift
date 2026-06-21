import SwiftUI

/// Dashboard summary of the month's budgets, read from `v_budget_progress`:
/// each row shows net spent vs. effective amount (periodic + carry-in) with a
/// carry-over note when present.
struct BudgetProgressCard: View {
    let progress: [BudgetProgress]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Progress")
                .font(.headline)

            ForEach(progress) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.budgetName)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.spent.asCurrency(code: currencyCode)) / \(item.effectiveAmount.asCurrency(code: currencyCode))")
                            .font(.subheadline.bold())
                    }

                    if item.carryOverAmount != 0 {
                        let positive = item.carryOverAmount > 0
                        Text("\(positive ? "+" : "")\(item.carryOverAmount.asCurrency(code: currencyCode)) \(positive ? "carried over" : "overspent")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background((positive ? Color.green : Color.red).opacity(0.1))
                            .clipShape(Capsule())
                    }

                    ProgressView(value: fraction(item))
                        .tint(item.remaining < 0 ? .red : .blue)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fraction(_ item: BudgetProgress) -> Double {
        guard item.effectiveAmount > 0 else { return item.spent > 0 ? 1 : 0 }
        return min(max(Double(item.spent) / Double(item.effectiveAmount), 0), 1)
    }
}
