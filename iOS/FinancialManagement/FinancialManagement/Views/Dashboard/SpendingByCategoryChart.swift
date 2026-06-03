import SwiftUI
import Charts

struct SpendingByCategoryChart: View {
    let data: [CategorySpending]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)

            Chart(data, id: \.categoryId) { item in
                SectorMark(
                    angle: .value("Amount", item.totalAmount),
                    innerRadius: .ratio(0.6),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("Category", item.categoryName))
            }
            .frame(height: 200)

            ForEach(data, id: \.categoryId) { item in
                HStack {
                    Text(item.categoryName)
                        .font(.subheadline)
                    Spacer()
                    Text(item.totalAmount.asCurrency(code: currencyCode))
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
