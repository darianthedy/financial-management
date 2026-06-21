import SwiftUI

/// Dashboard Accounts card: each active, dashboard-visible account with its
/// balance as of the selected month (`fn_account_balances_at`, falling back to
/// `starting_balance`) plus the combined total (iOS Tech Plan §8.1).
///
/// Mirrors web's `accounts-card.tsx`: a "Total balance" row on top, then the
/// per-account list (no divider). Negative balances render in danger; every
/// figure is `text-sm` semibold.
struct AccountsCard: View {
    let accounts: [DashboardAccount]
    let currencyCode: String

    private var total: Int64 { accounts.reduce(Int64(0)) { $0 + $1.balance } }

    var body: some View {
        DashboardCard(title: "Accounts") {
            if accounts.isEmpty {
                DashboardCardEmptyState(
                    title: "No accounts yet",
                    message: "Add an account to track your balance here."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Total balance")
                            .font(.subheadline)
                            .foregroundStyle(Color.appMutedForeground)
                        Spacer()
                        amount(total, semibold: true)
                    }

                    VStack(spacing: 8) {
                        ForEach(accounts) { item in
                            HStack(spacing: 8) {
                                AccountAvatar(
                                    imageUrl: item.account.imageUrl,
                                    accountType: item.account.type,
                                    size: 28
                                )

                                Text(item.account.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)

                                Spacer()

                                amount(item.balance, semibold: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func amount(_ value: Int64, semibold: Bool) -> some View {
        Text(value.asCurrency(code: currencyCode))
            .font(.subheadline.weight(semibold ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(value < 0 ? Color.appDanger : Color.appCardForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
