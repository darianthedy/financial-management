import SwiftUI

/// Unplanned Expenses widget (iOS Tech Plan §8.1): confirmed expenses for the
/// month with no budget and no fixed-expense link, aggregated by category
/// (null → "Uncategorized") and sorted by amount.
///
/// Mirrors web's `unplanned-expenses.tsx`: a "Total unplanned" row on top, then
/// the per-category list with a leading emoji (category icon, `📊` fallback, or
/// `❓` for the italic, muted "Uncategorized" row).
struct UnplannedExpensesCard: View {
    let groups: [UnplannedGroup]
    let currencyCode: String

    private var total: Int64 { groups.reduce(Int64(0)) { $0 + $1.total } }

    var body: some View {
        DashboardCard(title: "Unplanned Expenses") {
            if groups.isEmpty {
                DashboardCardEmptyState(
                    title: "Nothing unplanned",
                    message: "Every expense this month is covered by a budget or fixed expense."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Total unplanned")
                            .font(.subheadline)
                            .foregroundStyle(Color.appMutedForeground)
                        Spacer()
                        Text(total.asCurrency(code: currencyCode))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.appCardForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    VStack(spacing: 8) {
                        ForEach(groups) { group in
                            row(group)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ group: UnplannedGroup) -> some View {
        let uncategorized = group.categoryId == nil
        HStack(spacing: 8) {
            Text(group.icon ?? (uncategorized ? "❓" : "📊"))

            Text(group.categoryName)
                .font(.subheadline.weight(uncategorized ? .regular : .medium))
                .italic(uncategorized)
                .foregroundStyle(uncategorized ? Color.appMutedForeground : Color.appCardForeground)
                .lineLimit(1)

            Spacer()

            Text(group.total.asCurrency(code: currencyCode))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.appCardForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
