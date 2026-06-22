import SwiftUI

/// A single fixed expense. Paid status is derived (passed in) — there is no
/// per-row currency and no day-of-month, so the row shows just name + amount
/// with a paid indicator. Mirrors web's `fixed-expense-row.tsx`: a leading
/// `CheckCircle2` (success) when paid or a `Clock` (muted) when unpaid, a
/// medium-weight name (no strikethrough on web) and a semibold amount, all on
/// design tokens.
struct FixedExpenseRow: View {
    let expense: FixedExpense
    let isPaid: Bool
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPaid ? "checkmark.circle.fill" : "clock")
                .font(.body)
                .foregroundStyle(isPaid ? Color.appSuccess : Color.appMutedForeground)

            Text(expense.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.appForeground)

            Spacer()

            Text(expense.amount.asCurrency(code: currencyCode))
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.appForeground)
        }
        .padding(.vertical, 2)
    }
}
