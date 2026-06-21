import SwiftUI

/// A single fixed expense. Paid status is derived (passed in) — there is no
/// per-row currency and no day-of-month, so the row shows just name + amount
/// with a paid checkmark.
struct FixedExpenseRow: View {
    let expense: FixedExpense
    let isPaid: Bool
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isPaid ? .green : .secondary)

            Text(expense.name)
                .font(.body)
                .strikethrough(isPaid)

            Spacer()

            Text(expense.amount.asCurrency(code: currencyCode))
                .font(.body.monospacedDigit().bold())
        }
        .padding(.vertical, 2)
    }
}
