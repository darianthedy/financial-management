import SwiftUI

/// Dashboard Accounts card: each active, dashboard-visible account with its
/// balance as of the selected month (`fn_account_balances_at`, falling back to
/// `starting_balance`) plus the combined total (iOS Tech Plan §8.1).
struct AccountsCard: View {
    let accounts: [DashboardAccount]
    let currencyCode: String

    private var total: Int64 { accounts.reduce(Int64(0)) { $0 + $1.balance } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.headline)

            if accounts.isEmpty {
                Text("No accounts on the dashboard.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(accounts) { item in
                    HStack(spacing: 12) {
                        AccountAvatar(
                            imageUrl: item.account.imageUrl,
                            accountType: item.account.type,
                            size: 32
                        )

                        Text(item.account.name)
                            .font(.subheadline)

                        Spacer()

                        Text(item.balance.asCurrency(code: currencyCode))
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
