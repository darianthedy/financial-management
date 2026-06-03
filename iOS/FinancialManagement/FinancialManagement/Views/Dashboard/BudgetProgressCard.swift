import SwiftUI

struct BudgetProgressCard: View {
    let periods: [BudgetPeriod]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Progress")
                .font(.headline)

            ForEach(periods) { period in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Budget")
                            .font(.subheadline)
                        Spacer()
                        Text(period.effectiveAmount.asCurrency(code: period.currency))
                            .font(.subheadline.bold())
                    }

                    if period.carryOverAmount != 0 {
                        Text("Includes \(period.carryOverAmount.asCurrency(code: period.currency)) carry-over")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    ProgressView(value: 0.5)
                        .tint(.blue)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
