import SwiftUI

/// Unplanned Expenses widget (iOS Tech Plan §8.1): confirmed expenses for the
/// month with no budget and no fixed-expense link, aggregated by category
/// (null → "Uncategorized") and sorted by amount. Money rows are vertical-
/// stacked (§9.2).
struct UnplannedExpensesCard: View {
    let groups: [UnplannedGroup]
    let currencyCode: String

    private var total: Int64 { groups.reduce(Int64(0)) { $0 + $1.total } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unplanned Expenses")
                .font(.headline)

            if groups.isEmpty {
                Text("No unplanned spending this month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups) { group in
                    HStack {
                        Text(group.categoryName)
                            .font(.subheadline)
                        Spacer()
                        Text(group.total.asCurrency(code: currencyCode))
                            .font(.subheadline.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Divider()

                HStack {
                    Text("Total")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(total.asCurrency(code: currencyCode))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
