import SwiftUI

struct BudgetCard: View {
    let budget: Budget
    let period: BudgetPeriod?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budget.name)
                    .font(.headline)

                if budget.enableCarryOver {
                    Text("Carry-over")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                Spacer()

                if let period {
                    Text(period.effectiveAmount.asCurrency(code: period.currency))
                        .font(.subheadline.bold())
                }
            }

            if let period {
                if period.carryOverAmount != 0 {
                    HStack(spacing: 4) {
                        Text("Base: \(period.periodicAmount.asCurrency(code: period.currency))")
                        Text("•")
                        Text("Carry-over: \(period.carryOverAmount.asCurrency(code: period.currency))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                ProgressView(value: 0.5)
                    .tint(progressColor(0.5))
            } else {
                Text("No budget set for this month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress < 0.75 { return .green }
        if progress < 0.9 { return .yellow }
        return .red
    }
}
