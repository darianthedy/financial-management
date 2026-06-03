import SwiftUI

struct CashflowCard: View {
    let income: Int64
    let expense: Int64
    let net: Int64
    let currencyCode: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Cash Flow")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                cashflowRow(
                    label: "Income",
                    icon: "arrow.down.circle.fill",
                    amount: income,
                    color: .green
                )

                cashflowRow(
                    label: "Expense",
                    icon: "arrow.up.circle.fill",
                    amount: expense,
                    color: .red
                )

                Divider()

                cashflowRow(
                    label: "Net",
                    icon: "equal.circle.fill",
                    amount: net,
                    color: net >= 0 ? .green : .red,
                    labelColor: .primary
                )
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func cashflowRow(
        label: String,
        icon: String,
        amount: Int64,
        color: Color,
        labelColor: Color? = nil
    ) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(labelColor ?? color)

            Spacer()

            Text(amount.asCurrency(code: currencyCode))
                .font(.title3.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
