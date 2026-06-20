import SwiftUI

struct RecentTransactionsCard: View {
    @Environment(AppState.self) private var appState
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    TransactionListView()
                }
                .font(.subheadline)
            }

            ForEach(transactions) { txn in
                HStack {
                    Image(systemName: txn.type == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(txn.type == .income ? .green : .red)

                    VStack(alignment: .leading) {
                        Text(txn.description ?? txn.type.rawValue.capitalized)
                            .font(.subheadline)
                        Text(txn.transactionDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(txn.type == .income ? "+\(txn.amount.asCurrency(code: appState.defaultCurrency))" : "-\(txn.amount.asCurrency(code: appState.defaultCurrency))")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(txn.type == .income ? .green : .red)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
