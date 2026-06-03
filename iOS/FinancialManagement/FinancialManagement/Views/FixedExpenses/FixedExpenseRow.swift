import SwiftUI

struct FixedExpenseRow: View {
    let expense: FixedExpense
    let isPaid: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isPaid ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name)
                    .font(.body)
                    .strikethrough(isPaid)
                Text("Due day \(expense.dueDay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(expense.amount.asCurrency(code: expense.currency))
                .font(.body.monospacedDigit().bold())
        }
        .padding(.vertical, 2)
    }
}
